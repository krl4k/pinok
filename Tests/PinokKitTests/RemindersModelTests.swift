import Foundation
import Testing
@testable import PinokKit

@MainActor
@Suite("Reminders model", .serialized)
struct RemindersModelTests {
    init() { L10n.isRussian = false }

    private func reminder(_ title: String, enabled: Bool = true, interval: Int = 20) -> Reminder {
        var r = Reminder(title: title, caption: "", animation: .bell, interval: interval, sound: "Ping")
        r.enabled = enabled
        return r
    }

    // MARK: ReminderLibrary

    @Test func templateIDsAreUnique() {
        let ids = ReminderLibrary.all.map(\.id)
        #expect(Set(ids).count == ids.count)
    }

    @Test func templateIntervalsAreSelectable() {
        for tpl in ReminderLibrary.all {
            #expect(ReminderLibrary.intervals.contains(tpl.interval), "\(tpl.id)")
        }
    }

    @Test func templatesHaveTexts() {
        for tpl in ReminderLibrary.all {
            #expect(!tpl.title.isEmpty)
            #expect(!tpl.caption.isEmpty)
            #expect(!tpl.detail.isEmpty)
            #expect(!tpl.sound.isEmpty)
        }
    }

    @Test func templateLookup() {
        for tpl in ReminderLibrary.all {
            #expect(ReminderLibrary.template(tpl.id)?.id == tpl.id)
        }
        #expect(ReminderLibrary.template("nope") == nil)
        #expect(ReminderLibrary.template("") == nil)
    }

    @Test func defaultsArePostureAndTongue() {
        let d = ReminderLibrary.defaults
        #expect(d.map(\.template) == ["posture", "tongue"])
        #expect(d[0].id != d[1].id)
        #expect(ReminderLibrary.defaults.map(\.id) != d.map(\.id))
    }

    @Test func makeCopiesFields() {
        for tpl in ReminderLibrary.all {
            let r = tpl.make()
            #expect(r.template == tpl.id)
            #expect(r.title == tpl.title)
            #expect(r.caption == tpl.caption)
            #expect(r.animation == tpl.animation)
            #expect(r.interval == tpl.interval)
            #expect(r.sound == tpl.sound)
            #expect(r.showCaption == tpl.showCaption)
            #expect(r.enabled)
            #expect(!r.isCustom)
        }
    }

    @Test func makeGivesNewIDEachTime() {
        let tpl = ReminderLibrary.template("posture")!
        let ids = (0..<5).map { _ in tpl.make().id }
        #expect(Set(ids).count == 5)
    }

    @Test func intervalsSortedAndIncludeHours() {
        let iv = ReminderLibrary.intervals
        #expect(iv == iv.sorted())
        #expect(Set(iv).count == iv.count)
        for m in [60, 120, 180, 360] { #expect(iv.contains(m)) }
    }

    @Test func labels() {
        L10n.isRussian = false
        #expect(ReminderLibrary.label(10) == "10 min")
        #expect(ReminderLibrary.label(45) == "45 min")
        #expect(ReminderLibrary.label(59) == "59 min")
        #expect(ReminderLibrary.label(60) == "1 h")
        #expect(ReminderLibrary.label(120) == "2 h")
        #expect(ReminderLibrary.label(360) == "6 h")
    }

    @Test func everyIntervalHasALabel() {
        L10n.isRussian = false
        for m in ReminderLibrary.intervals {
            let label = ReminderLibrary.label(m)
            #expect(label.hasSuffix(m < 60 ? " min" : " h"))
        }
    }

    // MARK: Codable

    @Test func reminderRoundTrip() throws {
        var r = ReminderLibrary.template("water")!.make()
        r.enabled = false
        r.showCaption = false
        r.sound = "Frog"
        let custom = Reminder(title: "Мой", caption: "Сделай", animation: .breathe, interval: 15, sound: "")
        let data = try JSONEncoder().encode([r, custom])
        let back = try JSONDecoder().decode([Reminder].self, from: data)
        #expect(back == [r, custom])
        #expect(back[1].template == nil)
    }

    @Test func reminderSetRoundTrip() throws {
        let s = ReminderSet(name: "Morning", reminderIDs: [UUID(), UUID()], interval: 120,
                            enabled: false, sound: "Glass")
        let back = try JSONDecoder().decode(ReminderSet.self, from: JSONEncoder().encode(s))
        #expect(back == s)
    }

    @Test func reminderSetDefaults() {
        let s = ReminderSet(name: "X")
        #expect(s.reminderIDs.isEmpty)
        #expect(s.interval == 30)
        #expect(s.enabled)
        #expect(s.sound == "melody.jingle")
    }

    @Test func isCustom() {
        #expect(reminder("Mine").isCustom)
        #expect(!ReminderLibrary.template("blink")!.make().isCustom)
    }

    @Test func customDisplayTitleUnchanged() {
        let r = reminder("My very own reminder")
        #expect(r.displayTitle == "My very own reminder")
        #expect(reminder("Мой").displayTitle == "Мой")
    }

    @Test func detailForCustomAndTemplate() {
        L10n.isRussian = false
        #expect(reminder("Mine").detail == "Your own reminder.")
        let tpl = ReminderLibrary.template("posture")!
        #expect(tpl.make().detail == tpl.detail)
    }

    // MARK: ScheduledItem.build

    @Test func disabledRemindersExcluded() {
        let a = reminder("A"), b = reminder("B", enabled: false)
        let items = ScheduledItem.build(reminders: [a, b], sets: [])
        #expect(items.map(\.id) == [a.id])
        #expect(items[0].isSet == false)
        #expect(items[0].members == [a])
        #expect(items[0].title == "A")
        #expect(items[0].interval == a.interval)
        #expect(items[0].sound == a.sound)
    }

    @Test func membersOfEnabledSetNotScheduledAlone() {
        let a = reminder("A"), b = reminder("B"), c = reminder("C")
        let set = ReminderSet(name: "S", reminderIDs: [a.id, b.id], interval: 45, sound: "Glass")
        let items = ScheduledItem.build(reminders: [a, b, c], sets: [set])
        #expect(items.map(\.id) == [set.id, c.id])
        #expect(items[0].isSet)
        #expect(items[0].title == "S")
        #expect(items[0].interval == 45)
        #expect(items[0].sound == "Glass")
        #expect(items[0].members == [a, b])
    }

    @Test func disabledSetDoesNotHideMembers() {
        let a = reminder("A"), b = reminder("B")
        let set = ReminderSet(name: "S", reminderIDs: [a.id, b.id], enabled: false)
        let items = ScheduledItem.build(reminders: [a, b], sets: [set])
        #expect(items.map(\.id) == [a.id, b.id])
        #expect(items.allSatisfy { !$0.isSet })
    }

    @Test func setWithoutExistingMembersSkipped() {
        let a = reminder("A")
        let empty = ReminderSet(name: "Empty")
        let ghosts = ReminderSet(name: "Ghosts", reminderIDs: [UUID(), UUID()])
        let items = ScheduledItem.build(reminders: [a], sets: [empty, ghosts])
        #expect(items.map(\.id) == [a.id])
    }

    @Test func setMembersKeepReminderIDsOrder() {
        let a = reminder("A"), b = reminder("B"), c = reminder("C")
        let set = ReminderSet(name: "S", reminderIDs: [c.id, a.id, b.id])
        let items = ScheduledItem.build(reminders: [a, b, c], sets: [set])
        #expect(items.count == 1)
        #expect(items[0].members.map(\.title) == ["C", "A", "B"])
    }

    @Test func deletedIDsInSetIgnored() {
        let a = reminder("A"), b = reminder("B")
        let set = ReminderSet(name: "S", reminderIDs: [UUID(), a.id, UUID()])
        let items = ScheduledItem.build(reminders: [a, b], sets: [set])
        #expect(items.map(\.id) == [set.id, b.id])
        #expect(items[0].members == [a])
    }

    /// Documented behaviour: a set does not check `enabled` of its members.
    /// A disabled reminder inside an enabled set is still shown with the set.
    @Test func disabledReminderInsideEnabledSetStillShown() {
        let a = reminder("A"), off = reminder("Off", enabled: false)
        let set = ReminderSet(name: "S", reminderIDs: [a.id, off.id])
        let items = ScheduledItem.build(reminders: [a, off], sets: [set])
        #expect(items.count == 1)
        #expect(items[0].members.map(\.title) == ["A", "Off"])
    }

    @Test func setOfOnlyDisabledRemindersStillScheduled() {
        let off = reminder("Off", enabled: false)
        let set = ReminderSet(name: "S", reminderIDs: [off.id])
        let items = ScheduledItem.build(reminders: [off], sets: [set])
        #expect(items.map(\.id) == [set.id])
    }

    @Test func reminderInTwoEnabledSetsAppearsInBoth() {
        let a = reminder("A")
        let s1 = ReminderSet(name: "S1", reminderIDs: [a.id])
        let s2 = ReminderSet(name: "S2", reminderIDs: [a.id])
        let items = ScheduledItem.build(reminders: [a], sets: [s1, s2])
        #expect(items.map(\.id) == [s1.id, s2.id])
    }

    @Test func memberOfDisabledAndEnabledSetHiddenOnce() {
        let a = reminder("A")
        let off = ReminderSet(name: "Off", reminderIDs: [a.id], enabled: false)
        let on = ReminderSet(name: "On", reminderIDs: [a.id])
        let items = ScheduledItem.build(reminders: [a], sets: [off, on])
        #expect(items.map(\.id) == [on.id])
    }

    @Test func setsComeBeforeSingleReminders() {
        let a = reminder("A"), b = reminder("B")
        let set = ReminderSet(name: "S", reminderIDs: [b.id])
        let items = ScheduledItem.build(reminders: [a, b], sets: [set])
        #expect(items.map(\.isSet) == [true, false])
    }

    @Test func emptyInputs() {
        #expect(ScheduledItem.build(reminders: [], sets: []).isEmpty)
    }

    @Test func templateTitleIsTranslated() {
        let r = ReminderLibrary.template("posture")!.make()
        L10n.isRussian = false
        #expect(ScheduledItem.build(reminders: [r], sets: [])[0].title == "Posture")
    }

    // MARK: ReminderAnimation

    @Test(arguments: ReminderAnimation.allCases)
    func animationHasPresentation(_ a: ReminderAnimation) {
        #expect(!a.title.isEmpty)
        #expect(!a.symbol.isEmpty)
        #expect(a.colors.count == 2)
        #expect(a.id == a.rawValue)
    }

    @Test func everyTemplateAnimationIsKnown() {
        for tpl in ReminderLibrary.all {
            #expect(ReminderAnimation.allCases.contains(tpl.animation))
        }
    }
}


@Suite("IntervalLabelTests", .serialized)
@MainActor
struct IntervalLabelTests {
    @Test(arguments: [(10, "10 min"), (45, "45 min"), (60, "1 h"), (90, "1 h 30 min"), (120, "2 h"), (150, "2 h 30 min"), (360, "6 h")])
    func labels(minutes: Int, expected: String) {
        L10n.isRussian = false
        #expect(ReminderLibrary.label(minutes) == expected)
    }

    @Test func russianLabelForHalfHours() {
        L10n.isRussian = true
        defer { L10n.isRussian = false }
        #expect(ReminderLibrary.label(90) == "1 ч 30 мин")
    }
}
