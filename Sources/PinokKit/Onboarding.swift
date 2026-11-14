import AppKit
import ServiceManagement
import SwiftUI

// MARK: - Модель первого запуска

/// Что пользователь выбрал на экране приветствия. Применяется кнопкой «Начать».
@MainActor
@Observable
final class OnboardingModel {
    static let stepCount = 4

    var step = 0
    var selected: Set<String>
    var breaksOn: Bool
    var breakInterval: Int
    var exercises: Set<BreakExercise>

    /// Готовые напоминания для живого превью (id не меняются между перерисовками).
    @ObservationIgnored private let previewByTemplate: [String: Reminder] = Dictionary(
        uniqueKeysWithValues: ReminderLibrary.all.map { tpl in
            var r = tpl.make()
            r.showCaption = true // на превью видно, что это за напоминание
            return (tpl.id, r)
        })

    /// Выбранные напоминания — для превью, в порядке библиотеки.
    var selectedPreview: [Reminder] {
        ReminderLibrary.all.filter { selected.contains($0.id) }.compactMap { previewByTemplate[$0.id] }
    }

    init(settings: AppSettings) {
        let current = Set(settings.reminders.filter(\.enabled).compactMap(\.template))
        selected = current.isEmpty ? ["posture", "tongue"] : current
        breaksOn = settings.breakEnabled
        breakInterval = [30, 60].contains(settings.breakInterval) ? settings.breakInterval : 60
        exercises = Set(settings.breakExercises)
    }

    func toggle(_ template: String) {
        if selected.contains(template) { selected.remove(template) } else { selected.insert(template) }
    }

    func toggle(_ exercise: BreakExercise) {
        if exercises.contains(exercise) { exercises.remove(exercise) } else { exercises.insert(exercise) }
    }

    /// Записывает выбор в настройки. Свои напоминания пользователя не трогает.
    func apply(to s: AppSettings) {
        var kept = s.reminders.filter { r in
            guard let tpl = r.template else { return true }
            return selected.contains(tpl)
        }
        for i in kept.indices where kept[i].template != nil { kept[i].enabled = true }
        for tpl in ReminderLibrary.all where selected.contains(tpl.id) && !kept.contains(where: { $0.template == tpl.id }) {
            kept.append(tpl.make())
        }
        // Сначала готовые — в порядке библиотеки, потом свои.
        let order = Dictionary(uniqueKeysWithValues: ReminderLibrary.all.enumerated().map { ($1.id, $0) })
        s.reminders = kept.sorted { a, b in
            (a.template.flatMap { order[$0] } ?? Int.max) < (b.template.flatMap { order[$0] } ?? Int.max)
        }
        // Удалённые напоминания убираем и из наборов.
        let ids = Set(s.reminders.map(\.id))
        for i in s.sets.indices { s.sets[i].reminderIDs.removeAll { !ids.contains($0) } }

        s.breakEnabled = breaksOn
        s.breakInterval = breakInterval
        s.breakExercises = BreakExercise.allCases.filter { exercises.contains($0) }
        s.onboardingDone = true
    }
}

// MARK: - Окно

/// Онбординг на весь экран: рабочий стол приглушён, видно только Pinok.
@MainActor
final class OnboardingWindow {
    static let shared = OnboardingWindow()
    private var window: OverlayWindow?
    private var keyMonitor: Any?
    /// Для записи демо: не сохранять «пройдено» при закрытии.
    private var isDemo = false

    var isShowing: Bool { window != nil }

    func show(demo: Bool = false, frame: NSRect? = nil) {
        if let w = window {
            w.makeKeyAndOrderFront(nil)
            NSApp.activate()
            return
        }
        isDemo = demo
        let rect = frame ?? NSScreen.active.frame
        let model = OnboardingModel(settings: .shared)
        let view = OnboardingView(model: model, demo: demo) { [weak self] in self?.close() }

        let w = OverlayWindow(frame: rect)
        w.acceptsKey = true
        w.contentView = NSHostingView(rootView: view)
        w.alphaValue = 0
        w.makeKeyAndOrderFront(nil)
        NSApp.activate()
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.6
            w.animator().alphaValue = 1
        }
        window = w

        // Esc — закрыть
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard event.keyCode == 53 else { return event }
            MainActor.assumeIsolated { self?.close() }
            return nil
        }
    }

    func close() {
        guard let w = window else { return }
        window = nil
        if let m = keyMonitor { NSEvent.removeMonitor(m) }
        keyMonitor = nil
        Sounds.stop()
        // Закрыли — больше не показываем сами (можно открыть из настроек).
        if !isDemo { AppSettings.shared.onboardingDone = true }
        NSAnimationContext.runAnimationGroup({ ctx in
            ctx.duration = 0.5
            w.animator().alphaValue = 0
        }, completionHandler: { w.orderOut(nil) })
    }
}

// MARK: - Экран

struct OnboardingView: View {
    @Bindable var model: OnboardingModel
    var demo = false
    let onFinish: () -> Void

    @Bindable private var settings = AppSettings.shared
    @State private var intro = IntroState()
    @State private var forward = true
    /// Где стоит стеклянный круг — туда сходятся кометы.
    @State private var badgeCenter: CGPoint?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// Этапы интро-анимации.
    struct IntroState {
        var dim = false
        var strokes = false
        var burst = false
        var badge = false
        var arrow = false
        var bloom = false
        var title = false
        var subtitle = false
        var controls = false
    }

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width, h = geo.size.height
            ZStack {
                // Приглушённый рабочий стол
                BackdropBlur(material: .fullScreenUI)
                    .opacity(intro.dim ? 1 : 0)
                Color.black.opacity(intro.dim ? 0.62 : 0)

                // Мягкое цветное свечение за содержимым (не прямоугольный фон)
                LivingGradient()
                    .frame(width: w * 0.85, height: h * 0.8)
                    .clipShape(Ellipse())
                    .blur(radius: min(w, h) * 0.12)
                    .opacity(intro.bloom ? 0.55 : 0)
                    .scaleEffect(intro.bloom ? 1 : 0.4)

                // Линии-кометы с краёв экрана к центру
                CometStrokes(progress: intro.strokes ? 1 : 0, center: badgeCenter ?? CGPoint(x: w / 2, y: h * 0.36))
                    .opacity(intro.badge ? 0 : 1)
                    .allowsHitTesting(false)

                // Искры в момент, когда линии сходятся
                SparkBurst(isOn: intro.burst, center: badgeCenter ?? CGPoint(x: w / 2, y: h * 0.36))
                    .allowsHitTesting(false)

                // Содержимое шагов — колонка по центру
                VStack(spacing: 0) {
                    ZStack {
                        switch model.step {
                        case 0: welcome.transition(.blurReplace(forward: forward))
                        case 1: remindersStep.transition(.blurReplace(forward: forward))
                        case 2: breaksStep.transition(.blurReplace(forward: forward))
                        default: readyStep.transition(.blurReplace(forward: forward))
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)

                    footer
                        .opacity(intro.controls ? 1 : 0)
                        .offset(y: intro.controls ? 0 : 20)
                }
                .frame(width: min(820, w - 80), height: min(640, h - 120))
                .position(x: w / 2, y: h / 2)

                // Закрыть
                Button(action: onFinish) {
                    Image(systemName: "xmark")
                        .font(.system(size: 14, weight: .bold))
                        .frame(width: 34, height: 34)
                        .glassEffect(.regular, in: Circle())
                }
                .buttonStyle(.plain)
                .help(t("Close"))
                .accessibilityLabel(t("Close"))
                .position(x: 40, y: 40)
                .opacity(intro.controls ? 1 : 0)
            }
        }
        .coordinateSpace(.named("onboarding"))
        .onPreferenceChange(BadgeCenterKey.self) { badgeCenter = $0 }
        .foregroundStyle(.white)
        .ignoresSafeArea()
        .id(settings.language) // язык меняется сразу
        .task { await playIntro() }
    }

    // MARK: Шаг 1 — приветствие и язык

    private var welcome: some View {
        VStack(spacing: 26) {
            GlassBadge(d: 120, color: .white, glow: intro.bloom) {
                if intro.arrow {
                    Image(systemName: "arrow.up")
                        .font(.system(size: 52, weight: .semibold))
                        .transition(.symbolEffect(.drawOn))
                }
            }
            .scaleEffect(intro.badge ? 1 : 0.2)
            .opacity(intro.badge ? 1 : 0)
            .background(GeometryReader { proxy in
                let f = proxy.frame(in: .named("onboarding"))
                Color.clear.preference(key: BadgeCenterKey.self, value: CGPoint(x: f.midX, y: f.midY))
            })

            VStack(spacing: 10) {
                RevealText(text: "Pinok", isOn: intro.title)
                    .font(.system(size: 64, weight: .bold, design: .rounded))
                Text(t("Small pushes for a healthy day at the computer."))
                    .font(.system(size: 19, weight: .medium, design: .rounded))
                    .opacity(intro.subtitle ? 0.9 : 0)
                    .blur(radius: intro.subtitle ? 0 : 8)
            }

            VStack(spacing: 12) {
                Text(t("Choose your language"))
                    .font(.system(size: 13, weight: .semibold))
                    .opacity(0.75)
                HStack(spacing: 12) {
                    LanguagePill(title: "English", selected: currentLanguage == .en) { settings.language = .en }
                    LanguagePill(title: "Русский", selected: currentLanguage == .ru) { settings.language = .ru }
                }
            }
            .opacity(intro.controls ? 1 : 0)
            .offset(y: intro.controls ? 0 : 16)
        }
    }

    private var currentLanguage: AppLanguage { L10n.isRussian ? .ru : .en }

    // MARK: Шаг 2 — напоминания

    private var remindersStep: some View {
        VStack(alignment: .leading, spacing: 18) {
            StepHeader(title: t("Choose your reminders"),
                       subtitle: t("They show for a few seconds. You can click and type at this time."))
            HStack(alignment: .top, spacing: 18) {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 2), spacing: 10) {
                    ForEach(ReminderLibrary.all) { tpl in
                        ChoiceCard(symbol: tpl.animation.symbol, colors: tpl.animation.colors,
                                   title: t(tpl.title), detail: t("Every %@", ReminderLibrary.label(tpl.interval)),
                                   selected: model.selected.contains(tpl.id)) {
                            withAnimation(.snappy) { model.toggle(tpl.id) }
                            Haptics.play(.tap)
                        }
                    }
                }
                .frame(width: 430)

                VStack(spacing: 12) {
                    ReminderLivePreview(reminders: model.selectedPreview, height: 190)
                    EffectPanel(settings: settings, previewTemplate: firstSelectedTemplate)
                }
            }

            Text(t("You can change the times later in Settings."))
                .font(.callout)
                .opacity(0.7)
        }
    }

    private var firstSelectedTemplate: ReminderTemplate {
        ReminderLibrary.all.first { model.selected.contains($0.id) } ?? ReminderLibrary.all[0]
    }

    // MARK: Шаг 3 — перерывы

    private var breaksStep: some View {
        VStack(alignment: .leading, spacing: 18) {
            StepHeader(title: t("Breaks with exercises"),
                       subtitle: t("The screen locks for a few minutes. You do a short list of exercises."))

            GlassPanel {
                HStack {
                    Text(t("Lock the screen for breaks")).font(.system(size: 16, weight: .medium))
                    Spacer()
                    Toggle("", isOn: $model.breaksOn).labelsHidden().toggleStyle(.switch)
                }
                HStack {
                    Text(t("Every")).font(.system(size: 16, weight: .medium))
                    Spacer()
                    ForEach([30, 60], id: \.self) { m in
                        SmallPill(title: ReminderLibrary.label(m), selected: model.breakInterval == m) {
                            withAnimation(.snappy) { model.breakInterval = m }
                        }
                    }
                }
                .opacity(model.breaksOn ? 1 : 0.4)
                .disabled(!model.breaksOn)
            }

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 3), spacing: 12) {
                ForEach(BreakExercise.allCases) { ex in
                    ChoiceCard(symbol: ex.symbol, colors: SettingsPage.breaks.colors, title: ex.title,
                               detail: ex.instruction, selected: model.exercises.contains(ex)) {
                        withAnimation(.snappy) { model.toggle(ex) }
                        Haptics.play(.tap)
                    }
                }
            }
            .opacity(model.breaksOn ? 1 : 0.4)
            .disabled(!model.breaksOn)
        }
    }

    // MARK: Шаг 4 — готово

    private var readyStep: some View {
        VStack(spacing: 22) {
            GlassBadge(d: 96, color: .white, glow: true) {
                Image(systemName: "checkmark")
                    .font(.system(size: 40, weight: .bold))
                    .transition(.symbolEffect(.drawOn))
            }
            StepHeader(title: t("You are ready"),
                       subtitle: t("Pinok lives in the menu bar. Click the ↑ icon to see the next reminder."),
                       centered: true)
            GlassPanel {
                HStack {
                    Text(t("Launch at login")).font(.system(size: 16, weight: .medium))
                    Spacer()
                    Toggle("", isOn: Binding(
                        get: { SMAppService.mainApp.status == .enabled },
                        set: { on in
                            if on { try? SMAppService.mainApp.register() } else { try? SMAppService.mainApp.unregister() }
                        }))
                        .labelsHidden()
                        .toggleStyle(.switch)
                }
            }
            .frame(width: 420)

            Button {
                let tpl = ReminderLibrary.all.first { model.selected.contains($0.id) } ?? ReminderLibrary.all[0]
                Scheduler.shared.preview(tpl.make())
            } label: {
                Label(t("Show me a reminder"), systemImage: "play.fill")
            }
            .buttonStyle(PillButtonStyle())
        }
    }

    // MARK: Низ: точки и кнопки

    private var footer: some View {
        HStack {
            if model.step > 0 {
                Button(t("Back")) { go(-1) }
                    .buttonStyle(PillButtonStyle())
            }
            Spacer()
            HStack(spacing: 8) {
                ForEach(0..<OnboardingModel.stepCount, id: \.self) { i in
                    Capsule()
                        .fill(.white.opacity(i == model.step ? 0.95 : 0.35))
                        .frame(width: i == model.step ? 22 : 8, height: 8)
                }
            }
            .animation(.spring(response: 0.4, dampingFraction: 0.8), value: model.step)
            Spacer()
            if model.step < OnboardingModel.stepCount - 1 {
                Button(t("Continue")) { go(1) }
                    .buttonStyle(PillButtonStyle(prominent: true))
                    .keyboardShortcut(.defaultAction)
            } else {
                Button(t("Start")) {
                    if !demo { model.apply(to: settings) }
                    Sounds.play("melody.done")
                    Haptics.rhythm(.strong, count: 2, interval: 0.12)
                    onFinish()
                }
                .buttonStyle(PillButtonStyle(prominent: true))
                .keyboardShortcut(.defaultAction)
            }
        }
    }

    private func go(_ delta: Int) {
        forward = delta > 0
        Haptics.play(.click)
        withAnimation(.spring(response: 0.55, dampingFraction: 0.85)) {
            model.step = min(max(0, model.step + delta), OnboardingModel.stepCount - 1)
        }
    }

    // MARK: Интро

    private func playIntro() async {
        // Рабочий стол гаснет
        withAnimation(.easeOut(duration: 0.6)) { intro.dim = true }
        try? await Task.sleep(for: .milliseconds(300))

        Sounds.play(AppSettings.shared.introSound)
        if !reduceMotion {
            // Кометы летят к центру
            withAnimation(.timingCurve(0.5, 0, 0.2, 1, duration: 1.5)) { intro.strokes = true }
            try? await Task.sleep(for: .milliseconds(1350))
            // Вспышка искр
            intro.burst = true
        }
        Haptics.rhythm(.strong, count: 2, interval: 0.1)
        withAnimation(.spring(response: 0.6, dampingFraction: 0.6)) { intro.badge = true }
        withAnimation(.easeOut(duration: 1.6)) { intro.bloom = true }
        try? await Task.sleep(for: .milliseconds(250))
        withAnimation(.easeOut(duration: 0.9)) { intro.arrow = true }

        try? await Task.sleep(for: .milliseconds(500))
        intro.title = true

        try? await Task.sleep(for: .milliseconds(700))
        withAnimation(.easeOut(duration: 0.7)) { intro.subtitle = true }

        try? await Task.sleep(for: .milliseconds(450))
        withAnimation(.spring(response: 0.6, dampingFraction: 0.85)) { intro.controls = true }
    }
}

private struct BadgeCenterKey: PreferenceKey {
    static let defaultValue: CGPoint? = nil
    static func reduce(value: inout CGPoint?, nextValue: () -> CGPoint?) { value = nextValue() ?? value }
}

// MARK: - Рисовка интро

/// Светящиеся линии с краёв экрана, которые по дугам сходятся в центр.
struct CometStrokes: View {
    var progress: CGFloat
    let center: CGPoint

    private static let palette: [Color] = [
        Color(red: 1.00, green: 0.45, blue: 0.58), Color(red: 1.00, green: 0.65, blue: 0.35),
        Color(red: 0.70, green: 0.45, blue: 1.00), Color(red: 0.40, green: 0.65, blue: 1.00),
        Color(red: 0.40, green: 0.90, blue: 0.75),
    ]

    var body: some View {
        GeometryReader { geo in
            ZStack {
                ForEach(0..<14, id: \.self) { i in
                    CometPath(index: i, total: 14, center: center, size: geo.size, progress: progress)
                        .stroke(Self.palette[i % Self.palette.count],
                                style: StrokeStyle(lineWidth: i % 3 == 0 ? 3.5 : 2, lineCap: .round))
                        .shadow(color: Self.palette[i % Self.palette.count], radius: 8)
                }
            }
        }
    }
}

/// Одна дуга: от точки на краю экрана к центру. Рисуется «хвостом кометы».
private struct CometPath: Shape {
    let index: Int
    let total: Int
    let center: CGPoint
    let size: CGSize
    var progress: CGFloat

    var animatableData: CGFloat {
        get { progress }
        set { progress = newValue }
    }

    func path(in rect: CGRect) -> Path {
        // Каждая линия стартует чуть позже соседней.
        let delay = CGFloat(index) / CGFloat(total) * 0.35
        let local = min(1, max(0, (progress - delay) / (1 - delay)))
        guard local > 0 else { return Path() }

        // Точка старта по кругу за краями экрана.
        let angle = Double(index) / Double(total) * 2 * .pi + 0.3
        let radius = max(size.width, size.height) * 0.75
        let start = CGPoint(x: center.x + cos(angle) * radius, y: center.y + sin(angle) * radius)
        // Изгиб: дуги закручиваются в одну сторону.
        let swirl = angle + .pi / 2.2
        let c1 = CGPoint(x: center.x + cos(swirl) * radius * 0.55, y: center.y + sin(swirl) * radius * 0.55)
        let end = center

        var full = Path()
        full.move(to: start)
        full.addQuadCurve(to: end, control: c1)
        // Хвост длиной 35% пути движется к центру.
        return full.trimmedPath(from: max(0, local - 0.35), to: local)
    }
}

/// Искры, которые разлетаются из центра.
struct SparkBurst: View {
    let isOn: Bool
    let center: CGPoint

    var body: some View {
        ZStack {
            ForEach(0..<18, id: \.self) { i in
                let angle = Double(i) / 18 * 2 * .pi
                let distance: CGFloat = i % 2 == 0 ? 180 : 120
                Circle()
                    .fill(.white)
                    .frame(width: i % 3 == 0 ? 6 : 4, height: i % 3 == 0 ? 6 : 4)
                    .shadow(color: .white, radius: 6)
                    .position(x: center.x + (isOn ? cos(angle) * distance : 0),
                              y: center.y + (isOn ? sin(angle) * distance : 0))
                    .opacity(isOn ? 0 : 1)
                    .animation(.easeOut(duration: 0.9), value: isOn)
            }
        }
        .opacity(isOn ? 1 : 0)
    }
}

// MARK: - Части

/// Сила затемнения и размытия экрана: живое мини-превью, ползунок и «Попробовать».
private struct EffectPanel: View {
    @Bindable var settings: AppSettings
    let previewTemplate: ReminderTemplate

    private var effect: Binding<Double> {
        Binding(get: { settings.nudgeBlur },
                set: { v in settings.nudgeBlur = v; settings.nudgeDim = 0.05 + 0.4 * v })
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(t("Darken the screen")).font(.system(size: 15, weight: .semibold))
                Spacer()
                Button {
                    Scheduler.shared.preview(previewTemplate.make())
                } label: {
                    Label(t("Try it"), systemImage: "play.fill")
                }
                .buttonStyle(PillButtonStyle())
            }
            Text(t("How dark and blurry the screen becomes during a reminder."))
                .font(.system(size: 12)).opacity(0.8)
            HStack(spacing: 8) {
                Text(t("Light")).font(.caption).opacity(0.75)
                Slider(value: effect, in: 0...1)
                Text(t("Strong")).font(.caption).opacity(0.75)
            }
        }
        .padding(14)
        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}

/// Живой переливающийся фон (MeshGradient, точки медленно плавают).
struct LivingGradient: View {
    var body: some View {
        TimelineView(.animation) { ctx in
            let t = Float(ctx.date.timeIntervalSinceReferenceDate)
            MeshGradient(
                width: 3, height: 3,
                points: [
                    [0, 0], [0.5 + 0.1 * sin(t * 0.4), 0], [1, 0],
                    [0, 0.5 + 0.12 * sin(t * 0.55)],
                    [0.5 + 0.18 * sin(t * 0.35), 0.5 + 0.16 * cos(t * 0.45)],
                    [1, 0.5 + 0.12 * cos(t * 0.5)],
                    [0, 1], [0.5 + 0.1 * cos(t * 0.3), 1], [1, 1],
                ],
                colors: [
                    Color(red: 0.98, green: 0.45, blue: 0.55), Color(red: 1.00, green: 0.62, blue: 0.40), Color(red: 0.98, green: 0.78, blue: 0.45),
                    Color(red: 0.62, green: 0.38, blue: 0.95), Color(red: 0.90, green: 0.40, blue: 0.70), Color(red: 1.00, green: 0.55, blue: 0.45),
                    Color(red: 0.25, green: 0.45, blue: 0.95), Color(red: 0.40, green: 0.55, blue: 1.00), Color(red: 0.55, green: 0.40, blue: 0.95),
                ]
            )
        }
    }
}

/// Текст, буквы которого по очереди проявляются из размытия.
struct RevealText: View {
    let text: String
    let isOn: Bool

    var body: some View {
        HStack(spacing: 0) {
            ForEach(Array(text.enumerated()), id: \.offset) { i, ch in
                Text(String(ch))
                    .opacity(isOn ? 1 : 0)
                    .blur(radius: isOn ? 0 : 14)
                    .offset(y: isOn ? 0 : 14)
                    .animation(.spring(response: 0.6, dampingFraction: 0.8).delay(Double(i) * 0.07), value: isOn)
            }
        }
    }
}

/// Переход между шагами: размытие, лёгкий масштаб и сдвиг по направлению.
private struct BlurReplace: Transition {
    let forward: Bool
    func body(content: Content, phase: TransitionPhase) -> some View {
        let shift: CGFloat = phase == .willAppear ? (forward ? 40 : -40) : (phase == .didDisappear ? (forward ? -40 : 40) : 0)
        content
            .blur(radius: phase.isIdentity ? 0 : 14)
            .opacity(phase.isIdentity ? 1 : 0)
            .scaleEffect(phase.isIdentity ? 1 : 0.97)
            .offset(x: shift)
    }
}

private extension AnyTransition {
    static func blurReplace(forward: Bool) -> AnyTransition { AnyTransition(BlurReplace(forward: forward)) }
}

private struct StepHeader: View {
    let title: String
    let subtitle: String
    var centered = false

    var body: some View {
        VStack(alignment: centered ? .center : .leading, spacing: 6) {
            Text(title).font(.system(size: 32, weight: .bold, design: .rounded))
            Text(subtitle)
                .font(.system(size: 16, weight: .medium, design: .rounded))
                .opacity(0.85)
                .multilineTextAlignment(centered ? .center : .leading)
        }
        .frame(maxWidth: .infinity, alignment: centered ? .center : .leading)
    }
}

/// Стеклянная панель для настроек на онбординге.
private struct GlassPanel<Content: View>: View {
    @ViewBuilder var content: Content
    var body: some View {
        VStack(spacing: 14) { content }
            .padding(18)
            .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}

/// Карточка выбора с галочкой.
private struct ChoiceCard: View {
    let symbol: String
    let colors: [Color]
    let title: String
    let detail: String
    let selected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                AppIcon(symbol: symbol, colors: colors, size: 36)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(.system(size: 15, weight: .semibold, design: .rounded))
                    Text(detail).font(.system(size: 11, design: .rounded)).opacity(0.8).lineLimit(2)
                }
                Spacer(minLength: 4)
                Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 20))
                    .contentTransition(.symbolEffect(.replace))
                    .opacity(selected ? 1 : 0.6)
            }
            .padding(12)
            .frame(maxWidth: .infinity, minHeight: 68, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(.white.opacity(selected ? 0.24 : 0.08)))
            .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(.white.opacity(selected ? 0.6 : 0.18), lineWidth: selected ? 1.5 : 1))
            .contentShape(RoundedRectangle(cornerRadius: 14))
        }
        .buttonStyle(.plain)
    }
}

private struct LanguagePill: View {
    let title: String
    let selected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 17, weight: .semibold, design: .rounded))
                .padding(.horizontal, 26)
                .padding(.vertical, 12)
                .background(Capsule().fill(.white.opacity(selected ? 0.95 : 0.14)))
                .foregroundStyle(selected ? Color.black : .white)
                .overlay(Capsule().strokeBorder(.white.opacity(0.35)))
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .animation(.snappy, value: selected)
    }
}

private struct SmallPill: View {
    let title: String
    let selected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 14, weight: .semibold, design: .rounded))
                .padding(.horizontal, 14)
                .padding(.vertical, 7)
                .background(Capsule().fill(.white.opacity(selected ? 0.9 : 0.14)))
                .foregroundStyle(selected ? Color.black : .white)
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}

#Preview("Onboarding · reminders step", traits: .fixedLayout(width: 1280, height: 800)) {
    let _ = AppSettings.shared
    let _ = L10n.isRussian = false
    let model = OnboardingModel(settings: .shared)
    let _ = model.step = 1
    let _ = model.selected = ["posture", "blink", "water"]
    OnboardingView(model: model, demo: true, onFinish: {})
        .background(Color(red: 0.12, green: 0.1, blue: 0.16))
}

#Preview("Onboarding · effect panel", traits: .fixedLayout(width: 760, height: 160)) {
    let _ = AppSettings.shared
    let _ = L10n.isRussian = false
    EffectPanel(settings: AppSettings.shared, previewTemplate: ReminderLibrary.all[0])
        .padding(20)
        .foregroundStyle(.white)
        .background(LivingGradient())
}
