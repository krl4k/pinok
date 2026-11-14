import AppKit
import SwiftUI

/// Анимация напоминания — выбирается из небольшой библиотеки.
enum ReminderAnimation: String, Codable, CaseIterable, Identifiable {
    case arrowUp, tongueUp, blink, lookFar, water, stretch, workout, breathe, hands, bell, icon

    var id: String { rawValue }

    var title: String {
        switch self {
        case .arrowUp: t("Arrow up")
        case .tongueUp: t("Tongue up")
        case .blink: t("Blink")
        case .lookFar: t("Look far away")
        case .water: t("Water drop")
        case .stretch: t("Stretch")
        case .workout: t("Workout")
        case .breathe: t("Breathe")
        case .hands: t("Hands")
        case .bell: t("Bell")
        case .icon: t("Your icon")
        }
    }

    /// Значок для меню и боковой панели.
    var symbol: String {
        switch self {
        case .arrowUp: "figure.stand"
        case .tongueUp: "mouth.fill"
        case .blink: "eye.fill"
        case .lookFar: "binoculars.fill"
        case .water: "drop.fill"
        case .stretch: "figure.arms.open"
        case .workout: "figure.strengthtraining.functional"
        case .breathe: "wind"
        case .hands: "hands.and.sparkles.fill"
        case .bell: "bell.fill"
        case .icon: "star.fill"
        }
    }

    var colors: [Color] {
        switch self {
        case .arrowUp: [Color(red: 1.00, green: 0.36, blue: 0.56), Color(red: 1.00, green: 0.62, blue: 0.42)]
        case .tongueUp: [Color(red: 0.86, green: 0.30, blue: 0.78), Color(red: 1.00, green: 0.46, blue: 0.58)]
        case .blink: [Color(red: 0.16, green: 0.70, blue: 0.70), Color(red: 0.40, green: 0.85, blue: 0.62)]
        case .lookFar: [Color(red: 0.25, green: 0.50, blue: 1.00), Color(red: 0.40, green: 0.75, blue: 1.00)]
        case .water: [Color(red: 0.10, green: 0.62, blue: 0.95), Color(red: 0.35, green: 0.85, blue: 0.95)]
        case .stretch: [Color(red: 0.30, green: 0.72, blue: 0.35), Color(red: 0.62, green: 0.85, blue: 0.30)]
        case .workout: [Color(red: 0.95, green: 0.35, blue: 0.25), Color(red: 1.00, green: 0.58, blue: 0.25)]
        case .breathe: [Color(red: 0.45, green: 0.42, blue: 0.98), Color(red: 0.62, green: 0.70, blue: 1.00)]
        case .hands: [Color(red: 0.95, green: 0.45, blue: 0.62), Color(red: 1.00, green: 0.72, blue: 0.62)]
        case .bell: [Color(red: 1.00, green: 0.66, blue: 0.10), Color(red: 1.00, green: 0.82, blue: 0.30)]
        case .icon: [Color(red: 0.98, green: 0.45, blue: 0.62), Color(red: 1.00, green: 0.72, blue: 0.40)]
        }
    }
}

/// Одно напоминание пользователя (из библиотеки или своё).
struct Reminder: Codable, Identifiable, Hashable {
    var id = UUID()
    /// ID шаблона из библиотеки. `nil` — своё напоминание.
    var template: String?
    var title: String
    var caption: String
    var animation: ReminderAnimation
    var interval: Int
    var enabled = true
    var showCaption = true
    var sound: String
    /// Своя иконка: SF Symbol из списка…
    var symbol: String? = nil
    /// …или своя картинка (путь к png у Pinok).
    var imagePath: String? = nil
    /// Другие варианты текста. При показе выбирается случайный (из основного и этих).
    var extraCaptions: [String]? = nil

    var isCustom: Bool { template == nil }

    /// Иконка для меню, настроек и анимации «Твоя иконка».
    var iconSymbol: String { symbol ?? animation.symbol }

    /// Тексты встроенных напоминаний переводятся; свои — показываются как есть.
    var displayTitle: String { t(title) }
    var displayCaption: String { t(caption) }

    /// Все варианты текста: основной (с переводом) и свои дополнительные.
    var captionPool: [String] {
        let extras = (extraCaptions ?? []).map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
        return [displayCaption] + extras
    }

    /// Случайный текст для показа.
    func randomCaption() -> String { captionPool.randomElement() ?? displayCaption }

    var detail: String {
        if let template, let tpl = ReminderLibrary.template(template) { return t(tpl.detail) }
        return t("Your own reminder.")
    }
}

struct ReminderTemplate: Identifiable {
    let id: String
    let title: String
    let caption: String
    let detail: String
    let animation: ReminderAnimation
    let interval: Int
    let sound: String
    var showCaption = true

    func make() -> Reminder {
        Reminder(template: id, title: title, caption: caption, animation: animation,
                 interval: interval, showCaption: showCaption, sound: sound)
    }
}

/// Готовые напоминания.
enum ReminderLibrary {
    static let all: [ReminderTemplate] = [
        ReminderTemplate(id: "posture", title: "Posture", caption: "Sit up straight",
                         detail: "An arrow moves up the screen. It reminds you to sit up straight.",
                         animation: .arrowUp, interval: 20, sound: "melody.jingle"),
        ReminderTemplate(id: "tongue", title: "Tongue", caption: "Tongue up",
                         detail: "The tongue moves up to the roof of the mouth. Keep it there all day.",
                         animation: .tongueUp, interval: 30, sound: "melody.chime"),
        ReminderTemplate(id: "blink", title: "Blink", caption: "Blink slowly 10 times",
                         detail: "Your eyes become dry at the screen. Blink slowly to rest them.",
                         animation: .blink, interval: 20, sound: "melody.sparkle"),
        ReminderTemplate(id: "lookFar", title: "Look far away", caption: "Look far away for 20 seconds",
                         detail: "Every 20 minutes, look at a far object for 20 seconds. This rests your eyes.",
                         animation: .lookFar, interval: 20, sound: "melody.calm"),
        ReminderTemplate(id: "water", title: "Water", caption: "Drink some water",
                         detail: "Drink water during the day. Your body and your head need it.",
                         animation: .water, interval: 60, sound: "melody.chime"),
        ReminderTemplate(id: "breathe", title: "Breathe", caption: "Take 3 slow breaths",
                         detail: "Slow breaths help you to be calm and to focus.",
                         animation: .breathe, interval: 60, sound: "melody.breath"),
        ReminderTemplate(id: "handCream", title: "Hand cream", caption: "Put cream on your hands",
                         detail: "Your hands become dry at the keyboard. Put some cream on them.",
                         animation: .hands, interval: 180, sound: "melody.calm"),
    ]

    static func template(_ id: String) -> ReminderTemplate? { all.first { $0.id == id } }

    /// Что включено при первом запуске.
    static var defaults: [Reminder] {
        ["posture", "tongue"].compactMap { template($0)?.make() }
    }

    /// Интервалы в минутах: от 10 минут до 6 часов.
    static let intervals = [10, 15, 20, 30, 45, 60, 120, 180, 360]

    /// «20 min» или «3 h».
    static func label(_ minutes: Int) -> String {
        if minutes < 60 { return t("%ld min", minutes) }
        if minutes % 60 == 0 { return t("%ld h", minutes / 60) }
        return t("%ld h %ld min", minutes / 60, minutes % 60)
    }
}

/// Набор: несколько напоминаний, которые показываются одновременно.
struct ReminderSet: Codable, Identifiable, Hashable {
    var id = UUID()
    var name: String
    var reminderIDs: [UUID] = []
    var interval = 30
    var enabled = true
    var sound = "melody.jingle"
    /// Сколько секунд показывать набор. `nil` — как в общих настройках.
    var duration: Int?
}

/// То, что стоит в расписании: одиночное напоминание или набор.
struct ScheduledItem: Identifiable, Equatable {
    let id: UUID
    let title: String
    let interval: Int
    let sound: String
    let members: [Reminder]
    let isSet: Bool
    /// Своя длительность показа (у набора). `nil` — общая.
    var duration: Int? = nil

    /// Что сейчас в расписании. Напоминания из включённых наборов отдельно не показываются.
    static func build(reminders: [Reminder], sets: [ReminderSet]) -> [ScheduledItem] {
        let activeSets = sets.filter(\.enabled)
        let inSets = Set(activeSets.flatMap(\.reminderIDs))
        var items: [ScheduledItem] = activeSets.compactMap { set in
            let members = set.reminderIDs.compactMap { id in reminders.first { $0.id == id } }
            guard !members.isEmpty else { return nil }
            return ScheduledItem(id: set.id, title: set.name, interval: set.interval,
                                 sound: set.sound, members: members, isSet: true, duration: set.duration)
        }
        items += reminders
            .filter { $0.enabled && !inSets.contains($0.id) }
            .map { ScheduledItem(id: $0.id, title: $0.displayTitle, interval: $0.interval,
                                 sound: $0.sound, members: [$0], isSet: false) }
        return items
    }
}

/// Упражнение на экране перерыва (экран заблокирован — есть время подвигаться).
enum BreakExercise: String, Codable, CaseIterable, Identifiable {
    case stretch, pushUps, squats, walk, shoulders, neck

    var id: String { rawValue }

    var title: String {
        switch self {
        case .stretch: t("Stretch")
        case .pushUps: t("Push-ups")
        case .squats: t("Squats")
        case .walk: t("Walk")
        case .shoulders: t("Shoulder rolls")
        case .neck: t("Neck stretch")
        }
    }

    var instruction: String {
        switch self {
        case .stretch: t("Raise your arms and stretch up. Hold for 10 seconds.")
        case .pushUps: t("Do 10 push-ups.")
        case .squats: t("Do 15 squats. Keep your back straight.")
        case .walk: t("Walk around the room for 2 minutes.")
        case .shoulders: t("Roll your shoulders back 10 times.")
        case .neck: t("Tilt your head to each shoulder. Hold for 15 seconds.")
        }
    }

    var symbol: String {
        switch self {
        case .stretch: "figure.arms.open"
        case .pushUps: "figure.strengthtraining.functional"
        case .squats: "figure.cross.training"
        case .walk: "figure.walk"
        case .shoulders: "figure.cooldown"
        case .neck: "figure.mind.and.body"
        }
    }

    static let defaults: [BreakExercise] = [.stretch, .pushUps, .squats, .walk]
}

/// Иконки для своих напоминаний.
enum ReminderIcons {
    static let symbols = [
        "star.fill", "heart.fill", "bolt.fill", "leaf.fill", "flame.fill", "sun.max.fill", "moon.fill", "sparkles",
        "cup.and.saucer.fill", "mug.fill", "waterbottle.fill", "fork.knife", "carrot.fill", "pills.fill", "cross.case.fill", "bandage.fill",
        "brain.head.profile", "eyes", "ear.fill", "mouth.fill", "hand.raised.fill", "face.smiling", "lungs.fill", "drop.fill",
        "figure.walk", "figure.run", "figure.yoga", "figure.cooldown", "dumbbell.fill", "bed.double.fill", "book.fill", "pencil",
        "phone.fill", "bell.fill", "checkmark.seal.fill", "music.note", "pawprint.fill", "laptopcomputer", "house.fill", "gift.fill",
    ]

    /// Копирует картинку к Pinok, уменьшает до 256×256 (заполняя квадрат) и возвращает путь.
    static func importImage(_ url: URL) -> String? {
        guard let source = NSImage(contentsOf: url), source.size.width > 0, source.size.height > 0 else { return nil }
        let side: CGFloat = 256
        let scale = max(side / source.size.width, side / source.size.height)
        let w = source.size.width * scale, h = source.size.height * scale
        guard let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: Int(side), pixelsHigh: Int(side),
                                         bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                                         colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0) else { return nil }
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
        NSGraphicsContext.current?.imageInterpolation = .high
        source.draw(in: NSRect(x: (side - w) / 2, y: (side - h) / 2, width: w, height: h))
        NSGraphicsContext.restoreGraphicsState()
        guard let png = rep.representation(using: .png, properties: [:]) else { return nil }

        let fm = FileManager.default
        guard let support = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else { return nil }
        let dir = support.appendingPathComponent("Pinok/Icons", isDirectory: true)
        try? fm.createDirectory(at: dir, withIntermediateDirectories: true)
        let target = dir.appendingPathComponent(UUID().uuidString + ".png")
        guard (try? png.write(to: target)) != nil else { return nil }
        return target.path
    }
}
