import AppKit
import Foundation
import Testing
@testable import PinokKit

@MainActor
@Suite("BreakSessionTests", .serialized)
struct BreakSessionTests {
    private let start = Date(timeIntervalSince1970: 1_800_000_000)

    private func session(_ exercises: [BreakExercise], requireList: Bool = true, seconds: TimeInterval = 300) -> BreakSession {
        BreakSession(endDate: start.addingTimeInterval(seconds), exercises: exercises, requireList: requireList)
    }

    @Test func toggleMarksAndUnmarks() {
        let s = session([.pushUps, .squats])
        #expect(!s.allDone)
        s.toggle(.pushUps)
        #expect(s.done == [.pushUps])
        s.toggle(.pushUps)
        #expect(s.done.isEmpty)
    }

    @Test func allDoneWhenEveryExerciseIsMarked() {
        let s = session([.pushUps, .squats])
        s.toggle(.pushUps)
        #expect(!s.allDone)
        s.toggle(.squats)
        #expect(s.allDone)
    }

    @Test func neverFinishesBeforeTheTime() {
        let s = session([.pushUps], requireList: false)
        s.toggle(.pushUps)
        #expect(!s.canFinish(at: start.addingTimeInterval(299)))
        #expect(s.canFinish(at: start.addingTimeInterval(300)))
    }

    @Test func waitsForTheListWhenRequired() {
        let s = session([.pushUps, .squats], requireList: true)
        let after = start.addingTimeInterval(400)
        #expect(!s.canFinish(at: after))
        s.toggle(.pushUps)
        #expect(!s.canFinish(at: after))
        s.toggle(.squats)
        #expect(s.canFinish(at: after))
    }

    @Test func doesNotWaitWhenListIsNotRequired() {
        let s = session([.pushUps], requireList: false)
        #expect(s.canFinish(at: start.addingTimeInterval(300)))
    }

    @Test func emptyListNeverBlocks() {
        let s = session([], requireList: true)
        #expect(s.allDone)
        #expect(s.canFinish(at: start.addingTimeInterval(300)))
    }

    @Test(arguments: [0, 1, 2, 3, 10])
    func pickTakesAtMostCountFromEnabled(count: Int) {
        let enabled: [BreakExercise] = [.stretch, .pushUps, .squats]
        let picked = BreakSession.pick(from: enabled, count: count)
        #expect(picked.count == min(count, enabled.count))
        #expect(Set(picked).isSubset(of: Set(enabled)))
        #expect(Set(picked).count == picked.count)
    }

    @Test func pickWithNegativeCountIsEmpty() {
        #expect(BreakSession.pick(from: BreakExercise.allCases, count: -1).isEmpty)
    }

    @Test func everyExerciseHasTextAndSymbol() {
        L10n.isRussian = false
        for ex in BreakExercise.allCases {
            #expect(!ex.title.isEmpty)
            #expect(!ex.instruction.isEmpty)
            #expect(!ex.symbol.isEmpty)
        }
        #expect(Set(BreakExercise.defaults).isSubset(of: Set(BreakExercise.allCases)))
    }

    @Test func exercisesAreNotShortReminders() {
        // Упражнения — только на перерыве, не в библиотеке коротких напоминаний.
        let ids = Set(ReminderLibrary.all.map(\.id))
        #expect(!ids.contains("stretch"))
        #expect(!ids.contains("pushUps"))
    }
}

@MainActor
@Suite("HapticsTests", .serialized)
struct HapticsTests {
    @Test func playsOnlyWhenTurnedOn() {
        let original = Haptics.perform
        defer { Haptics.perform = original }
        var played: [NSHapticFeedbackManager.FeedbackPattern] = []
        Haptics.perform = { played.append($0) }

        let before = AppSettings.shared.haptics
        defer { AppSettings.shared.haptics = before }

        AppSettings.shared.haptics = true
        Haptics.play(.click)
        Haptics.play(.strong)
        #expect(played == [.alignment, .levelChange])

        AppSettings.shared.haptics = false
        Haptics.play(.tap)
        #expect(played.count == 2)
    }

    @Test func kindsMapToSystemPatterns() {
        #expect(Haptics.Kind.tap.pattern == .generic)
        #expect(Haptics.Kind.click.pattern == .alignment)
        #expect(Haptics.Kind.strong.pattern == .levelChange)
    }
}
