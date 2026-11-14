import SwiftUI

// MARK: - Превью

/// Английский для превью (язык — общий и может остаться русским от другого превью).
@MainActor private func english() { _ = AppSettings.shared; L10n.isRussian = false }

/// Набор для превью: создаём, если его ещё нет.
@MainActor private func demoSetPage() -> SettingsPage {
    let s = AppSettings.shared
    if s.sets.isEmpty {
        let ids = ["posture", "blink", "water"].compactMap { id in s.reminders.first { $0.template == id }?.id }
        s.sets = [ReminderSet(name: "Desk set", reminderIDs: ids, interval: 30, duration: 15)]
    }
    return .set(s.sets[0].id)
}

#Preview("Settings · General") {
    let _ = english()
    SettingsView(initialPage: .general)
}
#Preview("Settings · Reminder") {
    SettingsView(initialPage: AppSettings.shared.reminders.first.map { .reminder($0.id) } ?? .library)
}
#Preview("Settings · Library") {
    let _ = english()
    SettingsView(initialPage: .library)
}
#Preview("Settings · Breaks") {
    let _ = english()
    SettingsView(initialPage: .breaks)
}

#Preview("Settings · Set") {
    let _ = english()
    SettingsView(initialPage: demoSetPage())
}

#Preview("Settings · Library · RU") {
    let _ = AppSettings.shared   // сначала настройки (они выставляют язык)...
    let _ = L10n.isRussian = true // ...потом включаем русский только для превью
    SettingsView(initialPage: .library)
}

#Preview("Menu bar panel", traits: .sizeThatFitsLayout) {
    let _ = english()
    let _ = Scheduler.shared.resetAll()
    MenuContent()
        .background(.regularMaterial)
}
