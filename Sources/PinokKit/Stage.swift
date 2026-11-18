import AppKit
import SwiftUI

/// Режим записи демо для README: своё окно с «рабочим столом» по центру экрана,
/// поверх него проигрывается анимация. Записывается только эта область.
@MainActor
enum Stage {
    static let size = NSSize(width: 1280, height: 800)
    private static var window: NSWindow?

    static func run(_ kind: String) {
        guard let screen = NSScreen.main else { exit(1) }
        let frame = NSRect(x: screen.frame.midX - size.width / 2,
                           y: screen.frame.midY - size.height / 2,
                           width: size.width, height: size.height)

        let w = NSWindow(contentRect: frame, styleMask: [.borderless], backing: .buffered, defer: false)
        w.level = NSWindow.Level(rawValue: NSWindow.Level.screenSaver.rawValue - 1)
        w.isOpaque = true
        w.hasShadow = false
        w.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        w.contentView = NSHostingView(rootView: MockDesktop())
        w.orderFrontRegardless()
        window = w

        // Прямоугольник для `screencapture -R` (начало координат — левый верхний угол экрана).
        let topY = screen.frame.maxY - frame.maxY
        print("STAGE \(Int(frame.minX)),\(Int(topY)),\(Int(frame.width)),\(Int(frame.height))")
        fflush(stdout)

        let total: TimeInterval
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            switch kind {
            case "onboarding":
                OnboardingWindow.shared.show(demo: true, frame: frame)
            case "break":
                BreakController.demo.autoCheckForDemo = true
                BreakController.demo.show(seconds: 272, demo: false, frame: frame) { _ in }
            case "dayend":
                let session = DayEndSession(items: AppSettings.shared.dayEndItems)
                DayEndController.demo.show(session, demo: false, frame: frame) { _ in }
                for i in 0..<2 {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.6 + Double(i) * 1.1) {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) { session.toggle(i) }
                    }
                }
            default:
                let tpl = ReminderLibrary.template(kind) ?? ReminderLibrary.template("posture")!
                let reminders = kind == "set"
                    ? ["posture", "blink", "water"].compactMap { ReminderLibrary.template($0)?.make() }
                    : [tpl.make()]
                NudgeController().showRetained(reminders, frame: frame)
            }
        }
        total = kind == "break" || kind == "dayend" ? 7.5 : (kind == "onboarding" ? 7.5 : 5.5)
        DispatchQueue.main.asyncAfter(deadline: .now() + total) { exit(0) }
    }
}

private var retainedNudges: [NudgeController] = []

extension NudgeController {
    @MainActor
    func showRetained(_ reminders: [Reminder], frame: NSRect) {
        retainedNudges.append(self)
        show(reminders, frames: [frame])
    }
}

extension BreakController {
    @MainActor static let demo = BreakController()
}

extension DayEndController {
    @MainActor static let demo = DayEndController()
}

/// Обезличенный «рабочий стол»: обои и окно редактора.
private struct MockDesktop: View {
    var body: some View {
        ZStack {
            LinearGradient(colors: [Color(red: 0.36, green: 0.52, blue: 0.86), Color(red: 0.78, green: 0.52, blue: 0.72),
                                    Color(red: 0.98, green: 0.70, blue: 0.52)],
                           startPoint: .topLeading, endPoint: .bottomTrailing)

            VStack(spacing: 0) {
                HStack(spacing: 8) {
                    Circle().fill(Color(red: 1, green: 0.37, blue: 0.34)).frame(width: 12)
                    Circle().fill(Color(red: 1, green: 0.74, blue: 0.18)).frame(width: 12)
                    Circle().fill(Color(red: 0.16, green: 0.79, blue: 0.25)).frame(width: 12)
                    Spacer()
                }
                .padding(14)
                HStack(alignment: .top, spacing: 0) {
                    VStack(alignment: .leading, spacing: 12) {
                        ForEach(0..<9, id: \.self) { i in
                            RoundedRectangle(cornerRadius: 4).fill(Color.primary.opacity(i == 2 ? 0.16 : 0.07))
                                .frame(width: 150, height: 14)
                        }
                    }
                    .padding(18)
                    .frame(maxHeight: .infinity, alignment: .top)
                    .background(Color.primary.opacity(0.04))
                    VStack(alignment: .leading, spacing: 13) {
                        ForEach(0..<16, id: \.self) { i in
                            HStack(spacing: 8) {
                                RoundedRectangle(cornerRadius: 3)
                                    .fill([Color.pink, .blue, .purple, .orange][i % 4].opacity(0.45))
                                    .frame(width: CGFloat(40 + (i * 37) % 60), height: 10)
                                RoundedRectangle(cornerRadius: 3).fill(Color.primary.opacity(0.12))
                                    .frame(width: CGFloat(120 + (i * 71) % 300), height: 10)
                            }
                            .padding(.leading, CGFloat((i % 3) * 24))
                        }
                    }
                    .padding(24)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                }
            }
            .background(RoundedRectangle(cornerRadius: 14).fill(Color(white: 0.98)))
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .shadow(color: .black.opacity(0.3), radius: 30, y: 12)
            .padding(.horizontal, 110)
            .padding(.vertical, 80)
        }
        .environment(\.colorScheme, .light)
    }
}
