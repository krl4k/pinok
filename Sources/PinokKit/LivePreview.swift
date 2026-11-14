import SwiftUI

/// Живое превью напоминания в настройках: мини-«экран», на котором видно,
/// как напоминание (или набор) будет выглядеть. Обновляется при любом изменении.
struct ReminderLivePreview: View {
    let reminders: [Reminder]
    var height: CGFloat = 210
    /// Показать по-настоящему, на весь экран. nil — без кнопки.
    var onShowOnScreen: (() -> Void)?
    @Bindable private var settings = AppSettings.shared
    private var backdrop = PreviewBackdrop.shared
    @State private var replay = 0
    @State private var risen = true

    init(reminders: [Reminder], height: CGFloat = 210, onShowOnScreen: (() -> Void)? = nil) {
        self.reminders = reminders
        self.height = height
        self.onShowOnScreen = onShowOnScreen
    }

    /// Ключ: если что-то из этого поменялось — анимация проигрывается заново.
    private var signature: String {
        reminders.map { "\($0.animation.rawValue)|\($0.iconSymbol)|\($0.imagePath ?? "")|\($0.showCaption)|\($0.caption)" }
            .joined(separator: ";") + "|\(settings.arrowColor.rawValue)|\(replay)"
    }

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width, h = geo.size.height
            let n = max(1, reminders.count)
            let d = min(h * 0.38, w / CGFloat(n + 1) * 0.7)
            ZStack {
                // Фон: снимок экрана, обои или нарисованный «рабочий стол»
                ZStack {
                    if let image = backdrop.image {
                        Color.clear.overlay {
                            Image(nsImage: image).resizable().scaledToFill()
                        }
                        .clipped()
                    } else {
                        LinearGradient(colors: [Color(red: 0.36, green: 0.52, blue: 0.86), Color(red: 0.78, green: 0.52, blue: 0.72),
                                                Color(red: 0.98, green: 0.70, blue: 0.52)],
                                       startPoint: .topLeading, endPoint: .bottomTrailing)
                    }
                    RoundedRectangle(cornerRadius: 8)
                        .fill(.white.opacity(0.92))
                        .frame(width: w * 0.62, height: h * 0.62)
                        .overlay(alignment: .topLeading) {
                            VStack(alignment: .leading, spacing: 7) {
                                ForEach(0..<6, id: \.self) { i in
                                    Capsule().fill(Color.black.opacity(0.12))
                                        .frame(width: CGFloat(60 + (i * 47) % 140), height: 6)
                                }
                            }
                            .padding(14)
                        }
                }
                .blur(radius: 6 * settings.nudgeBlur)
                Color(white: 0.28).opacity(settings.nudgeDim)

                // Напоминания — как на экране, слева направо
                ForEach(Array(reminders.enumerated()), id: \.element.id) { index, r in
                    VStack(spacing: d * 0.12) {
                        GlassBadge(d: d, color: settings.arrowColor.color, glow: risen) {
                            ReminderAnimationView(animation: r.animation, color: settings.arrowColor.color, d: d,
                                                  symbol: r.iconSymbol, imagePath: r.imagePath)
                        }
                        Text(r.showCaption ? r.displayCaption : " ")
                            .font(.system(size: max(10, d * 0.16), weight: .semibold, design: .rounded))
                            .foregroundStyle(settings.arrowColor.color)
                            .lineLimit(2)
                            .multilineTextAlignment(.center)
                            .frame(maxWidth: w / CGFloat(n + 1) * 0.95)
                            .shadow(color: .black.opacity(0.35), radius: 3)
                            .opacity(r.showCaption ? 1 : 0)
                    }
                    .position(x: w * CGFloat(index + 1) / CGFloat(n + 1), y: h * 0.5 + (risen ? 0 : h * 0.12))
                    .opacity(risen ? 1 : 0)
                }
                .id(signature)

                if reminders.isEmpty {
                    Text(t("Select 2 or more reminders."))
                        .font(.callout)
                        .foregroundStyle(.white)
                }
            }
            .frame(width: w, height: h)
        }
        .frame(height: height)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(alignment: .topLeading) {
            Label(t("Live preview"), systemImage: "eye")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.white)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(Capsule().fill(.black.opacity(0.35)))
                .padding(10)
        }
        .overlay(alignment: .topTrailing) {
            HStack(spacing: 8) {
                Button {
                    replay += 1
                } label: {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(width: 30, height: 30)
                        .background(Circle().fill(.black.opacity(0.35)))
                }
                .buttonStyle(.plain)
                .help(t("Play again"))
            }
            .padding(10)
        }
        .overlay(alignment: .bottomTrailing) {
            if let onShowOnScreen {
                Button(action: onShowOnScreen) {
                    Label(t("Show on my screen"), systemImage: "play.fill")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.black)
                        .padding(.horizontal, 16)
                        .frame(height: 36)
                        .background(Capsule().fill(.white))
                        .shadow(color: .black.opacity(0.3), radius: 8, y: 3)
                }
                .buttonStyle(.plain)
                .disabled(reminders.isEmpty)
                .help(t("Show the reminder on the full screen, as it really looks."))
                .padding(12)
            }
        }
        .task { backdrop.loadWallpaper() }
        .onChange(of: signature) { _, _ in
            // Каждое изменение — короткий подъём, как на настоящем экране.
            risen = false
            withAnimation(.timingCurve(0.45, 0, 0.2, 1, duration: 0.8).delay(0.05)) { risen = true }
        }
    }
}
