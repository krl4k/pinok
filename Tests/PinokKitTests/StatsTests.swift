import Foundation
import Testing
@testable import PinokKit

@MainActor
@Suite("Stats", .serialized)
struct StatsTests {
    private let day: TimeInterval = 86_400

    private func make(_ d: UserDefaults, _ clock: TestClock) -> Stats {
        Stats(defaults: d, today: { clock.now })
    }

    @Test func startsEmpty() {
        let s = make(TestSupport.freshDefaults(), TestClock())
        #expect(s.total == 0)
        #expect(s.breaks == 0)
        #expect(s.counts.isEmpty)
        #expect(s.count(for: UUID()) == 0)
    }

    @Test func addCountsPerReminder() {
        let s = make(TestSupport.freshDefaults(), TestClock())
        let a = UUID(), b = UUID()
        s.add(a); s.add(a); s.add(b)
        #expect(s.count(for: a) == 2)
        #expect(s.count(for: b) == 1)
        #expect(s.count(for: UUID()) == 0)
        #expect(s.total == 3)
    }

    @Test func breaksSeparateFromTotal() {
        let s = make(TestSupport.freshDefaults(), TestClock())
        s.addBreak(); s.addBreak()
        #expect(s.breaks == 2)
        #expect(s.total == 0)
    }

    @Test func persistsAcrossInstancesSameDay() {
        let d = TestSupport.freshDefaults()
        let clock = TestClock()
        let a = UUID()
        let s = make(d, clock)
        s.add(a); s.add(a); s.addBreak()

        clock.advance(60)
        let r = make(d, clock)
        #expect(r.count(for: a) == 2)
        #expect(r.total == 2)
        #expect(r.breaks == 1)
    }

    @Test func newDayResetsOnAdd() {
        let d = TestSupport.freshDefaults()
        let clock = TestClock()
        let a = UUID(), b = UUID()
        let s = make(d, clock)
        s.add(a); s.addBreak()

        clock.advance(day)
        s.add(b)
        #expect(s.count(for: a) == 0)
        #expect(s.count(for: b) == 1)
        #expect(s.total == 1)
        #expect(s.breaks == 0)
    }

    @Test func newDayResetsOnAddBreak() {
        let clock = TestClock()
        let s = make(TestSupport.freshDefaults(), clock)
        s.add(UUID()); s.addBreak()
        clock.advance(day)
        s.addBreak()
        #expect(s.total == 0)
        #expect(s.breaks == 1)
    }

    @Test func explicitRollover() {
        let clock = TestClock()
        let s = make(TestSupport.freshDefaults(), clock)
        s.add(UUID()); s.addBreak()
        s.rollover()                       // same day: nothing changes
        #expect(s.total == 1)
        #expect(s.breaks == 1)
        clock.advance(day)
        s.rollover()
        #expect(s.total == 0)
        #expect(s.breaks == 0)
    }

    @Test func newInstanceOnNewDayStartsEmpty() {
        let d = TestSupport.freshDefaults()
        let clock = TestClock()
        make(d, clock).add(UUID())
        clock.advance(day)
        #expect(make(d, clock).total == 0)
    }

    @Test func goingBackLoadsThatDay() {
        let d = TestSupport.freshDefaults()
        let clock = TestClock()
        let a = UUID()
        let s = make(d, clock)
        s.add(a); s.add(a); s.addBreak()

        clock.advance(day)
        s.add(a)
        #expect(s.count(for: a) == 1)

        clock.advance(-day)
        s.rollover()
        #expect(s.count(for: a) == 2)
        #expect(s.breaks == 1)

        clock.advance(day)
        s.rollover()
        #expect(s.count(for: a) == 1)
        #expect(s.breaks == 0)
    }

    @Test func storageKeys() {
        let d = TestSupport.freshDefaults()
        let clock = TestClock()
        let a = UUID()
        let s = make(d, clock)
        s.add(a); s.addBreak()
        let k = Stats.key(for: clock.now)
        #expect((d.dictionary(forKey: "stats.\(k).counts") as? [String: Int]) == [a.uuidString: 1])
        #expect(d.integer(forKey: "stats.\(k).breaks") == 1)
    }

    @Test func keyFormat() {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = .current
        let date = cal.date(from: DateComponents(year: 2026, month: 3, day: 7, hour: 12))!
        #expect(Stats.key(for: date) == "2026-03-07")
        let date2 = cal.date(from: DateComponents(year: 1999, month: 12, day: 31, hour: 23, minute: 59))!
        #expect(Stats.key(for: date2) == "1999-12-31")
        let k = Stats.key(for: TestClock().now)
        #expect(k.count == 10)
        #expect(k.range(of: #"^\d{4}-\d{2}-\d{2}$"#, options: .regularExpression) != nil)
    }

    @Test func keyChangesAtMidnight() {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = .current
        let before = cal.date(from: DateComponents(year: 2026, month: 1, day: 1, hour: 23, minute: 59, second: 59))!
        #expect(Stats.key(for: before) == "2026-01-01")
        #expect(Stats.key(for: before.addingTimeInterval(1)) == "2026-01-02")
    }

    @Test func separateDefaultsDoNotShare() {
        let clock = TestClock()
        let a = UUID()
        make(TestSupport.freshDefaults(), clock).add(a)
        #expect(make(TestSupport.freshDefaults(), clock).count(for: a) == 0)
    }

    @Test func skipPostponeAndActiveTimePersist() {
        let d = TestSupport.freshDefaults()
        let clock = TestClock()
        let s = make(d, clock)
        s.addSkip(); s.addPostpone(); s.addPostpone()
        s.addActive(45)
        #expect(s.skipped == 1)
        #expect(s.postponed == 2)
        #expect(s.activeSeconds == 45)
        let again = make(d, clock)
        #expect(again.skipped == 1)
        #expect(again.postponed == 2)
        // Время пишем на диск раз в 30 с: 45 с сохранились как минимум до отметки 30.
        #expect(again.activeSeconds == 45)
    }

    @Test func newCountersResetOnNewDay() {
        let d = TestSupport.freshDefaults()
        let clock = TestClock()
        let s = make(d, clock)
        s.addSkip(); s.addPostpone(); s.addActive(120)
        clock.advance(day)
        s.rollover()
        #expect(s.skipped == 0)
        #expect(s.postponed == 0)
        #expect(s.activeSeconds == 0)
    }

    @Test func activeTimeFillsTimelineAndApps() {
        let d = TestSupport.freshDefaults()
        let clock = TestClock()
        let s = make(d, clock)
        s.addActive(20, app: "a")
        s.addActive(15, app: "b")
        s.addActive(10, app: "a")
        #expect(s.appSeconds == ["a": 30, "b": 15])
        #expect(s.topApps.map(\.id) == ["a", "b"])
        #expect(s.slots[s.currentSlot] == Stats.Slot.work)
        #expect(s.slots.filter { $0 != Stats.Slot.none }.count == 1)
        // На диск пишем раз в 30 с: последний раз — на 35-й секунде.
        let again = make(d, clock)
        #expect(again.appSeconds == ["a": 20, "b": 15])
        #expect(again.slots[again.currentSlot] == Stats.Slot.work)
    }

    @Test func breakMarksSlotAndEndsWorkStretch() {
        let s = make(TestSupport.freshDefaults(), TestClock())
        s.addActive(100)
        s.markBreak()
        #expect(s.slots[s.currentSlot] == Stats.Slot.rest)
        s.addActive(40)
        // Перерыв важнее работы в том же отрезке.
        #expect(s.slots[s.currentSlot] == Stats.Slot.rest)
        #expect(s.longestWork == 100)
        s.endWorkStretch()
        s.addActive(120)
        #expect(s.longestWork == 120)
    }

    @Test func slotIndexFromTime() {
        var c = DateComponents()
        c.year = 2026; c.month = 1; c.day = 1; c.hour = 9; c.minute = 44
        let date = Calendar.current.date(from: c)!
        #expect(Stats.slot(for: date) == 9 * 4 + 2)
    }
}
