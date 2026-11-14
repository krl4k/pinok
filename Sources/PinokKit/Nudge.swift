import AppKit
import SwiftUI

enum ArrowStyle: String, CaseIterable, Identifiable {
    case circle, plain
    var id: String { rawValue }
    var title: String {
        switch self {
        case .circle: t("Glass")
        case .plain: t("Line")
        }
    }
}

/// Мягкое напоминание: экран слегка сереет и мутнеет, по центру — анимация.
/// Клики и клавиатура проходят насквозь.
@MainActor
final class NudgeController {
    private var windows: [OverlayWindow] = []
    private(set) var isShowing = false

    /// Короче — анимация не успевает.
    nonisolated static let minDuration: TimeInterval = 4.0

    /// `duration` — сколько секунд на экране. `frames` — для записи демо.
    func show(_ reminders: [Reminder], duration: TimeInterval = NudgeController.minDuration, frames: [NSRect]? = nil) {
        let duration = max(Self.minDuration, duration)
        guard !isShowing, !reminders.isEmpty else { return }
        isShowing = true

        let s = AppSettings.shared
        let targets = frames ?? (s.nudgeAllScreens ? NSScreen.screens : [NSScreen.active]).map(\.frame)
        let config = NudgeView.Config(
            items: reminders.map { .init(animation: $0.animation, caption: $0.showCaption ? $0.randomCaption() : nil,
                                         symbol: $0.iconSymbol, imagePath: $0.imagePath) },
            duration: duration,
            dim: s.nudgeDim,
            blur: s.nudgeBlur,
            color: s.arrowColor.color,
            lineWidth: s.arrowWidth,
            arrowStyle: s.arrowStyle
        )

        for frame in targets {
            let w = OverlayWindow(frame: frame)
            w.ignoresMouseEvents = true
            w.contentView = NSHostingView(rootView: NudgeView(config: config))
            w.alphaValue = 0
            w.orderFrontRegardless()
            windows.append(w)
        }

        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.35
            ctx.timingFunction = CAMediaTimingFunction(name: .easeOut)
            windows.forEach { $0.animator().alphaValue = 1 }
        }

        // Три лёгких щелчка в такт анимации, которая поднимается.
        Haptics.rhythm(.click, count: 3, interval: 0.35, delay: 0.6)

        DispatchQueue.main.asyncAfter(deadline: .now() + duration - 0.7) { [weak self] in
            self?.hide()
        }
    }

    private func hide() {
        let ws = windows
        windows = []
        NSAnimationContext.runAnimationGroup({ ctx in
            ctx.duration = 0.6
            ctx.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            ws.forEach { $0.animator().alphaValue = 0 }
        }, completionHandler: { [weak self] in
            ws.forEach { $0.orderOut(nil) }
            MainActor.assumeIsolated { self?.isShowing = false }
        })
    }
}

// MARK: - Сцена

struct NudgeView: View {
    struct Config {
        /// Одно напоминание или несколько (набор) — делят экран слева направо.
        struct Item {
            var animation: ReminderAnimation
            var caption: String?
            var symbol: String? = nil
            var imagePath: String? = nil
        }
        var items: [Item]
        var duration: TimeInterval = NudgeController.minDuration
        var dim: Double
        var blur: Double
        var color: Color
        var lineWidth: Double
        var arrowStyle: ArrowStyle
    }

    let config: Config

    @State private var visible = false   // появился
    @State private var risen = false     // поднялся из нижней трети в верхнюю
    @State private var leaving = false   // улетает и тает
    @State private var go = false        // запустить анимацию внутри круга
    @State private var draw: CGFloat = 0 // прорисовка линейной стрелки
    @State private var glow = false
    @State private var timeLeft: CGFloat = 1 // кольцо-таймер при длинном показе
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// Кольцо показываем, только если напоминание висит дольше обычного.
    private var showsTimer: Bool { config.duration > NudgeController.minDuration + 0.5 }

    private func isPlainArrow(_ item: Config.Item) -> Bool {
        item.animation == .arrowUp && config.arrowStyle == .plain
    }

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width, h = geo.size.height
            let n = max(1, config.items.count)
            // Чем больше значков, тем они меньше — чтобы поместились в ряд.
            let d = min(min(w, h) * 0.15, w / CGFloat(n + 1) * 0.7)
            // Центр значков: нижняя треть → верхняя треть
            // При «Уменьшить движение» — без полёта: сразу на месте, только плавное появление.
            let y = reduceMotion ? h * 0.32 : (leaving ? h * 0.24 : (risen ? h * 0.32 : h * 0.74))
            let trail = (risen && !reduceMotion) ? h * 0.2 : 0

            ZStack {
                BackdropBlur(material: .fullScreenUI)
                    .opacity(config.blur)
                Color(white: 0.28)
                    .opacity(config.dim)

                ForEach(Array(config.items.enumerated()), id: \.offset) { index, item in
                    // Равномерно слева направо
                    let x = w * CGFloat(index + 1) / CGFloat(n + 1)

                    // Мягкий «хвост» под значком — подчёркивает движение вверх
                    Capsule()
                        .fill(LinearGradient(colors: [config.color.opacity(0.45), config.color.opacity(0)],
                                             startPoint: .top, endPoint: .bottom))
                        .frame(width: d * 0.08, height: trail)
                        .blur(radius: d * 0.03)
                        .position(x: x, y: y + trail / 2)
                        .opacity(visible && !leaving ? 1 : 0)

                    // Место под подпись есть всегда — так значки в наборе стоят на одной линии.
                    let fontSize = max(16, min(28, d * 0.16))
                    VStack(spacing: d * 0.16) {
                        symbol(item, d: d)
                        Text(item.caption ?? " ")
                            .font(.system(size: fontSize, weight: .semibold, design: .rounded))
                            .foregroundStyle(config.color)
                            .multilineTextAlignment(.center)
                            .lineLimit(2)
                            .frame(maxWidth: w / CGFloat(n + 1) * 0.95)
                            .frame(height: fontSize * 2.6, alignment: .top)
                            .shadow(color: .black.opacity(0.35), radius: 6, y: 1)
                            .opacity(item.caption == nil ? 0 : 1)
                    }
                    .scaleEffect(reduceMotion ? 1 : (visible ? (leaving ? 0.9 : 1) : 0.6))
                    .opacity(visible && !leaving ? 1 : 0)
                    .position(x: x, y: y)
                }
            }
            .frame(width: w, height: h)
        }
        .ignoresSafeArea()
        .task { await play() }
    }

    @ViewBuilder
    private func symbol(_ item: Config.Item, d: CGFloat) -> some View {
        if isPlainArrow(item) {
            ArrowShape(progress: draw)
                .stroke(config.color, style: StrokeStyle(lineWidth: config.lineWidth, lineCap: .round, lineJoin: .round))
                .frame(width: d * 0.6, height: d * 1.5)
                .shadow(color: config.color.opacity(glow ? 0.9 : 0.4), radius: glow ? 22 : 10)
        } else {
            GlassBadge(d: d, color: config.color, glow: glow) {
                if go {
                    ReminderAnimationView(animation: item.animation, color: config.color,
                                          d: d, weight: symbolWeight, symbol: item.symbol, imagePath: item.imagePath)
                }
            }
            .overlay {
                if showsTimer {
                    Circle()
                        .trim(from: 0, to: timeLeft)
                        .stroke(config.color.opacity(0.75), style: StrokeStyle(lineWidth: max(2, d * 0.035), lineCap: .round))
                        .rotationEffect(.degrees(-90))
                        .frame(width: d * 1.14, height: d * 1.14)
                }
            }
        }
    }

    private var symbolWeight: Font.Weight {
        switch config.lineWidth {
        case ..<5: .regular
        case ..<8: .semibold
        case ..<11: .bold
        default: .heavy
        }
    }

    private func play() async {
        let total = config.duration
        // Уход начинается за 1.25 с до конца.
        let leaveAt = total - 1.25

        // 0.2 с — появляется в нижней трети
        try? await Task.sleep(for: .milliseconds(200))
        withAnimation(.spring(response: 0.55, dampingFraction: 0.75)) { visible = true }

        // 0.35 с — плавно поднимается в верхнюю треть (2.3 с, при долгом показе — медленнее, до 4 с)
        try? await Task.sleep(for: .milliseconds(150))
        let rise = min(4.0, 2.3 * total / NudgeController.minDuration)
        withAnimation(.timingCurve(0.45, 0, 0.2, 1, duration: rise)) { risen = true }

        // 0.6 с — запускаем анимацию внутри круга и кольцо-таймер
        try? await Task.sleep(for: .milliseconds(250))
        withAnimation(.easeOut(duration: 0.9)) { go = true }
        withAnimation(.timingCurve(0.22, 0.8, 0.25, 1, duration: 1.1)) { draw = 1 }
        if showsTimer {
            withAnimation(.linear(duration: leaveAt - 0.6)) { timeLeft = 0 }
        }

        // ~1.9 с — мягко «дышит»; при долгом показе — до самого ухода
        try? await Task.sleep(for: .milliseconds(1300))
        if showsTimer {
            withAnimation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true)) { glow = true }
        } else {
            withAnimation(.easeInOut(duration: 0.45).repeatCount(2, autoreverses: true)) { glow = true }
        }

        // Улетает чуть выше и тает
        try? await Task.sleep(for: .seconds(max(0, leaveAt - 1.9)))
        withAnimation(.easeIn(duration: 0.55)) { leaving = true }
    }
}

/// Стеклянный круг с тёмной подложкой и цветным свечением.
struct GlassBadge<Content: View>: View {
    let d: CGFloat
    let color: Color
    var glow = false
    @ViewBuilder var content: Content
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    var body: some View {
        ZStack {
            Circle()
                .fill(color.opacity(glow ? 0.55 : 0.25))
                .frame(width: d * 1.05, height: d * 1.05)
                .blur(radius: d * 0.22)
            // Тёмная подложка — чтобы светлый значок читался на любом фоне
            Circle()
                .fill(LinearGradient(colors: [Color(white: 0.32).opacity(0.75), Color(white: 0.08).opacity(0.85)],
                                     startPoint: .top, endPoint: .bottom))
                .frame(width: d, height: d)
            if reduceTransparency {
                Circle().fill(Color(white: 0.18)).frame(width: d, height: d)
            } else {
                Color.clear
                    .frame(width: d, height: d)
                    .glassEffect(.regular, in: Circle())
            }
            content
        }
        .frame(width: d, height: d)
    }
}

// MARK: - Библиотека анимаций

/// Анимация внутри стеклянного круга. Запускается, когда вью появляется.
struct ReminderAnimationView: View {
    let animation: ReminderAnimation
    let color: Color
    let d: CGFloat
    var weight: Font.Weight = .semibold
    /// Для анимации «Твоя иконка».
    var symbol: String? = nil
    var imagePath: String? = nil

    var body: some View {
        switch animation {
        case .arrowUp: DrawOnSymbol(name: "arrow.up", size: d * 0.44, weight: weight, color: color)
        case .tongueUp: TongueAnimation(d: d)
        case .blink: BlinkAnimation(d: d, color: color)
        case .lookFar: LookFarAnimation(d: d, color: color)
        case .water: WaterAnimation(d: d, color: color)
        case .stretch: DrawOnSymbol(name: "figure.arms.open", size: d * 0.46, weight: weight, color: color, bounce: true)
        case .workout: DrawOnSymbol(name: "figure.strengthtraining.functional", size: d * 0.46, weight: weight,
                                    color: color, bounce: true)
        case .breathe: BreatheAnimation(d: d, color: color)
        case .hands: DrawOnSymbol(name: "hands.and.sparkles.fill", size: d * 0.42, weight: weight, color: color, bounce: true)
        case .bell: BellAnimation(d: d, color: color)
        case .icon:
            if let imagePath, let image = NSImage(contentsOfFile: imagePath) {
                ImagePop(image: image, d: d)
            } else {
                DrawOnSymbol(name: symbol ?? "star.fill", size: d * 0.42, weight: weight, color: color, bounce: true)
            }
        }
    }
}

/// SF Symbol, который «прорисовывается», а потом может подпрыгнуть.
private struct DrawOnSymbol: View {
    let name: String
    let size: CGFloat
    let weight: Font.Weight
    let color: Color
    var bounce = false

    @State private var shown = false
    @State private var hop = 0

    var body: some View {
        ZStack {
            if shown {
                Image(systemName: name)
                    .font(.system(size: size, weight: weight))
                    .foregroundStyle(LinearGradient(colors: [color, color.opacity(0.8)], startPoint: .top, endPoint: .bottom))
                    .shadow(color: .black.opacity(0.25), radius: 3, y: 1)
                    .symbolEffect(.bounce, options: .repeat(2), value: hop)
                    .transition(.symbolEffect(.drawOn))
            }
        }
        .task {
            withAnimation(.easeOut(duration: 0.9)) { shown = true }
            guard bounce else { return }
            try? await Task.sleep(for: .milliseconds(1000))
            hop += 1
        }
    }
}

private struct TongueAnimation: View {
    let d: CGFloat
    @State private var up: CGFloat = 0

    var body: some View {
        MouthView(tongue: up)
            .frame(width: d * 0.6, height: d * 0.42)
            .offset(y: d * 0.03)
            .task {
                try? await Task.sleep(for: .milliseconds(300))
                withAnimation(.spring(response: 0.6, dampingFraction: 0.55)) { up = 1 }
            }
    }
}

/// Глаз, который медленно моргает два раза.
private struct BlinkAnimation: View {
    let d: CGFloat
    let color: Color
    @State private var open: CGFloat = 1

    var body: some View {
        ZStack {
            EyeShape().fill(Color.white.opacity(0.95))
            Circle()
                .fill(RadialGradient(colors: [Color(red: 0.35, green: 0.75, blue: 0.85), Color(red: 0.10, green: 0.40, blue: 0.55)],
                                     center: .center, startRadius: 0, endRadius: d * 0.1))
                .frame(width: d * 0.2, height: d * 0.2)
            Circle().fill(.black).frame(width: d * 0.09, height: d * 0.09)
            Circle().fill(.white.opacity(0.9)).frame(width: d * 0.035).offset(x: d * 0.03, y: -d * 0.03)
        }
        .clipShape(EyeShape())
        .overlay(EyeShape().stroke(color, lineWidth: max(1.5, d * 0.025)))
        .frame(width: d * 0.62, height: d * 0.34)
        .scaleEffect(x: 1, y: open)
        .task {
            try? await Task.sleep(for: .milliseconds(350))
            for _ in 0..<2 {
                withAnimation(.easeIn(duration: 0.12)) { open = 0.06 }
                try? await Task.sleep(for: .milliseconds(170))
                withAnimation(.easeOut(duration: 0.2)) { open = 1 }
                try? await Task.sleep(for: .milliseconds(450))
            }
        }
    }
}

/// Форма глаза: два дуговых века.
struct EyeShape: Shape {
    func path(in r: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: r.minX, y: r.midY))
        p.addQuadCurve(to: CGPoint(x: r.maxX, y: r.midY), control: CGPoint(x: r.midX, y: r.minY - r.height * 0.5))
        p.addQuadCurve(to: CGPoint(x: r.minX, y: r.midY), control: CGPoint(x: r.midX, y: r.maxY + r.height * 0.5))
        p.closeSubpath()
        return p
    }
}

/// Бинокль и волны, которые уходят вдаль.
private struct LookFarAnimation: View {
    let d: CGFloat
    let color: Color
    @State private var wave = false

    var body: some View {
        ZStack {
            ForEach(0..<3, id: \.self) { i in
                Circle()
                    .stroke(color.opacity(0.7), lineWidth: max(1, d * 0.02))
                    .frame(width: d * 0.35, height: d * 0.35)
                    .scaleEffect(wave ? 2.4 : 0.6)
                    .opacity(wave ? 0 : 0.9)
                    .animation(.easeOut(duration: 1.4).delay(Double(i) * 0.35), value: wave)
            }
            Image(systemName: "binoculars.fill")
                .font(.system(size: d * 0.3, weight: .semibold))
                .foregroundStyle(color)
                .shadow(color: .black.opacity(0.25), radius: 3, y: 1)
        }
        .task {
            try? await Task.sleep(for: .milliseconds(200))
            wave = true
        }
    }
}

/// Капля, которая наполняется водой снизу вверх.
private struct WaterAnimation: View {
    let d: CGFloat
    let color: Color
    @State private var fill: CGFloat = 0
    @State private var hop = 0

    var body: some View {
        let size = d * 0.46
        ZStack {
            Image(systemName: "drop")
                .font(.system(size: size, weight: .semibold))
                .foregroundStyle(color)
            Image(systemName: "drop.fill")
                .font(.system(size: size, weight: .semibold))
                .foregroundStyle(LinearGradient(colors: [Color(red: 0.45, green: 0.85, blue: 1), Color(red: 0.1, green: 0.55, blue: 0.95)],
                                                startPoint: .top, endPoint: .bottom))
                .mask(alignment: .bottom) {
                    Rectangle().frame(height: size * 1.3 * fill)
                }
        }
        .shadow(color: .black.opacity(0.25), radius: 3, y: 1)
        .symbolEffect(.bounce, value: hop)
        .task {
            try? await Task.sleep(for: .milliseconds(250))
            withAnimation(.easeInOut(duration: 1.1)) { fill = 1 }
            try? await Task.sleep(for: .milliseconds(1100))
            hop += 1
        }
    }
}

/// Круг, который медленно расширяется и сжимается — вдох и выдох.
private struct BreatheAnimation: View {
    let d: CGFloat
    let color: Color
    @State private var inhale = false

    var body: some View {
        ZStack {
            Circle()
                .fill(RadialGradient(colors: [color.opacity(0.85), color.opacity(0.15)],
                                     center: .center, startRadius: 0, endRadius: d * 0.3))
                .frame(width: d * 0.6, height: d * 0.6)
                .scaleEffect(inhale ? 1 : 0.45)
            Circle()
                .stroke(color.opacity(0.8), lineWidth: max(1, d * 0.015))
                .frame(width: d * 0.6, height: d * 0.6)
                .scaleEffect(inhale ? 1.08 : 0.5)
        }
        .task {
            try? await Task.sleep(for: .milliseconds(150))
            withAnimation(.easeInOut(duration: 1.1)) { inhale = true }
            try? await Task.sleep(for: .milliseconds(1150))
            withAnimation(.easeInOut(duration: 1.0)) { inhale = false }
        }
    }
}

/// Своя картинка: появляется с пружиной и подпрыгивает.
private struct ImagePop: View {
    let image: NSImage
    let d: CGFloat
    @State private var shown = false

    var body: some View {
        Image(nsImage: image)
            .resizable()
            .scaledToFill()
            .frame(width: d * 0.62, height: d * 0.62)
            .clipShape(Circle())
            .shadow(color: .black.opacity(0.25), radius: 3, y: 1)
            .scaleEffect(shown ? 1 : 0.3)
            .opacity(shown ? 1 : 0)
            .task { withAnimation(.spring(response: 0.5, dampingFraction: 0.55)) { shown = true } }
    }
}

/// Колокольчик: появляется и качается.
private struct BellAnimation: View {
    let d: CGFloat
    let color: Color
    @State private var shown = false
    @State private var ring = 0

    var body: some View {
        Image(systemName: "bell.fill")
            .font(.system(size: d * 0.42, weight: .semibold))
            .foregroundStyle(color)
            .shadow(color: .black.opacity(0.25), radius: 3, y: 1)
            .scaleEffect(shown ? 1 : 0.3)
            .opacity(shown ? 1 : 0)
            .symbolEffect(.wiggle, options: .repeat(3), value: ring)
            .task {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.6)) { shown = true }
                try? await Task.sleep(for: .milliseconds(400))
                ring += 1
            }
    }
}

// MARK: - Стрелка

/// Вертикальная стрелка вверх. `progress` 0…1 — насколько она «дорисована»;
/// наконечник едет вместе с кончиком линии.
struct ArrowShape: Shape {
    var progress: CGFloat

    var animatableData: CGFloat {
        get { progress }
        set { progress = newValue }
    }

    func path(in rect: CGRect) -> Path {
        var p = Path()
        guard progress > 0.001 else { return p }

        let x = rect.midX
        let bottom = rect.maxY
        let tipY = bottom - rect.height * progress

        p.move(to: CGPoint(x: x, y: bottom))
        p.addLine(to: CGPoint(x: x, y: tipY))

        let head = min(rect.width / 2, rect.height * 0.3) * min(1, progress * 1.6)
        p.move(to: CGPoint(x: x - head, y: tipY + head))
        p.addLine(to: CGPoint(x: x, y: tipY))
        p.addLine(to: CGPoint(x: x + head, y: tipY + head))
        return p
    }
}

// MARK: - Рот и язык

/// Открытый рот анфас: губы, верхние зубы, язык. `tongue` 0 — язык лежит, 1 — прижат к нёбу.
struct MouthView: View {
    var tongue: CGFloat

    private let tongueTop = Color(red: 1.00, green: 0.60, blue: 0.66)
    private let tongueBottom = Color(red: 0.86, green: 0.34, blue: 0.45)
    private let lipLight = Color(red: 0.98, green: 0.55, blue: 0.60)
    private let lipDark = Color(red: 0.80, green: 0.28, blue: 0.38)

    var body: some View {
        GeometryReader { g in
            let w = g.size.width, h = g.size.height
            let tongueW = w * 0.84, tongueH = h * 0.9
            // центр языка: внизу рта → вверху (кончик уходит за зубы)
            let tongueY = h * 1.02 + (h * 0.47 - h * 1.02) * tongue

            ZStack {
                // полость рта
                MouthShape().fill(RadialGradient(
                    colors: [Color(red: 0.62, green: 0.18, blue: 0.24), Color(red: 0.42, green: 0.10, blue: 0.16)],
                    center: .center, startRadius: 0, endRadius: w * 0.55))

                // язык
                ZStack(alignment: .top) {
                    UnevenRoundedRectangle(topLeadingRadius: tongueW * 0.48,
                                           topTrailingRadius: tongueW * 0.48)
                        .fill(LinearGradient(colors: [tongueTop, tongueBottom],
                                             startPoint: .top, endPoint: .bottom))
                    // блик
                    Ellipse()
                        .fill(.white.opacity(0.28))
                        .frame(width: tongueW * 0.32, height: tongueH * 0.1)
                        .offset(x: -tongueW * 0.14, y: tongueH * 0.1)
                        .blur(radius: 1.5)
                    // бороздка
                    Capsule()
                        .fill(tongueBottom.opacity(0.7))
                        .frame(width: max(1.5, w * 0.018), height: tongueH * 0.3)
                        .offset(y: tongueH * 0.16)
                }
                .frame(width: tongueW, height: tongueH)
                .position(x: w / 2, y: tongueY)

                // верхние зубы
                HStack(spacing: max(1, w * 0.012)) {
                    ForEach(0..<6, id: \.self) { _ in
                        UnevenRoundedRectangle(bottomLeadingRadius: w * 0.035,
                                               bottomTrailingRadius: w * 0.035)
                            .fill(LinearGradient(colors: [.white, Color(white: 0.86)],
                                                 startPoint: .top, endPoint: .bottom))
                    }
                }
                .frame(width: w * 0.86, height: h * 0.24)
                .position(x: w / 2, y: h * 0.12)
            }
            .clipShape(MouthShape())
            .overlay(
                MouthShape().stroke(
                    LinearGradient(colors: [lipLight, lipDark], startPoint: .top, endPoint: .bottom),
                    style: StrokeStyle(lineWidth: max(2, w * 0.07), lineJoin: .round))
            )
            .shadow(color: .black.opacity(0.25), radius: 3, y: 1.5)
        }
    }
}

/// Форма открытого рта: верхняя губа — пологая дуга, нижняя — глубокая.
struct MouthShape: Shape {
    func path(in r: CGRect) -> Path {
        var p = Path()
        let cornerY = r.minY + r.height * 0.18
        let left = CGPoint(x: r.minX, y: cornerY)
        let right = CGPoint(x: r.maxX, y: cornerY)
        p.move(to: left)
        p.addQuadCurve(to: right, control: CGPoint(x: r.midX, y: r.minY - r.height * 0.12))
        p.addQuadCurve(to: left, control: CGPoint(x: r.midX, y: r.minY + r.height * 1.75))
        p.closeSubpath()
        return p
    }
}

// MARK: - Превью

/// «Обои» для превью, чтобы было видно затемнение и стекло.
private struct PreviewWallpaper: View {
    var body: some View {
        LinearGradient(colors: [Color(red: 0.98, green: 0.64, blue: 0.45), Color(red: 0.50, green: 0.36, blue: 0.78)],
                       startPoint: .topLeading, endPoint: .bottomTrailing)
    }
}

private extension NudgeView.Config {
    static func preview(_ animation: ReminderAnimation, caption: String? = "Sit up straight",
                        style: ArrowStyle = .circle) -> Self {
        preview([.init(animation: animation, caption: caption)], style: style)
    }

    static func preview(_ items: [Item], style: ArrowStyle = .circle) -> Self {
        .init(items: items, dim: 0.25, blur: 0.6, color: .white, lineWidth: 7, arrowStyle: style)
    }
}

#Preview("Nudge · Posture (glass)", traits: .fixedLayout(width: 1000, height: 650)) {
    NudgeView(config: .preview(.arrowUp)).background(PreviewWallpaper())
}

#Preview("Nudge · Posture (line)", traits: .fixedLayout(width: 1000, height: 650)) {
    NudgeView(config: .preview(.arrowUp, style: .plain)).background(PreviewWallpaper())
}

#Preview("Nudge · Tongue", traits: .fixedLayout(width: 1000, height: 650)) {
    NudgeView(config: .preview(.tongueUp, caption: "Tongue up")).background(PreviewWallpaper())
}

#Preview("Nudge · Set of 3", traits: .fixedLayout(width: 1000, height: 650)) {
    NudgeView(config: .preview([
        .init(animation: .arrowUp, caption: "Sit up straight"),
        .init(animation: .blink, caption: "Blink slowly 10 times"),
        .init(animation: .water, caption: "Drink some water"),
    ])).background(PreviewWallpaper())
}

/// Все анимации библиотеки в финальном кадре.
#Preview("Animation library", traits: .sizeThatFitsLayout) {
    LazyVGrid(columns: Array(repeating: GridItem(.fixed(150), spacing: 20), count: 4), spacing: 24) {
        ForEach(ReminderAnimation.allCases) { a in
            VStack(spacing: 10) {
                GlassBadge(d: 120, color: .white) {
                    ReminderAnimationView(animation: a, color: .white, d: 120)
                }
                Text(a.title).font(.caption).foregroundStyle(.white)
            }
        }
    }
    .padding(30)
    .background(PreviewWallpaper())
}

#Preview("Mouth · tongue down / up", traits: .sizeThatFitsLayout) {
    HStack(spacing: 40) {
        MouthView(tongue: 0).frame(width: 180, height: 126)
        MouthView(tongue: 1).frame(width: 180, height: 126)
    }
    .padding(40)
    .background(Color(white: 0.2))
}
