import SwiftUI

public struct PinokApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var delegate

    public init() {}

    public var body: some Scene {
        MenuBarExtra {
            MenuContent()
        } label: {
            MenuBarLabel()
        }
        .menuBarExtraStyle(.window)

        Settings {
            SettingsView()
        }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        MainActor.assumeIsolated {
            if let i = CommandLine.arguments.firstIndex(of: "--render-variants"), i + 1 < CommandLine.arguments.count {
                DesignVariantRenderer.renderAll(to: CommandLine.arguments[i + 1])
                exit(0)
            }
            // Файл настроек из терминала: --export-settings <файл> | --import-settings <файл>
            let a = CommandLine.arguments
            if let i = a.firstIndex(of: "--export-settings"), i + 1 < a.count {
                let ok = (try? AppSettings.shared.exportBackup().write(to: URL(fileURLWithPath: a[i + 1]))) != nil
                print(ok ? "saved: \(a[i + 1])" : "error: cannot write \(a[i + 1])")
                exit(ok ? 0 : 1)
            }
            if let i = a.firstIndex(of: "--import-settings"), i + 1 < a.count {
                guard let data = FileManager.default.contents(atPath: a[i + 1]) else { print("error: cannot read"); exit(1) }
                do { try AppSettings.shared.importBackup(data); print("loaded: \(a[i + 1])"); exit(0) }
                catch { print("error: \(error)"); exit(1) }
            }
            if let i = CommandLine.arguments.firstIndex(of: "--render-panel"), i + 1 < CommandLine.arguments.count {
                Scheduler.shared.start()
                Scheduler.shared.tick()
                DesignVariantRenderer.renderPanel(to: CommandLine.arguments[i + 1])
                exit(0)
            }
            Scheduler.shared.start()

            // Для быстрой проверки из терминала:
            //   Pinok.app/Contents/MacOS/Pinok --demo <template id> | --demo-break
            let args = CommandLine.arguments
            if let i = args.firstIndex(of: "--stage"), i + 1 < args.count {
                Stage.run(args[i + 1])
                return
            }
            if args.contains("--diagnose") {
                print("mic in use:        ", SmartPause.isMicInUse())
                print("camera in use:     ", SmartPause.isCameraInUse())
                print("fullscreen video:  ", SmartPause.isFullscreenVideo())
                exit(0)
            }
            if !AppSettings.shared.onboardingDone || args.contains("--onboarding") {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { OnboardingWindow.shared.show() }
            }
            if let i = args.firstIndex(of: "--page"), i + 1 < args.count,
               let page = SettingsPage(argument: args[i + 1]) {
                SettingsView.launchPage = page
            }
            if let i = args.firstIndex(of: "--demo"), i + 1 < args.count,
               let tpl = ReminderLibrary.template(args[i + 1]) {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { Scheduler.shared.preview(tpl.make()) }
            }
            if args.contains("--demo-break") {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { Scheduler.shared.previewBreak() }
            }
        }
    }
}

// MARK: - Трей

struct MenuBarLabel: View {
    @Environment(\.openSettings) private var openSettings
    private var scheduler = Scheduler.shared
    private var settings = AppSettings.shared

    var body: some View {
        let icon = scheduler.isHolding ? "pause.circle.fill" : "arrow.up.circle.fill"
        let text = settings.showCountdown ? scheduler.menuBarText : nil
        Image(nsImage: Self.render(icon: icon, text: text))
            .task {
                if CommandLine.arguments.contains("--open-settings") {
                    try? await Task.sleep(for: .milliseconds(400))
                    NSApp.activate()
                    openSettings()
                }
            }
    }

    /// MenuBarExtra показывает только одну картинку или текст, поэтому
    /// рисуем «иконка + минуты» в одну template-картинку (подстраивается под тему).
    @MainActor
    static func render(icon: String, text: String?) -> NSImage {
        let content = HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 15, weight: .medium))
            if let text {
                Text(text)
                    .font(.system(size: 13, weight: .medium))
                    .monospacedDigit()
            }
        }
        .foregroundStyle(.black)
        .frame(height: 18)

        let renderer = ImageRenderer(content: content)
        renderer.scale = NSScreen.main?.backingScaleFactor ?? 2
        let image = renderer.nsImage ?? NSImage()
        image.isTemplate = true
        return image
    }
}

/// Панель в трее: крупный отсчёт только до перерыва, короткие напоминания — без таймеров.
/// Статистики нет намеренно: приложение про силы и покой, а не про счёт.
struct MenuContent: View {
    @Environment(\.openSettings) private var openSettings
    private var scheduler = Scheduler.shared
    private var settings = AppSettings.shared

    var body: some View {
        let _ = settings.language
        VStack(spacing: 14) {
            header
            nowTab
        }
        .padding(16)
        .frame(width: 340)
    }

    // MARK: Шапка

    /// Шапка в одну строку: иконка · выход · настройки.
    private var header: some View {
        HStack(spacing: 8) {
                AppIcon(symbol: "arrow.up", colors: [Color(red: 1.00, green: 0.45, blue: 0.58), Color(red: 0.62, green: 0.40, blue: 0.95)], size: 24)
                    .accessibilityHidden(true)
                Text("Pinok").font(.headline)
                Spacer(minLength: 0)
                // Выход — красная кнопка рядом с шестерёнкой.
                Button { NSApp.terminate(nil) } label: {
                    Image(systemName: "power")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.red)
                        .frame(width: 32, height: 32)
                        .background(Circle().fill(Color.red.opacity(0.12)))
                        .contentShape(Circle())
                }
                .buttonStyle(.plain)
                .help(t("Quit Pinok"))
                .accessibilityLabel(t("Quit Pinok"))
                .keyboardShortcut("q")
                Button {
                    closePanel()
                    NSApp.activate()
                    openSettings()
                } label: {
                    Image(systemName: "gearshape.fill")
                        .font(.system(size: 16, weight: .medium))
                        .frame(width: 32, height: 32)
                        .contentShape(Circle())
                }
                .buttonStyle(.plain)
                .glassEffect(.regular.interactive(), in: Circle())
                .help(t("Settings…"))
                .accessibilityLabel(t("Settings…"))
                .keyboardShortcut(",")
        }
    }

    // MARK: Сейчас

    private var nowTab: some View {
        VStack(spacing: 14) {
            hero
            if !scheduler.isPaused && !scheduler.onBreak { pauseRow }
            // Строка о конце дня — в самом низу: за последний час до конца и после него.
            if !scheduler.onBreak && !scheduler.onDayEnd { dayEndStatus }
        }
    }

    /// Главный блок: отсчёт до перерыва или состояние (пауза, звонок, простой, перерыв).
    @ViewBuilder private var hero: some View {
        if scheduler.onBreak {
            Hero(symbol: "cup.and.saucer.fill", tint: SettingsPage.breaks.colors[0],
                 caption: nil, big: t("Break time"))
        } else if scheduler.onDayEnd {
            Hero(symbol: "sunset.fill", tint: SettingsPage.dayEnd.colors[0], caption: nil,
                 big: t("The workday is over"), bigSize: 26)
        } else if let until = scheduler.pausedUntil {
            VStack(spacing: 12) {
                Hero(symbol: "pause.circle.fill", tint: .orange, caption: t("Pause ends in"),
                     big: formatCountdown(until.timeIntervalSince(scheduler.now)), monospaced: true)
                Button(t("Resume")) { scheduler.resume() }
                    .buttonStyle(PanelPill(filled: true))
            }
        } else if let reason = scheduler.busyReason {
            Hero(symbol: "pause.circle.fill", tint: .orange, caption: t("Reminders wait"),
                 big: reason.title, bigSize: 24)
        } else if scheduler.isIdle {
            Hero(symbol: "moon.fill", tint: .indigo, caption: nil,
                 big: t("You are away. Timers are waiting."), bigSize: 17)
        } else if settings.breakEnabled, let nb = scheduler.nextBreak {
            VStack(spacing: 12) {
                Hero(symbol: "cup.and.saucer.fill", tint: SettingsPage.breaks.colors[0],
                     caption: t("Break in"), big: formatCountdown(nb.timeIntervalSince(scheduler.now)), monospaced: true)
                HStack(spacing: 6) {
                    Button(t("Start now")) { scheduler.startBreak(); closePanel() }
                        .buttonStyle(PanelPill(filled: true))
                    ForEach(snoozeOptions, id: \.self) { m in
                        Button(t("+%ld min", m)) { scheduler.postponeBreak(minutes: m) }
                            .buttonStyle(PanelPill(filled: false))
                    }
                }
            }
        } else {
            Hero(symbol: "checkmark.circle.fill", tint: .green, caption: t("Breaks are off"),
                 big: t("Pinok is on"), bigSize: 28)
        }
    }

    /// Конец дня внизу панели. За час до конца: «Рабочий день до 18:00».
    /// После конца: «Рабочий день закончен» и как скоро вернётся список.
    @ViewBuilder private var dayEndStatus: some View {
        if let end = scheduler.upcomingDayEnd, end.timeIntervalSince(scheduler.now) <= 3600 {
            dayEndRow(t("Workday ends at %@", Self.timeText(end)), showList: false)
        } else if scheduler.dayEndActive {
            dayEndRow(t("The workday is over"), showList: true)
        } else if scheduler.isDayEnded, !scheduler.isDayClosed, settings.dayEndEnabled {
            dayEndRow(t("The list comes back in %ld min of work", scheduler.minutesToNextDayEndList), showList: true)
        }
    }

    private func dayEndRow(_ text: String, showList: Bool) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "sunset.fill").foregroundStyle(SettingsPage.dayEnd.colors[0])
            Text(text)
                .font(.callout)
                .fixedSize(horizontal: false, vertical: true)
            Spacer()
            Menu {
                if showList {
                    Button(t("Show the list")) { scheduler.showDayEndNow(); closePanel() }
                    Divider()
                }
                ForEach(dayEndPostponeOptions, id: \.self) { m in
                    Button(dayEndPostponeLabel(m)) { scheduler.postponeDayEnd(minutes: m) }
                }
                Divider()
                Button(t("Skip today")) { scheduler.skipDayEnd() }
            } label: {
                Text(t("Move"))
            }
            .menuStyle(.borderlessButton)
            .fixedSize()
        }
        .padding(.horizontal, 12).padding(.vertical, 9)
        .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Color.primary.opacity(0.05)))
    }

    /// «18:00» или «6:00 PM» — по языку приложения.
    private static func timeText(_ date: Date) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: L10n.isRussian ? "ru_RU" : "en_US")
        f.timeStyle = .short
        f.dateStyle = .none
        return f.string(from: date)
    }

    /// «Пауза»: подпись и три квадратные кнопки — 1, 5 и 30 минут.
    private var pauseRow: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(t("Pause")).font(.caption.weight(.semibold)).foregroundStyle(.secondary)
            HStack(spacing: 8) {
                ForEach([1, 5, 30], id: \.self) { m in
                    Button {
                        scheduler.pause(for: TimeInterval(m * 60))
                    } label: {
                        VStack(spacing: 4) {
                            Image(systemName: "pause.fill").font(.system(size: 15, weight: .semibold))
                            Text(t("%ld min", m)).font(.callout.weight(.semibold))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Color.primary.opacity(0.07)))
                        .contentShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(t("Pause for %ld min", m))
                }
            }
        }
    }

    /// Закрыть панель после действия.
    private func closePanel() {
        NSApp.keyWindow?.orderOut(nil)
    }
}

// MARK: - Части панели

private struct Hero: View {
    let symbol: String
    let tint: Color
    let caption: String?
    let big: String
    var bigSize: CGFloat = 46
    var monospaced = false

    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: symbol)
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(tint)
            if let caption {
                Text(caption).font(.callout).foregroundStyle(.secondary)
            }
            Text(big)
                .font(.system(size: bigSize, weight: .bold, design: .rounded))
                .monospacedDigit()
                .multilineTextAlignment(.center)
                .contentTransition(monospaced ? .numericText(countsDown: true) : .identity)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 4)
        .accessibilityElement(children: .combine)
    }
}

/// Кнопка-капсула панели: «Начать сейчас» залита, «+N мин» — с рамкой.
private struct PanelPill: ButtonStyle {
    let filled: Bool
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.callout.weight(.semibold))
            .lineLimit(1)
            .fixedSize()
            .padding(.horizontal, 10).padding(.vertical, 7)
            .background(Capsule().fill(Color.primary.opacity(filled ? (configuration.isPressed ? 0.2 : 0.12) : (configuration.isPressed ? 0.08 : 0))))
            .overlay(Capsule().strokeBorder(Color.primary.opacity(filled ? 0 : 0.2)))
            .contentShape(Capsule())
    }
}
