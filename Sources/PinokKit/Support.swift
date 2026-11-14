import AppKit
import SwiftUI

// MARK: - Звуки

enum Sounds {
    /// Встроенные звуки macOS из /System/Library/Sounds.
    /// Название для списка: мелодии переводятся, системные звуки — как есть.
    static func title(_ name: String) -> String {
        if let m = Melodies.melody(for: name) { return "♪ " + t(m.title) }
        if name == onboarding { return "♪ " + t("Welcome melody") }
        if name.hasPrefix(filePrefix) {
            return "📁 " + URL(fileURLWithPath: String(name.dropFirst(filePrefix.count))).deletingPathExtension().lastPathComponent
        }
        return name.isEmpty ? t("None") : name
    }

    /// Копирует выбранный файл к Pinok (Application Support), чтобы он не потерялся.
    /// Возвращает имя звука "file:<путь>".
    static func importFile(_ url: URL) -> String? {
        let fm = FileManager.default
        guard let support = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else { return nil }
        let dir = support.appendingPathComponent("Pinok/Sounds", isDirectory: true)
        try? fm.createDirectory(at: dir, withIntermediateDirectories: true)
        let target = dir.appendingPathComponent(url.lastPathComponent)
        if target.path != url.path {
            try? fm.removeItem(at: target)
            guard (try? fm.copyItem(at: url, to: target)) != nil else { return nil }
        }
        return filePrefix + target.path
    }

    static let all = ["Basso", "Blow", "Bottle", "Frog", "Funk", "Glass", "Hero",
                      "Morse", "Ping", "Pop", "Purr", "Sosumi", "Submarine", "Tink"]

    /// Свой звук из файла: "file:<путь>".
    static let filePrefix = "file:"
    /// Звук из ресурсов приложения: "bundle:<имя файла>".
    static let bundlePrefix = "bundle:"
    /// Звук заставки по умолчанию.
    static let onboarding = "bundle:onboarding.mp3"

    /// Путь к звуку из ресурсов приложения (или nil, если его нет в сборке).
    static func bundlePath(_ name: String) -> String? {
        guard name.hasPrefix(bundlePrefix) else { return nil }
        let file = String(name.dropFirst(bundlePrefix.count))
        let url = URL(fileURLWithPath: file)
        return Bundle.main.path(forResource: url.deletingPathExtension().lastPathComponent,
                                ofType: url.pathExtension)
    }
    @MainActor private static var current: NSSound?

    /// Остановить любой звук: файл, мелодию или системный.
    @MainActor
    static func stop() {
        current?.stop()
        current = nil
        MelodyPlayer.shared.stop()
    }

    /// Звук сейчас играет.
    @MainActor
    static var isPlaying: Bool {
        (current?.isPlaying ?? false) || MelodyPlayer.shared.isPlaying
    }

    /// `force` — играть, даже если звуки выключены (кнопка ▶ в настройках).
    @MainActor
    static func play(_ name: String, force: Bool = false) {
        guard force || AppSettings.shared.soundsEnabled else { return }
        if let melody = Melodies.melody(for: name) {
            MelodyPlayer.shared.play(melody, volume: Float(AppSettings.shared.volume))
            return
        }
        if name.hasPrefix(bundlePrefix) {
            // Нет файла в сборке (например, в тестах) — играем джингл.
            guard let path = bundlePath(name) else { play("melody.jingle", force: force); return }
            play(filePrefix + path, force: force)
            return
        }
        if name.hasPrefix(filePrefix) {
            let path = String(name.dropFirst(filePrefix.count))
            guard let sound = NSSound(contentsOfFile: path, byReference: true) else { return }
            current?.stop()
            sound.volume = Float(AppSettings.shared.volume)
            sound.play()
            current = sound
            return
        }
        guard !name.isEmpty, let sound = NSSound(named: NSSound.Name(name)) else { return }
        current?.stop()
        sound.stop()
        sound.volume = Float(AppSettings.shared.volume)
        sound.play()
        current = sound
    }
}

// MARK: - Статистика за сегодня

@MainActor
@Observable
final class Stats {
    static let shared = Stats()

    /// Сколько раз сработало каждое напоминание сегодня (ключ — id напоминания).
    private(set) var counts: [String: Int] = [:]
    private(set) var breaks = 0
    /// Пропущенные перерывы (кнопка «Пропустить»).
    private(set) var skipped = 0
    /// Сколько раз перерыв отложили (+1 / +5 / +10 мин).
    private(set) var postponed = 0
    /// Секунды за компьютером сегодня (без простоя).
    private(set) var activeSeconds = 0
    /// Лента дня: 96 отрезков по 15 минут. Значения — `Slot`.
    private(set) var slots: [Int] = Stats.emptySlots
    /// Секунды по приложениям (ключ — bundle id приложения впереди).
    private(set) var appSeconds: [String: Int] = [:]
    /// Самый длинный отрезок работы без перерыва и без простоя, в секундах.
    private(set) var longestWork = 0
    @ObservationIgnored private var currentWork = 0

    enum Slot { static let none = 0, work = 1, rest = 2 }
    static let slotsPerDay = 96
    static var emptySlots: [Int] { Array(repeating: Slot.none, count: slotsPerDay) }

    @ObservationIgnored private var day: String
    @ObservationIgnored private let d: UserDefaults
    @ObservationIgnored private let today: () -> Date

    /// `defaults` и `today` можно подменить в тестах.
    init(defaults: UserDefaults = .standard, today: @escaping () -> Date = Date.init) {
        d = defaults
        self.today = today
        day = Stats.key(for: today())
        load()
    }

    var total: Int { counts.values.reduce(0, +) }

    func count(for id: UUID) -> Int { counts[id.uuidString] ?? 0 }

    func add(_ id: UUID) { rollover(); counts[id.uuidString, default: 0] += 1; save() }
    func addBreak() { rollover(); breaks += 1; save() }
    func addSkip() { rollover(); skipped += 1; save() }
    func addPostpone() { rollover(); postponed += 1; save() }

    /// Добавить время за компьютером (и приложению впереди). Пишем на диск раз в 30 секунд.
    func addActive(_ seconds: Int, app: String? = nil) {
        guard seconds > 0 else { return }
        rollover()
        let before = activeSeconds / 30
        activeSeconds += seconds
        if let app { appSeconds[app, default: 0] += seconds }
        currentWork += seconds
        longestWork = max(longestWork, currentWork)
        let i = currentSlot
        if slots[i] == Slot.none { slots[i] = Slot.work }
        if activeSeconds / 30 != before { save() }
    }

    /// Отрезки, которые прошли на перерыве. Станут «перерывом» на ленте, только если перерыв закончили.
    @ObservationIgnored private var pendingRest: Set<Int> = []

    /// Идёт перерыв: запоминаем отрезок и начинаем новый отрезок работы.
    func markBreak() {
        rollover()
        currentWork = 0
        pendingRest.insert(currentSlot)
    }

    /// Перерыв закончили — отмечаем его на ленте.
    func commitBreak() {
        rollover()
        for i in pendingRest where slots.indices.contains(i) { slots[i] = Slot.rest }
        pendingRest = []
        save()
    }

    /// Перерыв пропустили или отложили — на ленте его нет.
    func dropBreak() { pendingRest = [] }

    /// Человек ушёл от компьютера — отрезок работы закончился.
    func endWorkStretch() { currentWork = 0 }

    /// Приложения по убыванию времени.
    var topApps: [(id: String, seconds: Int)] {
        appSeconds.sorted { $0.value > $1.value }.map { (id: $0.key, seconds: $0.value) }
    }

    var currentSlot: Int { Stats.slot(for: today()) }

    static func slot(for date: Date) -> Int {
        let c = Calendar.current.dateComponents([.hour, .minute], from: date)
        return min(slotsPerDay - 1, (c.hour ?? 0) * 4 + (c.minute ?? 0) / 15)
    }

    /// Сбрасывает счётчики, если наступил новый день.
    func rollover() {
        let now = Stats.key(for: today())
        if now != day {
            save()          // дописываем хвост старого дня (пишем раз в 30 с)
            day = now
            pendingRest = []
            load()
        }
    }

    private func load() {
        counts = d.dictionary(forKey: "stats.\(day).counts") as? [String: Int] ?? [:]
        breaks = d.integer(forKey: "stats.\(day).breaks")
        skipped = d.integer(forKey: "stats.\(day).skipped")
        postponed = d.integer(forKey: "stats.\(day).postponed")
        activeSeconds = d.integer(forKey: "stats.\(day).active")
        let stored = d.array(forKey: "stats.\(day).slots") as? [Int] ?? []
        slots = stored.count == Stats.slotsPerDay ? stored : Stats.emptySlots
        appSeconds = d.dictionary(forKey: "stats.\(day).apps") as? [String: Int] ?? [:]
        longestWork = d.integer(forKey: "stats.\(day).longest")
        currentWork = 0
    }

    func save() {
        d.set(counts, forKey: "stats.\(day).counts")
        d.set(breaks, forKey: "stats.\(day).breaks")
        d.set(skipped, forKey: "stats.\(day).skipped")
        d.set(postponed, forKey: "stats.\(day).postponed")
        d.set(activeSeconds, forKey: "stats.\(day).active")
        d.set(slots, forKey: "stats.\(day).slots")
        d.set(appSeconds, forKey: "stats.\(day).apps")
        d.set(longestWork, forKey: "stats.\(day).longest")
    }

    static func key(for date: Date) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd"
        return f.string(from: date)
    }
}

// MARK: - Окна

/// Прозрачное окно без рамки на весь экран, поверх всего, на всех Spaces.
final class OverlayWindow: NSWindow {
    var acceptsKey = false

    convenience init(screen: NSScreen) {
        self.init(frame: screen.frame)
    }

    init(frame: NSRect) {
        super.init(contentRect: frame, styleMask: [.borderless], backing: .buffered, defer: false)
        setFrame(frame, display: false)
        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        level = .screenSaver
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
        isReleasedWhenClosed = false
        animationBehavior = .none
    }

    override var canBecomeKey: Bool { acceptsKey }
    override var canBecomeMain: Bool { acceptsKey }
}

extension NSScreen {
    /// Экран, где пользователь сейчас работает:
    /// 1) где окно активного приложения, 2) где активная строка меню, 3) где курсор.
    static var active: NSScreen {
        if let screen = screenOfFrontmostWindow() { return screen }
        if let main { return main }
        let mouse = NSEvent.mouseLocation
        return screens.first { NSMouseInRect(mouse, $0.frame, false) } ?? screens[0]
    }

    /// Экран, на котором больше всего окна активного приложения (не нашего).
    private static func screenOfFrontmostWindow() -> NSScreen? {
        guard let app = NSWorkspace.shared.frontmostApplication,
              app.processIdentifier != getpid(),
              let primary = screens.first else { return nil }
        let info = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID)
            as? [[String: Any]] ?? []
        // Окна идут сверху вниз — первое окно приложения на уровне 0 и есть активное.
        guard let window = info.first(where: {
            ($0[kCGWindowOwnerPID as String] as? pid_t) == app.processIdentifier
                && ($0[kCGWindowLayer as String] as? Int) == 0
        }),
            let dict = window[kCGWindowBounds as String] as? NSDictionary,
            let cg = CGRect(dictionaryRepresentation: dict), cg.width > 50, cg.height > 50
        else { return nil }
        // Координаты CGWindow — от левого верхнего угла главного экрана; переводим в координаты AppKit.
        let rect = NSRect(x: cg.minX, y: primary.frame.maxY - cg.maxY, width: cg.width, height: cg.height)
        return screens.max { a, b in
            a.frame.intersection(rect).area < b.frame.intersection(rect).area
        }.flatMap { $0.frame.intersects(rect) ? $0 : nil }
    }
}

private extension NSRect {
    var area: CGFloat { isNull ? 0 : width * height }
}

/// Размытие того, что находится ПОД окном (рабочий стол, другие приложения).
/// При «Уменьшить прозрачность» — плотный фон без размытия.
struct BackdropBlur: View {
    var material: NSVisualEffectView.Material = .fullScreenUI
    var cornerRadius: CGFloat = 0
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    var body: some View {
        if reduceTransparency {
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(Color(white: 0.16))
        } else {
            BackdropBlurView(material: material, cornerRadius: cornerRadius)
        }
    }
}

private struct BackdropBlurView: NSViewRepresentable {
    var material: NSVisualEffectView.Material = .fullScreenUI
    var cornerRadius: CGFloat = 0

    func makeNSView(context: Context) -> NSVisualEffectView {
        let v = NSVisualEffectView()
        v.blendingMode = .behindWindow
        v.state = .active
        update(v)
        return v
    }

    func updateNSView(_ v: NSVisualEffectView, context: Context) { update(v) }

    private func update(_ v: NSVisualEffectView) {
        v.material = material
        v.maskImage = cornerRadius > 0 ? Self.roundedMask(radius: cornerRadius) : nil
    }

    private static func roundedMask(radius: CGFloat) -> NSImage {
        let edge = radius * 2 + 1
        let image = NSImage(size: NSSize(width: edge, height: edge), flipped: false) { rect in
            NSColor.black.setFill()
            NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius).fill()
            return true
        }
        image.capInsets = NSEdgeInsets(top: radius, left: radius, bottom: radius, right: radius)
        image.resizingMode = .stretch
        return image
    }
}

// MARK: - Форматирование

func formatCountdown(_ interval: TimeInterval) -> String {
    let total = max(0, Int(interval.rounded(.up)))
    let h = total / 3600, m = (total % 3600) / 60, s = total % 60
    return h > 0 ? String(format: "%d:%02d:%02d", h, m, s) : String(format: "%d:%02d", m, s)
}

// MARK: - Кнопка-«таблетка» для оверлеев

struct PillButtonStyle: ButtonStyle {
    var prominent = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 15, weight: .medium, design: .rounded))
            .foregroundStyle(.white)
            .padding(.horizontal, 22)
            .padding(.vertical, 11)
            .background(Capsule().fill(.white.opacity(prominent ? 0.28 : 0.14)))
            .overlay(Capsule().strokeBorder(.white.opacity(0.22), lineWidth: 1))
            .contentShape(Capsule())
            .scaleEffect(configuration.isPressed ? 0.96 : 1)
            .animation(.spring(response: 0.25, dampingFraction: 0.7), value: configuration.isPressed)
    }
}
