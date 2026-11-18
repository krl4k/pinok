import SwiftUI
import Observation

enum TimingKind { case reminders, breaks, dayEnd }

enum ArrowColor: String, CaseIterable, Identifiable {
    case white, mint, blue, orange

    var id: String { rawValue }

    var title: String {
        switch self {
        case .white: t("White")
        case .mint: t("Mint")
        case .blue: t("Blue")
        case .orange: t("Orange")
        }
    }

    var color: Color {
        switch self {
        case .white: .white
        case .mint: Color(red: 0.45, green: 0.95, blue: 0.80)
        case .blue: Color(red: 0.45, green: 0.72, blue: 1.00)
        case .orange: Color(red: 1.00, green: 0.72, blue: 0.38)
        }
    }
}

/// Все настройки приложения. Хранятся в UserDefaults.
@MainActor
@Observable
final class AppSettings {
    static let shared = AppSettings()

    /// Вызывается, когда меняется что-то, что влияет на расписание.
    @ObservationIgnored var onTimingChange: ((TimingKind) -> Void)?
    @ObservationIgnored private let d: UserDefaults

    // MARK: Общие
    var language: AppLanguage { didSet { d.set(language.rawValue, forKey: "language"); L10n.apply(language) } }
    var showCountdown: Bool { didSet { d.set(showCountdown, forKey: "showCountdown") } }
    var volume: Double { didSet { d.set(volume, forKey: "volume") } }
    /// Общий выключатель всех звуков Pinok.
    var soundsEnabled: Bool { didSet { d.set(soundsEnabled, forKey: "soundsEnabled") } }
    var idleMinutes: Int { didSet { d.set(idleMinutes, forKey: "idleMinutes") } }
    /// Экран приветствия уже показан.
    var onboardingDone: Bool { didSet { d.set(onboardingDone, forKey: "onboardingDone") } }
    /// Звук заставки (экран приветствия).
    var introSound: String { didSet { d.set(introSound, forKey: "introSound") } }
    /// Вибрация трекпада.
    var haptics: Bool { didSet { d.set(haptics, forKey: "haptics") } }

    // MARK: Умное поведение
    /// Не прерывать, пока пользователь печатает или тащит что-то мышью.
    var smartTiming: Bool { didSet { d.set(smartTiming, forKey: "smartTiming") } }
    var pauseOnCalls: Bool { didSet { d.set(pauseOnCalls, forKey: "pauseOnCalls") } }
    var pauseOnVideo: Bool { didSet { d.set(pauseOnVideo, forKey: "pauseOnVideo") } }

    // MARK: Напоминания
    var reminders: [Reminder] {
        didSet {
            if let data = try? JSONEncoder().encode(reminders) { d.set(data, forKey: "reminders") }
            onTimingChange?(.reminders)
        }
    }

    var sets: [ReminderSet] {
        didSet {
            if let data = try? JSONEncoder().encode(sets) { d.set(data, forKey: "sets") }
            onTimingChange?(.reminders)
        }
    }

    // MARK: Вид напоминаний (общий для всех)
    var nudgeDim: Double { didSet { d.set(nudgeDim, forKey: "nudgeDim") } }
    var nudgeBlur: Double { didSet { d.set(nudgeBlur, forKey: "nudgeBlur") } }
    var arrowColor: ArrowColor { didSet { d.set(arrowColor.rawValue, forKey: "arrowColor") } }
    var arrowWidth: Double { didSet { d.set(arrowWidth, forKey: "arrowWidth") } }
    var arrowStyle: ArrowStyle { didSet { d.set(arrowStyle.rawValue, forKey: "arrowStyle") } }
    var nudgeAllScreens: Bool { didSet { d.set(nudgeAllScreens, forKey: "nudgeAllScreens") } }
    /// Сколько секунд напоминание на экране.
    var nudgeDuration: Int { didSet { d.set(nudgeDuration, forKey: "nudgeDuration") } }

    // MARK: Перерыв
    var breakEnabled: Bool { didSet { d.set(breakEnabled, forKey: "breakEnabled"); onTimingChange?(.breaks) } }
    var breakInterval: Int { didSet { d.set(breakInterval, forKey: "breakInterval"); onTimingChange?(.breaks) } }
    var breakDuration: Int { didSet { d.set(breakDuration, forKey: "breakDuration") } }
    /// За сколько секунд предупреждать о перерыве (0 — не предупреждать).
    var breakWarning: Int { didSet { d.set(breakWarning, forKey: "breakWarning") } }
    var breakStartSound: String { didSet { d.set(breakStartSound, forKey: "breakStartSound") } }
    var breakEndSound: String { didSet { d.set(breakEndSound, forKey: "breakEndSound") } }
    /// Отсчёт у курсора за 10 секунд до перерыва.
    var floatingCountdown: Bool { didSet { d.set(floatingCountdown, forKey: "floatingCountdown") } }
    var breakBackground: BreakBackground { didSet { d.set(breakBackground.rawValue, forKey: "breakBackground") } }
    var breakGradient: BreakGradient { didSet { d.set(breakGradient.rawValue, forKey: "breakGradient") } }
    var breakImagePath: String { didSet { d.set(breakImagePath, forKey: "breakImagePath") } }
    /// Какие упражнения могут выпасть на перерыве.
    var breakExercises: [BreakExercise] {
        didSet { d.set(breakExercises.map(\.rawValue), forKey: "breakExercises") }
    }
    /// Сколько упражнений в списке на одном перерыве.
    var breakExerciseCount: Int { didSet { d.set(breakExerciseCount, forKey: "breakExerciseCount") } }
    /// Не заканчивать перерыв по времени, пока список не отмечен.
    var breakRequireList: Bool { didSet { d.set(breakRequireList, forKey: "breakRequireList") } }

    // MARK: Конец рабочего дня
    var dayEndEnabled: Bool { didSet { d.set(dayEndEnabled, forKey: "dayEndEnabled"); onTimingChange?(.dayEnd) } }
    /// Во сколько заканчивать работу: минуты от полуночи.
    var dayEndTime: Int { didSet { d.set(dayEndTime, forKey: "dayEndTime"); onTimingChange?(.dayEnd) } }
    /// Рабочие дни: номера как в Calendar (1 — воскресенье, 2 — понедельник…).
    var dayEndDays: [Int] { didSet { d.set(dayEndDays, forKey: "dayEndDays"); onTimingChange?(.dayEnd) } }
    /// За сколько минут предупредить. Можно выбрать несколько; пусто — не предупреждать.
    var dayEndWarnings: [Int] { didSet { d.set(dayEndWarnings, forKey: "dayEndWarnings"); onTimingChange?(.dayEnd) } }
    /// Через сколько минут снова показать список, если пошёл его делать.
    var dayEndSnooze: Int { didSet { d.set(dayEndSnooze, forKey: "dayEndSnooze") } }
    /// Пункты списка на конец дня.
    var dayEndItems: [String] { didSet { d.set(dayEndItems, forKey: "dayEndItems") } }
    var dayEndSound: String { didSet { d.set(dayEndSound, forKey: "dayEndSound") } }
    /// Не настройка, а состояние: когда рабочий день закрыли (чтобы после перезапуска не показать снова).
    var dayEndClosedOn: Date? {
        didSet { d.set(dayEndClosedOn?.timeIntervalSince1970 ?? 0, forKey: "dayEndClosedOn") }
    }

    /// Пункты по умолчанию. Показываем через t(), поэтому они переводятся.
    static let defaultDayEndItems = [
        "Write what you did today",
        "Write where you stopped",
        "Write a to-do list for tomorrow",
        "Close the work apps",
    ]

    /// `defaults` — для тестов можно передать отдельный UserDefaults.
    init(defaults: UserDefaults = .standard) {
        d = defaults
        Self.migrateFromUpright(into: d)
        d.register(defaults: [
            "language": AppLanguage.system.rawValue,
            "showCountdown": true,
            "volume": 0.6,
            "soundsEnabled": true,
            "idleMinutes": 5,
            "haptics": true,
            "onboardingDone": false,
            "introSound": Sounds.onboarding,
            "smartTiming": true,
            "pauseOnCalls": true,
            "pauseOnVideo": true,
            "floatingCountdown": true,
            "breakBackground": BreakBackground.blur.rawValue,
            "breakGradient": BreakGradient.sunset.rawValue,
            "breakImagePath": "",
            "breakExercises": BreakExercise.defaults.map(\.rawValue),
            "breakExerciseCount": 2,
            "breakRequireList": true,
            "nudgeDim": 0.25,
            "nudgeBlur": 0.6,
            "arrowColor": ArrowColor.white.rawValue,
            "arrowWidth": 7.0,
            "arrowStyle": ArrowStyle.circle.rawValue,
            "nudgeAllScreens": true,
            "nudgeDuration": 4,
            "breakEnabled": true,
            "breakInterval": 60,
            "breakDuration": 5,
            "breakWarning": 60,
            "breakStartSound": "melody.jingle",
            "breakEndSound": "melody.done",
            "dayEndEnabled": false,
            "dayEndTime": 18 * 60,
            "dayEndDays": [2, 3, 4, 5, 6],
            "dayEndWarnings": [30, 5],
            "dayEndSnooze": 5,
            "dayEndItems": Self.defaultDayEndItems,
            "dayEndSound": "melody.done",
        ])

        let lang = AppLanguage(rawValue: d.string(forKey: "language") ?? "") ?? .system
        language = lang
        L10n.apply(lang)
        showCountdown = d.bool(forKey: "showCountdown")
        volume = d.double(forKey: "volume")
        soundsEnabled = d.bool(forKey: "soundsEnabled")
        idleMinutes = d.integer(forKey: "idleMinutes")
        haptics = d.bool(forKey: "haptics")
        onboardingDone = d.bool(forKey: "onboardingDone")
        introSound = d.string(forKey: "introSound") ?? Sounds.onboarding
        smartTiming = d.bool(forKey: "smartTiming")
        pauseOnCalls = d.bool(forKey: "pauseOnCalls")
        pauseOnVideo = d.bool(forKey: "pauseOnVideo")

        nudgeDim = d.double(forKey: "nudgeDim")
        nudgeBlur = d.double(forKey: "nudgeBlur")
        arrowColor = ArrowColor(rawValue: d.string(forKey: "arrowColor") ?? "") ?? .white
        arrowWidth = d.double(forKey: "arrowWidth")
        arrowStyle = ArrowStyle(rawValue: d.string(forKey: "arrowStyle") ?? "") ?? .circle
        nudgeAllScreens = d.bool(forKey: "nudgeAllScreens")
        nudgeDuration = d.integer(forKey: "nudgeDuration")
        var loaded = Self.loadReminders(d)
        Self.applyJingleDefaults(d, reminders: &loaded)
        Self.turnCaptionsOn(d, reminders: &loaded)
        reminders = loaded
        var loadedSets = d.data(forKey: "sets").flatMap { try? JSONDecoder().decode([ReminderSet].self, from: $0) } ?? []
        // «Наборы» теперь «Комбо»: старое имя по умолчанию переименовываем.
        for i in loadedSets.indices where loadedSets[i].name == "My set" || loadedSets[i].name == "Мой набор" {
            loadedSets[i].name = t("My combo")
        }
        sets = loadedSets

        breakEnabled = d.bool(forKey: "breakEnabled")
        breakInterval = d.integer(forKey: "breakInterval")
        breakDuration = d.integer(forKey: "breakDuration")
        breakWarning = d.integer(forKey: "breakWarning")
        breakStartSound = d.string(forKey: "breakStartSound") ?? ""
        breakEndSound = d.string(forKey: "breakEndSound") ?? ""
        floatingCountdown = d.bool(forKey: "floatingCountdown")
        breakBackground = BreakBackground(rawValue: d.string(forKey: "breakBackground") ?? "") ?? .blur
        breakGradient = BreakGradient(rawValue: d.string(forKey: "breakGradient") ?? "") ?? .sunset
        breakImagePath = d.string(forKey: "breakImagePath") ?? ""
        breakExercises = (d.stringArray(forKey: "breakExercises") ?? []).compactMap(BreakExercise.init(rawValue:))
        breakExerciseCount = d.integer(forKey: "breakExerciseCount")
        breakRequireList = d.bool(forKey: "breakRequireList")

        dayEndEnabled = d.bool(forKey: "dayEndEnabled")
        dayEndTime = d.integer(forKey: "dayEndTime")
        dayEndDays = (d.array(forKey: "dayEndDays") as? [Int]) ?? [2, 3, 4, 5, 6]
        dayEndWarnings = (d.array(forKey: "dayEndWarnings") as? [Int]) ?? [30, 5]
        dayEndSnooze = d.integer(forKey: "dayEndSnooze")
        dayEndItems = d.stringArray(forKey: "dayEndItems") ?? Self.defaultDayEndItems
        dayEndSound = d.string(forKey: "dayEndSound") ?? ""
        let closed = d.double(forKey: "dayEndClosedOn")
        dayEndClosedOn = closed > 0 ? Date(timeIntervalSince1970: closed) : nil
    }

    /// Читает напоминания. Если их ещё нет — собирает из старых настроек осанки и языка.
    static func loadReminders(_ d: UserDefaults) -> [Reminder] {
        if let data = d.data(forKey: "reminders"),
           var list = try? JSONDecoder().decode([Reminder].self, from: data) {
            // Один раз: старые короткие звуки по умолчанию → мелодии.
            if !d.bool(forKey: "melodiesApplied") {
                let oldDefaults = ["posture": "Pop", "tongue": "Tink"]
                for i in list.indices {
                    if let tpl = list[i].template, oldDefaults[tpl] == list[i].sound,
                       let template = ReminderLibrary.template(tpl) {
                        list[i].sound = template.sound
                    }
                }
                d.set(true, forKey: "melodiesApplied")
                if let data = try? JSONEncoder().encode(list) { d.set(data, forKey: "reminders") }
            }
            return list
        }
        var posture = ReminderLibrary.template("posture")!.make()
        var tongue = ReminderLibrary.template("tongue")!.make()
        if d.object(forKey: "nudgeInterval") != nil {
            posture.enabled = d.bool(forKey: "nudgeEnabled")
            posture.interval = d.integer(forKey: "nudgeInterval")
            posture.showCaption = d.bool(forKey: "nudgeCaption")
            if let old = d.string(forKey: "nudgeSound"), old != "Pop" { posture.sound = old }
        }
        if d.object(forKey: "tongueInterval") != nil {
            tongue.enabled = d.bool(forKey: "tongueEnabled")
            tongue.interval = d.integer(forKey: "tongueInterval")
            tongue.showCaption = d.bool(forKey: "tongueCaption")
            if let old = d.string(forKey: "tongueSound"), old != "Tink" { tongue.sound = old }
        }
        let list = [posture, tongue]
        // Первый запуск (данных ещё нет): сразу сохраняем, чтобы id не менялись при каждом запуске,
        // и отмечаем, что перенос мелодий уже не нужен — звуки здесь уже новые.
        if d.data(forKey: "reminders") == nil {
            if let data = try? JSONEncoder().encode(list) { d.set(data, forKey: "reminders") }
            d.set(true, forKey: "melodiesApplied")
        }
        return list
    }

    /// Один раз: «Показывать текст на экране» теперь включено по умолчанию у всех.
    static func turnCaptionsOn(_ d: UserDefaults, reminders: inout [Reminder]) {
        guard !d.bool(forKey: "captionsOnApplied") else { return }
        d.set(true, forKey: "captionsOnApplied")
        guard reminders.contains(where: { !$0.showCaption }) else { return }
        for i in reminders.indices { reminders[i].showCaption = true }
        if let data = try? JSONEncoder().encode(reminders) { d.set(data, forKey: "reminders") }
    }

    /// Один раз: прежние стандартные звуки → новый джингл и «Готово».
    static func applyJingleDefaults(_ d: UserDefaults, reminders: inout [Reminder]) {
        guard !d.bool(forKey: "jingleApplied") else { return }
        d.set(true, forKey: "jingleApplied")
        var changed = false
        for i in reminders.indices where reminders[i].template == "posture" && reminders[i].sound == "melody.rise" {
            reminders[i].sound = "melody.jingle"
            changed = true
        }
        if changed, let data = try? JSONEncoder().encode(reminders) { d.set(data, forKey: "reminders") }
        if d.string(forKey: "breakStartSound") == "Glass" { d.set("melody.jingle", forKey: "breakStartSound") }
        if d.string(forKey: "breakEndSound") == "Hero" { d.set("melody.done", forKey: "breakEndSound") }
    }

    /// Приложение раньше называлось Upright — один раз переносим его настройки.
    static func migrateFromUpright(into d: UserDefaults) {
        guard d === UserDefaults.standard,
              Bundle.main.bundleIdentifier != "dev.local.upright",
              !d.bool(forKey: "migratedFromUpright"),
              let old = UserDefaults(suiteName: "dev.local.upright")?.persistentDomain(forName: "dev.local.upright")
        else { return }
        for (key, value) in old where d.object(forKey: key) == nil { d.set(value, forKey: key) }
        d.set(true, forKey: "migratedFromUpright")
    }
}
