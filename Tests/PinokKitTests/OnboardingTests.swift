import Foundation
import Testing
@testable import PinokKit

@MainActor
@Suite("OnboardingTests", .serialized)
struct OnboardingTests {
    private func settings() -> AppSettings { AppSettings(defaults: TestSupport.freshDefaults()) }

    @Test func freshInstallNeedsOnboarding() {
        #expect(settings().onboardingDone == false)
    }

    @Test func startsWithCurrentReminders() {
        let s = settings()
        let m = OnboardingModel(settings: s)
        #expect(m.selected == ["posture", "tongue"])
        #expect(m.step == 0)
        #expect(m.breaksOn == s.breakEnabled)
    }

    @Test func applyAddsAndRemovesTemplatesInLibraryOrder() {
        let s = settings()
        let postureID = s.reminders.first { $0.template == "posture" }!.id
        let m = OnboardingModel(settings: s)
        m.toggle("tongue")   // убрать
        m.toggle("water")    // добавить
        m.toggle("blink")    // добавить
        m.apply(to: s)
        #expect(s.reminders.compactMap(\.template) == ["posture", "blink", "water"])
        // Существующее напоминание сохраняет id (статистика и наборы не теряются).
        #expect(s.reminders.first?.id == postureID)
        #expect(s.onboardingDone)
    }

    @Test func applyKeepsCustomReminders() {
        let s = settings()
        let custom = Reminder(title: "Mine", caption: "Do it", animation: .bell, interval: 30, sound: "Pop")
        s.reminders.append(custom)
        let m = OnboardingModel(settings: s)
        m.apply(to: s)
        #expect(s.reminders.contains { $0.id == custom.id })
        #expect(s.reminders.last?.id == custom.id)
    }

    @Test func applyRemovesDeletedRemindersFromSets() {
        let s = settings()
        let tongue = s.reminders.first { $0.template == "tongue" }!
        let posture = s.reminders.first { $0.template == "posture" }!
        s.sets = [ReminderSet(name: "S", reminderIDs: [posture.id, tongue.id])]
        let m = OnboardingModel(settings: s)
        m.toggle("tongue")
        m.apply(to: s)
        #expect(s.sets[0].reminderIDs == [posture.id])
    }

    @Test func applyWritesBreakChoices() {
        let s = settings()
        let m = OnboardingModel(settings: s)
        m.breaksOn = false
        m.breakInterval = 90
        m.exercises = [.walk, .stretch]
        m.apply(to: s)
        #expect(s.breakEnabled == false)
        #expect(s.breakInterval == 90)
        // Порядок как в списке упражнений, а не как кликали.
        #expect(s.breakExercises == [.stretch, .walk])
    }

    @Test func applyTurnsSelectedTemplatesOn() {
        let s = settings()
        s.reminders[0].enabled = false
        let m = OnboardingModel(settings: s)
        m.selected.insert(s.reminders[0].template!)
        m.apply(to: s)
        #expect(s.reminders.allSatisfy { $0.enabled })
    }

    @Test func unusualBreakIntervalFallsBackToSixty() {
        let s = settings()
        s.breakInterval = 120
        #expect(OnboardingModel(settings: s).breakInterval == 60)
    }
}

@MainActor
@Suite("JingleMigrationTests", .serialized)
struct JingleMigrationTests {
    @Test func oldDefaultSoundsBecomeJingleOnce() throws {
        let d = TestSupport.freshDefaults()
        var posture = ReminderLibrary.template("posture")!.make()
        posture.sound = "melody.rise"
        var tongue = ReminderLibrary.template("tongue")!.make()
        tongue.sound = "Pop"     // выбор пользователя — не трогаем
        d.set(try JSONEncoder().encode([posture, tongue]), forKey: "reminders")
        d.set(true, forKey: "melodiesApplied")
        d.set("Glass", forKey: "breakStartSound")
        d.set("Hero", forKey: "breakEndSound")

        let s = AppSettings(defaults: d)
        #expect(s.reminders[0].sound == "melody.jingle")
        #expect(s.reminders[1].sound == "Pop")
        #expect(s.breakStartSound == "melody.jingle")
        #expect(s.breakEndSound == "melody.done")

        // Второй раз ничего не меняет.
        s.reminders[0].sound = "melody.rise"
        s.breakStartSound = "Glass"
        let again = AppSettings(defaults: d)
        #expect(again.reminders[0].sound == "melody.rise")
        #expect(again.breakStartSound == "Glass")
    }
}

@MainActor
@Suite("SoundsSwitchTests", .serialized)
struct SoundsSwitchTests {
    @Test func soundsAreOnByDefaultAndPersist() {
        let d = TestSupport.freshDefaults()
        let s = AppSettings(defaults: d)
        #expect(s.soundsEnabled)
        s.soundsEnabled = false
        #expect(AppSettings(defaults: d).soundsEnabled == false)
    }
}

@MainActor
@Suite("CaptionsOnTests", .serialized)
struct CaptionsOnTests {
    @Test func everyTemplateShowsTextByDefault() {
        #expect(ReminderLibrary.all.allSatisfy { $0.make().showCaption })
    }

    @Test func oldRemindersGetTextOnOnce() throws {
        let d = TestSupport.freshDefaults()
        var posture = ReminderLibrary.template("posture")!.make()
        posture.showCaption = false
        d.set(try JSONEncoder().encode([posture]), forKey: "reminders")
        d.set(true, forKey: "melodiesApplied")
        d.set(true, forKey: "jingleApplied")

        let s = AppSettings(defaults: d)
        #expect(s.reminders[0].showCaption == true)

        // Выбор пользователя после этого сохраняется.
        s.reminders[0].showCaption = false
        #expect(AppSettings(defaults: d).reminders[0].showCaption == false)
    }
}
