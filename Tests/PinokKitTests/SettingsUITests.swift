import AppKit
import SwiftUI
import Testing
@testable import PinokKit

/// Сохраняем и возвращаем общие настройки, которые тесты меняют.
@MainActor
private func withSharedSettings(_ body: (AppSettings) async throws -> Void) async rethrows {
    let s = AppSettings.shared
    let reminders = s.reminders, sets = s.sets, breaks = s.breakEnabled, sounds = s.soundsEnabled
    defer {
        s.reminders = reminders
        s.sets = sets
        s.breakEnabled = breaks
        s.soundsEnabled = sounds
        L10n.isRussian = false
    }
    L10n.isRussian = false
    try await body(s)
}

@MainActor
@Suite("SidebarModelTests", .serialized)
struct SidebarModelTests {
    @Test func groupsAreInTheRightOrder() async {
        await withSharedSettings { s in
            s.reminders = ReminderLibrary.defaults
            let combo = ReminderSet(name: "C", reminderIDs: [s.reminders[0].id])
            s.sets = [combo]

            let groups = SidebarModel.groups(for: s)
            #expect(groups.map(\.title) == [nil, "Short reminders", "Combos", "Long breaks"])
            #expect(groups[0].pages == [.general])
            #expect(groups[1].pages == s.reminders.map { .reminder($0.id) } + [.library])
            #expect(groups[2].pages == [.set(combo.id), .newSet])
            #expect(groups[3].pages == [.breaks])
        }
    }

    @Test func everyPageIsUniqueAndHasATitle() async {
        await withSharedSettings { s in
            s.reminders = ReminderLibrary.all.map { $0.make() }
            s.sets = [ReminderSet(name: "C1"), ReminderSet(name: "C2")]
            let pages = SidebarModel.pages(for: s)
            #expect(Set(pages).count == pages.count)
            for p in pages {
                #expect(!p.title.isEmpty, "\(p)")
                #expect(!p.symbol.isEmpty, "\(p)")
                #expect(p.colors.count == 2, "\(p)")
            }
        }
    }

    @Test func statusDotFollowsOnAndOff() async {
        await withSharedSettings { s in
            s.reminders = ReminderLibrary.defaults
            s.reminders[1].enabled = false
            s.sets = [ReminderSet(name: "C", enabled: false)]
            s.breakEnabled = true
            #expect(SidebarModel.isOn(.reminder(s.reminders[0].id), settings: s) == true)
            #expect(SidebarModel.isOn(.reminder(s.reminders[1].id), settings: s) == false)
            #expect(SidebarModel.isOn(.set(s.sets[0].id), settings: s) == false)
            #expect(SidebarModel.isOn(.breaks, settings: s) == true)
            #expect(SidebarModel.isOn(.general, settings: s) == nil)
            #expect(SidebarModel.isOn(.library, settings: s) == nil)
        }
    }

    @Test func pageArgumentsOpenTheRightPage() async {
        await withSharedSettings { s in
            s.reminders = ReminderLibrary.defaults
            #expect(SettingsPage(argument: "general") == .general)
            #expect(SettingsPage(argument: "library") == .library)
            #expect(SettingsPage(argument: "breaks") == .breaks)
            #expect(SettingsPage(argument: "posture") == .reminder(s.reminders[0].id))
            #expect(SettingsPage(argument: "nope") == nil)
        }
    }
}

/// Настоящее окно настроек: клик по каждой строке боковой панели открывает её страницу.
/// Этот тест ловит строки без метки выбора (`.tag`) — тогда боковая панель «не кликается».
@MainActor
@Suite("SettingsUITests", .serialized)
struct SettingsUITests {
    private func findTable(in view: NSView) -> NSTableView? {
        if let table = view as? NSTableView { return table }
        for sub in view.subviews {
            if let found = findTable(in: sub) { return found }
        }
        return nil
    }

    @Test func everySidebarRowOpensItsPage() async throws {
        try await withSharedSettings { s in
            s.reminders = ReminderLibrary.defaults
            s.sets = [ReminderSet(name: "C", reminderIDs: [s.reminders[0].id])]

            var opened: [SettingsPage] = []
            let view = SettingsView(initialPage: .general) { opened.append($0) }
            let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 940, height: 660),
                                  styleMask: [.titled, .closable], backing: .buffered, defer: false)
            window.isReleasedWhenClosed = false
            window.contentView = NSHostingView(rootView: view)
            window.layoutIfNeeded()
            window.display()
            defer { window.orderOut(nil) }
            try await Task.sleep(for: .milliseconds(300))

            let table = try #require(findTable(in: window.contentView!), "Sidebar list is not found")
            #expect(table.numberOfRows > 0)

            for row in 0..<table.numberOfRows {
                table.selectRowIndexes(IndexSet(integer: row), byExtendingSelection: false)
                try await Task.sleep(for: .milliseconds(30))
            }
            try await Task.sleep(for: .milliseconds(200))

            // Каждая страница боковой панели (кроме уже открытой «Общие») открылась хотя бы раз.
            let expected = Set(SidebarModel.pages(for: s)).subtracting([.general])
            #expect(expected.isSubset(of: Set(opened)), "Not opened: \(expected.subtracting(Set(opened)))")
        }
    }
}

@MainActor
@Suite("MuteTests", .serialized)
struct MuteTests {
    @Test func nothingPlaysWhenSoundsAreOff() async {
        await withSharedSettings { s in
            s.soundsEnabled = false
            Sounds.play("melody.jingle")
            Sounds.play("Pop")
            Sounds.play(Sounds.onboarding)
            #expect(Sounds.isPlaying == false)
        }
    }
}

@MainActor
@Suite("OnboardingPreviewTests", .serialized)
struct OnboardingPreviewTests {
    @Test func previewShowsSelectedInLibraryOrderWithText() {
        let m = OnboardingModel(settings: AppSettings(defaults: TestSupport.freshDefaults()))
        m.selected = ["water", "posture", "blink"]
        let preview = m.selectedPreview
        #expect(preview.compactMap(\.template) == ["posture", "blink", "water"])
        #expect(preview.allSatisfy { $0.showCaption })
    }

    @Test func previewIdsDoNotChangeBetweenReads() {
        let m = OnboardingModel(settings: AppSettings(defaults: TestSupport.freshDefaults()))
        let first = m.selectedPreview.map(\.id)
        let second = m.selectedPreview.map(\.id)
        #expect(first == second)
    }
}
