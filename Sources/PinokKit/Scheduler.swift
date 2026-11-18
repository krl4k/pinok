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
    /// Плашка «Рабочий день закончится через …».
    func showDayEndWarning(endAt: Date, onPostpone: @escaping (Int) -> Void, onSkip: @escaping () -> Void)
    /// Экран конца рабочего дня со списком дел.
    func showDayEnd(_ session: DayEndSession, demo: Bool, completion: @escaping (DayEndOutcome) -> Void)
}

/// Настоящие окна и звуки.
@MainActor
final class LivePresenter: ReminderPresenter {
    private let nudge = NudgeController()
    private let breaks = BreakController()
    private let warning = WarningController()
    private let cursor = CursorCountdownController()
    private let dayEnd = DayEndController()
    private let dayEndWarning = DayEndWarningController()

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
    func showDayEndWarning(endAt: Date, onPostpone: @escaping (Int) -> Void, onSkip: @escaping () -> Void) {
        dayEndWarning.show(endAt: endAt, onPostpone: onPostpone, onSkip: onSkip)
    }
    func showDayEnd(_ session: DayEndSession, demo: Bool, completion: @escaping (DayEndOutcome) -> Void) {
        dayEndWarning.hide()
        dayEnd.show(session, demo: demo, completion: completion)
    }
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
    /// На экране список конца рабочего дня.
    private(set) var onDayEnd = false
    /// Рабочий день уже кончился, а список ещё не закрыт: напоминания и перерывы молчат.
    private(set) var dayEndActive = false
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
    /// Случайная добавка к разносу напоминаний (в тестах — 0).
    @ObservationIgnored private let jitter: () -> TimeInterval
    @ObservationIgnored private let detectBusy: @MainActor (AppSettings) -> BusyReason?

    @ObservationIgnored private var timer: Timer?
    @ObservationIgnored private var warnedFor: Date?
    @ObservationIgnored private var lastOverlay: Date?
    @ObservationIgnored private var knownIntervals: [UUID: Int] = [:]
    @ObservationIgnored private var tickCount = 0
    /// Состояние конца дня на сегодня (сбрасывается в новый день).
    @ObservationIgnored private var dayEndDay: Date?
    @ObservationIgnored private var dayEndWarned: Set<Int> = []
    @ObservationIgnored private(set) var dayEndShowAgainAt: Date?
    /// Конец дня перенесли («+30 мин», если очень занят) — новое время только на сегодня.
    private(set) var dayEndOverride: Date?
    /// Отметки в списке сохраняются, пока человек ходит их делать.
    @ObservationIgnored private(set) var dayEndSession: DayEndSession?

    /// Сколько ждать, пока пользователь допечатает (smart timing).
    static let typingGrace: TimeInterval = 2.5
    static let maxNudgeDefer: TimeInterval = 20
    static let maxBreakDefer: TimeInterval = 30
    /// После любого показа следующее напоминание ждёт минимум 5 минут, даже если его срок уже наступил.
    static let spacing: TimeInterval = 300
    /// При планировании напоминания тоже не ставим ближе 5 минут друг к другу (+ до 2 минут случайно).
    static let minGap: TimeInterval = spacing
    static let maxJitter: TimeInterval = 120

    init(settings: AppSettings? = nil,
         stats: Stats? = nil,
         presenter: ReminderPresenter? = nil,
         clock: @escaping () -> Date = Date.init,
         idleSeconds: @escaping () -> TimeInterval = Scheduler.systemIdleSeconds,
         frontApp: (@MainActor () -> String?)? = nil,
         jitter: (() -> TimeInterval)? = nil,
         detectBusy: (@MainActor (AppSettings) -> BusyReason?)? = nil) {
        self.settings = settings ?? .shared
        self.stats = stats ?? .shared
        self.presenter = presenter ?? LivePresenter()
        self.clock = clock
        self.idleSeconds = idleSeconds
        self.frontApp = frontApp ?? { Scheduler.frontmostAppID() }
        self.jitter = jitter ?? { TimeInterval.random(in: 0...Scheduler.maxJitter) }
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
            case .dayEnd: self?.dayEndSettingsChanged()
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
        nextFire[id] = spread(clock().addingTimeInterval(TimeInterval(item.interval * 60)), id: id, among: nextFire)
        knownIntervals[id] = item.interval
    }

    /// Сдвигает время напоминания, чтобы оно не шло вплотную к другим:
    /// если рядом (ближе `minGap`) уже есть другое — ставим после него на `minGap` + случайная добавка.
    func spread(_ date: Date, id: UUID, among fires: [UUID: Date]) -> Date {
        let others = fires.filter { $0.key != id }.map(\.value).sorted()
        var result = date
        var moved = true
        var guardCount = 0
        while moved && guardCount < 50 {
            moved = false
            guardCount += 1
            if let near = others.first(where: { abs($0.timeIntervalSince(result)) < Self.minGap }) {
                result = near.addingTimeInterval(Self.minGap + jitter())
                moved = true
            }
        }
        return result
    }

    /// Напоминания изменились в настройках: новые и изменённые — заново, удалённые — убрать.
    func syncReminders() {
        var updated: [UUID: Date] = [:]
        var fresh: [ScheduledItem] = []
        for item in scheduledItems {
            if let date = nextFire[item.id], knownIntervals[item.id] == item.interval {
                updated[item.id] = date
            } else {
                fresh.append(item)
            }
            knownIntervals[item.id] = item.interval
        }
        // Новые ставим по одному, разнося от уже стоящих — чтобы не пришли все разом.
        for item in fresh {
            let base = clock().addingTimeInterval(TimeInterval(item.interval * 60))
            updated[item.id] = spread(base, id: item.id, among: updated)
        }
        nextFire = updated
    }

    private func resetReminders() {
        nextFire = [:]
        knownIntervals = [:]
        syncReminders()
    }

    func resetBreak() {
        // `now` обновляем тут же: иначе до следующего тика строка меню считает от старого `now`
        // и на миг показывает 61m вместо 60m.
        now = clock()
        nextBreak = settings.breakEnabled
            ? now.addingTimeInterval(TimeInterval(settings.breakInterval * 60)) : nil
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
            guard now >= until else {
                // Пауза не отменяет конец рабочего дня. Но во время звонка и когда никого нет — ждём.
                if !isSuspended, !onBreak, !onDayEnd, idleSeconds() < TimeInterval(settings.idleMinutes * 60) {
                    _ = tickDayEnd(typing: false, canShow: { self.detectBusy(self.settings) == nil })
                }
                return
            }
            pausedUntil = nil
            resetAll()
        }
        if isSuspended || onBreak || onDayEnd { return }

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

        // Рабочий день кончился — перерывы и напоминания больше не нужны.
        if tickDayEnd(typing: typing, canShow: { true }) { return }

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

    // MARK: - Конец рабочего дня

    /// Когда заканчивается рабочий день в этот день. nil — функция выключена или день не рабочий.
    func dayEndDate(on date: Date) -> Date? {
        guard settings.dayEndEnabled else { return nil }
        let cal = Calendar.current
        guard settings.dayEndDays.contains(cal.component(.weekday, from: date)) else { return nil }
        return cal.date(bySettingHour: settings.dayEndTime / 60, minute: settings.dayEndTime % 60,
                        second: 0, of: date)
    }

    /// Сегодня рабочий день уже закрыт («Закончить день» или «Пропустить сегодня»).
    var isDayClosed: Bool {
        settings.dayEndClosedOn.map { Calendar.current.isDate($0, inSameDayAs: now) } ?? false
    }

    /// Ближайший конец рабочего дня сегодня — для панели. nil, если он уже прошёл или закрыт.
    var upcomingDayEnd: Date? {
        guard !isDayClosed, let end = todayDayEnd, end > now else { return nil }
        return end
    }

    /// Конец дня сегодня с учётом переноса.
    var todayDayEnd: Date? {
        guard let planned = dayEndDate(on: now) else { return nil }
        return dayEndOverride ?? planned
    }

    private var dayEndWarnings: [Int] {
        settings.dayEndWarnings.filter { $0 > 0 }
    }

    private func dayEndNewDayIfNeeded() {
        let day = Calendar.current.startOfDay(for: now)
        guard dayEndDay != day else { return }
        dayEndDay = day
        dayEndWarned = []
        dayEndShowAgainAt = nil
        dayEndSession = nil
        dayEndOverride = nil
    }

    /// Предупреждения и экран конца дня. Возвращает true, если рабочий день уже кончился.
    /// `canShow` проверяем только когда есть что показать (в паузе это проверка звонка).
    private func tickDayEnd(typing: Bool, canShow: () -> Bool) -> Bool {
        dayEndNewDayIfNeeded()
        guard !isDayClosed, let end = todayDayEnd else {
            if dayEndActive { dayEndActive = false }
            return false
        }
        let left = end.timeIntervalSince(now)
        if left <= 0 {
            if !dayEndActive { dayEndActive = true }
            let waitOver = dayEndShowAgainAt.map { now >= $0 } ?? true
            // Человек печатает — даём закончить фразу, как перед перерывом.
            let letFinish = typing && -left < Self.maxBreakDefer
            if waitOver, !letFinish, canShow() { showDayEnd() }
            return true
        }
        if dayEndActive { dayEndActive = false }
        // Несколько предупреждений сразу (Mac проснулся за 3 минуты до конца) — показываем одно.
        let due = dayEndWarnings.filter { left <= TimeInterval($0 * 60) && !dayEndWarned.contains($0) }
        if !due.isEmpty, canShow() {
            dayEndWarned.formUnion(due)
            presenter.showDayEndWarning(endAt: end,
                                        onPostpone: { [weak self] m in self?.postponeDayEnd(minutes: m) },
                                        onSkip: { [weak self] in self?.skipDayEnd() })
            presenter.playSound(settings.dayEndSound)
        }
        return false
    }

    /// Показать список конца дня. Отметки сохраняются между показами.
    func showDayEnd() {
        guard !onDayEnd, !onBreak else { return }
        presenter.hideHints()
        let session = dayEndSession ?? DayEndSession(items: settings.dayEndItems)
        dayEndSession = session
        onDayEnd = true
        dayEndActive = true
        presenter.playSound(settings.dayEndSound)
        presenter.showDayEnd(session, demo: false) { [weak self] outcome in
            self?.dayEndFinished(outcome)
        }
    }

    func dayEndFinished(_ outcome: DayEndOutcome) {
        onDayEnd = false
        switch outcome {
        case .later:
            dayEndShowAgainAt = clock().addingTimeInterval(TimeInterval(max(1, settings.dayEndSnooze) * 60))
        case .done:
            closeDay()
            pauseUntilTomorrow()
        case .skipped:
            closeDay()
            resetAll()
        case .postponed(let minutes):
            postponeDayEnd(minutes: minutes)
        }
    }

    /// «+N мин»: очень занят. До конца дня — прибавляем к его времени, после — к «сейчас».
    /// Пока ждём, напоминания и перерывы идут как обычно. Последнее предупреждение придёт снова.
    func postponeDayEnd(minutes: Int) {
        guard !isDayClosed, let end = todayDayEnd else { return }
        now = clock()
        let wasOver = end <= now
        let newEnd = max(end, now).addingTimeInterval(TimeInterval(minutes * 60))
        dayEndOverride = newEnd
        dayEndShowAgainAt = nil
        dayEndActive = false
        let left = newEnd.timeIntervalSince(now)
        dayEndWarned = Set(dayEndWarnings.filter { left <= TimeInterval($0 * 60) })
        // Пока список был на экране, перерывы стояли — начинаем их отсчёт заново.
        if wasOver { resetAll() }
    }

    /// «Пропустить сегодня» с плашки или из панели.
    func skipDayEnd() {
        guard !isDayClosed, !onDayEnd else { return }
        let wasOver = dayEndActive
        closeDay()
        if wasOver { resetAll() }
    }

    private func closeDay() {
        settings.dayEndClosedOn = clock()
        dayEndActive = false
        dayEndShowAgainAt = nil
        dayEndSession = nil
    }

    /// Показать список из панели, не дожидаясь «показать снова».
    func showDayEndNow() {
        dayEndShowAgainAt = nil
        showDayEnd()
    }

    func previewDayEnd() {
        guard !onDayEnd, !onBreak else { return }
        presenter.playSound(settings.dayEndSound)
        presenter.showDayEnd(DayEndSession(items: settings.dayEndItems), demo: true) { _ in }
    }

    /// Поменяли время, дни или включили функцию. Если время уже прошло — сегодня экран не показываем:
    /// человек сейчас в настройках, а не заканчивает работу. Уже начавшиеся предупреждения тоже не показываем.
    func dayEndSettingsChanged() {
        now = clock()
        dayEndNewDayIfNeeded()
        dayEndShowAgainAt = nil
        dayEndOverride = nil
        guard !onDayEnd, let end = dayEndDate(on: now) else {
            dayEndActive = false
            return
        }
        let left = end.timeIntervalSince(now)
        if left <= 0, !isDayClosed {
            settings.dayEndClosedOn = now
            dayEndSession = nil
        }
        dayEndWarned = Set(dayEndWarnings.filter { left <= TimeInterval($0 * 60) })
        dayEndActive = false
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
        if isHolding || isSuspended || isIdle || dayEndActive { return nil }
        if onBreak { return t("break") }
        // Только до перерыва: короткие напоминания идут без отсчёта.
        guard settings.breakEnabled, let nb = nextBreak else { return nil }
        let minutes = Int((nb.timeIntervalSince(now) / 60).rounded(.up))
        return minutes <= 1 ? t("<1m") : t("%ldm", minutes)
    }
}
