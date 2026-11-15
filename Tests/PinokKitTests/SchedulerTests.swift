import Foundation
import Testing
@testable import PinokKit

@MainActor
@Suite("SchedulerTests", .serialized)
struct SchedulerTests {

    // MARK: - Одиночные напоминания

    @Test func reminderFiresAfterIntervalNotBefore() {
        let h = SchedulerHarness()
        let r = SchedulerHarness.reminder("A", every: 20, sound: "melody.rise")
        h.settings.reminders = [r]
        h.reset()
        #expect(h.scheduler.nextFire[r.id] == h.at(1200))

        h.tick(at: 1199)
        #expect(h.presenter.nudges.isEmpty)
        #expect(h.stats.count(for: r.id) == 0)

        h.tick(at: 1200)
        #expect(h.presenter.nudges.count == 1)
        #expect(h.presenter.nudges.first?.map(\.id) == [r.id])
        #expect(h.presenter.sounds == ["melody.rise"])
        #expect(h.stats.count(for: r.id) == 1)
        #expect(h.scheduler.nextFire[r.id] == h.at(2400))
    }

    @Test func reminderRepeatsEveryInterval() {
        let h = SchedulerHarness()
        let r = SchedulerHarness.reminder("A", every: 20)
        h.settings.reminders = [r]
        h.reset()
        h.run(seconds: 3600)
        #expect(h.presenter.nudges.count == 3)
        #expect(h.stats.count(for: r.id) == 3)
    }

    @Test func disabledReminderIsNotScheduled() {
        let h = SchedulerHarness()
        var r = SchedulerHarness.reminder("A", every: 10)
        r.enabled = false
        h.settings.reminders = [r]
        h.reset()
        #expect(h.scheduler.nextFire[r.id] == nil)
        h.tick(at: 3600)
        #expect(h.presenter.nudges.isEmpty)
    }

    // MARK: - Один показ за тик и интервал между показами

    @Test func sameIntervalRemindersAreSpreadApart() {
        let h = SchedulerHarness()
        let a = SchedulerHarness.reminder("A", every: 20)
        let b = SchedulerHarness.reminder("B", every: 20)
        h.settings.reminders = [a, b]
        h.reset()

        let fa = try! #require(h.scheduler.nextFire[a.id])
        let fb = try! #require(h.scheduler.nextFire[b.id])
        // Один в срок, другой — через 3 минуты после него.
        #expect(abs(fa.timeIntervalSince(fb)) == Scheduler.minGap)
        let first = min(fa, fb), second = max(fa, fb)
        #expect(first == h.at(1200))

        h.tick(at: 1200)
        #expect(h.presenter.nudges.count == 1)
        h.clock.now = second.addingTimeInterval(-1)
        h.scheduler.tick()
        #expect(h.presenter.nudges.count == 1)
        h.clock.now = second
        h.scheduler.tick()
        #expect(h.presenter.nudges.count == 2)
        #expect(h.stats.count(for: a.id) == 1)
        #expect(h.stats.count(for: b.id) == 1)
    }

    @Test func refireKeepsTheGap() {
        let h = SchedulerHarness()
        let a = SchedulerHarness.reminder("A", every: 10)
        let b = SchedulerHarness.reminder("B", every: 20)
        h.settings.reminders = [a, b]
        h.reset()
        h.tick(at: 600)   // A; его следующий раз попал бы на 1200 вместе с B — уходит на 1380
        #expect(h.scheduler.nextFire[b.id] == h.at(1200))
        #expect(h.scheduler.nextFire[a.id] == h.at(1200 + Scheduler.minGap))
    }

    @Test func manyRemindersNeverCloserThanTheGap() {
        let h = SchedulerHarness()
        h.settings.reminders = (0..<6).map { SchedulerHarness.reminder("R\($0)", every: 15) }
        h.reset()
        let times = h.scheduler.nextFire.values.sorted()
        for (x, y) in zip(times, times.dropFirst()) {
            #expect(y.timeIntervalSince(x) >= Scheduler.minGap)
        }
    }

    @Test func dueItemAfterPreviewIsPushedBySpacing() {
        let h = SchedulerHarness()
        let a = SchedulerHarness.reminder("A", every: 20)
        let other = SchedulerHarness.reminder("Other", every: 60)
        h.settings.reminders = [a]
        h.reset()
        h.clock.now = h.at(1190)
        h.scheduler.preview(other)
        h.tick(at: 1200)
        #expect(h.presenter.nudges.count == 1)  // только превью
        #expect(h.scheduler.nextFire[a.id] == h.at(1235))
        h.tick(at: 1235)
        #expect(h.presenter.nudges.count == 2)
    }

    @Test func itemAfterSpacingWindowFiresAtOnce() {
        let h = SchedulerHarness()
        let a = SchedulerHarness.reminder("A", every: 10)
        let b = SchedulerHarness.reminder("B", every: 20)
        h.settings.reminders = [a, b]
        h.reset()
        h.tick(at: 600)   // A
        h.tick(at: 1200)  // B (A разнесён на 3 минуты позже)
        h.tick(at: 1380)  // A
        #expect(h.presenter.nudges.count == 3)
    }

    // MARK: - Smart timing

    @Test func typingDefersReminderUpTo20Seconds() {
        let h = SchedulerHarness()
        h.settings.smartTiming = true
        let r = SchedulerHarness.reminder("A", every: 20)
        h.settings.reminders = [r]
        h.reset()
        h.idle = 1  // печатает

        h.tick(at: 1200)
        h.tick(at: 1210)
        h.tick(at: 1219)
        #expect(h.presenter.nudges.isEmpty)
        h.tick(at: 1220)
        #expect(h.presenter.nudges.count == 1)
    }

    @Test func reminderFiresWhenTypingStops() {
        let h = SchedulerHarness()
        h.settings.smartTiming = true
        let r = SchedulerHarness.reminder("A", every: 20)
        h.settings.reminders = [r]
        h.reset()
        h.idle = 1
        h.tick(at: 1200)
        #expect(h.presenter.nudges.isEmpty)
        h.idle = Scheduler.typingGrace
        h.tick(at: 1205)
        #expect(h.presenter.nudges.count == 1)
    }

    @Test func typingIsIgnoredWhenSmartTimingIsOff() {
        let h = SchedulerHarness()
        let r = SchedulerHarness.reminder("A", every: 20)
        h.settings.reminders = [r]
        h.reset()
        h.idle = 0
        h.tick(at: 1200)
        #expect(h.presenter.nudges.count == 1)
    }

    @Test func typingDefersBreakUpTo30Seconds() {
        let h = SchedulerHarness()
        h.settings.smartTiming = true
        h.settings.breakEnabled = true
        h.reset()
        h.idle = 1
        h.tick(at: 3600)
        h.tick(at: 3629)
        #expect(h.presenter.breaks.isEmpty)
        #expect(!h.scheduler.onBreak)
        h.tick(at: 3630)
        #expect(h.presenter.breaks.count == 1)
        #expect(h.scheduler.onBreak)
    }

    @Test func breakStartsWhenTypingStops() {
        let h = SchedulerHarness()
        h.settings.smartTiming = true
        h.settings.breakEnabled = true
        h.reset()
        h.idle = 1
        h.tick(at: 3600)
        #expect(h.presenter.breaks.isEmpty)
        h.idle = 5
        h.tick(at: 3605)
        #expect(h.presenter.breaks.count == 1)
    }

    // MARK: - Напоминание прямо перед перерывом

    @Test func reminderJustBeforeBreakIsSkippedButRescheduled() {
        let h = SchedulerHarness()
        h.settings.breakEnabled = true
        let r = SchedulerHarness.reminder("A", every: 59)
        h.settings.reminders = [r]
        h.reset()
        // В 3541 с до перерыва 59 с (< 60): напоминание не показываем.
        h.tick(at: 3541)
        #expect(h.presenter.nudges.isEmpty)
        #expect(h.stats.count(for: r.id) == 0)
        #expect(h.scheduler.nextFire[r.id] == h.at(3541 + 59 * 60))
    }

    @Test func reminderExactly60SecondsBeforeBreakIsShown() {
        let h = SchedulerHarness()
        h.settings.breakEnabled = true
        let r = SchedulerHarness.reminder("A", every: 59)
        h.settings.reminders = [r]
        h.reset()
        h.tick(at: 3540)
        #expect(h.presenter.nudges.count == 1)
    }

    // MARK: - Перерыв

    @Test func breakWarningShowsOnceAtLeadTime() {
        let h = SchedulerHarness()
        h.settings.breakEnabled = true
        h.settings.breakWarning = 60
        h.reset()
        h.tick(at: 3539)
        #expect(h.presenter.warnings.isEmpty)
        h.tick(at: 3540)
        #expect(h.presenter.warnings == [h.at(3600)])
        h.tick(at: 3541)
        h.tick(at: 3580)
        #expect(h.presenter.warnings.count == 1)
    }

    @Test func noWarningWhenLeadIsZero() {
        let h = SchedulerHarness()
        h.settings.breakEnabled = true
        h.settings.breakWarning = 0
        h.reset()
        for s in stride(from: 3500.0, through: 3599, by: 1) { h.tick(at: s) }
        #expect(h.presenter.warnings.isEmpty)
    }

    @Test func cursorCountdownInLast10Seconds() {
        let h = SchedulerHarness()
        h.settings.breakEnabled = true
        h.settings.floatingCountdown = true
        h.reset()
        h.tick(at: 3589)
        #expect(h.presenter.cursorCountdowns.isEmpty)
        h.tick(at: 3590)
        #expect(h.presenter.cursorCountdowns == [h.at(3600)])
    }

    @Test func noCursorCountdownWhenDisabled() {
        let h = SchedulerHarness()
        h.settings.breakEnabled = true
        h.settings.floatingCountdown = false
        h.reset()
        h.tick(at: 3595)
        h.tick(at: 3600)
        #expect(h.presenter.cursorCountdowns.isEmpty)
    }

    @Test func breakStartsOnTime() {
        let h = SchedulerHarness()
        h.settings.breakEnabled = true
        h.settings.breakDuration = 3
        h.reset()
        h.tick(at: 3599)
        #expect(h.presenter.breaks.isEmpty)
        h.tick(at: 3600)
        #expect(h.presenter.breaks.count == 1)
        #expect(h.presenter.breaks[0].seconds == 180)
        #expect(h.presenter.breaks[0].demo == false)
        #expect(h.presenter.sounds == ["Glass"])
        #expect(h.scheduler.onBreak)
        #expect(h.scheduler.menuBarText == "break")
    }

    @Test func nothingFiresDuringBreak() {
        let h = SchedulerHarness()
        h.settings.breakEnabled = true
        let r = SchedulerHarness.reminder("A", every: 61)
        h.settings.reminders = [r]
        h.reset()
        h.tick(at: 3600)
        #expect(h.scheduler.onBreak)
        h.tick(at: 3660)
        h.tick(at: 3700)
        #expect(h.presenter.nudges.isEmpty)
        #expect(h.presenter.breaks.count == 1)
    }

    @Test func startBreakTwiceShowsOneBreak() {
        let h = SchedulerHarness()
        h.settings.breakEnabled = true
        h.reset()
        h.scheduler.startBreak()
        h.scheduler.startBreak()
        #expect(h.presenter.breaks.count == 1)
    }

    @Test func finishedBreakPlaysEndSoundCountsAndResetsAll() {
        let h = SchedulerHarness()
        h.settings.breakEnabled = true
        let r = SchedulerHarness.reminder("A", every: 25)
        h.settings.reminders = [r]
        h.reset()
        h.tick(at: 3600)
        h.clock.now = h.at(3900)
        h.presenter.breaks[0].completion(.finished)
        #expect(!h.scheduler.onBreak)
        #expect(h.presenter.sounds.last == "Hero")
        #expect(h.stats.breaks == 1)
        #expect(h.scheduler.nextBreak == h.at(3900 + 3600))
        #expect(h.scheduler.nextFire[r.id] == h.at(3900 + 1500))
    }

    @Test func skippedBreakResetsWithoutCounting() {
        let h = SchedulerHarness()
        h.settings.breakEnabled = true
        let r = SchedulerHarness.reminder("A", every: 25)
        h.settings.reminders = [r]
        h.reset()
        h.tick(at: 3600)
        h.clock.now = h.at(3610)
        h.presenter.breaks[0].completion(.skipped)
        #expect(!h.scheduler.onBreak)
        #expect(h.stats.breaks == 0)
        #expect(!h.presenter.sounds.contains("Hero"))
        #expect(h.scheduler.nextBreak == h.at(3610 + 3600))
        #expect(h.scheduler.nextFire[r.id] == h.at(3610 + 1500))
    }

    @Test func snoozedBreakMovesBreakAndResetsReminders() {
        let h = SchedulerHarness()
        h.settings.breakEnabled = true
        let r = SchedulerHarness.reminder("A", every: 25)
        h.settings.reminders = [r]
        h.reset()
        h.tick(at: 3600)
        h.clock.now = h.at(3605)
        h.presenter.breaks[0].completion(.snoozed(minutes: 5))
        #expect(!h.scheduler.onBreak)
        #expect(h.stats.breaks == 0)
        #expect(h.scheduler.nextBreak == h.at(3605 + 300))
        #expect(h.scheduler.nextFire[r.id] == h.at(3605 + 1500))
        h.tick(at: 3905)
        #expect(h.presenter.breaks.count == 2)
    }

    @Test func snoozeBreakAllowsANewWarning() {
        let h = SchedulerHarness()
        h.settings.breakEnabled = true
        h.settings.breakWarning = 60
        h.reset()
        h.tick(at: 3540)
        #expect(h.presenter.warnings.count == 1)
        let hidden = h.presenter.hideHintsCount
        h.scheduler.snoozeBreak(minutes: 5)
        #expect(h.presenter.hideHintsCount == hidden + 1)
        #expect(h.scheduler.nextBreak == h.at(3540 + 300))
        h.tick(at: 3779)
        #expect(h.presenter.warnings.count == 1)
        h.tick(at: 3780)
        #expect(h.presenter.warnings.count == 2)
        #expect(h.presenter.warnings.last == h.at(3840))
    }

    @Test func previewBreakIsDemoAndDoesNotChangeState() {
        let h = SchedulerHarness()
        h.settings.breakEnabled = true
        h.reset()
        h.scheduler.previewBreak()
        #expect(h.presenter.breaks.count == 1)
        #expect(h.presenter.breaks[0].demo)
        #expect(h.presenter.breaks[0].seconds == 10)
        #expect(!h.scheduler.onBreak)
        h.presenter.breaks[0].completion(.finished)
        #expect(h.stats.breaks == 0)
        #expect(h.presenter.sounds == ["Glass", "Hero"])
    }

    @Test func breaksOffMeansNoBreak() {
        let h = SchedulerHarness()
        h.settings.breakEnabled = false
        h.reset()
        h.tick(at: 3600)
        h.tick(at: 7200)
        #expect(h.presenter.breaks.isEmpty)
    }

    // MARK: - Пауза

    @Test func nothingFiresWhilePausedAndTimersResetWhenPauseEnds() {
        let h = SchedulerHarness()
        h.settings.breakEnabled = true
        let r = SchedulerHarness.reminder("A", every: 20)
        h.settings.reminders = [r]
        h.reset()
        h.scheduler.pause(for: 4000)
        #expect(h.scheduler.isPaused)
        #expect(h.scheduler.pausedUntil == h.at(4000))
        h.tick(at: 1200)
        h.tick(at: 3600)
        #expect(h.scheduler.menuBarText == nil)
        h.tick(at: 3999)
        #expect(h.presenter.nudges.isEmpty)
        #expect(h.presenter.breaks.isEmpty)

        h.tick(at: 4000)
        #expect(!h.scheduler.isPaused)
        #expect(h.presenter.nudges.isEmpty)
        #expect(h.scheduler.nextFire[r.id] == h.at(4000 + 1200))
        #expect(h.scheduler.nextBreak == h.at(4000 + 3600))
    }

    @Test func resumeResetsTimers() {
        let h = SchedulerHarness()
        let r = SchedulerHarness.reminder("A", every: 20)
        h.settings.reminders = [r]
        h.reset()
        h.scheduler.pause(for: 3600)
        h.clock.now = h.at(500)
        h.scheduler.resume()
        #expect(!h.scheduler.isPaused)
        #expect(h.scheduler.nextFire[r.id] == h.at(1700))
        h.tick(at: 1699)
        #expect(h.presenter.nudges.isEmpty)
        h.tick(at: 1700)
        #expect(h.presenter.nudges.count == 1)
    }

    @Test func pauseUntilTomorrowEndsAtNextMidnight() {
        let h = SchedulerHarness()
        h.reset()
        let hidden = h.presenter.hideHintsCount
        h.scheduler.pauseUntilTomorrow()
        let cal = Calendar.current
        let expected = cal.date(byAdding: .day, value: 1, to: cal.startOfDay(for: h.clock.now))
        #expect(h.scheduler.pausedUntil == expected)
        #expect(h.scheduler.isHolding)
        #expect(h.presenter.hideHintsCount == hidden + 1)
    }

    // MARK: - Простой

    @Test func idleHoldsEverythingAndResetsOnReturn() {
        let h = SchedulerHarness()
        h.settings.breakEnabled = true
        let r = SchedulerHarness.reminder("A", every: 20)
        h.settings.reminders = [r]
        h.reset()
        h.idle = 300  // 5 минут = idleMinutes
        let hidden = h.presenter.hideHintsCount
        h.tick(at: 1000)
        #expect(h.scheduler.isIdle)
        #expect(h.presenter.hideHintsCount == hidden + 1)
        h.tick(at: 1200)
        h.tick(at: 3600)
        #expect(h.presenter.nudges.isEmpty)
        #expect(h.presenter.breaks.isEmpty)
        #expect(h.scheduler.menuBarText == nil)

        h.idle = 1
        h.tick(at: 4000)
        #expect(!h.scheduler.isIdle)
        #expect(h.presenter.nudges.isEmpty)
        #expect(h.scheduler.nextFire[r.id] == h.at(4000 + 1200))
        #expect(h.scheduler.nextBreak == h.at(4000 + 3600))
    }

    @Test func idleBelowThresholdIsNotIdle() {
        let h = SchedulerHarness()
        h.reset()
        h.idle = 299
        h.tick(at: 10)
        #expect(!h.scheduler.isIdle)
    }

    // MARK: - Сон

    @Test func suspendHoldsEverythingAndWakeResets() {
        let h = SchedulerHarness()
        let r = SchedulerHarness.reminder("A", every: 20)
        h.settings.reminders = [r]
        h.reset()
        h.scheduler.suspend()
        #expect(h.scheduler.isSuspended)
        h.tick(at: 1200)
        h.tick(at: 2000)
        #expect(h.presenter.nudges.isEmpty)
        #expect(h.scheduler.menuBarText == nil)
        h.clock.now = h.at(2000)
        h.scheduler.wake()
        #expect(!h.scheduler.isSuspended)
        #expect(h.scheduler.nextFire[r.id] == h.at(3200))
    }

    @Test func wakeWithoutSuspendDoesNotReset() {
        let h = SchedulerHarness()
        let r = SchedulerHarness.reminder("A", every: 20)
        h.settings.reminders = [r]
        h.reset()
        h.clock.now = h.at(600)
        h.scheduler.wake()
        #expect(h.scheduler.nextFire[r.id] == h.at(1200))
    }

    // MARK: - Звонок / видео

    @Test func busyIsCheckedEveryThirdTick() {
        let h = SchedulerHarness()
        h.reset()
        h.busy = .call
        h.tick(at: 1)
        h.tick(at: 2)
        #expect(h.scheduler.busyReason == nil)
        let hidden = h.presenter.hideHintsCount
        h.tick(at: 3)
        #expect(h.scheduler.busyReason == .call)
        #expect(h.scheduler.isHolding)
        #expect(h.presenter.hideHintsCount == hidden + 1)
    }

    @Test func busyHoldsEverythingThenGivesGraceSlots() {
        let h = SchedulerHarness()
        h.settings.breakEnabled = true
        let a = SchedulerHarness.reminder("A", every: 20)
        let b = SchedulerHarness.reminder("B", every: 30)
        h.settings.reminders = [a, b]
        h.reset()
        h.busy = .video
        h.tick(at: 1); h.tick(at: 2); h.tick(at: 3)
        #expect(h.scheduler.busyReason == .video)

        h.tick(at: 1200); h.tick(at: 1800); h.tick(at: 3600)  // tickCount 4, 5, 6
        #expect(h.presenter.nudges.isEmpty)
        #expect(h.presenter.breaks.isEmpty)
        #expect(h.scheduler.menuBarText == nil)

        h.busy = nil
        h.tick(at: 4000); h.tick(at: 4001)  // 7, 8: ещё «занят»
        #expect(h.scheduler.busyReason == .video)
        h.tick(at: 4002)                    // 9: конец звонка
        #expect(h.scheduler.busyReason == nil)
        #expect(h.presenter.nudges.isEmpty)
        // Просроченные: A (1200) → +30 с, B (1800) → +75 с, перерыв → после последнего слота + 30 с.
        #expect(h.scheduler.nextFire[a.id] == h.at(4002 + 30))
        #expect(h.scheduler.nextFire[b.id] == h.at(4002 + 75))
        #expect(h.scheduler.nextBreak == h.at(4002 + 120 + 30))

        h.tick(at: 4031)
        #expect(h.presenter.nudges.isEmpty)
        h.tick(at: 4032)
        #expect(h.presenter.nudges.count == 1)
        h.tick(at: 4077)
        #expect(h.presenter.nudges.count == 2)
        h.tick(at: 4152)
        #expect(h.presenter.breaks.count == 1)
    }

    @Test func busyEndKeepsFutureItems() {
        let h = SchedulerHarness()
        let a = SchedulerHarness.reminder("A", every: 60)
        h.settings.reminders = [a]
        h.reset()
        h.busy = .call
        h.tick(at: 1); h.tick(at: 2); h.tick(at: 3)
        h.busy = nil
        h.tick(at: 4); h.tick(at: 5); h.tick(at: 6)
        #expect(h.scheduler.busyReason == nil)
        #expect(h.scheduler.nextFire[a.id] == h.at(3600))
    }

    // MARK: - Наборы

    @Test func enabledSetFiresAllMembersTogether() {
        let h = SchedulerHarness()
        let a = SchedulerHarness.reminder("A", every: 20)
        let b = SchedulerHarness.reminder("B", every: 30)
        let c = SchedulerHarness.reminder("C", every: 25)
        let set = ReminderSet(name: "Combo", reminderIDs: [a.id, b.id], interval: 10, sound: "melody.calm")
        h.settings.reminders = [a, b, c]
        h.settings.sets = [set]
        h.reset()
        #expect(h.scheduler.nextFire[a.id] == nil)
        #expect(h.scheduler.nextFire[b.id] == nil)
        #expect(h.scheduler.nextFire[set.id] == h.at(600))
        #expect(h.scheduler.nextFire[c.id] == h.at(1500))

        h.tick(at: 600)
        #expect(h.presenter.nudges.count == 1)
        #expect(h.presenter.nudges[0].map(\.id) == [a.id, b.id])
        #expect(h.presenter.sounds == ["melody.calm"])
        #expect(h.stats.count(for: a.id) == 1)
        #expect(h.stats.count(for: b.id) == 1)
        #expect(h.stats.count(for: set.id) == 0)

        h.tick(at: 1200)  // набор снова; A один не срабатывает
        #expect(h.presenter.nudges.count == 2)
        #expect(h.presenter.nudges.allSatisfy { $0.count == 2 })
    }

    @Test func disabledSetDoesNotBlockMembers() {
        let h = SchedulerHarness()
        let a = SchedulerHarness.reminder("A", every: 20)
        let set = ReminderSet(name: "Off", reminderIDs: [a.id], interval: 10, enabled: false)
        h.settings.reminders = [a]
        h.settings.sets = [set]
        h.reset()
        #expect(h.scheduler.nextFire[set.id] == nil)
        #expect(h.scheduler.nextFire[a.id] == h.at(1200))
        h.tick(at: 1200)
        #expect(h.presenter.nudges.map { $0.map(\.id) } == [[a.id]])
    }

    @Test func emptySetIsNotScheduled() {
        let h = SchedulerHarness()
        let empty = ReminderSet(name: "Empty", reminderIDs: [], interval: 10)
        let ghost = ReminderSet(name: "Ghost", reminderIDs: [UUID()], interval: 10)
        h.settings.sets = [empty, ghost]
        h.reset()
        #expect(h.scheduler.nextFire.isEmpty)
        h.tick(at: 600)
        #expect(h.presenter.nudges.isEmpty)
    }

    @Test func disabledMemberIsStillShownInsideSet() {
        // Набор берёт участников по id, без проверки `enabled` у напоминания.
        let h = SchedulerHarness()
        var a = SchedulerHarness.reminder("A", every: 20)
        a.enabled = false
        let set = ReminderSet(name: "S", reminderIDs: [a.id], interval: 10)
        h.settings.reminders = [a]
        h.settings.sets = [set]
        h.reset()
        h.tick(at: 600)
        #expect(h.presenter.nudges.count == 1)
    }

    // MARK: - syncReminders

    @Test func syncKeepsDateWhenIntervalUnchanged() {
        let h = SchedulerHarness()
        var a = SchedulerHarness.reminder("A", every: 20)
        h.settings.reminders = [a]
        h.reset()
        h.clock.now = h.at(300)
        a.title = "Renamed"
        h.settings.reminders = [a]
        h.scheduler.syncReminders()
        #expect(h.scheduler.nextFire[a.id] == h.at(1200))
    }

    @Test func syncReschedulesWhenIntervalChanges() {
        let h = SchedulerHarness()
        var a = SchedulerHarness.reminder("A", every: 20)
        h.settings.reminders = [a]
        h.reset()
        h.clock.now = h.at(300)
        a.interval = 30
        h.settings.reminders = [a]
        h.scheduler.syncReminders()
        #expect(h.scheduler.nextFire[a.id] == h.at(300 + 1800))
    }

    @Test func syncDropsDeletedAndDisabledAndAddsNew() {
        let h = SchedulerHarness()
        let a = SchedulerHarness.reminder("A", every: 20)
        var b = SchedulerHarness.reminder("B", every: 30)
        let c = SchedulerHarness.reminder("C", every: 45)
        h.settings.reminders = [a, b]
        h.reset()
        h.clock.now = h.at(100)
        b.enabled = false
        h.settings.reminders = [b, c]  // A удалено, B выключено, C новое
        h.scheduler.syncReminders()
        #expect(h.scheduler.nextFire[a.id] == nil)
        #expect(h.scheduler.nextFire[b.id] == nil)
        #expect(h.scheduler.nextFire[c.id] == h.at(100 + 2700))
        #expect(h.scheduler.nextFire.count == 1)
    }

    @Test func syncReenabledReminderStartsFresh() {
        let h = SchedulerHarness()
        var a = SchedulerHarness.reminder("A", every: 20)
        h.settings.reminders = [a]
        h.reset()
        a.enabled = false
        h.settings.reminders = [a]
        h.scheduler.syncReminders()
        h.clock.now = h.at(500)
        a.enabled = true
        h.settings.reminders = [a]
        h.scheduler.syncReminders()
        #expect(h.scheduler.nextFire[a.id] == h.at(500 + 1200))
    }

    // MARK: - preview / remindNow

    @Test func previewShowsButDoesNotCount() {
        let h = SchedulerHarness()
        let a = SchedulerHarness.reminder("A", every: 20, sound: "Tink")
        h.settings.reminders = [a]
        h.reset()
        h.scheduler.preview(a)
        #expect(h.presenter.nudges.map { $0.map(\.id) } == [[a.id]])
        #expect(h.presenter.sounds == ["Tink"])
        #expect(h.stats.count(for: a.id) == 0)
        #expect(h.stats.total == 0)
        #expect(h.scheduler.nextFire[a.id] == h.at(1200))
    }

    @Test func previewSetShowsMembersWithoutCounting() {
        let h = SchedulerHarness()
        let a = SchedulerHarness.reminder("A", every: 20)
        let b = SchedulerHarness.reminder("B", every: 20)
        let set = ReminderSet(name: "S", reminderIDs: [a.id, b.id], interval: 10, enabled: false)
        h.settings.reminders = [a, b]
        h.settings.sets = [set]
        h.reset()
        h.scheduler.preview(set)
        #expect(h.presenter.nudges.map { $0.map(\.id) } == [[a.id, b.id]])
        #expect(h.stats.total == 0)
    }

    @Test func remindNowShowsCountsAndReschedules() {
        let h = SchedulerHarness()
        let a = SchedulerHarness.reminder("A", every: 20)
        h.settings.reminders = [a]
        h.reset()
        h.clock.now = h.at(700)
        h.scheduler.remindNow(a.id)
        #expect(h.presenter.nudges.count == 1)
        #expect(h.stats.count(for: a.id) == 1)
        #expect(h.scheduler.nextFire[a.id] == h.at(1900))
    }

    @Test func remindNowUnknownIDDoesNothing() {
        let h = SchedulerHarness()
        h.reset()
        h.scheduler.remindNow(UUID())
        #expect(h.presenter.nudges.isEmpty)
    }

    @Test func nothingIsShownWhileANudgeIsOnScreen() {
        let h = SchedulerHarness()
        let a = SchedulerHarness.reminder("A", every: 20)
        h.settings.reminders = [a]
        h.reset()
        h.presenter.isShowingNudge = true
        h.tick(at: 1200)
        #expect(h.presenter.nudges.isEmpty)
        #expect(h.stats.count(for: a.id) == 0)
        // Показ не теряется: напоминание ждёт, пока текущее закроется.
        #expect(h.scheduler.nextFire[a.id] == h.at(1200))
        h.presenter.isShowingNudge = false
        h.tick(at: 1201)
        #expect(h.presenter.nudges.count == 1)
        #expect(h.stats.count(for: a.id) == 1)
        #expect(h.scheduler.nextFire[a.id] == h.at(1201 + 1200))
    }

    // MARK: - menuBarText

    @Test func menuBarTextRoundsMinutesUp() {
        let h = SchedulerHarness()
        h.settings.breakEnabled = true
        h.settings.breakInterval = 20
        h.reset()
        h.tick(at: 0)
        #expect(h.scheduler.menuBarText == "20m")
        h.tick(at: 30)       // 19:30 осталось
        #expect(h.scheduler.menuBarText == "20m")
        h.tick(at: 60)       // ровно 19 минут
        #expect(h.scheduler.menuBarText == "19m")
        h.tick(at: 1110)     // 90 с
        #expect(h.scheduler.menuBarText == "2m")
        h.tick(at: 1140)     // 60 с
        #expect(h.scheduler.menuBarText == "<1m")
        h.tick(at: 1170)     // 30 с
        #expect(h.scheduler.menuBarText == "<1m")
    }

    @Test func menuBarTextShowsOnlyTheBreak() {
        let h = SchedulerHarness()
        h.settings.breakEnabled = true
        h.settings.breakInterval = 15
        let a = SchedulerHarness.reminder("A", every: 5)
        h.settings.reminders = [a]
        h.reset()
        h.tick(at: 0)
        #expect(h.scheduler.menuBarText == "15m")
    }

    @Test func menuBarTextNilWhenOnlyRemindersAreOn() {
        let h = SchedulerHarness()
        h.settings.reminders = [SchedulerHarness.reminder("A", every: 5)]
        h.reset()
        h.tick(at: 0)
        #expect(h.scheduler.menuBarText == nil)
    }

    @Test func menuBarTextNilWithNothingScheduled() {
        let h = SchedulerHarness()
        h.reset()
        h.tick(at: 0)
        #expect(h.scheduler.menuBarText == nil)
    }

    @Test func menuBarTextNilWhenPausedIdleOrBusy() {
        let h = SchedulerHarness()
        h.settings.breakEnabled = true
        h.reset()

        h.scheduler.pause(for: 60)
        #expect(h.scheduler.menuBarText == nil)
        h.scheduler.resume()
        h.tick(at: 1)
        #expect(h.scheduler.menuBarText != nil)

        h.idle = 1000
        h.tick(at: 2)
        #expect(h.scheduler.menuBarText == nil)
        h.idle = 10
        h.tick(at: 3)
        #expect(h.scheduler.menuBarText != nil)

        h.busy = .call
        h.tick(at: 4); h.tick(at: 5); h.tick(at: 6)
        #expect(h.scheduler.busyReason == .call)
        #expect(h.scheduler.menuBarText == nil)
    }

    // MARK: - Статистика перерывов и время за компьютером

    @Test func skippedAndSnoozedBreaksAreCounted() {
        let h = SchedulerHarness()
        h.settings.breakEnabled = true
        h.reset()
        h.tick(at: 3600)
        h.presenter.breaks[0].completion(.snoozed(minutes: 5))
        #expect(h.stats.postponed == 1)
        h.tick(at: 3600 + 300)
        h.presenter.breaks[1].completion(.skipped)
        #expect(h.stats.skipped == 1)
        #expect(h.stats.breaks == 0)
    }

    @Test func postponeFromPanelAddsToBreakTime() {
        let h = SchedulerHarness()
        h.settings.breakEnabled = true
        h.reset()
        h.clock.now = h.at(600)
        h.scheduler.postponeBreak(minutes: 10)
        #expect(h.scheduler.nextBreak == h.at(3600 + 600))
        #expect(h.stats.postponed == 1)
    }

    @Test func postponeWithoutBreakDoesNothing() {
        let h = SchedulerHarness()
        h.reset()
        h.scheduler.postponeBreak(minutes: 5)
        #expect(h.scheduler.nextBreak == nil)
        #expect(h.stats.postponed == 0)
    }

    @Test func activeTimeCountsOnlyWithRecentInput() {
        let h = SchedulerHarness()
        h.reset()
        h.run(seconds: 10)
        #expect(h.stats.activeSeconds == 10)
        h.idle = 120              // 2 мин без касаний — ещё за компьютером (порог 5 мин)
        h.run(seconds: 10)
        #expect(h.stats.activeSeconds == 20)
        h.idle = 400              // больше 5 мин — ушёл
        h.run(seconds: 10)
        #expect(h.stats.activeSeconds == 20)
        h.idle = 5
        h.advanceAndTick(600)   // сон или долгий разрыв не считаем
        #expect(h.stats.activeSeconds == 20)
        h.run(seconds: 3)
        #expect(h.stats.activeSeconds == 23)
    }

    @Test func activeTimeCountsDuringPause() {
        let h = SchedulerHarness()
        h.reset()
        h.scheduler.pause(for: 3600)
        h.run(seconds: 5)
        #expect(h.stats.activeSeconds == 5)
    }

    @Test func activeTimeGoesToFrontApp() {
        let h = SchedulerHarness()
        h.reset()
        h.run(seconds: 5)
        h.app = "com.test.browser"
        h.run(seconds: 3)
        h.app = nil
        h.run(seconds: 2)
        #expect(h.stats.appSeconds == ["com.test.editor": 5, "com.test.browser": 3])
        #expect(h.stats.activeSeconds == 10)
    }

    @Test func breakIsMarkedOnTimelineAndAwayEndsStretch() {
        let h = SchedulerHarness()
        h.settings.breakEnabled = true
        h.reset()
        h.run(seconds: 30)
        #expect(h.stats.longestWork == 30)
        h.idle = 400
        h.run(seconds: 5)
        h.idle = 5
        h.run(seconds: 10)
        #expect(h.stats.longestWork == 30)
        h.scheduler.startBreak()
        h.run(seconds: 1)
        h.presenter.breaks.last?.completion(.finished)
        #expect(h.stats.slots[h.stats.currentSlot] == Stats.Slot.rest)
    }

    // MARK: - Исправления по ревью

    @Test func screenWakeOnLockScreenDoesNotResume() {
        let h = SchedulerHarness()
        h.reset()
        h.scheduler.suspend(.locked)
        h.scheduler.suspend(.screens)
        h.scheduler.wake(.screens)          // экран проснулся на экране входа
        #expect(h.scheduler.isSuspended)
        h.scheduler.wake(.locked)           // разблокировали
        #expect(!h.scheduler.isSuspended)
    }

    @Test func lockEndsWorkStretch() {
        let h = SchedulerHarness()
        h.reset()
        h.run(seconds: 600)
        h.scheduler.suspend(.locked)
        h.clock.advance(3600)
        h.scheduler.wake(.locked)
        h.run(seconds: 600)
        #expect(h.stats.longestWork == 600)
    }

    @Test func skippedBreakIsNotPaintedOnTimeline() {
        let h = SchedulerHarness()
        h.settings.breakEnabled = true
        h.reset()
        h.tick(at: 3600)
        #expect(h.scheduler.onBreak)
        h.run(seconds: 5)
        h.presenter.breaks[0].completion(.skipped)
        #expect(!h.stats.slots.contains(Stats.Slot.rest))
    }

    @Test func finishedBreakIsPaintedOnTimeline() {
        let h = SchedulerHarness()
        h.settings.breakEnabled = true
        h.reset()
        h.tick(at: 3600)
        h.run(seconds: 5)
        h.presenter.breaks[0].completion(.finished)
        #expect(h.stats.slots.contains(Stats.Slot.rest))
    }

    @Test func importedZeroIntervalsAreClamped() throws {
        let h = SchedulerHarness()
        let json = #"{"format":"pinok.settings","version":1,"breakInterval":0,"idleMinutes":0,"breakDuration":-3}"#
        try h.settings.importBackup(Data(json.utf8), filesDir: FileManager.default.temporaryDirectory)
        #expect(h.settings.breakInterval >= 10)
        #expect(h.settings.idleMinutes >= 1)
        #expect(h.settings.breakDuration >= 1)
    }
}
