import Foundation
import Testing
@testable import PinokKit

/// Сколько секунд напоминание или набор на экране.
@MainActor
@Suite("DurationTests", .serialized)
struct DurationTests {
    private func make() -> (Scheduler, AppSettings, FakePresenter, TestClock) {
        let clock = TestClock()
        let settings = AppSettings(defaults: TestSupport.freshDefaults())
        settings.breakEnabled = false
        settings.smartTiming = false
        let presenter = FakePresenter()
        let scheduler = Scheduler(settings: settings, presenter: presenter, clock: { clock.now }, idleSeconds: { 100 },
                                  detectBusy: { _ in nil })
        return (scheduler, settings, presenter, clock)
    }

    @Test func defaultDurationIsFourSeconds() {
        let (_, settings, _, _) = make()
        #expect(settings.nudgeDuration == 4)
    }

    @Test func reminderUsesTheGlobalDuration() {
        let (scheduler, settings, presenter, clock) = make()
        settings.nudgeDuration = 15
        var r = ReminderLibrary.template("posture")!.make()
        r.interval = 10
        settings.reminders = [r]
        settings.sets = []
        scheduler.resetAll()
        clock.advance(600)
        scheduler.tick()
        #expect(presenter.nudgeDurations == [15])
    }

    @Test func setUsesItsOwnDuration() {
        let (scheduler, settings, presenter, clock) = make()
        settings.nudgeDuration = 8
        let a = ReminderLibrary.template("posture")!.make()
        let b = ReminderLibrary.template("blink")!.make()
        settings.reminders = [a, b]
        settings.sets = [ReminderSet(name: "S", reminderIDs: [a.id, b.id], interval: 10, duration: 60)]
        scheduler.resetAll()
        clock.advance(600)
        scheduler.tick()
        #expect(presenter.nudges.first?.count == 2)
        #expect(presenter.nudgeDurations == [60])
    }

    @Test func setWithoutDurationShowsForEightSeconds() {
        let (scheduler, settings, presenter, _) = make()
        settings.nudgeDuration = 30
        let a = ReminderLibrary.template("posture")!.make()
        settings.reminders = [a]
        let set = ReminderSet(name: "S", reminderIDs: [a.id], duration: nil)
        settings.sets = [set]
        scheduler.preview(set)
        #expect(presenter.nudgeDurations == [8])
    }

    @Test func durationPersists() {
        let d = TestSupport.freshDefaults()
        let s = AppSettings(defaults: d)
        s.nudgeDuration = 30
        s.sets = [ReminderSet(name: "S", duration: 45)]
        let again = AppSettings(defaults: d)
        #expect(again.nudgeDuration == 30)
        #expect(again.sets.first?.duration == 45)
    }

    @Test func oldSetsWithoutDurationStillDecode() throws {
        let json = #"[{"id":"\#(UUID().uuidString)","name":"Old","reminderIDs":[],"interval":30,"enabled":true,"sound":"Pop"}]"#
        let sets = try JSONDecoder().decode([ReminderSet].self, from: Data(json.utf8))
        #expect(sets.first?.duration == nil)
    }
}
