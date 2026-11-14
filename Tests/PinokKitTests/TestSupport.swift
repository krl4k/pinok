import Foundation
@testable import PinokKit

/// Общие помощники для тестов.
enum TestSupport {
    /// Чистый UserDefaults для одного теста.
    static func freshDefaults(_ name: String = UUID().uuidString) -> UserDefaults {
        let suite = "pinok.tests.\(name)"
        let d = UserDefaults(suiteName: suite)!
        d.removePersistentDomain(forName: suite)
        return d
    }
}

/// Часы, которые двигаем руками.
final class TestClock {
    var now: Date
    init(_ start: Date = Date(timeIntervalSince1970: 1_800_000_000)) { now = start }
    func advance(_ seconds: TimeInterval) { now = now.addingTimeInterval(seconds) }
}

/// Заглушка показа: запоминает, что показали.
@MainActor
final class FakePresenter: ReminderPresenter {
    var isShowingNudge = false
    var nudges: [[Reminder]] = []
    var nudgeDurations: [TimeInterval] = []
    var breaks: [(seconds: Int, demo: Bool, completion: (BreakOutcome) -> Void)] = []
    var warnings: [Date] = []
    var cursorCountdowns: [Date] = []
    var hideHintsCount = 0
    var sounds: [String] = []

    func showNudge(_ reminders: [Reminder], duration: TimeInterval) {
        nudges.append(reminders)
        nudgeDurations.append(duration)
    }
    func showBreak(seconds: Int, demo: Bool, completion: @escaping (BreakOutcome) -> Void) {
        breaks.append((seconds, demo, completion))
    }
    func showWarning(breakAt: Date, onSnooze: @escaping (Int) -> Void, onStartNow: @escaping () -> Void) {
        warnings.append(breakAt)
    }
    func showCursorCountdown(breakAt: Date) { cursorCountdowns.append(breakAt) }
    func hideHints() { hideHintsCount += 1 }
    func playSound(_ name: String) { sounds.append(name) }
}
