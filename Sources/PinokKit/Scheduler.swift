import AppKit
import CoreGraphics
import Observation

/// Что показывает приложение. В тестах подменяется на заглушку.
@MainActor
protocol ReminderPresenter: AnyObject {
    var isShowingNudge: Bool { get }
    func showNudge(_ reminders: [Reminder], duration: TimeInterval)
    func showBreak(seconds: Int, demo: Bool, completion: @escaping (BreakOutcome) -> Void)
    func showWarning(breakAt: Date, onSnooze: @escaping (Int) -> Void, onStartNow: @escaping () -> Void)
    func showCursorCountdown(breakAt: Date)
    func hideHints()
    func playSound(_ name: String)
}

/// Настоящие окна и звуки.
@MainActor
final class LivePresenter: ReminderPresenter {
    private let nudge = NudgeController()
    private let breaks = BreakController()
    private let warning = WarningController()
    private let cursor = CursorCountdownController()

    var isShowingNudge: Bool { nudge.isShowing }
    func showNudge(_ reminders: [Reminder], duration: TimeInterval) { nudge.show(reminders, duration: duration) }
    func showBreak(seconds: Int, demo: Bool, completion: @escaping (BreakOutcome) -> Void) {
        breaks.show(seconds: seconds, demo: demo, completion: completion)
    }
    func showWarning(breakAt: Date, onSnooze: @escaping (Int) -> Void, onStartNow: @escaping () -> Void) {
        warning.show(breakAt: breakAt, onSnooze: onSnooze, onStartNow: onStartNow)
    }
    func showCursorCountdown(breakAt: Date) { cursor.show(breakAt: breakAt) }
    func hideHints() { warning.hide(); cursor.hide() }
    func playSound(_ name: String) { Sounds.play(name) }
}

/// Сердце приложения: считает время до напоминаний и перерывов, ставит паузы,
/// следит за простоем, сном, звонками и полноэкранным видео.
@MainActor
@Observable
final class Scheduler {
    static let shared = Scheduler()

    /// Когда сработает каждое напоминание или набор из расписания.
    private(set) var nextFire: [UUID: Date] = [:]
    private(set) var nextBreak: Date?
    private(set) var pausedUntil: Date?
    private(set) var isIdle = false
    /// Почему всё остановлено: сон, экраны, блокировка, другой пользователь. Продолжаем, только когда причин нет.
    enum SuspendReason { case sleep, screens, session, locked }
    private(set) var suspendReasons: Set<SuspendReason> = []
    var isSuspended: Bool { !suspendReasons.isEmpty }
    private(set) var onBreak = false
    /// Напоминания придержаны: идёт звонок или полноэкранное видео.
    private(set) var busyReason: BusyReason?
    /// Обновляется каждую секунду, чтобы UI перерисовывал отсчёт.
    private(set) var now: Date

    @ObservationIgnored let settings: AppSettings
    @ObservationIgnored private let stats: Stats
    @ObservationIgnored private let presenter: ReminderPresenter
    @ObservationIgnored private let clock: () -> Date
    @ObservationIgnored private let idleSeconds: () -> TimeInterval
    @ObservationIgnored private let frontApp: @MainActor () -> String?
    @ObservationIgnored private let detectBusy: @MainActor (AppSettings) -> BusyReason?

    @ObservationIgnored private var timer: Timer?
    @ObservationIgnored private var warnedFor: Date?
    @ObservationIgnored private var lastOverlay: Date?
    @ObservationIgnored private var knownIntervals: [UUID: Int] = [:]
    @ObservationIgnored private var tickCount = 0

    /// Сколько ждать, пока пользователь допечатает (smart timing).
    static let typingGrace: TimeInterval = 2.5
    static let maxNudgeDefer: TimeInterval = 20
    static let maxBreakDefer: TimeInterval = 30
    /// Минимальная пауза между двумя напоминаниями подряд.
    static let spacing: TimeInterval = 45

    init(settings: AppSettings? = nil,
         stats: Stats? = nil,
         presenter: ReminderPresenter? = nil,
         clock: @escaping () -> Date = Date.init,
         idleSeconds: @escaping () -> TimeInterval = Scheduler.systemIdleSeconds,
         frontApp: (@MainActor () -> String?)? = nil,
         detectBusy: (@MainActor (AppSettings) -> BusyReason?)? = nil) {
        self.settings = settings ?? .shared
        self.stats = stats ?? .shared
        self.presenter = presenter ?? LivePresenter()
        self.clock = clock
        self.idleSeconds = idleSeconds
        self.frontApp = frontApp ?? { Scheduler.frontmostAppID() }
        self.detectBusy = detectBusy ?? { Scheduler.systemBusyReason($0) }
        self.now = clock()
    }

    var isPaused: Bool { pausedUntil != nil }
    /// Пауза вручную или умная пауза — в трее показываем ⏸.
    var isHolding: Bool { isPaused || busyReason != nil }

    /// Одиночные напоминания и включённые наборы.
    var scheduledItems: [ScheduledItem] {
        ScheduledItem.build(reminders: settings.reminders, sets: settings.sets)
    }

    func start() {
        resetAll()
        settings.onTimingChange = { [weak self] kind in
            switch kind {
            case .reminders: self?.syncReminders()
            case .breaks: self?.resetBreak()
            }
        }
        let t = Timer(timeInterval: 1, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.tick() }
        }
        RunLoop.main.add(t, forMode: .common)
        timer = t
        observeSystem()
    }

    // MARK: - Расписание

    func reset(_ id: UUID) {
        guard let item = scheduledItems.first(where: { $0.id == id }) else {
            nextFire[id] = nil
            return
        }
        nextFire[id] = clock().addingTimeInterval(TimeInterval(item.interval * 60))
        knownIntervals[id] = item.interval
    }

    /// Напоминания изменились в настройках: новые и изменённые — заново, удалённые — убрать.
    func syncReminders() {
        var updated: [UUID: Date] = [:]
        for item in scheduledItems {
            if let date = nextFire[item.id], knownIntervals[item.id] == item.interval {
                updated[item.id] = date
            } else {
                updated[item.id] = clock().addingTimeInterval(TimeInterval(item.interval * 60))
            }
            knownIntervals[item.id] = item.interval
        }
        nextFire = updated
    }

    private func resetReminders() {
        nextFire = [:]
        knownIntervals = [:]
        syncReminders()
    }

    func resetBreak() {
        nextBreak = settings.breakEnabled
            ? clock().addingTimeInterval(TimeInterval(settings.breakInterval * 60)) : nil
        warnedFor = nil
        presenter.hideHints()
    }

    func resetAll() {
        resetReminders()
        resetBreak()
    }

    func tick() {
        let previous = now
        now = clock()
        stats.rollover()
        countActiveTime(since: previous)

        if let until = pausedUntil {
            guard now >= until else { return }
            pausedUntil = nil
            resetAll()
        }
        if isSuspended || onBreak { return }

        // Простой: если никого нет за компьютером — ждём, по возвращении начинаем заново.
        let idle = idleSeconds()
        if idle >= TimeInterval(settings.idleMinutes * 60) {
            if !isIdle { isIdle = true; presenter.hideHints() }
            return
        }
        if isIdle {
            isIdle = false
            resetAll()
            return
        }

        // Умная пауза: звонок или полноэкранное видео (проверяем раз в 3 секунды).
        tickCount += 1
        if tickCount % 3 == 0 { updateBusy() }
        if busyReason != nil { return }

        // Smart timing: пока человек печатает — даём ему закончить.
        let typing = settings.smartTiming && idle < Self.typingGrace

        if let nb = nextBreak {
            let left = nb.timeIntervalSince(now)
            if settings.floatingCountdown, left <= 10 {
                presenter.showCursorCountdown(breakAt: nb)
            }
            if left <= 0 {
                if typing, -left < Self.maxBreakDefer { return }
                startBreak()
                return
            }
            let lead = TimeInterval(settings.breakWarning)
            if lead > 0, warnedFor != nb, left <= lead {
                warnedFor = nb
                presenter.showWarning(breakAt: nb,
                                      onSnooze: { [weak self] m in self?.snoozeBreak(minutes: m) },
                                      onStartNow: { [weak self] in self?.startBreak() })
            }
        }

        // Напоминания: за один тик показываем не больше одного.
        let due = scheduledItems
            .compactMap { item in nextFire[item.id].map { (item, $0) } }
            .filter { now >= $0.1 }
            .sorted { $0.1 < $1.1 }
        guard let (item, date) = due.first else { return }
        // На экране уже есть напоминание — ждём, пока оно закроется (не теряем этот показ).
        if presenter.isShowingNudge { return }
        if typing, now.timeIntervalSince(date) < Self.maxNudgeDefer { return }

        if let last = lastOverlay, now.timeIntervalSince(last) < Self.spacing {
            // Только что было другое напоминание — сдвигаем это.
            nextFire[item.id] = last.addingTimeInterval(Self.spacing)
            return
        }
        // Перерыв вот-вот начнётся — мягкое напоминание не нужно.
        let breakSoon = nextBreak.map { $0.timeIntervalSince(now) < 60 } ?? false
        if !breakSoon { show(item) }
        reset(item.id)
    }

    private func updateBusy() {
        let reason = detectBusy(settings)
        if reason != nil, busyReason == nil { presenter.hideHints() }
        if reason == nil, busyReason != nil { graceAfterBusy() }
        busyReason = reason
    }

    /// После звонка не обрушиваем всё накопившееся сразу — даём время и разносим.
    private func graceAfterBusy() {
        var slot = clock().addingTimeInterval(30)
        for (id, date) in nextFire.sorted(by: { $0.value < $1.value }) where date < slot {
            nextFire[id] = slot
            slot = slot.addingTimeInterval(Self.spacing)
        }
        if let nb = nextBreak, nb < slot.addingTimeInterval(30) {
            nextBreak = slot.addingTimeInterval(30)
            warnedFor = nil
        }
    }

    // MARK: - Действия

    /// Показать напоминание или набор и записать в статистику.
    func show(_ item: ScheduledItem, countInStats: Bool = true) {
        guard !onBreak, !presenter.isShowingNudge, !item.members.isEmpty else { return }
        lastOverlay = clock()
        presenter.showNudge(item.members, duration: TimeInterval(item.duration ?? settings.nudgeDuration))
        presenter.playSound(item.sound)
        if countInStats { item.members.forEach { stats.add($0.id) } }
    }

    /// «Напомнить сейчас» из меню — показывает и перезапускает таймер.
    func remindNow(_ id: UUID) {
        guard let item = scheduledItems.first(where: { $0.id == id }) else { return }
        show(item)
        reset(id)
    }

    func preview(_ reminder: Reminder) {
        show(ScheduledItem(id: reminder.id, title: reminder.displayTitle, interval: reminder.interval,
                           sound: reminder.sound, members: [reminder], isSet: false), countInStats: false)
    }

    func preview(_ set: ReminderSet) {
        let members = set.reminderIDs.compactMap { id in settings.reminders.first { $0.id == id } }
        show(ScheduledItem(id: set.id, title: set.name, interval: set.interval, sound: set.sound,
                           members: members, isSet: true, duration: set.shownFor), countInStats: false)
    }

    func startBreak() {
        guard !onBreak else { return }
        presenter.hideHints()
        onBreak = true
        presenter.playSound(settings.breakStartSound)
        presenter.showBreak(seconds: settings.breakDuration * 60, demo: false) { [weak self] outcome in
            self?.breakEnded(outcome)
        }
    }

    func breakEnded(_ outcome: BreakOutcome) {
        onBreak = false
        switch outcome {
        case .finished:
            presenter.playSound(settings.breakEndSound)
            stats.commitBreak()
            stats.addBreak()
            resetAll()
        case .skipped:
            stats.dropBreak()
            stats.addSkip()
            resetAll()
        case .snoozed(let minutes):
            stats.dropBreak()
            snoozeBreak(minutes: minutes)
            resetReminders()
        }
    }

    func previewBreak() {
        guard !onBreak else { return }
        presenter.playSound(settings.breakStartSound)
        presenter.showBreak(seconds: 10, demo: true) { [weak self] outcome in
            if case .finished = outcome, let self { self.presenter.playSound(self.settings.breakEndSound) }
        }
    }

    func snoozeBreak(minutes: Int) {
        presenter.hideHints()
        nextBreak = clock().addingTimeInterval(TimeInterval(minutes * 60))
        warnedFor = nil
        stats.addPostpone()
    }

    /// «+N мин» из трея: перерыв ещё не скоро, поэтому прибавляем к его времени, а не к «сейчас».
    func postponeBreak(minutes: Int) {
        guard let nb = nextBreak else { return }
        presenter.hideHints()
        nextBreak = max(nb, clock()).addingTimeInterval(TimeInterval(minutes * 60))
        warnedFor = nil
        stats.addPostpone()
    }

    /// Время за компьютером: считаем секунды между тиками, пока человек не ушёл (порог — настройка простоя).
    /// Сон и долгие разрывы (больше 5 с) не считаем.
    private func countActiveTime(since previous: Date) {
        guard !isSuspended else { return }
        if onBreak { stats.markBreak(); return }   // отрезок станет «перерывом», только если перерыв закончат
        // Тот же порог, что и для «тебя нет за компьютером»: чтение и видео без касаний тоже считаются.
        guard idleSeconds() < TimeInterval(settings.idleMinutes * 60) else {
            stats.endWorkStretch()
            return
        }
        let delta = now.timeIntervalSince(previous)
        guard delta > 0 else { return }
        guard delta <= 5 else {
            // Долгий разрыв (сон, зависание) — отрезок работы закончился.
            stats.endWorkStretch()
            return
        }
        stats.addActive(Int(delta.rounded()), app: frontApp())
    }

    /// Bundle id приложения впереди (сам Pinok не считаем).
    static func frontmostAppID() -> String? {
        guard let id = NSWorkspace.shared.frontmostApplication?.bundleIdentifier,
              id != Bundle.main.bundleIdentifier else { return nil }
        return id
    }

    /// «Пропустить следующий перерыв» — сдвигаем его на целый интервал.
    func skipNextBreak() {
        guard let nb = nextBreak else { return }
        presenter.hideHints()
        nextBreak = nb.addingTimeInterval(TimeInterval(settings.breakInterval * 60))
        warnedFor = nil
        stats.addSkip()
    }

    func pause(for interval: TimeInterval) {
        pausedUntil = clock().addingTimeInterval(interval)
        presenter.hideHints()
    }

    func pauseUntilTomorrow() {
        let cal = Calendar.current
        pausedUntil = cal.date(byAdding: .day, value: 1, to: cal.startOfDay(for: clock()))
        presenter.hideHints()
    }

    func resume() {
        pausedUntil = nil
        resetAll()
    }

    // MARK: - Сон и блокировка

    private func observeSystem() {
        let ws = NSWorkspace.shared.notificationCenter
        let pairs: [(Notification.Name, Notification.Name, SuspendReason)] = [
            (NSWorkspace.willSleepNotification, NSWorkspace.didWakeNotification, .sleep),
            (NSWorkspace.screensDidSleepNotification, NSWorkspace.screensDidWakeNotification, .screens),
            (NSWorkspace.sessionDidResignActiveNotification, NSWorkspace.sessionDidBecomeActiveNotification, .session),
        ]
        for (off, on, reason) in pairs {
            ws.addObserver(forName: off, object: nil, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated { self?.suspend(reason) }
            }
            ws.addObserver(forName: on, object: nil, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated { self?.wake(reason) }
            }
        }

        let dnc = DistributedNotificationCenter.default()
        dnc.addObserver(forName: .init("com.apple.screenIsLocked"), object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.suspend(.locked) }
        }
        dnc.addObserver(forName: .init("com.apple.screenIsUnlocked"), object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.wake(.locked) }
        }
    }

    func suspend(_ reason: SuspendReason = .sleep) {
        suspendReasons.insert(reason)
        presenter.hideHints()
        stats.endWorkStretch()
        stats.save()
    }

    /// Продолжаем только когда ушли все причины: экран проснулся на экране входа — ещё рано.
    func wake(_ reason: SuspendReason = .sleep) {
        guard suspendReasons.remove(reason) != nil, suspendReasons.isEmpty else { return }
        resetAll()
    }

    // MARK: - Системные источники

    nonisolated static func systemIdleSeconds() -> TimeInterval {
        CGEventSource.secondsSinceLastEventType(.combinedSessionState, eventType: CGEventType(rawValue: ~0)!)
    }

    static func systemBusyReason(_ settings: AppSettings) -> BusyReason? {
        if settings.pauseOnCalls, SmartPause.isMicInUse() || SmartPause.isCameraInUse() { return .call }
        if settings.pauseOnVideo, SmartPause.isFullscreenVideo() { return .video }
        return nil
    }

    // MARK: - Тексты для меню

    func remaining(until date: Date?) -> String? {
        date.map { formatCountdown($0.timeIntervalSince(now)) }
    }

    /// Для меню: время считаем на момент открытия и НЕ подписываемся на ежесекундный `now`.
    /// Иначе открытое меню перерисовывается каждую секунду и у пунктов ломается подсветка.
    func remainingAtOpen(until date: Date?) -> String? {
        date.map { formatCountdown($0.timeIntervalSince(clock())) }
    }

    /// Текст рядом с иконкой в трее: минуты до ближайшего события.
    var menuBarText: String? {
        if isHolding || isSuspended || isIdle { return nil }
        if onBreak { return t("break") }
        // Только до перерыва: короткие напоминания идут без отсчёта.
        guard settings.breakEnabled, let nb = nextBreak else { return nil }
        let minutes = Int((nb.timeIntervalSince(now) / 60).rounded(.up))
        return minutes <= 1 ? t("<1m") : t("%ldm", minutes)
    }
}
