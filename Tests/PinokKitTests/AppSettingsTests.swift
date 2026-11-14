import Foundation
import Testing
@testable import PinokKit

@MainActor
@Suite("AppSettings", .serialized)
struct AppSettingsTests {
    /// Settings on the given defaults. `L10n.apply` is global; keep English for tests.
    private func make(_ d: UserDefaults) -> AppSettings {
        let s = AppSettings(defaults: d)
        L10n.isRussian = false
        return s
    }

    private func encode(_ reminders: [Reminder]) -> Data {
        try! JSONEncoder().encode(reminders)
    }

    // MARK: Defaults

    @Test func cleanInstallDefaults() {
        let s = make(TestSupport.freshDefaults())
        #expect(s.language == .system)
        #expect(s.showCountdown == true)
        #expect(s.volume == 0.6)
        #expect(s.idleMinutes == 5)
        #expect(s.smartTiming == true)
        #expect(s.pauseOnCalls == true)
        #expect(s.pauseOnVideo == true)
        #expect(s.nudgeDim == 0.25)
        #expect(s.nudgeBlur == 0.6)
        #expect(s.arrowColor == .white)
        #expect(s.arrowWidth == 7.0)
        #expect(s.arrowStyle == .circle)
        #expect(s.nudgeAllScreens == true)
        #expect(s.breakEnabled == true)
        #expect(s.breakInterval == 60)
        #expect(s.breakDuration == 5)
        #expect(s.breakWarning == 60)
        #expect(s.breakStartSound == "melody.jingle")
        #expect(s.breakEndSound == "melody.done")
        #expect(s.floatingCountdown == true)
        #expect(s.breakBackground == .blur)
        #expect(s.breakGradient == .sunset)
        #expect(s.breakImagePath == "")
        #expect(s.breakMessages == BreakTips.defaults)
        #expect(s.sets.isEmpty)
    }

    @Test func cleanInstallHasPostureAndTongue() {
        let s = make(TestSupport.freshDefaults())
        #expect(s.reminders.map(\.template) == ["posture", "tongue"])
        let posture = ReminderLibrary.template("posture")!
        let tongue = ReminderLibrary.template("tongue")!
        #expect(s.reminders[0].sound == posture.sound)
        #expect(s.reminders[0].interval == posture.interval)
        #expect(s.reminders[0].showCaption == true)
        #expect(s.reminders[1].sound == tongue.sound)
        #expect(s.reminders[1].interval == tongue.interval)
        #expect(s.reminders.allSatisfy { $0.enabled })
    }

    @Test func cleanInstallReminderIDsAreStableAcrossLaunches() {
        // Default reminders are built in init but never written (didSet does not run in init),
        // so every launch gets new UUIDs until the user changes something.
        let d = TestSupport.freshDefaults()
        let first = make(d).reminders.map(\.id)
        let second = make(d).reminders.map(\.id)
        #expect(first == second)
    }

    // MARK: Persistence

    @Test func scalarPropertiesPersist() {
        let d = TestSupport.freshDefaults()
        let s = make(d)
        s.showCountdown = false
        s.volume = 0.15
        s.idleMinutes = 12
        s.smartTiming = false
        s.pauseOnCalls = false
        s.pauseOnVideo = false
        s.nudgeDim = 0.7
        s.nudgeBlur = 0.1
        s.arrowWidth = 11
        s.nudgeAllScreens = false
        s.breakEnabled = false
        s.breakInterval = 90
        s.breakDuration = 10
        s.breakWarning = 0
        s.breakStartSound = "Ping"
        s.breakEndSound = ""
        s.floatingCountdown = false
        s.breakImagePath = "/tmp/pic.png"

        let r = make(d)
        #expect(r.showCountdown == false)
        #expect(r.volume == 0.15)
        #expect(r.idleMinutes == 12)
        #expect(r.smartTiming == false)
        #expect(r.pauseOnCalls == false)
        #expect(r.pauseOnVideo == false)
        #expect(r.nudgeDim == 0.7)
        #expect(r.nudgeBlur == 0.1)
        #expect(r.arrowWidth == 11)
        #expect(r.nudgeAllScreens == false)
        #expect(r.breakEnabled == false)
        #expect(r.breakInterval == 90)
        #expect(r.breakDuration == 10)
        #expect(r.breakWarning == 0)
        #expect(r.breakStartSound == "Ping")
        #expect(r.breakEndSound == "")
        #expect(r.floatingCountdown == false)
        #expect(r.breakImagePath == "/tmp/pic.png")
    }

    @Test func enumPropertiesPersist() {
        let d = TestSupport.freshDefaults()
        let s = make(d)
        s.language = .en
        s.arrowColor = .orange
        s.arrowStyle = .plain
        s.breakBackground = .gradient
        s.breakGradient = .midnight

        let r = make(d)
        #expect(r.language == .en)
        #expect(r.arrowColor == .orange)
        #expect(r.arrowStyle == .plain)
        #expect(r.breakBackground == .gradient)
        #expect(r.breakGradient == .midnight)
    }

    @Test(arguments: AppLanguage.allCases)
    func languagePersists(_ lang: AppLanguage) {
        let d = TestSupport.freshDefaults()
        make(d).language = lang
        #expect(make(d).language == lang)
    }

    @Test func languageAppliesL10n() {
        let s = make(TestSupport.freshDefaults())
        s.language = .ru
        #expect(L10n.isRussian == true)
        s.language = .en
        #expect(L10n.isRussian == false)
    }

    @Test func unknownEnumRawValuesFallBack() {
        let d = TestSupport.freshDefaults()
        d.set("klingon", forKey: "language")
        d.set("purple", forKey: "arrowColor")
        d.set("zigzag", forKey: "arrowStyle")
        d.set("video", forKey: "breakBackground")
        d.set("rainbow", forKey: "breakGradient")
        let s = make(d)
        #expect(s.language == .system)
        #expect(s.arrowColor == .white)
        #expect(s.arrowStyle == .circle)
        #expect(s.breakBackground == .blur)
        #expect(s.breakGradient == .sunset)
    }

    @Test func breakMessagesPersist() {
        let d = TestSupport.freshDefaults()
        make(d).breakMessages = ["One", "Two"]
        #expect(make(d).breakMessages == ["One", "Two"])
    }

    @Test func emptyBreakMessagesPersist() {
        let d = TestSupport.freshDefaults()
        make(d).breakMessages = []
        #expect(make(d).breakMessages == [])
    }

    @Test func remindersPersist() {
        let d = TestSupport.freshDefaults()
        let s = make(d)
        var custom = Reminder(title: "Mine", caption: "Do it", animation: .bell, interval: 45, sound: "Frog")
        custom.enabled = false
        custom.showCaption = false
        s.reminders.append(custom)
        s.reminders[0].interval = 120

        let r = make(d)
        #expect(r.reminders == s.reminders)
        #expect(r.reminders.count == 3)
        #expect(r.reminders[2] == custom)
    }

    @Test func emptyRemindersPersist() {
        let d = TestSupport.freshDefaults()
        make(d).reminders = []
        #expect(make(d).reminders.isEmpty)
    }

    @Test func setsPersist() {
        let d = TestSupport.freshDefaults()
        let s = make(d)
        let set = ReminderSet(name: "Eyes", reminderIDs: s.reminders.map(\.id), interval: 45,
                              enabled: false, sound: "melody.calm")
        s.sets = [set]
        #expect(make(d).sets == [set])
    }

    @Test func corruptSetsFallBackToEmpty() {
        let d = TestSupport.freshDefaults()
        d.set(Data("not json".utf8), forKey: "sets")
        #expect(make(d).sets.isEmpty)
    }

    // MARK: onTimingChange

    @Test func timingChangeForReminders() {
        let s = make(TestSupport.freshDefaults())
        var kinds: [TimingKind] = []
        s.onTimingChange = { kinds.append($0) }
        s.reminders[0].interval = 45
        s.sets = [ReminderSet(name: "X")]
        #expect(kinds == [.reminders, .reminders])
    }

    @Test func timingChangeForBreaks() {
        let s = make(TestSupport.freshDefaults())
        var kinds: [TimingKind] = []
        s.onTimingChange = { kinds.append($0) }
        s.breakEnabled = false
        s.breakInterval = 30
        #expect(kinds == [.breaks, .breaks])
    }

    @Test func noTimingChangeForUnrelatedProperties() {
        let s = make(TestSupport.freshDefaults())
        var kinds: [TimingKind] = []
        s.onTimingChange = { kinds.append($0) }
        s.breakDuration = 7
        s.breakWarning = 30
        s.volume = 0.2
        s.idleMinutes = 3
        s.showCountdown = false
        s.smartTiming = false
        s.pauseOnCalls = false
        s.pauseOnVideo = false
        s.nudgeDim = 0.4
        s.nudgeBlur = 0.4
        s.arrowColor = .blue
        s.arrowWidth = 5
        s.arrowStyle = .plain
        s.nudgeAllScreens = false
        s.breakStartSound = "Ping"
        s.breakEndSound = "Ping"
        s.floatingCountdown = false
        s.breakBackground = .image
        s.breakGradient = .ocean
        s.breakImagePath = "x"
        s.breakMessages = ["a"]
        s.language = .en
        #expect(kinds.isEmpty)
    }

    @Test func initDoesNotCallTimingChange() {
        // The callback is set after init, so nothing fires on load; also check the
        // first assignment after init does fire exactly once.
        let s = make(TestSupport.freshDefaults())
        var count = 0
        s.onTimingChange = { _ in count += 1 }
        #expect(count == 0)
        s.breakEnabled = s.breakEnabled
        #expect(count == 1)
    }

    // MARK: Migration from the old reminders format

    @Test func migratesOldPostureAndTongueKeys() {
        let d = TestSupport.freshDefaults()
        d.set(false, forKey: "nudgeEnabled")
        d.set(45, forKey: "nudgeInterval")
        d.set(true, forKey: "nudgeCaption")
        d.set("Pop", forKey: "nudgeSound")
        d.set(true, forKey: "tongueEnabled")
        d.set(15, forKey: "tongueInterval")
        d.set(false, forKey: "tongueCaption")
        d.set("Tink", forKey: "tongueSound")

        let list = AppSettings.loadReminders(d)
        #expect(list.count == 2)
        let posture = list[0], tongue = list[1]
        #expect(posture.template == "posture")
        #expect(posture.enabled == false)
        #expect(posture.interval == 45)
        #expect(posture.showCaption == true)
        #expect(posture.sound == ReminderLibrary.template("posture")!.sound)
        #expect(tongue.template == "tongue")
        #expect(tongue.enabled == true)
        #expect(tongue.interval == 15)
        #expect(tongue.showCaption == false)
        #expect(tongue.sound == ReminderLibrary.template("tongue")!.sound)
    }

    @Test func migrationKeepsCustomOldSounds() {
        let d = TestSupport.freshDefaults()
        d.set(20, forKey: "nudgeInterval")
        d.set("Frog", forKey: "nudgeSound")
        d.set(30, forKey: "tongueInterval")
        d.set("Basso", forKey: "tongueSound")
        let list = AppSettings.loadReminders(d)
        #expect(list[0].sound == "Frog")
        #expect(list[1].sound == "Basso")
    }

    @Test func migrationOnlyPostureKeys() {
        let d = TestSupport.freshDefaults()
        d.set(false, forKey: "nudgeEnabled")
        d.set(60, forKey: "nudgeInterval")
        let list = AppSettings.loadReminders(d)
        #expect(list[0].enabled == false)
        #expect(list[0].interval == 60)
        // Tongue untouched — template defaults.
        let tongue = ReminderLibrary.template("tongue")!
        #expect(list[1].enabled == true)
        #expect(list[1].interval == tongue.interval)
        #expect(list[1].sound == tongue.sound)
    }

    @Test func migrationViaAppSettingsInit() {
        let d = TestSupport.freshDefaults()
        d.set(true, forKey: "nudgeEnabled")
        d.set(10, forKey: "nudgeInterval")
        d.set(false, forKey: "tongueEnabled")
        d.set(360, forKey: "tongueInterval")
        let s = make(d)
        #expect(s.reminders.map(\.interval) == [10, 360])
        #expect(s.reminders.map(\.enabled) == [true, false])
    }

    // MARK: Melody migration

    @Test func melodyMigrationReplacesOldDefaultSounds() {
        let d = TestSupport.freshDefaults()
        var posture = ReminderLibrary.template("posture")!.make()
        posture.sound = "Pop"
        var tongue = ReminderLibrary.template("tongue")!.make()
        tongue.sound = "Tink"
        d.set(encode([posture, tongue]), forKey: "reminders")

        let list = AppSettings.loadReminders(d)
        #expect(list[0].sound == ReminderLibrary.template("posture")!.sound)
        #expect(list[1].sound == ReminderLibrary.template("tongue")!.sound)
        #expect(list.map(\.id) == [posture.id, tongue.id])
        #expect(d.bool(forKey: "melodiesApplied"))
        // The migrated list is written back.
        let stored = try! JSONDecoder().decode([Reminder].self, from: d.data(forKey: "reminders")!)
        #expect(stored == list)
    }

    @Test func melodyMigrationLeavesOtherSoundsAlone() {
        let d = TestSupport.freshDefaults()
        var posture = ReminderLibrary.template("posture")!.make()
        posture.sound = "Frog"                      // custom sound
        var tongueWithPop = ReminderLibrary.template("tongue")!.make()
        tongueWithPop.sound = "Pop"                 // Pop is old default only for posture
        let custom = Reminder(title: "Mine", caption: "", animation: .bell, interval: 20, sound: "Pop")
        var water = ReminderLibrary.template("water")!.make()
        water.sound = "Tink"                        // not an old default for water
        d.set(encode([posture, tongueWithPop, custom, water]), forKey: "reminders")

        let list = AppSettings.loadReminders(d)
        #expect(list.map(\.sound) == ["Frog", "Pop", "Pop", "Tink"])
        #expect(d.bool(forKey: "melodiesApplied"))
    }

    @Test func melodyMigrationRunsOnlyOnce() {
        let d = TestSupport.freshDefaults()
        let posture = ReminderLibrary.template("posture")!.make()
        d.set(encode([posture]), forKey: "reminders")
        _ = AppSettings.loadReminders(d)            // sets the flag
        #expect(d.bool(forKey: "melodiesApplied"))

        // User now deliberately picks "Pop" again.
        var chosen = posture
        chosen.sound = "Pop"
        d.set(encode([chosen]), forKey: "reminders")
        #expect(AppSettings.loadReminders(d)[0].sound == "Pop")
    }

    @Test func melodyMigrationThroughAppSettingsKeepsUserChoiceLater() {
        let d = TestSupport.freshDefaults()
        var posture = ReminderLibrary.template("posture")!.make()
        posture.sound = "Pop"
        d.set(encode([posture]), forKey: "reminders")
        let s = make(d)
        #expect(s.reminders[0].sound == ReminderLibrary.template("posture")!.sound)
        s.reminders[0].sound = "Pop"
        #expect(make(d).reminders[0].sound == "Pop")
    }

    @Test func userPickedPopOnNewInstallIsKept() {
        // New install: defaults are never saved and `melodiesApplied` is only set when stored
        // reminders exist. The user then picks "Pop" for posture (saved), and on the next
        // launch the one-time melody migration runs for the first time and replaces it.
        let d = TestSupport.freshDefaults()
        let s = make(d)
        s.reminders[0].sound = "Pop"
        let r = make(d)
        #expect(r.reminders[0].sound == "Pop")
    }

    // MARK: Corrupt data

    @Test func corruptRemindersFallBackToDefaults() {
        let d = TestSupport.freshDefaults()
        d.set(Data("{broken".utf8), forKey: "reminders")
        let list = AppSettings.loadReminders(d)
        #expect(list.map(\.template) == ["posture", "tongue"])
        #expect(d.bool(forKey: "melodiesApplied") == false)
    }

    @Test func corruptRemindersUseOldKeysIfPresent() {
        let d = TestSupport.freshDefaults()
        d.set(Data([0xFF, 0x00]), forKey: "reminders")
        d.set(120, forKey: "nudgeInterval")
        let s = make(d)
        #expect(s.reminders.count == 2)
        #expect(s.reminders[0].interval == 120)
    }

    @Test func remindersOfWrongTypeFallBack() {
        let d = TestSupport.freshDefaults()
        d.set("a string", forKey: "reminders")
        #expect(make(d).reminders.map(\.template) == ["posture", "tongue"])
    }

    // MARK: migrateFromUpright

    @Test func uprightMigrationIgnoresNonStandardDefaults() {
        let d = TestSupport.freshDefaults()
        AppSettings.migrateFromUpright(into: d)
        #expect(d.object(forKey: "migratedFromUpright") == nil)
        #expect(d.dictionaryRepresentation().keys.contains("migratedFromUpright") == false)
        _ = make(d)
        #expect(d.object(forKey: "migratedFromUpright") == nil)
    }
}
