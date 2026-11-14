import AppKit
import SwiftUI

enum BreakOutcome {
    case finished, skipped
    case snoozed(minutes: Int)
}

/// Варианты «отложить».
let snoozeOptions = [1, 5, 10]

enum BreakTips {
    static let defaults = [
        "Stand up and walk for 2 minutes",
        "Look at something far away for 20 seconds",
        "Roll your shoulders back 10 times",
        "Join your hands and stretch up",
        "Drink a glass of water",
        "Take 10 slow, deep breaths",
        "Tilt your head to each shoulder for 15 seconds",
        "Pull your shoulders back for 5 seconds. Do it 5 times.",
    ]

    /// Случайная подсказка для перерыва.
    @MainActor
    static func random() -> String { t(defaults.randomElement() ?? defaults[0]) }
}

// MARK: - Фон блокера

enum BreakBackground: String, CaseIterable, Identifiable {
    case blur, wallpaper, gradient, image
    var id: String { rawValue }
    var title: String {
        switch self {
        case .blur: t("Blur screen")
        case .wallpaper: t("Wallpaper")
        case .gradient: t("Gradient")
        case .image: t("Image")
        }
    }
}

enum BreakGradient: String, CaseIterable, Identifiable {
    case sunset, ocean, forest, lavender, midnight
    var id: String { rawValue }
    var title: String { t(rawValue.capitalized) }
    var colors: [Color] {
        switch self {
        case .sunset: [Color(red: 1.00, green: 0.58, blue: 0.36), Color(red: 0.82, green: 0.28, blue: 0.55)]
        case .ocean: [Color(red: 0.22, green: 0.62, blue: 0.96), Color(red: 0.08, green: 0.22, blue: 0.52)]
        case .forest: [Color(red: 0.30, green: 0.74, blue: 0.52), Color(red: 0.06, green: 0.32, blue: 0.30)]
        case .lavender: [Color(red: 0.74, green: 0.58, blue: 1.00), Color(red: 0.38, green: 0.28, blue: 0.74)]
        case .midnight: [Color(red: 0.20, green: 0.22, blue: 0.38), Color(red: 0.04, green: 0.04, blue: 0.10)]
        }
    }
}

/// Что именно рисовать под блокером на конкретном экране.
enum BreakBackdrop {
    case blur
    case gradient([Color])
    case image(NSImage, blur: CGFloat)

    @MainActor
    static func current(for screen: NSScreen?) -> BreakBackdrop {
        let s = AppSettings.shared
        switch s.breakBackground {
        case .blur:
            return .blur
        case .gradient:
            return .gradient(s.breakGradient.colors)
        case .wallpaper:
            if let screen, let url = NSWorkspace.shared.desktopImageURL(for: screen),
               let img = NSImage(contentsOf: url) {
                return .image(img, blur: 30)
            }
            return .blur
        case .image:
            if !s.breakImagePath.isEmpty, let img = NSImage(contentsOfFile: s.breakImagePath) {
                return .image(img, blur: 0)
            }
            return .blur
        }
    }
}

struct BreakBackdropView: View {
    let backdrop: BreakBackdrop

    var body: some View {
        switch backdrop {
        case .blur:
            ZStack {
                BackdropBlur(material: .fullScreenUI)
                Color.black.opacity(0.35)
            }
        case .gradient(let colors):
            ZStack {
                LinearGradient(colors: colors, startPoint: .topLeading, endPoint: .bottomTrailing)
                Color.black.opacity(0.12)
            }
        case .image(let image, let blur):
            ZStack {
                Color.black
                Color.clear
                    .overlay {
                        Image(nsImage: image)
                            .resizable()
                            .scaledToFill()
                            .blur(radius: blur)
                            .scaleEffect(blur > 0 ? 1.08 : 1) // прячем светлые края размытия
                    }
                    .clipped()
                Color.black.opacity(0.35)
            }
        }
    }
}

// MARK: - Блокер

/// Состояние одного перерыва: время, список упражнений и что уже сделано.
@MainActor
@Observable
final class BreakSession {
    let endDate: Date
    let exercises: [BreakExercise]
    /// Не закрывать перерыв по времени, пока список не отмечен.
    let requireList: Bool
    private(set) var done: Set<BreakExercise> = []

    init(endDate: Date, exercises: [BreakExercise], requireList: Bool) {
        self.endDate = endDate
        self.exercises = exercises
        self.requireList = requireList
    }

    var allDone: Bool { exercises.allSatisfy { done.contains($0) } }

    func toggle(_ exercise: BreakExercise) {
        if done.contains(exercise) { done.remove(exercise) } else { done.insert(exercise) }
    }

    /// Можно ли закрыть перерыв, когда время вышло.
    func canFinish(at date: Date) -> Bool {
        guard date >= endDate else { return false }
        return !requireList || exercises.isEmpty || allDone
    }

    /// Случайные упражнения для перерыва.
    static func pick(from enabled: [BreakExercise], count: Int) -> [BreakExercise] {
        Array(enabled.shuffled().prefix(max(0, count)))
    }
}

/// Блокер экрана на время перерыва — на всех мониторах.
@MainActor
final class BreakController {
    private(set) var isActive = false
    private var windows: [OverlayWindow] = []
    private var keyMonitor: Any?
    private var ticker: Timer?
    private var completion: ((BreakOutcome) -> Void)?
    private var session: BreakSession?
    /// Только для записи демо: сам отмечает упражнения по очереди.
    var autoCheckForDemo = false

    /// `frame` — для записи демо: один блокер в заданном прямоугольнике.
    func show(seconds: Int, demo: Bool, frame: NSRect? = nil, completion: @escaping (BreakOutcome) -> Void) {
        // Уже идёт (например, демо из настроек) — закрываем его без ответа и показываем новый.
        // Иначе настоящий перерыв никогда не вызовет completion, и расписание застрянет.
        if isActive {
            self.completion = nil
            finish(.skipped)
        }
        isActive = true
        self.completion = completion

        let settings = AppSettings.shared
        let session = BreakSession(
            endDate: Date().addingTimeInterval(TimeInterval(seconds)),
            exercises: BreakSession.pick(from: settings.breakExercises, count: settings.breakExerciseCount),
            requireList: settings.breakRequireList && !demo)
        self.session = session

        let tip = BreakTips.random()
        let primaryFrame = frame ?? NSScreen.active.frame
        let targets: [(NSRect, NSScreen?)] = frame.map { [($0, NSScreen.main)] }
            ?? NSScreen.screens.map { ($0.frame, $0) }

        for (rect, screen) in targets {
            let isPrimary = rect == primaryFrame
            let w = OverlayWindow(frame: rect)
            w.acceptsKey = isPrimary
            w.contentView = NSHostingView(rootView: BreakView(
                session: session,
                isPrimary: isPrimary,
                demo: demo,
                tip: tip,
                backdrop: .current(for: screen),
                onDone: { [weak self] in self?.finish(.finished) },
                onSkip: { [weak self] in self?.finish(.skipped) },
                onSnooze: { [weak self] m in self?.finish(.snoozed(minutes: m)) }
            ))
            w.alphaValue = 0
            if isPrimary { w.makeKeyAndOrderFront(nil) } else { w.orderFrontRegardless() }
            windows.append(w)
        }

        NSApp.activate()
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.5
            ctx.timingFunction = CAMediaTimingFunction(name: .easeOut)
            windows.forEach { $0.animator().alphaValue = 1 }
        }
        Haptics.play(.strong)

        // Esc — пропустить
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard event.keyCode == 53 else { return event }
            MainActor.assumeIsolated { self?.finish(.skipped) }
            return nil
        }

        let t = Timer(timeInterval: 0.25, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self, let session = self.session, session.canFinish(at: Date()) else { return }
                self.finish(.finished)
            }
        }
        RunLoop.main.add(t, forMode: .common)
        ticker = t

        if autoCheckForDemo {
            for (i, ex) in session.exercises.enumerated() {
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.6 + Double(i) * 1.1) {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) { session.toggle(ex) }
                }
            }
        }
    }

    private func finish(_ outcome: BreakOutcome) {
        guard isActive else { return }
        isActive = false
        session = nil
        ticker?.invalidate()
        ticker = nil
        if let m = keyMonitor { NSEvent.removeMonitor(m) }
        keyMonitor = nil

        let ws = windows
        windows = []
        NSAnimationContext.runAnimationGroup({ ctx in
            ctx.duration = 0.5
            ctx.timingFunction = CAMediaTimingFunction(name: .easeIn)
            ws.forEach { $0.animator().alphaValue = 0 }
        }, completionHandler: {
            ws.forEach { $0.orderOut(nil) }
        })

        let c = completion
        completion = nil
        c?(outcome)
    }
}

struct BreakView: View {
    let session: BreakSession
    let isPrimary: Bool
    let demo: Bool
    let tip: String
    let backdrop: BreakBackdrop
    let onDone: () -> Void
    let onSkip: () -> Void
    let onSnooze: (Int) -> Void

    @State private var appeared = false

    var body: some View {
        ZStack {
            BreakBackdropView(backdrop: backdrop)

            TimelineView(.periodic(from: .now, by: 1)) { ctx in
                let remaining = session.endDate.timeIntervalSince(ctx.date)
                if isPrimary {
                    content(remaining: remaining)
                } else {
                    Text(formatCountdown(remaining))
                        .font(.system(size: 72, weight: .light, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(.white.opacity(0.85))
                }
            }
            .scaleEffect(appeared ? 1 : 0.92)
            .opacity(appeared ? 1 : 0)
        }
        .ignoresSafeArea()
        .onAppear {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.1)) { appeared = true }
        }
    }

    private func content(remaining: TimeInterval) -> some View {
        VStack(spacing: 18) {
            Text(t("Time for a break"))
                .font(.system(size: 34, weight: .semibold, design: .rounded))

            Text(formatCountdown(remaining))
                .font(.system(size: 88, weight: .light, design: .rounded))
                .monospacedDigit()

            if session.exercises.isEmpty {
                Text(tip)
                    .font(.system(size: 19, weight: .regular, design: .rounded))
                    .foregroundStyle(.white.opacity(0.8))
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 560)
            } else {
                // Список дел: отметь каждое упражнение
                VStack(spacing: 10) {
                    ForEach(session.exercises) { ex in
                        ExerciseRow(exercise: ex, done: session.done.contains(ex)) {
                            withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) { session.toggle(ex) }
                            if session.done.contains(ex) {
                                Sounds.play("Tink")
                                Haptics.play(.strong)
                            } else {
                                Haptics.play(.tap)
                            }
                        }
                    }
                }
                .frame(width: 560)

                Text(tip)
                    .font(.system(size: 15, weight: .regular, design: .rounded))
                    .foregroundStyle(.white.opacity(0.7))
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 560)

                if session.allDone {
                    Button {
                        Haptics.rhythm(.strong, count: 2, interval: 0.12)
                        onDone()
                    } label: {
                        Label(t("Done. Continue"), systemImage: "checkmark")
                    }
                    .buttonStyle(PillButtonStyle(prominent: true))
                    .transition(.scale.combined(with: .opacity))
                } else if remaining <= 0, session.requireList {
                    Text(t("Time is up. Check the list to continue."))
                        .font(.system(size: 15, weight: .medium, design: .rounded))
                        .foregroundStyle(.white.opacity(0.9))
                }
            }

            HStack(spacing: 10) {
                Button(t("Skip"), action: onSkip)
                    .buttonStyle(PillButtonStyle())
                Rectangle()
                    .fill(.white.opacity(0.25))
                    .frame(width: 1, height: 26)
                    .padding(.horizontal, 6)
                ForEach(snoozeOptions, id: \.self) { m in
                    Button(t("+%ld min", m)) { onSnooze(m) }
                        .buttonStyle(PillButtonStyle())
                }
            }
            .padding(.top, 10)

            if demo {
                Text(t("Preview · Esc to close"))
                    .font(.system(size: 13))
                    .foregroundStyle(.white.opacity(0.5))
                    .padding(.top, 6)
            }
        }
        .foregroundStyle(.white)
        .shadow(color: .black.opacity(0.25), radius: 10)
    }
}

/// Одна строка списка: отметка, значок, название и что сделать.
private struct ExerciseRow: View {
    let exercise: BreakExercise
    let done: Bool
    let toggle: () -> Void

    var body: some View {
        Button(action: toggle) {
            HStack(spacing: 14) {
                Image(systemName: done ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 26, weight: .medium))
                    .foregroundStyle(done ? Color.green : .white.opacity(0.8))
                    .contentTransition(.symbolEffect(.replace))
                Image(systemName: exercise.symbol)
                    .font(.system(size: 26))
                    .frame(width: 34)
                VStack(alignment: .leading, spacing: 2) {
                    Text(exercise.title)
                        .font(.system(size: 19, weight: .semibold, design: .rounded))
                        .strikethrough(done, color: .white.opacity(0.7))
                    Text(exercise.instruction)
                        .font(.system(size: 14, design: .rounded))
                        .opacity(0.8)
                }
                Spacer()
            }
            .foregroundStyle(.white)
            .opacity(done ? 0.65 : 1)
            .padding(.horizontal, 18)
            .padding(.vertical, 12)
            .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(.white.opacity(done ? 0.08 : 0.16)))
            .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(.white.opacity(0.22)))
            .contentShape(RoundedRectangle(cornerRadius: 16))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Предупреждение перед перерывом

/// Небольшая плашка сверху по центру: «Break in 0:45».
@MainActor
final class WarningController {
    private var panel: NSPanel?

    func show(breakAt: Date, onSnooze: @escaping (Int) -> Void, onStartNow: @escaping () -> Void) {
        hide()
        let size = NSSize(width: 600, height: 90)
        let screen = NSScreen.active
        let origin = NSPoint(x: screen.visibleFrame.midX - size.width / 2,
                             y: screen.visibleFrame.maxY - size.height - 4)

        let p = NSPanel(contentRect: NSRect(origin: origin, size: size),
                        styleMask: [.borderless, .nonactivatingPanel],
                        backing: .buffered, defer: false)
        p.isOpaque = false
        p.backgroundColor = .clear
        p.hasShadow = false
        p.level = .statusBar
        p.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        p.isReleasedWhenClosed = false
        p.becomesKeyOnlyIfNeeded = true
        p.contentView = NSHostingView(rootView: WarningView(
            breakAt: breakAt,
            onSnooze: { [weak self] m in self?.hide(); onSnooze(m) },
            onStartNow: { [weak self] in self?.hide(); onStartNow() }
        ))
        p.orderFrontRegardless()
        panel = p
    }

    func hide() {
        guard let p = panel else { return }
        panel = nil
        NSAnimationContext.runAnimationGroup({ ctx in
            ctx.duration = 0.25
            p.animator().alphaValue = 0
        }, completionHandler: { p.orderOut(nil) })
    }
}

struct WarningView: View {
    let breakAt: Date
    let onSnooze: (Int) -> Void
    let onStartNow: () -> Void

    @State private var appeared = false

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "cup.and.saucer.fill")
                .font(.system(size: 18))
            TimelineView(.periodic(from: .now, by: 1)) { ctx in
                Text(t("Break in %@", formatCountdown(breakAt.timeIntervalSince(ctx.date))))
                    .font(.system(size: 15, weight: .medium, design: .rounded))
                    .monospacedDigit()
            }
            Spacer(minLength: 8)
            ForEach(snoozeOptions, id: \.self) { m in
                Button(t("+%ld min", m)) { onSnooze(m) }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
            }
            Button(t("Start now"), action: onStartNow)
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
        }
        .padding(.horizontal, 20)
        .frame(height: 52)
        .background(BackdropBlur(material: .hudWindow, cornerRadius: 26))
        .overlay(Capsule().strokeBorder(.white.opacity(0.15), lineWidth: 1))
        .shadow(color: .black.opacity(0.25), radius: 12, y: 4)
        .padding(.horizontal, 12)
        .frame(maxHeight: .infinity, alignment: .top)
        .padding(.top, 8)
        .offset(y: appeared ? 0 : -70)
        .opacity(appeared ? 1 : 0)
        .onAppear {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.75)) { appeared = true }
        }
    }
}

// MARK: - Отсчёт у курсора

/// Маленькая «таблетка» рядом с курсором за последние секунды до перерыва.
@MainActor
final class CursorCountdownController {
    private var panel: NSPanel?
    private var follow: Timer?
    private var breakAt: Date?

    private static let size = NSSize(width: 230, height: 44)

    func show(breakAt: Date) {
        if panel != nil, self.breakAt == breakAt { return }
        hide(animated: false)
        self.breakAt = breakAt

        let p = NSPanel(contentRect: NSRect(origin: .zero, size: Self.size),
                        styleMask: [.borderless, .nonactivatingPanel],
                        backing: .buffered, defer: false)
        p.isOpaque = false
        p.backgroundColor = .clear
        p.hasShadow = false
        p.level = .screenSaver
        p.ignoresMouseEvents = true
        p.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
        p.isReleasedWhenClosed = false
        p.contentView = NSHostingView(rootView: CursorCountdownView(breakAt: breakAt))
        Self.place(p)
        p.alphaValue = 0
        p.orderFrontRegardless()
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.25
            p.animator().alphaValue = 1
        }
        panel = p

        let t = Timer(timeInterval: 1.0 / 60, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated {
                if let p = self?.panel { Self.place(p) }
            }
        }
        RunLoop.main.add(t, forMode: .common)
        follow = t
    }

    func hide(animated: Bool = true) {
        follow?.invalidate()
        follow = nil
        breakAt = nil
        guard let p = panel else { return }
        panel = nil
        guard animated else { p.orderOut(nil); return }
        NSAnimationContext.runAnimationGroup({ ctx in
            ctx.duration = 0.2
            p.animator().alphaValue = 0
        }, completionHandler: { p.orderOut(nil) })
    }

    private static func place(_ p: NSPanel) {
        let m = NSEvent.mouseLocation
        p.setFrameOrigin(NSPoint(x: m.x + 16, y: m.y - size.height - 12))
    }
}

struct CursorCountdownView: View {
    let breakAt: Date

    var body: some View {
        TimelineView(.periodic(from: .now, by: 0.2)) { ctx in
            let left = breakAt.timeIntervalSince(ctx.date)
            let seconds = Int(left.rounded(.up))
            HStack(spacing: 7) {
                Image(systemName: "cup.and.saucer.fill")
                    .font(.system(size: 12, weight: .semibold))
                if left > 0 {
                    Text(t("Break in"))
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .opacity(0.85)
                    Text("\(seconds)")
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .contentTransition(.numericText(countsDown: true))
                } else {
                    Text(t("Finish typing…"))
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                }
            }
            .animation(.snappy, value: seconds)
            .foregroundStyle(.white)
            .padding(.horizontal, 12)
            .frame(height: 30)
            .background(Capsule().fill(Color.black.opacity(0.45)))
            .glassEffect(.regular, in: Capsule())
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
    }
}

// MARK: - Превью

#Preview("Break · checklist", traits: .fixedLayout(width: 1200, height: 800)) {
    let session = BreakSession(endDate: .now.addingTimeInterval(272), exercises: [.pushUps, .squats],
                               requireList: true)
    let _ = session.toggle(.pushUps)
    BreakView(session: session, isPrimary: true, demo: false, tip: BreakTips.defaults[4],
              backdrop: .gradient(BreakGradient.ocean.colors), onDone: {}, onSkip: {}, onSnooze: { _ in })
}

#Preview("Break heads-up", traits: .fixedLayout(width: 600, height: 90)) {
    WarningView(breakAt: .now.addingTimeInterval(58), onSnooze: { _ in }, onStartNow: {})
        .background(Color(white: 0.85))
}

#Preview("Cursor countdown", traits: .fixedLayout(width: 230, height: 44)) {
    CursorCountdownView(breakAt: .now.addingTimeInterval(7))
        .background(Color(white: 0.85))
}
