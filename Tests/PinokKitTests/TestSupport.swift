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
    /// «+N мин» на плашке перед перерывом.
    var warningSnoozes: [(Int) -> Void] = []
    var cursorCountdowns: [Date] = []
    var hideHintsCount = 0
    var sounds: [String] = []

    /// Сколько раз показали это напоминание (одно или в наборе).
    func shownCount(_ id: UUID) -> Int { nudges.filter { $0.contains { $0.id == id } }.count }

    func showNudge(_ reminders: [Reminder], duration: TimeInterval) {
        nudges.append(reminders)
        nudgeDurations.append(duration)
    }
    func showBreak(seconds: Int, demo: Bool, completion: @escaping (BreakOutcome) -> Void) {
        breaks.append((seconds, demo, completion))
    }
    func showWarning(breakAt: Date, onSnooze: @escaping (Int) -> Void, onStartNow: @escaping () -> Void) {
        warnings.append(breakAt)
        warningSnoozes.append(onSnooze)
    }
    func showCursorCountdown(breakAt: Date) { cursorCountdowns.append(breakAt) }
    func hideHints() { hideHintsCount += 1 }
    func playSound(_ name: String) { sounds.append(name) }

    var dayEndWarnings: [(endAt: Date, postpone: (Int) -> Void, skip: () -> Void)] = []
    var dayEnds: [(session: DayEndSession, demo: Bool, completion: (DayEndOutcome) -> Void)] = []
    func showDayEndWarning(endAt: Date, onPostpone: @escaping (Int) -> Void, onSkip: @escaping () -> Void) {
        dayEndWarnings.append((endAt, onPostpone, onSkip))
    }
    func showDayEnd(_ session: DayEndSession, demo: Bool, completion: @escaping (DayEndOutcome) -> Void) {
        dayEnds.append((session, demo, completion))
    }
}
