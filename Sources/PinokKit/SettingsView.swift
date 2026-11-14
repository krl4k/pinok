import ServiceManagement
import UniformTypeIdentifiers
import SwiftUI

// MARK: - Разделы

enum SettingsPage: Hashable {
    case general, reminder(UUID), library, set(UUID), newSet, breaks

    /// Для `--page <name>`: general, library, breaks, stats, appearance, sounds или id шаблона (posture, tongue…).
    @MainActor
    init?(argument: String) {
        switch argument {
        case "general": self = .general
        case "library": self = .library
        case "breaks": self = .breaks
        default:
            guard let r = AppSettings.shared.reminders.first(where: { $0.template == argument }) else { return nil }
            self = .reminder(r.id)
        }
    }

    @MainActor
    var reminder: Reminder? {
        guard case .reminder(let id) = self else { return nil }
        return AppSettings.shared.reminders.first { $0.id == id }
    }

    @MainActor
    var reminderSet: ReminderSet? {
        guard case .set(let id) = self else { return nil }
        return AppSettings.shared.sets.first { $0.id == id }
    }

    @MainActor
    var title: String {
        switch self {
        case .general: t("General")
        case .reminder: reminder?.displayTitle ?? ""
        case .library: t("Add reminder")
        case .set: reminderSet?.name ?? t("Combo")
        case .newSet: t("New combo")
        case .breaks: t("Breaks")
        }
    }

    @MainActor
    var symbol: String {
        switch self {
        case .general: "gearshape.fill"
        case .reminder: reminder?.iconSymbol ?? "bell.fill"
        case .library: "plus"
        case .set: "square.stack.3d.up.fill"
        case .newSet: "plus"
        case .breaks: "cup.and.saucer.fill"
        }
    }

    @MainActor
    var colors: [Color] {
        switch self {
        case .general: [Color(red: 0.62, green: 0.45, blue: 0.98), Color(red: 0.92, green: 0.45, blue: 0.85)]
        case .reminder: reminder?.animation.colors ?? [.gray, .gray]
        case .library: [Color(red: 0.20, green: 0.72, blue: 0.45), Color(red: 0.25, green: 0.62, blue: 0.85)]
        case .set, .newSet: [Color(red: 0.55, green: 0.35, blue: 0.95), Color(red: 0.30, green: 0.70, blue: 0.95)]
        case .breaks: [Color(red: 1.00, green: 0.55, blue: 0.22), Color(red: 1.00, green: 0.80, blue: 0.36)]
        }
    }

    @MainActor var tint: Color { colors[0] }
}

// MARK: - Окно настроек

/// Структура боковой панели: группы и страницы по порядку. Отдельно от вида — для тестов.
struct SidebarModel {
    struct Group: Equatable {
        let title: String?
        let pages: [SettingsPage]
    }

    @MainActor
    static func groups(for settings: AppSettings) -> [Group] {
        [
            Group(title: nil, pages: [.general]),
            Group(title: t("Short reminders"), pages: settings.reminders.map { .reminder($0.id) } + [.library]),
            Group(title: t("Combos"), pages: settings.sets.map { .set($0.id) } + [.newSet]),
            Group(title: t("Long breaks"), pages: [.breaks]),
        ]
    }

    /// Все страницы подряд — в том же порядке, что строки в списке.
    @MainActor
    static func pages(for settings: AppSettings) -> [SettingsPage] {
        groups(for: settings).flatMap(\.pages)
    }

    /// Включено ли то, что на странице (для точки состояния). nil — у страницы нет вкл/выкл.
    @MainActor
    static func isOn(_ page: SettingsPage, settings: AppSettings) -> Bool? {
        switch page {
        case .reminder(let id): settings.reminders.first { $0.id == id }?.enabled
        case .set(let id): settings.sets.first { $0.id == id }?.enabled
        case .breaks: settings.breakEnabled
        default: nil
        }
    }
}

struct SettingsView: View {
    @State private var page: SettingsPage
    private var settings = AppSettings.shared
    /// Для тестов: вызывается, когда в боковой панели выбрали другую страницу.
    var onPageChange: ((SettingsPage) -> Void)?

    /// Страница, которая откроется первой (для `--open-settings --page breaks`).
    @MainActor static var launchPage: SettingsPage?

    private let explicitPage: SettingsPage?

    init(initialPage: SettingsPage? = nil, onPageChange: ((SettingsPage) -> Void)? = nil) {
        explicitPage = initialPage
        self.onPageChange = onPageChange
        _page = State(initialValue: initialPage ?? Self.defaultPage)
    }

    @MainActor
    private static var defaultPage: SettingsPage {
        launchPage ?? AppSettings.shared.reminders.first.map { .reminder($0.id) } ?? .library
    }

    var body: some View {
        // Своя раскладка вместо NavigationSplitView: окно настроек игнорирует ширину его колонки.
        HStack(spacing: 0) {
            List(selection: $page) {
                ForEach(Array(SidebarModel.groups(for: settings).enumerated()), id: \.offset) { _, group in
                    if let title = group.title {
                        Section(title) {
                            ForEach(group.pages, id: \.self) { p in row(p, isOn: onBinding(p)) }
                        }
                    } else {
                        ForEach(group.pages, id: \.self) { p in row(p, isOn: onBinding(p)) }
                    }
                }
            }
            .listStyle(.sidebar)
            .frame(width: 270)

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    detail
                }
                .padding(24)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(maxWidth: .infinity)
        }
        .frame(width: 940, height: 660)
        .navigationTitle(page.title)
        .id(settings.language) // мгновенно перерисовать всё при смене языка
        .background(BringToFront())
        .onAppear { if explicitPage == nil { page = Self.defaultPage } }
        .onChange(of: page) { _, new in onPageChange?(new) }
    }

    /// Переключатель вкл/выкл для точки состояния (nil — у страницы его нет).
    private func onBinding(_ p: SettingsPage) -> Binding<Bool>? {
        switch p {
        case .reminder(let id): reminderOn(id)
        case .set(let id): comboOn(id)
        case .breaks: Binding(get: { settings.breakEnabled }, set: { settings.breakEnabled = $0 })
        default: nil
        }
    }

    /// Строка боковой панели. `isOn` — точка состояния слева (зелёная — включено).
    private func row(_ p: SettingsPage, isOn: Binding<Bool>? = nil) -> some View {
        Group {
            Label {
                Text(p.title)
            } icon: {
                Group {
                    if let r = p.reminder {
                        ReminderIcon(reminder: r, size: 24)
                    } else {
                        AppIcon(symbol: p.symbol, colors: p.colors, size: 24)
                    }
                }
                .opacity(isOn?.wrappedValue == false ? 0.55 : 1)
                // Статус на углу иконки: зелёный — включено, серый — выключено.
                .overlay(alignment: .bottomTrailing) {
                    if let isOn {
                        Circle()
                            .fill(isOn.wrappedValue ? Color.green : Color(white: 0.6))
                            .frame(width: 9, height: 9)
                            .overlay(Circle().strokeBorder(Color(nsColor: .windowBackgroundColor), lineWidth: 1.5))
                            .offset(x: 3, y: 3)
                            .help(isOn.wrappedValue ? t("On") : t("Off"))
                    }
                }
            }
        }
        .tag(p) // без метки список не выбирает строку
    }

    private func reminderOn(_ id: UUID) -> Binding<Bool> {
        Binding(get: { settings.reminders.first { $0.id == id }?.enabled ?? false },
                set: { v in if let i = settings.reminders.firstIndex(where: { $0.id == id }) { settings.reminders[i].enabled = v } })
    }

    private func comboOn(_ id: UUID) -> Binding<Bool> {
        Binding(get: { settings.sets.first { $0.id == id }?.enabled ?? false },
                set: { v in if let i = settings.sets.firstIndex(where: { $0.id == id }) { settings.sets[i].enabled = v } })
    }

    @ViewBuilder
    private var detail: some View {
        switch page {
        case .general: GeneralPage()
        case .reminder(let id): ReminderPage(id: id, onRemove: { page = .library })
        case .library: LibraryPage(onOpen: { page = .reminder($0) })
        case .set(let id): SetPage(id: id, onRemove: { page = .newSet })
        case .newSet: NewSetPage(onOpen: { page = .set($0) })
        case .breaks: BreaksPage()
        }
    }
}

// MARK: - Общие

private struct GeneralPage: View {
    @Bindable private var s = AppSettings.shared
    private var stats = Stats.shared
    @State private var moreSmartPause = false

    var body: some View {
        PageHeader(page: .general, subtitle: t("Today: %ld reminders · %ld breaks", stats.total, stats.breaks))

        Card {
            Row(title: t("Language")) {
                Picker("", selection: $s.language) {
                    ForEach(AppLanguage.allCases) { Text($0.title).tag($0) }
                }
                .labelsHidden()
                .pickerStyle(.segmented)
                .fixedSize()
            }
            CardDivider()
            LaunchAtLoginRow()
            CardDivider()
            ToggleRow(title: t("Show minutes to the break in the menu bar"), isOn: $s.showCountdown)
        }

        SectionTitle(t("Reminders"))
        ReminderLivePreview(reminders: Array(s.reminders.prefix(1))) {
            Scheduler.shared.preview(s.reminders.first ?? ReminderLibrary.template("posture")!.make())
        }
        Card {
            Row(title: t("Color of the icon and text"),
                subtitle: t("The arrow, the icon and the text of a reminder on the screen.")) {
                HStack(spacing: 10) {
                    ForEach(ArrowColor.allCases) { c in
                        Circle()
                            .fill(c.color)
                            .overlay(Circle().strokeBorder(.black.opacity(0.15)))
                            .frame(width: 22, height: 22)
                            .padding(2)
                            .overlay(Circle().strokeBorder(s.arrowColor == c ? Color.accentColor : .clear, lineWidth: 2))
                            .contentShape(Circle())
                            .onTapGesture { withAnimation(.snappy) { s.arrowColor = c } }
                            .help(c.title)
                    }
                }
            }
            CardDivider()
            StackedRow(title: t("Darken the screen"),
                       subtitle: t("How dark and blurry the screen becomes during a reminder.")) {
                HStack(spacing: 10) {
                    Text(t("Light")).font(.caption).foregroundStyle(.secondary).fixedSize()
                    Slider(value: Binding(
                        get: { s.nudgeBlur },
                        set: { v in s.nudgeBlur = v; s.nudgeDim = 0.05 + 0.4 * v }), in: 0...1)
                    Text(t("Strong")).font(.caption).foregroundStyle(.secondary).fixedSize()
                }
            }
            CardDivider()
            StackedRow(title: t("Show a reminder for"), subtitle: t("Give yourself more time to do it.")) {
                ChipPicker(options: [4, 8, 15, 30], selection: $s.nudgeDuration,
                           tint: SettingsPage.general.tint) { t("%ld sec", $0) }
            }
            CardDivider()
            ToggleRow(title: t("Sounds"), subtitle: t("Turn off to mute all sounds of Pinok."), isOn: $s.soundsEnabled)
            CardDivider()
            Row(title: t("Volume"), subtitle: t("You hear a short sound when you release the slider.")) {
                // Как в macOS: короткий звук с новой громкостью, когда отпустил ползунок.
                Slider(value: $s.volume, in: 0...1) { editing in
                    if !editing { Sounds.play("Pop", force: true) }
                }
                .frame(width: 220)
            }
            .disabled(!s.soundsEnabled)
            CardDivider()
            ToggleRow(title: t("Trackpad haptics"),
                      subtitle: t("You feel it only when your finger is on the trackpad."),
                      isOn: $s.haptics)

        }

        SectionTitle(t("Smart pause"))
        Card {
            ToggleRow(title: t("Smart pause"),
                      subtitle: t("Wait while you type, talk in a call or watch a video."),
                      isOn: Binding(
                          get: { s.smartTiming || s.pauseOnCalls || s.pauseOnVideo },
                          set: { v in s.smartTiming = v; s.pauseOnCalls = v; s.pauseOnVideo = v }))
            CardDivider()
            MoreDisclosure(isExpanded: $moreSmartPause) {
                VStack(spacing: 0) {
                    ToggleRow(title: t("Pause during calls"), isOn: $s.pauseOnCalls)
                    ToggleRow(title: t("Pause during full-screen video"), isOn: $s.pauseOnVideo)
                    ToggleRow(title: t("Wait until I stop typing"), isOn: $s.smartTiming)
                    Row(title: t("Pause when I'm away for")) {
                        ChipPicker(options: [3, 5, 10, 15], selection: $s.idleMinutes,
                                   tint: SettingsPage.general.tint) { t("%ld min", $0) }
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
        }

        Card {
            Row(title: t("Welcome screen"), subtitle: t("Choose the language and the first reminders again.")) {
                Button(t("Show")) { OnboardingWindow.shared.show() }
            }
            CardDivider()
            SoundRow(title: t("Welcome sound"), colors: SettingsPage.general.colors,
                     selection: $s.introSound)
        }
    }
}

private struct LaunchAtLoginRow: View {
    @State private var enabled = SMAppService.mainApp.status == .enabled
    @State private var error: String?

    var body: some View {
        ToggleRow(title: t("Launch at login"),
                  subtitle: error,
                  isOn: Binding(
                      get: { enabled },
                      set: { newValue in
                          do {
                              if newValue { try SMAppService.mainApp.register() } else { try SMAppService.mainApp.unregister() }
                              enabled = newValue
                              error = nil
                          } catch {
                              self.error = error.localizedDescription
                          }
                      }))
    }
}

// MARK: - Напоминание

private struct ReminderPage: View {
    let id: UUID
    let onRemove: () -> Void
    @Bindable private var s = AppSettings.shared
    @State private var more = false

    var body: some View {
        if let i = s.reminders.firstIndex(where: { $0.id == id }) {
            let r = s.reminders[i]
            PageHeader(title: r.displayTitle, subtitle: r.detail, symbol: r.iconSymbol, colors: r.animation.colors,
                       imagePath: r.imagePath, isOn: $s.reminders[i].enabled)

            ReminderLivePreview(reminders: [r]) { Scheduler.shared.preview(s.reminders[i]) }

            Card {
                IntervalRow(selection: $s.reminders[i].interval, tint: r.animation.colors[0])
                    .disabled(!r.enabled)
                CardDivider()
                ToggleRow(title: t("Show the text on the screen"), subtitle: r.displayCaption,
                          isOn: $s.reminders[i].showCaption)
            }

            if let set = s.sets.first(where: { $0.enabled && $0.reminderIDs.contains(id) }) {
                FooterNote(t("This reminder is in the combo “%@”. It shows with the combo.", set.name))
                    .padding(.top, 8)
            }

            if r.isCustom {
                SectionTitle(t("Text"))
                Card {
                    TextRow(title: t("Name"), text: $s.reminders[i].title)
                    CardDivider()
                    TextRow(title: t("Text on the screen"), text: $s.reminders[i].caption)
                    CardDivider()
                    IconRow(reminder: $s.reminders[i])
                }
            }

            Card {
                AnimationRow(selection: $s.reminders[i][dynamicMember: \.animation],
                             symbol: r.iconSymbol, imagePath: r.imagePath)
                CardDivider()
                SoundRow(title: t("Sound"), colors: r.animation.colors,
                         selection: $s.reminders[i].sound)
            }

            Card {
                MoreDisclosure(isExpanded: $more) {
                    CaptionsEditor(main: r.displayCaption,
                                   extras: Binding(get: { s.reminders[i].extraCaptions ?? [] },
                                                   set: { s.reminders[i].extraCaptions = $0.isEmpty ? nil : $0 }))
                        .padding(.top, 8)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
            }

            HStack {
                Spacer()
                Button(role: .destructive) {
                    onRemove()
                    withAnimation(.snappy) {
                        s.reminders.removeAll { $0.id == id }
                        for i in s.sets.indices { s.sets[i].reminderIDs.removeAll { $0 == id } }
                    }
                } label: {
                    Label(t("Remove reminder"), systemImage: "trash")
                }
            }
        } else {
            FooterNote(t("This reminder was removed."))
        }
    }
}

// MARK: - Набор

private struct SetPage: View {
    let id: UUID
    let onRemove: () -> Void
    @Bindable private var s = AppSettings.shared

    var body: some View {
        if let i = s.sets.firstIndex(where: { $0.id == id }) {
            let set = s.sets[i]
            let colors = SettingsPage.set(id).colors
            PageHeader(title: set.name,
                 subtitle: t("Show some reminders at the same time. They share the screen from left to right."),
                 symbol: "square.stack.3d.up.fill", colors: colors,
                 isOn: $s.sets[i].enabled)

            ReminderLivePreview(reminders: set.reminderIDs.compactMap { id in s.reminders.first { $0.id == id } }) {
                Scheduler.shared.preview(s.sets[i])
            }

            Card {
                TextRow(title: t("Name"), text: $s.sets[i].name)
                CardDivider()
                IntervalRow(selection: $s.sets[i].interval, tint: colors[0])
                    .disabled(!set.enabled)
                CardDivider()
                StackedRow(title: t("Show the combo for"),
                           subtitle: t("A combo has more actions. Give it more time.")) {
                    ChipPicker(options: [0, 8, 15, 30, 60],
                               selection: Binding(get: { s.sets[i].duration ?? 0 },
                                                  set: { s.sets[i].duration = $0 == 0 ? nil : $0 }),
                               tint: colors[0]) { $0 == 0 ? t("Auto") : t("%ld sec", $0) }
                }
            }

            SectionTitle(t("Reminders in this combo"))
            Card {
                ForEach(Array(s.reminders.enumerated()), id: \.element.id) { index, r in
                    if index > 0 { CardDivider() }
                    HStack(spacing: 12) {
                        ReminderIcon(reminder: r, size: 26)
                        Text(r.displayTitle)
                        Spacer()
                        Toggle("", isOn: Binding(
                            get: { s.sets[i].reminderIDs.contains(r.id) },
                            set: { on in
                                if on { s.sets[i].reminderIDs.append(r.id) } else { s.sets[i].reminderIDs.removeAll { $0 == r.id } }
                            }))
                            .labelsHidden()
                            .toggleStyle(.switch)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 9)
                }
            }
            FooterNote(set.reminderIDs.count < 2
                       ? t("Select 2 or more reminders.")
                       : t("A reminder in a combo that is on does not show alone."))

            SectionTitle(t("Sound"))
            Card {
                SoundRow(title: t("Sound"), colors: colors,
                         selection: $s.sets[i].sound)
            }

            HStack {
                Spacer()
                Button(role: .destructive) {
                    onRemove()
                    withAnimation(.snappy) { s.sets.removeAll { $0.id == id } }
                } label: {
                    Label(t("Remove combo"), systemImage: "trash")
                }
            }
        } else {
            FooterNote(t("This combo was removed."))
        }
    }
}

private struct NewSetPage: View {
    let onOpen: (UUID) -> Void
    @Bindable private var s = AppSettings.shared

    var body: some View {
        PageHeader(page: .newSet,
             subtitle: t("Show some reminders at the same time. They share the screen from left to right."),
             action: nil)
        FooterNote(t("A reminder in a combo that is on does not show alone."))
            .padding(.top, 8)
        HStack {
            Spacer()
            Button {
                let set = ReminderSet(name: t("My combo"), reminderIDs: Array(s.reminders.prefix(2).map(\.id)))
                s.sets.append(set)
                onOpen(set.id)
            } label: {
                Label(t("New combo"), systemImage: "plus")
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
        }
    }
}

// MARK: - Библиотека

private struct LibraryPage: View {
    let onOpen: (UUID) -> Void
    @Bindable private var s = AppSettings.shared

    @State private var name = ""
    @State private var caption = ""
    @State private var animation: ReminderAnimation = .bell
    @State private var interval = 60
    /// Черновик только для иконки (символ или картинка).
    @State private var iconDraft = Reminder(template: nil, title: "", caption: "", animation: .bell,
                                            interval: 60, sound: "melody.jingle")

    var body: some View {
        PageHeader(title: t("Add reminder"), subtitle: t("Pick a ready reminder, or make your own."),
             symbol: "plus", colors: SettingsPage.library.colors, action: nil)

        SectionTitle(t("Ready reminders"))
        LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
            ForEach(ReminderLibrary.all) { tpl in
                TemplateCard(template: tpl, added: s.reminders.contains { $0.template == tpl.id }) {
                    if let existing = s.reminders.first(where: { $0.template == tpl.id }) {
                        onOpen(existing.id)
                    } else {
                        let r = tpl.make()
                        s.reminders.append(r)
                        onOpen(r.id)
                    }
                }
            }
        }

        SectionTitle(t("Your own reminder"))
        Card {
            TextRow(title: t("Name"), placeholder: t("For example: Relax your face"), text: $name)
            CardDivider()
            TextRow(title: t("Text on the screen"), placeholder: t("For example: Relax your jaw"), text: $caption)
            CardDivider()
            IconRow(reminder: $iconDraft)
            CardDivider()
            IntervalRow(selection: $interval, tint: animation.colors[0])
        }

        Card {
            AnimationRow(selection: $animation, symbol: iconDraft.symbol, imagePath: iconDraft.imagePath)
        }

        HStack {
            Spacer()
            Button(action: create) {
                Label(t("Create reminder"), systemImage: "plus")
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
        }
    }

    private func create() {
        let title = name.trimmingCharacters(in: .whitespaces)
        let text = caption.trimmingCharacters(in: .whitespaces)
        let r = Reminder(template: nil, title: title, caption: text.isEmpty ? title : text,
                         animation: animation, interval: interval, sound: "melody.jingle",
                         symbol: iconDraft.symbol, imagePath: iconDraft.imagePath)
        iconDraft.symbol = nil
        iconDraft.imagePath = nil
        s.reminders.append(r)
        name = ""
        caption = ""
        onOpen(r.id)
    }
}

private struct TemplateCard: View {
    let template: ReminderTemplate
    let added: Bool
    let action: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            AppIcon(symbol: template.animation.symbol, colors: template.animation.colors, size: 40)
            VStack(alignment: .leading, spacing: 4) {
                Text(t(template.title)).font(.headline)
                Text(t(template.detail))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                Text(t("Every %@", ReminderLibrary.label(template.interval)))
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
            Spacer(minLength: 8)
            if added {
                Button(t("Open"), action: action)
                    .controlSize(.small)
            } else {
                Button(t("Add"), action: action)
                    .buttonStyle(.borderedProminent)
                    .tint(template.animation.colors[0])
                    .controlSize(.small)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, minHeight: 96, alignment: .topLeading)
        .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Color.primary.opacity(0.045)))
    }
}

/// Строка «Анимация»: текущая анимация и кнопка, которая открывает выбор.
private struct AnimationRow: View {
    @Binding var selection: ReminderAnimation
    var symbol: String? = nil
    var imagePath: String? = nil
    @State private var choosing = false
    private let color = AppSettings.shared.arrowColor.color

    var body: some View {
        Row(title: t("Animation")) {
            HStack(spacing: 10) {
                ZStack {
                    LinearGradient(colors: [Color(red: 0.98, green: 0.64, blue: 0.45), Color(red: 0.50, green: 0.36, blue: 0.78)],
                                   startPoint: .topLeading, endPoint: .bottomTrailing)
                    GlassBadge(d: 30, color: color) {
                        ReminderAnimationView(animation: selection, color: color, d: 30,
                                              symbol: symbol, imagePath: imagePath)
                            .id(selection)
                    }
                }
                .frame(width: 40, height: 40)
                .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
                Text(selection.title)
                    .foregroundStyle(.secondary)
                Button(t("Change…")) { choosing = true }
                    .popover(isPresented: $choosing, arrowEdge: .bottom) {
                        AnimationPicker(selection: Binding(
                            get: { selection },
                            set: { selection = $0; choosing = false }),
                                        symbol: symbol, imagePath: imagePath)
                            .padding(16)
                            .frame(width: 520)
                    }
            }
        }
    }
}

/// Выбор анимации: небольшие карточки с живым превью.
private struct AnimationPicker: View {
    @Binding var selection: ReminderAnimation
    var symbol: String? = nil
    var imagePath: String? = nil
    private let color = AppSettings.shared.arrowColor.color

    var body: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 3), spacing: 12) {
            ForEach(ReminderAnimation.allCases) { a in
                let selected = a == selection
                VStack(spacing: 6) {
                    ZStack {
                        LinearGradient(colors: [Color(red: 0.98, green: 0.64, blue: 0.45), Color(red: 0.50, green: 0.36, blue: 0.78)],
                                       startPoint: .topLeading, endPoint: .bottomTrailing)
                        GlassBadge(d: 60, color: color) {
                            ReminderAnimationView(animation: a, color: color, d: 60,
                                                  symbol: symbol, imagePath: imagePath)
                                .id(selected) // при выборе анимация проигрывается заново
                        }
                    }
                    .frame(height: 88)
                    .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
                    .padding(3)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .strokeBorder(selected ? Color.accentColor : .clear, lineWidth: 3)
                    )
                    Text(a.title)
                        .font(.callout.weight(selected ? .semibold : .regular))
                        .foregroundStyle(selected ? .primary : .secondary)
                }
                .contentShape(Rectangle())
                .onTapGesture { withAnimation(.snappy) { selection = a } }
            }
        }
    }
}

private struct IntervalRow: View {
    @Binding var selection: Int
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(t("Every"))
            ChipPicker(options: ReminderLibrary.intervals, selection: $selection, tint: tint) {
                ReminderLibrary.label($0)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 11)
    }
}

/// Строка, где заголовок сверху, а выбор — под ним (когда в одну строку тесно).
private struct StackedRow<Content: View>: View {
    let title: String
    var subtitle: String?
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                if let subtitle {
                    Text(subtitle).font(.caption).foregroundStyle(.secondary)
                }
            }
            content
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 11)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct TextRow: View {
    let title: String
    var placeholder = ""
    @Binding var text: String

    var body: some View {
        Row(title: title) {
            TextField(placeholder, text: $text)
                .textFieldStyle(.roundedBorder)
                .frame(width: 300)
        }
    }
}

// MARK: - Перерывы

private struct BreaksPage: View {
    @Bindable private var s = AppSettings.shared
    private let page = SettingsPage.breaks
    @State private var more = false

    var body: some View {
        PageHeader(page: page,
                   subtitle: t("The screen locks for a few minutes. Stand up, stretch and rest your eyes."),
                   isOn: $s.breakEnabled,
                   action: { Scheduler.shared.previewBreak() })

        Card {
            Row(title: t("Every")) {
                ChipPicker(options: [30, 45, 60, 90, 120], selection: $s.breakInterval, tint: page.tint) {
                    ReminderLibrary.label($0)
                }
            }
            .disabled(!s.breakEnabled)
            CardDivider()
            Row(title: t("Duration")) {
                ChipPicker(options: [1, 3, 5, 10], selection: $s.breakDuration, tint: page.tint) { t("%ld min", $0) }
            }
            .disabled(!s.breakEnabled)
            CardDivider()
            Row(title: t("Warn me")) {
                ChipPicker(options: [0, 30, 60, 120], selection: $s.breakWarning, tint: page.tint) {
                    $0 == 0 ? t("Off") : ($0 < 60 ? t("%ld sec before", $0) : t("%ld min before", $0 / 60))
                }
            }
            .disabled(!s.breakEnabled)
        }

        SectionTitle(t("Exercises"))
        Card {
            ForEach(Array(BreakExercise.allCases.enumerated()), id: \.element) { index, ex in
                if index > 0 { CardDivider() }
                HStack(spacing: 12) {
                    AppIcon(symbol: ex.symbol, colors: page.colors, size: 28)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(ex.title)
                        Text(ex.instruction).font(.caption).foregroundStyle(.secondary)
                    }
                    Spacer()
                    Toggle("", isOn: Binding(
                        get: { s.breakExercises.contains(ex) },
                        set: { on in
                            if on { s.breakExercises.append(ex) } else { s.breakExercises.removeAll { $0 == ex } }
                        }))
                        .labelsHidden()
                        .toggleStyle(.switch)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 9)
            }
            CardDivider()
            Row(title: t("Exercises in one break")) {
                ChipPicker(options: [1, 2, 3], selection: $s.breakExerciseCount, tint: page.tint) { "\($0)" }
            }
        }
        FooterNote(t("Each break shows a list of exercises that are on. Click each one when you do it."))

        SectionTitle(t("Sound"))
        Card {
            SoundRow(title: t("Break starts"), colors: page.colors, selection: $s.breakStartSound)
            CardDivider()
            SoundRow(title: t("Break ends"), colors: page.colors, selection: $s.breakEndSound)
        }

        Card {
            MoreDisclosure(isExpanded: $more) {
                VStack(alignment: .leading, spacing: 12) {
                    ToggleRow(title: t("End the break only when the list is done"),
                              subtitle: t("Skip and Esc always work."),
                              isOn: $s.breakRequireList)
                    Text(t("Background")).font(.headline).padding(.leading, 16)
                    BackgroundPicker()
                }
                .padding(.top, 8)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
        }
    }
}

private struct BackgroundPicker: View {
    @Bindable private var s = AppSettings.shared
    @State private var wallpaper: NSImage? = NSScreen.main
        .flatMap { NSWorkspace.shared.desktopImageURL(for: $0) }
        .flatMap { NSImage(contentsOf: $0) }

    var body: some View {
        Card {
            HStack(spacing: 12) {
                ForEach(BreakBackground.allCases) { bg in
                    BackgroundOption(kind: bg, selected: s.breakBackground == bg, backdrop: preview(for: bg))
                        .onTapGesture {
                            if bg == .image, s.breakImagePath.isEmpty {
                                chooseImage()
                            } else {
                                withAnimation(.snappy) { s.breakBackground = bg }
                            }
                        }
                }
            }
            .padding(16)

            if s.breakBackground == .gradient {
                CardDivider()
                HStack(spacing: 18) {
                    ForEach(BreakGradient.allCases) { g in
                        VStack(spacing: 6) {
                            Circle()
                                .fill(LinearGradient(colors: g.colors, startPoint: .topLeading, endPoint: .bottomTrailing))
                                .frame(width: 30, height: 30)
                                .padding(3)
                                .overlay(Circle().strokeBorder(s.breakGradient == g ? Color.accentColor : .clear, lineWidth: 2.5))
                            Text(g.title)
                                .font(.caption)
                                .foregroundStyle(s.breakGradient == g ? .primary : .secondary)
                        }
                        .contentShape(Rectangle())
                        .onTapGesture { withAnimation(.snappy) { s.breakGradient = g } }
                    }
                    Spacer()
                }
                .padding(16)
            }

            if s.breakBackground == .image {
                CardDivider()
                Row(title: t("Image"),
                    subtitle: s.breakImagePath.isEmpty ? t("No image selected")
                        : URL(fileURLWithPath: s.breakImagePath).lastPathComponent) {
                    Button(t("Choose…")) { chooseImage() }
                }
            }
        }
    }

    private func preview(for bg: BreakBackground) -> BreakBackdrop {
        switch bg {
        case .blur: .blur
        case .gradient: .gradient(s.breakGradient.colors)
        case .wallpaper: wallpaper.map { .image($0, blur: 10) } ?? .gradient([Color(white: 0.55), Color(white: 0.3)])
        case .image: NSImage(contentsOfFile: s.breakImagePath).map { .image($0, blur: 0) }
            ?? .gradient([Color(white: 0.55), Color(white: 0.3)])
        }
    }

    private func chooseImage() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.image]
        panel.allowsMultipleSelection = false
        panel.message = t("Choose a picture for breaks")
        if panel.runModal() == .OK, let url = panel.url {
            s.breakImagePath = url.path
            withAnimation(.snappy) { s.breakBackground = .image }
        }
    }
}

private struct BackgroundOption: View {
    let kind: BreakBackground
    let selected: Bool
    let backdrop: BreakBackdrop

    var body: some View {
        VStack(spacing: 8) {
            ZStack {
                if kind == .blur {
                    // Имитация размытого рабочего стола
                    ZStack {
                        LinearGradient(colors: [Color(red: 0.98, green: 0.64, blue: 0.45), Color(red: 0.50, green: 0.36, blue: 0.78)],
                                       startPoint: .topLeading, endPoint: .bottomTrailing)
                        Circle().fill(.white.opacity(0.55)).frame(width: 36).offset(x: -28, y: -14)
                        RoundedRectangle(cornerRadius: 4).fill(.white.opacity(0.4)).frame(width: 50, height: 30).offset(x: 26, y: 12)
                    }
                    .blur(radius: 7)
                    Color.black.opacity(0.3)
                } else {
                    BreakBackdropView(backdrop: backdrop)
                }
                if kind == .image, case .gradient = backdrop {
                    Image(systemName: "photo.badge.plus")
                        .font(.system(size: 22))
                        .foregroundStyle(.white)
                } else {
                    Text("4:59")
                        .font(.system(size: 20, weight: .light, design: .rounded))
                        .foregroundStyle(.white)
                }
            }
            .frame(height: 84)
            .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
            .padding(3)
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(selected ? Color.accentColor : .clear, lineWidth: 3)
            )

            Text(kind.title)
                .font(.callout.weight(selected ? .semibold : .regular))
                .foregroundStyle(selected ? .primary : .secondary)
        }
        .frame(maxWidth: .infinity)
        .contentShape(Rectangle())
    }
}

// MARK: - Звуки

struct SoundRow: View {
    let title: String
    let colors: [Color]
    @Binding var selection: String

    private static let chooseTag = "__choose"
    /// Последний выбранный звук — чтобы вернуть его, когда звук снова включили.
    @State private var lastSound = "melody.jingle"

    /// Свой файл: mp3, m4a, wav, aiff.
    private func chooseFile() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.audio]
        panel.allowsMultipleSelection = false
        panel.message = t("Choose a sound file")
        if panel.runModal() == .OK, let url = panel.url, let name = Sounds.importFile(url) {
            selection = name
            Sounds.play(name, force: true)
        }
    }

    var body: some View {
        HStack(spacing: 12) {
            Text(title)
            Spacer()
            if !selection.isEmpty {
            Picker("", selection: Binding(
                get: { selection },
                set: { new in
                    // Срабатывает только при выборе в списке — не при открытии страницы.
                    if new == Self.chooseTag {
                        chooseFile()
                    } else {
                        selection = new
                        Sounds.play(new, force: true)
                    }
                })) {
                if selection.hasPrefix(Sounds.filePrefix) {
                    Text(Sounds.title(selection)).tag(selection)
                }
                Text(t("Choose a file…")).tag(Self.chooseTag)
                Text(Sounds.title(Sounds.onboarding)).tag(Sounds.onboarding)
                Section(t("Melodies")) {
                    ForEach(Melodies.all) { m in
                        Text(Sounds.title(Melodies.prefix + m.id)).tag(Melodies.prefix + m.id)
                    }
                }
                Section(t("Short sounds")) {
                    ForEach(Sounds.all, id: \.self) { Text($0).tag($0) }
                }
            }
            .labelsHidden()
            .fixedSize()

            // Играет только по кнопке. Пока играет — кнопка останавливает звук.
            TimelineView(.periodic(from: .now, by: 0.25)) { _ in
                let playing = Sounds.isPlaying
                Button {
                    if playing { Sounds.stop() } else { Sounds.play(selection, force: true) }
                } label: {
                    Image(systemName: playing ? "stop.circle.fill" : "play.circle.fill")
                        .font(.title2)
                        .foregroundStyle(selection.isEmpty ? Color.secondary : colors[0])
                        .contentTransition(.symbolEffect(.replace))
                }
                .buttonStyle(.plain)
                .help(playing ? t("Stop") : t("Play"))
            }
            }

            // Звук включён / выключен
            Toggle("", isOn: Binding(
                get: { !selection.isEmpty },
                set: { on in
                    if on {
                        selection = lastSound
                    } else {
                        lastSound = selection
                        Sounds.stop()
                        selection = ""
                    }
                }))
                .labelsHidden()
                .toggleStyle(.switch)
                .help(t("Sound on or off"))
        }
        .onAppear { if !selection.isEmpty { lastSound = selection } }
        .padding(.horizontal, 16)
        .padding(.vertical, 9)
    }
}

// MARK: - Компоненты

/// «Ещё»: раскрывается кликом по всей строке, а не только по стрелке.
private struct MoreDisclosure<Content: View>: View {
    @Binding var isExpanded: Bool
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button {
                withAnimation(.snappy) { isExpanded.toggle() }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .rotationEffect(.degrees(isExpanded ? 90 : 0))
                    Text(t("More"))
                    Spacer()
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if isExpanded {
                content
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
    }
}

/// Иконка напоминания: своя картинка или цветная иконка с символом.
struct ReminderIcon: View {
    let reminder: Reminder
    var size: CGFloat = 24

    var body: some View {
        if let path = reminder.imagePath, let image = NSImage(contentsOfFile: path) {
            IconImage(image: image, size: size)
        } else {
            AppIcon(symbol: reminder.iconSymbol, colors: reminder.animation.colors, size: size)
        }
    }
}

/// Картинка в форме иконки (скруглённый квадрат).
struct IconImage: View {
    let image: NSImage
    let size: CGFloat

    var body: some View {
        Image(nsImage: image)
            .resizable()
            .scaledToFill()
            .frame(width: size, height: size)
            .clipShape(RoundedRectangle(cornerRadius: size * 0.27, style: .continuous))
            .shadow(color: .black.opacity(0.15), radius: 1.5, y: 0.5)
    }
}

/// Другие варианты текста напоминания. Каждый раз показывается случайный.
private struct CaptionsEditor: View {
    let main: String
    @Binding var extras: [String]
    @State private var draft = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(t("Other texts")).font(.headline)
            Text(t("Each time, the reminder shows one text at random."))
                .font(.caption)
                .foregroundStyle(.secondary)

            HStack(spacing: 8) {
                Image(systemName: "text.quote").foregroundStyle(.secondary)
                Text(main).foregroundStyle(.secondary)
                Spacer()
                Text(t("Main")).font(.caption).foregroundStyle(.tertiary)
            }
            .padding(.vertical, 4)

            ForEach(Array(extras.enumerated()), id: \.offset) { index, text in
                HStack(spacing: 8) {
                    Image(systemName: "text.quote").foregroundStyle(.secondary)
                    Text(text)
                    Spacer()
                    Button {
                        withAnimation(.snappy) { _ = extras.remove(at: index) }
                    } label: {
                        Image(systemName: "minus.circle.fill").foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                    .help(t("Remove"))
                }
                .padding(.vertical, 4)
            }

            HStack(spacing: 8) {
                Image(systemName: "plus.circle.fill").foregroundStyle(Color.accentColor)
                TextField(t("Add one more text…"), text: $draft)
                    .textFieldStyle(.plain)
                    .onSubmit(add)
                Button(t("Add"), action: add)
                    .disabled(draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            .padding(.vertical, 4)
        }
    }

    private func add() {
        let text = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        withAnimation(.snappy) { extras.append(text) }
        draft = ""
    }
}

/// Строка «Иконка»: текущая иконка и кнопка, которая открывает выбор.
private struct IconRow: View {
    @Binding var reminder: Reminder
    @State private var choosing = false

    var body: some View {
        Row(title: t("Icon")) {
            HStack(spacing: 10) {
                ReminderIcon(reminder: reminder, size: 32)
                Button(t("Change…")) { choosing = true }
                    .popover(isPresented: $choosing, arrowEdge: .bottom) {
                        IconPicker(reminder: $reminder) { choosing = false }
                    }
            }
        }
    }
}

/// Сетка иконок, своя картинка и сброс.
private struct IconPicker: View {
    @Binding var reminder: Reminder
    let close: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            LazyVGrid(columns: Array(repeating: GridItem(.fixed(40), spacing: 8), count: 8), spacing: 8) {
                ForEach(ReminderIcons.symbols, id: \.self) { symbol in
                    let selected = reminder.imagePath == nil && reminder.symbol == symbol
                    Button {
                        reminder.symbol = symbol
                        reminder.imagePath = nil
                        close()
                    } label: {
                        AppIcon(symbol: symbol, colors: reminder.animation.colors, size: 36)
                            .padding(2)
                            .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .strokeBorder(selected ? Color.accentColor : .clear, lineWidth: 2))
                    }
                    .buttonStyle(.plain)
                }
            }
            HStack {
                Button {
                    let panel = NSOpenPanel()
                    panel.allowedContentTypes = [.image]
                    panel.allowsMultipleSelection = false
                    panel.message = t("Choose an image for the icon")
                    if panel.runModal() == .OK, let url = panel.url, let path = ReminderIcons.importImage(url) {
                        reminder.imagePath = path
                        close()
                    }
                } label: {
                    Label(t("Choose an image…"), systemImage: "photo")
                }
                Spacer()
                Button(t("Reset")) {
                    reminder.symbol = nil
                    reminder.imagePath = nil
                    close()
                }
                .disabled(reminder.symbol == nil && reminder.imagePath == nil)
            }
        }
        .padding(16)
        .frame(width: 8 * 48 + 24)
    }
}

/// Цветная иконка-скруглённый квадрат, как в Системных настройках.
struct AppIcon: View {
    let symbol: String
    let colors: [Color]
    var size: CGFloat = 24

    var body: some View {
        RoundedRectangle(cornerRadius: size * 0.27, style: .continuous)
            .fill(LinearGradient(colors: colors, startPoint: .top, endPoint: .bottom))
            .overlay(
                Image(systemName: symbol)
                    .font(.system(size: size * 0.52, weight: .semibold))
                    .foregroundStyle(.white)
            )
            .frame(width: size, height: size)
            .shadow(color: colors[0].opacity(0.3), radius: 1.5, y: 0.5)
    }
}

/// Компактная шапка страницы: цветная иконка, название, пояснение и «Показать».
private struct PageHeader: View {
    let title: String
    let subtitle: String
    let symbol: String
    let colors: [Color]
    var imagePath: String?
    /// Включено ли то, что настраиваем (напоминание, комбо, перерывы).
    var isOn: Binding<Bool>?
    var action: (() -> Void)?

    init(title: String, subtitle: String, symbol: String, colors: [Color], imagePath: String? = nil,
         isOn: Binding<Bool>? = nil, action: (() -> Void)? = nil) {
        self.title = title
        self.subtitle = subtitle
        self.symbol = symbol
        self.colors = colors
        self.imagePath = imagePath
        self.isOn = isOn
        self.action = action
    }

    @MainActor
    init(page: SettingsPage, subtitle: String, isOn: Binding<Bool>? = nil, action: (() -> Void)? = nil) {
        self.init(title: page.title, subtitle: subtitle, symbol: page.symbol, colors: page.colors,
                  isOn: isOn, action: action)
    }

    var body: some View {
        HStack(spacing: 14) {
            if let imagePath, let image = NSImage(contentsOfFile: imagePath) {
                IconImage(image: image, size: 44)
            } else {
                AppIcon(symbol: symbol, colors: colors, size: 44)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.title2.weight(.semibold))
                Text(subtitle)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 12)
            if let action {
                Button(action: action) {
                    Label(t("Preview"), systemImage: "play.fill")
                }
                .buttonStyle(.glass)
                .controlSize(.large)
            }
            if let isOn {
                VStack(spacing: 3) {
                    Toggle("", isOn: isOn)
                        .labelsHidden()
                        .toggleStyle(.switch)
                        .controlSize(.large)
                    Text(isOn.wrappedValue ? t("On") : t("Off"))
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(isOn.wrappedValue ? Color.accentColor : .secondary)
                }
                .help(isOn.wrappedValue ? t("On") : t("Off"))
            }
        }
        .padding(.bottom, 4)
    }
}

private struct SectionTitle: View {
    let text: String
    init(_ text: String) { self.text = text }

    var body: some View {
        Text(text)
            .font(.system(size: 15, weight: .bold))
            .padding(.leading, 4)
            .padding(.bottom, -10)
    }
}

private struct FooterNote: View {
    let text: String
    init(_ text: String) { self.text = text }

    var body: some View {
        Text(text)
            .font(.callout)
            .foregroundStyle(.secondary)
            .padding(.leading, 4)
            .padding(.top, -10)
    }
}

/// Скруглённая карточка-группа.
private struct Card<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 0) { content }
            .background(RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.primary.opacity(0.045)))
    }
}

private struct CardDivider: View {
    var body: some View { Divider().padding(.horizontal, 16) }
}

private struct Row<Trailing: View>: View {
    let title: String
    var subtitle: String?
    @ViewBuilder var trailing: Trailing

    var body: some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                if let subtitle {
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer(minLength: 12)
            trailing
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 11)
    }
}

private struct ToggleRow: View {
    let title: String
    var subtitle: String?
    @Binding var isOn: Bool

    var body: some View {
        Row(title: title, subtitle: subtitle) {
            Toggle("", isOn: $isOn)
                .labelsHidden()
                .toggleStyle(.switch)
        }
    }
}

private struct SliderRow: View {
    let title: String
    @Binding var value: Double
    let range: ClosedRange<Double>

    var body: some View {
        Row(title: title) {
            Slider(value: $value, in: range)
                .frame(width: 260)
        }
    }
}

/// Выбор из нескольких значений «таблетками».
private struct ChipPicker<T: Hashable>: View {
    let options: [T]
    @Binding var selection: T
    var tint: Color = .accentColor
    let label: (T) -> String

    @Environment(\.isEnabled) private var isEnabled

    var body: some View {
        HStack(spacing: 6) {
            ForEach(options, id: \.self) { option in
                let selected = option == selection
                Text(label(option))
                    .font(.system(size: 12.5, weight: selected ? .semibold : .regular))
                    .monospacedDigit()
                    .padding(.horizontal, 9)
                    .padding(.vertical, 5)
                    .background(Capsule().fill(selected ? tint : Color.primary.opacity(0.07)))
                    .foregroundStyle(selected ? Color.white : Color.primary)
                    .contentShape(Capsule())
                    .onTapGesture { withAnimation(.snappy) { selection = option } }
            }
        }
        .opacity(isEnabled ? 1 : 0.45)
    }
}

/// Приложение живёт только в трее, поэтому окно настроек может открыться
/// за другими окнами. Поднимаем его наверх при появлении.
private struct BringToFront: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView {
        let v = NSView()
        DispatchQueue.main.async {
            NSApp.activate()
            v.window?.makeKeyAndOrderFront(nil)
            v.window?.orderFrontRegardless()
        }
        return v
    }
    func updateNSView(_ nsView: NSView, context: Context) {}
}

