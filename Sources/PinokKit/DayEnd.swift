import AppKit
import SwiftUI

/// Чем закончился экран конца дня.
enum DayEndOutcome: Equatable {
    /// «Закончить день»: пауза до завтра.
    case done
    /// «Сделать пункты»: экран уходит и вернётся через несколько минут.
    case later
    /// «Пропустить сегодня»: работаем дальше, напоминания идут как обычно.
    case skipped
    /// «+N мин»: очень занят, конец дня переносится.
    case postponed(minutes: Int)
}

/// На сколько можно перенести конец дня.
let dayEndPostponeOptions = [10, 30, 60]

/// «+10 min», «+1 h».
@MainActor
func dayEndPostponeLabel(_ minutes: Int) -> String {
    minutes % 60 == 0 ? t("+%ld h", minutes / 60) : t("+%ld min", minutes)
}

/// Список дел на конец дня и что уже отмечено. Живёт весь вечер, пока день не закрыт.
@MainActor
@Observable
final class DayEndSession {
    let items: [String]
    private(set) var done: Set<Int> = []
    /// День уже закончили, а человек всё ещё работает — экран говорит об этом.
    var afterEnd = false

    /// Пустые пункты не показываем.
    init(items: [String]) {
        self.items = items.map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
    }

    var allDone: Bool { items.indices.allSatisfy { done.contains($0) } }

    func toggle(_ index: Int) {
        guard items.indices.contains(index) else { return }
        if done.contains(index) { done.remove(index) } else { done.insert(index) }
    }
}

// MARK: - Экран конца дня

/// Экран на всех мониторах. В отличие от перерыва — без таймера: его закрывает только человек.
@MainActor
final class DayEndController {
    private(set) var isActive = false
    private var windows: [OverlayWindow] = []
    private var keyMonitor: Any?
    private var completion: ((DayEndOutcome) -> Void)?

    func show(_ session: DayEndSession, demo: Bool, frame: NSRect? = nil,
              completion: @escaping (DayEndOutcome) -> Void) {
        if isActive {
            self.completion = nil
            finish(.later)
        }
        isActive = true
        self.completion = completion

        let snooze = max(1, AppSettings.shared.dayEndSnooze)
        let primaryFrame = frame ?? NSScreen.active.frame
        let targets: [(NSRect, NSScreen?)] = frame.map { [($0, NSScreen.main)] }
            ?? NSScreen.screens.map { ($0.frame, $0) }

        for (rect, screen) in targets {
            let isPrimary = rect == primaryFrame
            let w = OverlayWindow(frame: rect)
            w.acceptsKey = isPrimary
            w.contentView = NSHostingView(rootView: DayEndView(
                session: session,
                isPrimary: isPrimary,
                demo: demo,
                snoozeMinutes: snooze,
                backdrop: .current(for: screen),
                onEnd: { [weak self] in self?.finish(.done) },
                onLater: { [weak self] in self?.finish(.later) },
                onSkip: { [weak self] in self?.finish(.skipped) },
                onPostpone: { [weak self] m in self?.finish(.postponed(minutes: m)) }
            ))
            w.alphaValue = 0
            if isPrimary { w.makeKeyAndOrderFront(nil) } else { w.orderFrontRegardless() }
            windows.append(w)
        }

        NSApp.activate()
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.6
            ctx.timingFunction = CAMediaTimingFunction(name: .easeOut)
            windows.forEach { $0.animator().alphaValue = 1 }
        }
        Haptics.play(.strong)

        // Esc — «сделать пункты»: уйти и вернуться позже, но не закрыть день.
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard event.keyCode == 53 else { return event }
            MainActor.assumeIsolated { self?.finish(.later) }
            return nil
        }
    }

    private func finish(_ outcome: DayEndOutcome) {
        guard isActive else { return }
        isActive = false
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

struct DayEndView: View {
    let session: DayEndSession
    let isPrimary: Bool
    let demo: Bool
    let snoozeMinutes: Int
    let backdrop: BreakBackdrop
    let onEnd: () -> Void
    let onLater: () -> Void
    let onSkip: () -> Void
    let onPostpone: (Int) -> Void

    @State private var appeared = false

    var body: some View {
        ZStack {
            BreakBackdropView(backdrop: backdrop)

            Group {
                if isPrimary {
                    content
                } else {
                    VStack(spacing: 14) {
                        Image(systemName: "sunset.fill").font(.system(size: 54))
                        Text(t("The workday is over"))
                            .font(.system(size: 34, weight: .semibold, design: .rounded))
                    }
                    .foregroundStyle(.white.opacity(0.9))
                }
            }
            .scaleEffect(appeared ? 1 : 0.94)
            .opacity(appeared ? 1 : 0)
        }
        .ignoresSafeArea()
        .onAppear {
            withAnimation(.spring(response: 0.7, dampingFraction: 0.85).delay(0.1)) { appeared = true }
        }
    }

    private var content: some View {
        VStack(spacing: 18) {
            Image(systemName: "sunset.fill")
                .font(.system(size: 46))
                .symbolRenderingMode(.multicolor)

            Text(session.afterEnd ? t("Time to stop work") : t("The workday is over"))
                .font(.system(size: 34, weight: .semibold, design: .rounded))

            Text(session.afterEnd ? t("You still work after the end of the day. Do these steps. Then stop.")
                                  : t("Do these steps. Then stop work."))
                .font(.system(size: 18, design: .rounded))
                .foregroundStyle(.white.opacity(0.8))

            if !session.items.isEmpty {
                VStack(spacing: 10) {
                    ForEach(Array(session.items.enumerated()), id: \.offset) { index, item in
                        DayEndRow(number: index + 1, text: t(item), done: session.done.contains(index)) {
                            withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) { session.toggle(index) }
                            if session.done.contains(index) {
                                Sounds.play("Tink")
                                Haptics.play(.strong)
                            } else {
                                Haptics.play(.tap)
                            }
                        }
                    }
                }
                .frame(width: 560)
                .padding(.top, 4)
            }

            HStack(spacing: 14) {
                Button(action: onLater) {
                    Label(t("Do the steps"), systemImage: "pencil.and.list.clipboard")
                }
                .buttonStyle(PillButtonStyle(prominent: !session.allDone, large: true))
                // Закончить день — только удержанием: случайный клик не закроет день.
                HoldToConfirmButton(title: t("End the day"),
                                    symbol: session.allDone ? "checkmark" : "moon.fill",
                                    prominent: session.allDone,
                                    action: onEnd)
            }
            .padding(.top, 14)
            .animation(.snappy, value: session.allDone)

            Text(t("Pinok will show this list again in %ld min.", snoozeMinutes))
                .font(.system(size: 14, design: .rounded))
                .foregroundStyle(.white.opacity(0.65))

            // Очень занят: перенести конец дня или пропустить сегодня.
            HStack(spacing: 10) {
                Text(t("Busy?"))
                    .font(.system(size: 14, weight: .medium, design: .rounded))
                    .foregroundStyle(.white.opacity(0.7))
                ForEach(dayEndPostponeOptions, id: \.self) { m in
                    Button(dayEndPostponeLabel(m)) { onPostpone(m) }
                        .buttonStyle(PillButtonStyle())
                }
                Rectangle()
                    .fill(.white.opacity(0.25))
                    .frame(width: 1, height: 26)
                    .padding(.horizontal, 6)
                Button(t("Skip today"), action: onSkip)
                    .buttonStyle(PillButtonStyle())
            }
            .padding(.top, 14)

            if demo {
                Text(t("Preview · Esc to close"))
                    .font(.system(size: 13))
                    .foregroundStyle(.white.opacity(0.5))
            }
        }
        .foregroundStyle(.white)
        .shadow(color: .black.opacity(0.25), radius: 10)
    }
}

/// Кнопка, которую надо зажать: пока держишь, она заполняется слева направо.
/// Отпустил раньше — заливка уходит назад, ничего не происходит.
struct HoldToConfirmButton: View {
    let title: String
    let symbol: String
    var prominent = false
    var duration: Double = 1.5
    let action: () -> Void

    @State private var progress: CGFloat = 0
    @State private var pressing = false
    @State private var fired = false

    var body: some View {
        VStack(spacing: 3) {
            Label(title, systemImage: symbol)
                .font(.system(size: 20, weight: .semibold, design: .rounded))
            Text(t("Click and hold"))
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .opacity(0.7)
        }
        .foregroundStyle(.white)
        .frame(minWidth: 200)
        .padding(.horizontal, 30)
        .padding(.vertical, 10)
        .background {
            GeometryReader { g in
                ZStack(alignment: .leading) {
                    Rectangle().fill(.white.opacity(prominent ? 0.28 : 0.14))
                    Rectangle().fill(.white.opacity(0.42)).frame(width: g.size.width * progress)
                }
            }
            .clipShape(Capsule())
        }
        .overlay(Capsule().strokeBorder(.white.opacity(pressing ? 0.5 : 0.22), lineWidth: 1))
        .contentShape(Capsule())
        .scaleEffect(pressing ? 0.97 : 1)
        .animation(.spring(response: 0.25, dampingFraction: 0.7), value: pressing)
        .onLongPressGesture(minimumDuration: duration, maximumDistance: 60) {
            fired = true
            Haptics.rhythm(.strong, count: 2, interval: 0.12)
            action()
        } onPressingChanged: { isPressing in
            pressing = isPressing
            if isPressing {
                fired = false
                Haptics.play(.tap)
                withAnimation(.linear(duration: duration)) { progress = 1 }
            } else if !fired {
                withAnimation(.easeOut(duration: 0.3)) { progress = 0 }
            }
        }
        // VoiceOver не умеет «держать» — для него обычное действие.
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(title)
        .accessibilityAddTraits(.isButton)
        .accessibilityAction { action() }
    }
}

/// Одна строка списка: номер или отметка и текст.
private struct DayEndRow: View {
    let number: Int
    let text: String
    let done: Bool
    let toggle: () -> Void

    var body: some View {
        Button(action: toggle) {
            HStack(spacing: 14) {
                Image(systemName: done ? "checkmark.circle.fill" : "\(min(number, 50)).circle")
                    .font(.system(size: 26, weight: .medium))
                    .foregroundStyle(done ? Color.green : .white.opacity(0.8))
                    .contentTransition(.symbolEffect(.replace))
                Text(text)
                    .font(.system(size: 19, weight: .semibold, design: .rounded))
                    .strikethrough(done, color: .white.opacity(0.7))
                    .multilineTextAlignment(.leading)
                Spacer()
            }
            .foregroundStyle(.white)
            .opacity(done ? 0.65 : 1)
            .padding(.horizontal, 18)
            .padding(.vertical, 14)
            .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(.white.opacity(done ? 0.08 : 0.16)))
            .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(.white.opacity(0.22)))
            .contentShape(RoundedRectangle(cornerRadius: 16))
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(done ? .isSelected : [])
    }
}

// MARK: - Предупреждение о конце дня

/// Плашка сверху по центру: «Рабочий день закончится через 30:00». Уходит сама через 20 секунд.
@MainActor
final class DayEndWarningController {
    private var panel: NSPanel?
    private var hideWork: DispatchWorkItem?
    static let visibleFor: TimeInterval = 20

    func show(endAt: Date, onPostpone: @escaping (Int) -> Void, onSkip: @escaping () -> Void) {
        hide()
        let size = NSSize(width: 720, height: 90)
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
        p.contentView = NSHostingView(rootView: DayEndWarningView(
            endAt: endAt,
            onClose: { [weak self] in self?.hide() },
            onPostpone: { [weak self] m in self?.hide(); onPostpone(m) },
            onSkip: { [weak self] in self?.hide(); onSkip() }))
        p.orderFrontRegardless()
        panel = p

        let work = DispatchWorkItem { [weak self] in MainActor.assumeIsolated { self?.hide() } }
        hideWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + Self.visibleFor, execute: work)
    }

    func hide() {
        hideWork?.cancel()
        hideWork = nil
        guard let p = panel else { return }
        panel = nil
        NSAnimationContext.runAnimationGroup({ ctx in
            ctx.duration = 0.25
            p.animator().alphaValue = 0
        }, completionHandler: { p.orderOut(nil) })
    }
}

struct DayEndWarningView: View {
    let endAt: Date
    let onClose: () -> Void
    let onPostpone: (Int) -> Void
    let onSkip: () -> Void

    @State private var appeared = false

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "sunset.fill")
                .font(.system(size: 18))
                .symbolRenderingMode(.multicolor)
            TimelineView(.periodic(from: .now, by: 1)) { ctx in
                Text(t("The workday ends in %@", formatCountdown(endAt.timeIntervalSince(ctx.date))))
                    .font(.system(size: 15, weight: .medium, design: .rounded))
                    .monospacedDigit()
            }
            Spacer(minLength: 8)
            ForEach(dayEndPostponeOptions, id: \.self) { m in
                Button(dayEndPostponeLabel(m)) { onPostpone(m) }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
            }
            Button(t("Skip today"), action: onSkip)
                .buttonStyle(.bordered)
                .controlSize(.small)
            Button(t("OK"), action: onClose)
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

// MARK: - Превью

#Preview("Day end · list", traits: .fixedLayout(width: 1200, height: 800)) {
    let session = DayEndSession(items: AppSettings.defaultDayEndItems)
    let _ = session.toggle(0)
    DayEndView(session: session, isPrimary: true, demo: false, snoozeMinutes: 5,
               backdrop: .gradient(BreakGradient.sunset.colors), onEnd: {}, onLater: {}, onSkip: {},
               onPostpone: { _ in })
}

#Preview("Hold button", traits: .fixedLayout(width: 400, height: 160)) {
    HoldToConfirmButton(title: "End the day", symbol: "moon.fill", action: {})
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(LinearGradient(colors: BreakGradient.sunset.colors, startPoint: .top, endPoint: .bottom))
}

#Preview("Day end warning", traits: .fixedLayout(width: 720, height: 90)) {
    DayEndWarningView(endAt: .now.addingTimeInterval(30 * 60), onClose: {}, onPostpone: { _ in }, onSkip: {})
        .background(Color(white: 0.85))
}
