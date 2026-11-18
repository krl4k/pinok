import Foundation
import Testing
@testable import PinokKit

/// Конец рабочего дня: предупреждения, экран со списком, перенос и пропуск.
@MainActor
@Suite("DayEnd", .serialized)
struct DayEndTests {
    /// Рабочий день кончается через час после старта, все дни рабочие, предупреждения за 30 и 5 минут.
    private func harness(endIn minutes: Int = 60) -> SchedulerHarness {
        let h = SchedulerHarness()
        let cal = Calendar.current
        let c = cal.dateComponents([.hour, .minute], from: h.start)
        let startMinutes = (c.hour ?? 0) * 60 + (c.minute ?? 0)
        precondition(startMinutes + minutes < 24 * 60, "test start is too late in the day")
        h.settings.dayEndDays = Array(1...7)
        h.settings.dayEndWarnings = [30, 5]
        h.settings.dayEndSnooze = 5
        h.settings.dayEndTime = startMinutes + minutes
        h.settings.dayEndEnabled = true
        h.settings.dayEndClosedOn = nil
        h.reset()
        return h
    }

    @Test func warnsAt30And5MinutesThenShowsTheList() {
        let h = harness()
        h.tick(at: 29 * 60)
        #expect(h.presenter.dayEndWarnings.isEmpty)
        h.tick(at: 30 * 60)
        #expect(h.presenter.dayEndWarnings.count == 1)
        #expect(h.presenter.dayEndWarnings[0].endAt == h.at(3600))
        h.tick(at: 31 * 60)
        #expect(h.presenter.dayEndWarnings.count == 1)
        h.tick(at: 55 * 60)
        #expect(h.presenter.dayEndWarnings.count == 2)
        #expect(h.presenter.dayEnds.isEmpty)

        h.tick(at: 3600)
        #expect(h.presenter.dayEnds.count == 1)
        #expect(h.scheduler.onDayEnd)
        #expect(h.scheduler.dayEndActive)
        #expect(h.presenter.dayEnds[0].session.items == AppSettings.defaultDayEndItems)
    }

    @Test func manyWarningsAtOnceShowOnlyOne() {
        let h = harness(endIn: 3)
        h.tick(at: 1)
        #expect(h.presenter.dayEndWarnings.count == 1)
        h.tick(at: 2)
        #expect(h.presenter.dayEndWarnings.count == 1)
    }

    @Test func doTheStepsShowsTheListAgainAndKeepsTheMarks() {
        let h = harness()
        h.tick(at: 3600)
        let session = h.presenter.dayEnds[0].session
        session.toggle(0)
        h.presenter.dayEnds[0].completion(.later)
        #expect(!h.scheduler.onDayEnd)
        #expect(h.scheduler.dayEndActive)

        h.tick(at: 3600 + 4 * 60)
        #expect(h.presenter.dayEnds.count == 1)
        h.tick(at: 3600 + 5 * 60)
        #expect(h.presenter.dayEnds.count == 2)
        #expect(h.presenter.dayEnds[1].session === session)
        #expect(session.done == [0])
    }

    @Test func breaksAndRemindersWaitAfterTheEnd() {
        let h = harness()
        h.settings.reminders = [SchedulerHarness.reminder("Posture", every: 10)]
        h.settings.breakEnabled = true
        h.settings.breakInterval = 70
        h.reset()
        h.tick(at: 3600)
        h.presenter.dayEnds[0].completion(.later)
        let nudges = h.presenter.nudges.count
        for s in stride(from: 3601.0, to: 3600 + 4 * 60, by: 1) { h.tick(at: s) }
        #expect(h.presenter.nudges.count == nudges)
        #expect(h.presenter.breaks.isEmpty)
        #expect(h.scheduler.menuBarText == nil)
    }

    @Test func endTheDayPausesUntilTomorrow() {
        let h = harness()
        h.tick(at: 3600)
        h.presenter.dayEnds[0].completion(.done)
        #expect(h.scheduler.isDayClosed)
        #expect(!h.scheduler.dayEndActive)
        let cal = Calendar.current
        #expect(h.scheduler.pausedUntil == cal.date(byAdding: .day, value: 1, to: cal.startOfDay(for: h.at(3600))))
        h.tick(at: 3600 + 600)
        #expect(h.presenter.dayEnds.count == 1)
    }

    @Test func skipTodayLetsRemindersContinue() {
        let h = harness()
        h.settings.reminders = [SchedulerHarness.reminder("Posture", every: 10)]
        h.reset()
        h.tick(at: 3600)
        h.presenter.dayEnds[0].completion(.skipped)
        #expect(h.scheduler.isDayClosed)
        #expect(!h.scheduler.isPaused)
        let before = h.presenter.nudges.count
        h.tick(at: 3600 + 10 * 60)
        #expect(h.presenter.nudges.count == before + 1)
        #expect(h.presenter.dayEnds.count == 1)
    }

    @Test func postponeFromTheWarningMovesTheEnd() {
        let h = harness()
        h.tick(at: 30 * 60)
        h.presenter.dayEndWarnings[0].postpone(30)
        #expect(h.scheduler.upcomingDayEnd == h.at(90 * 60))
        // Новый конец через час: оба предупреждения придут снова — за 30 и за 5 минут.
        h.tick(at: 59 * 60)
        #expect(h.presenter.dayEndWarnings.count == 1)
        h.tick(at: 60 * 60)
        #expect(h.presenter.dayEndWarnings.count == 2)
        #expect(h.presenter.dayEnds.isEmpty)
        h.tick(at: 85 * 60)
        #expect(h.presenter.dayEndWarnings.count == 3)
        h.tick(at: 90 * 60)
        #expect(h.presenter.dayEnds.count == 1)
    }

    @Test func postponeFromTheListStartsFromNowAndRestartsBreaks() {
        let h = harness()
        h.settings.breakEnabled = true
        h.settings.breakInterval = 70
        h.reset()
        h.tick(at: 3600)
        h.tick(at: 3600 + 120)
        h.presenter.dayEnds[0].completion(.postponed(minutes: 10))
        #expect(!h.scheduler.onDayEnd)
        #expect(!h.scheduler.dayEndActive)
        #expect(h.scheduler.upcomingDayEnd == h.at(3600 + 120 + 600))
        #expect(h.scheduler.nextBreak == h.at(3600 + 120 + 70 * 60))
        h.tick(at: 3600 + 120 + 300)
        #expect(h.presenter.dayEndWarnings.count == 1)
        h.tick(at: 3600 + 120 + 600)
        #expect(h.presenter.dayEnds.count == 2)
    }

    @Test func turningItOnAfterTheEndTimeDoesNotShowTheListToday() {
        let h = harness()
        h.settings.dayEndEnabled = false
        h.clock.now = h.at(3700)
        h.settings.dayEndEnabled = true
        h.scheduler.dayEndSettingsChanged()   // в приложении это вызывает onTimingChange
        h.tick(at: 3701)
        #expect(h.presenter.dayEnds.isEmpty)
        #expect(h.scheduler.isDayClosed)
    }

    @Test func nothingOnADayOff() {
        let h = harness()
        let today = Calendar.current.component(.weekday, from: h.start)
        h.settings.dayEndDays = Array(1...7).filter { $0 != today }
        h.tick(at: 30 * 60)
        h.tick(at: 3600)
        #expect(h.presenter.dayEndWarnings.isEmpty)
        #expect(h.presenter.dayEnds.isEmpty)
    }

    @Test func showsDuringAManualPause() {
        let h = harness()
        h.scheduler.pause(for: 2 * 3600)
        h.tick(at: 3600)
        #expect(h.presenter.dayEnds.count == 1)
    }

    @Test func waitsDuringACall() {
        let h = harness()
        h.busy = .call
        for s in 1...3 { h.tick(at: TimeInterval(s)) }
        for s in 0...5 { h.tick(at: TimeInterval(3600 + s)) }
        #expect(h.presenter.dayEnds.isEmpty)
        h.busy = nil
        for s in 6...9 { h.tick(at: TimeInterval(3600 + s)) }
        #expect(h.presenter.dayEnds.count == 1)
    }

    @Test func emptyStepsAreNotShown() {
        let session = DayEndSession(items: ["One", "  ", "", "Two"])
        #expect(session.items == ["One", "Two"])
        #expect(!session.allDone)
        session.toggle(0)
        session.toggle(1)
        #expect(session.allDone)
    }
}
