import AppKit

/// Файл настроек Pinok: экспорт и импорт всех настроек одним JSON.
/// Свои картинки и звуки кладём внутрь файла (base64), чтобы файл работал на другом Mac.
/// Статистика и «приветствие показано» не переносятся — они относятся к этому Mac.
struct SettingsBackup: Codable, Equatable {
    static let format = "pinok.settings"
    static let currentVersion = 1
    /// Ссылка на файл внутри бэкапа: "embedded:<ключ>".
    static let embeddedPrefix = "embedded:"

    var format = SettingsBackup.format
    var version = SettingsBackup.currentVersion
    var appVersion: String?
    var exportedAt: Date?

    // Общие
    var language: String?
    var showCountdown: Bool?
    var volume: Double?
    var soundsEnabled: Bool?
    var idleMinutes: Int?
    var introSound: String?
    var haptics: Bool?
    var smartTiming: Bool?
    var pauseOnCalls: Bool?
    var pauseOnVideo: Bool?

    // Вид напоминаний
    var nudgeDim: Double?
    var nudgeBlur: Double?
    var arrowColor: String?
    var arrowWidth: Double?
    var arrowStyle: String?
    var nudgeAllScreens: Bool?
    var nudgeDuration: Int?

    // Напоминания и комбо
    var reminders: [Reminder]?
    var combos: [ReminderSet]?

    // Перерывы
    var breakEnabled: Bool?
    var breakInterval: Int?
    var breakDuration: Int?
    var breakWarning: Int?
    var breakStartSound: String?
    var breakEndSound: String?
    var floatingCountdown: Bool?
    var breakBackground: String?
    var breakGradient: String?
    var breakImagePath: String?
    var breakMessages: [String]?
    var breakExercises: [String]?
    var breakExerciseCount: Int?
    var breakRequireList: Bool?

    /// Свои файлы: ключ → содержимое в base64.
    var files: [String: String]?

    enum BackupError: Error { case notPinokFile, newerVersion }
}

@MainActor
extension AppSettings {
    /// Собрать файл настроек.
    func exportBackup() -> Data {
        var files: [String: String] = [:]
        var keys: [String: String] = [:]   // путь → ключ, чтобы один файл не класть дважды

        /// Положить файл внутрь бэкапа и вернуть ссылку на него.
        func embed(_ path: String) -> String {
            if let key = keys[path] { return SettingsBackup.embeddedPrefix + key }
            guard !path.isEmpty, let data = FileManager.default.contents(atPath: path) else { return path }
            let key = UUID().uuidString.prefix(8) + "-" + (path as NSString).lastPathComponent
            files[key] = data.base64EncodedString()
            keys[path] = key
            return SettingsBackup.embeddedPrefix + key
        }
        func embedSound(_ sound: String) -> String {
            guard sound.hasPrefix(Sounds.filePrefix) else { return sound }
            let ref = embed(String(sound.dropFirst(Sounds.filePrefix.count)))
            return ref.hasPrefix(SettingsBackup.embeddedPrefix) ? ref : sound
        }

        var b = SettingsBackup()
        b.appVersion = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
        b.exportedAt = Date()
        b.language = language.rawValue
        b.showCountdown = showCountdown
        b.volume = volume
        b.soundsEnabled = soundsEnabled
        b.idleMinutes = idleMinutes
        b.introSound = embedSound(introSound)
        b.haptics = haptics
        b.smartTiming = smartTiming
        b.pauseOnCalls = pauseOnCalls
        b.pauseOnVideo = pauseOnVideo
        b.nudgeDim = nudgeDim
        b.nudgeBlur = nudgeBlur
        b.arrowColor = arrowColor.rawValue
        b.arrowWidth = arrowWidth
        b.arrowStyle = arrowStyle.rawValue
        b.nudgeAllScreens = nudgeAllScreens
        b.nudgeDuration = nudgeDuration
        b.reminders = reminders.map { r in
            var r = r
            r.sound = embedSound(r.sound)
            if let path = r.imagePath { r.imagePath = embed(path) }
            return r
        }
        b.combos = sets.map { c in
            var c = c
            c.sound = embedSound(c.sound)
            return c
        }
        b.breakEnabled = breakEnabled
        b.breakInterval = breakInterval
        b.breakDuration = breakDuration
        b.breakWarning = breakWarning
        b.breakStartSound = embedSound(breakStartSound)
        b.breakEndSound = embedSound(breakEndSound)
        b.floatingCountdown = floatingCountdown
        b.breakBackground = breakBackground.rawValue
        b.breakGradient = breakGradient.rawValue
        b.breakImagePath = embed(breakImagePath)
        b.breakMessages = breakMessages
        b.breakExercises = breakExercises.map(\.rawValue)
        b.breakExerciseCount = breakExerciseCount
        b.breakRequireList = breakRequireList
        b.files = files.isEmpty ? nil : files

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return (try? encoder.encode(b)) ?? Data()
    }

    /// Прочитать файл настроек и применить. Поля, которых нет в файле, не меняются.
    /// Числа приводим к разумным границам: интервал 0 дал бы бесконечные перерывы.
    /// `filesDir` — куда положить свои картинки и звуки из файла.
    func importBackup(_ data: Data, filesDir: URL? = nil) throws {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        guard let b = try? decoder.decode(SettingsBackup.self, from: data),
              b.format == SettingsBackup.format else { throw SettingsBackup.BackupError.notPinokFile }
        guard b.version <= SettingsBackup.currentVersion else { throw SettingsBackup.BackupError.newerVersion }

        let dir = filesDir ?? Self.importedFilesDir
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        var written: [String: String] = [:]

        /// Достать файл из бэкапа на диск и вернуть его путь.
        func restore(_ ref: String) -> String {
            guard ref.hasPrefix(SettingsBackup.embeddedPrefix) else { return ref }
            let key = String(ref.dropFirst(SettingsBackup.embeddedPrefix.count))
            if let path = written[key] { return path }
            guard let base64 = b.files?[key], let data = Data(base64Encoded: base64) else { return "" }
            let target = dir.appendingPathComponent((key as NSString).lastPathComponent)
            guard (try? data.write(to: target)) != nil else { return "" }
            written[key] = target.path
            return target.path
        }
        func restoreSound(_ sound: String) -> String {
            guard sound.hasPrefix(SettingsBackup.embeddedPrefix) else { return sound }
            let path = restore(sound)
            return path.isEmpty ? "melody.jingle" : Sounds.filePrefix + path
        }

        if let v = b.language.flatMap(AppLanguage.init(rawValue:)) { language = v }
        if let v = b.showCountdown { showCountdown = v }
        if let v = b.volume { volume = min(1, max(0, v)) }
        if let v = b.soundsEnabled { soundsEnabled = v }
        if let v = b.idleMinutes { idleMinutes = max(1, v) }
        if let v = b.introSound { introSound = restoreSound(v) }
        if let v = b.haptics { haptics = v }
        if let v = b.smartTiming { smartTiming = v }
        if let v = b.pauseOnCalls { pauseOnCalls = v }
        if let v = b.pauseOnVideo { pauseOnVideo = v }
        if let v = b.nudgeDim { nudgeDim = min(1, max(0, v)) }
        if let v = b.nudgeBlur { nudgeBlur = min(1, max(0, v)) }
        if let v = b.arrowColor.flatMap(ArrowColor.init(rawValue:)) { arrowColor = v }
        if let v = b.arrowWidth { arrowWidth = v }
        if let v = b.arrowStyle.flatMap(ArrowStyle.init(rawValue:)) { arrowStyle = v }
        if let v = b.nudgeAllScreens { nudgeAllScreens = v }
        if let v = b.nudgeDuration { nudgeDuration = max(1, v) }
        if let list = b.reminders {
            reminders = list.map { r in
                var r = r
                r.sound = restoreSound(r.sound)
                r.interval = max(1, r.interval)
                if let ref = r.imagePath {
                    let path = restore(ref)
                    r.imagePath = path.isEmpty ? nil : path
                }
                return r
            }
        }
        if let list = b.combos {
            let ids = Set(reminders.map(\.id))
            sets = list.map { c in
                var c = c
                c.sound = restoreSound(c.sound)
                c.interval = max(1, c.interval)
                c.duration = c.duration.map { max(1, $0) }
                c.reminderIDs = c.reminderIDs.filter(ids.contains)
                return c
            }
        }
        if let v = b.breakEnabled { breakEnabled = v }
        if let v = b.breakInterval { breakInterval = max(10, v) }
        if let v = b.breakDuration { breakDuration = max(1, v) }
        if let v = b.breakWarning { breakWarning = max(0, v) }
        if let v = b.breakStartSound { breakStartSound = restoreSound(v) }
        if let v = b.breakEndSound { breakEndSound = restoreSound(v) }
        if let v = b.floatingCountdown { floatingCountdown = v }
        if let v = b.breakBackground.flatMap(BreakBackground.init(rawValue:)) { breakBackground = v }
        if let v = b.breakGradient.flatMap(BreakGradient.init(rawValue:)) { breakGradient = v }
        if let v = b.breakImagePath { breakImagePath = restore(v) }
        if let v = b.breakMessages { breakMessages = v }
        if let v = b.breakExercises { breakExercises = v.compactMap(BreakExercise.init(rawValue:)) }
        if let v = b.breakExerciseCount { breakExerciseCount = max(1, v) }
        if let v = b.breakRequireList { breakRequireList = v }
    }

    /// Куда кладём свои файлы из импорта.
    static var importedFilesDir: URL {
        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSTemporaryDirectory())
        return support.appendingPathComponent("Pinok/Imported", isDirectory: true)
    }
}

// MARK: - Окна «Сохранить» и «Открыть»

@MainActor
enum BackupPanels {
    /// Показывает окно сохранения. Возвращает текст результата для настроек.
    static func export(_ settings: AppSettings) -> String? {
        let panel = NSSavePanel()
        panel.nameFieldStringValue = "Pinok settings.json"
        panel.allowedContentTypes = [.json]
        panel.canCreateDirectories = true
        guard panel.runModal() == .OK, let url = panel.url else { return nil }
        do {
            try settings.exportBackup().write(to: url)
            return t("Pinok saved the settings.")
        } catch {
            return t("Pinok cannot save the file.")
        }
    }

    /// Выбор файла для импорта.
    static func chooseFile() -> URL? {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.json]
        panel.allowsMultipleSelection = false
        return panel.runModal() == .OK ? panel.url : nil
    }

    static func importFile(_ url: URL, into settings: AppSettings) -> String {
        guard let data = try? Data(contentsOf: url) else { return t("Pinok cannot open the file.") }
        do {
            try settings.importBackup(data)
            return t("Pinok loaded the settings.")
        } catch SettingsBackup.BackupError.newerVersion {
            return t("This file is from a newer Pinok. Update the app.")
        } catch {
            return t("This file is not a Pinok settings file.")
        }
    }
}
