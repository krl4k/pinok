import Foundation
import Testing
@testable import PinokKit

@MainActor
@Suite("Settings file", .serialized)
struct BackupTests {
    private func tempDir() -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("pinok-backup-\(UUID().uuidString)")
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    @Test func roundTripCopiesSettings() throws {
        let a = AppSettings(defaults: TestSupport.freshDefaults())
        a.idleMinutes = 10
        a.breakInterval = 45
        a.breakDuration = 3
        a.arrowColor = .mint
        a.breakExercises = [.squats]
        var r = Reminder(title: "Mine", caption: "Do it", animation: .bell, interval: 15, sound: "Pop")
        r.enabled = false
        a.reminders = [r]
        a.sets = [ReminderSet(name: "Desk", reminderIDs: [r.id], interval: 20)]

        let b = AppSettings(defaults: TestSupport.freshDefaults())
        try b.importBackup(a.exportBackup(), filesDir: tempDir())

        #expect(b.idleMinutes == 10)
        #expect(b.breakInterval == 45)
        #expect(b.breakDuration == 3)
        #expect(b.arrowColor == .mint)
        #expect(b.breakExercises == [.squats])
        #expect(b.reminders == [r])
        #expect(b.sets.map(\.name) == ["Desk"])
        #expect(b.sets.first?.reminderIDs == [r.id])
    }

    @Test func ownFilesTravelInsideTheFile() throws {
        let src = tempDir()
        let image = src.appendingPathComponent("icon.png")
        let sound = src.appendingPathComponent("ding.mp3")
        try Data([1, 2, 3]).write(to: image)
        try Data([4, 5, 6, 7]).write(to: sound)

        let a = AppSettings(defaults: TestSupport.freshDefaults())
        var r = Reminder(title: "Mine", caption: "Do it", animation: .bell, interval: 15,
                         sound: Sounds.filePrefix + sound.path)
        r.imagePath = image.path
        a.reminders = [r]
        a.breakImagePath = image.path

        let data = a.exportBackup()
        // В файле нет путей этого Mac — только встроенные файлы.
        let text = String(decoding: data, as: UTF8.self)
        #expect(!text.contains(src.path))

        let dest = tempDir()
        let b = AppSettings(defaults: TestSupport.freshDefaults())
        try b.importBackup(data, filesDir: dest)

        let got = try #require(b.reminders.first)
        let imagePath = try #require(got.imagePath)
        #expect(imagePath.hasPrefix(dest.path))
        #expect(FileManager.default.contents(atPath: imagePath) == Data([1, 2, 3]))
        #expect(got.sound.hasPrefix(Sounds.filePrefix + dest.path))
        #expect(FileManager.default.contents(atPath: String(got.sound.dropFirst(Sounds.filePrefix.count))) == Data([4, 5, 6, 7]))
        // Одна и та же картинка у напоминания и перерыва — один файл.
        #expect(b.breakImagePath == imagePath)
    }

    @Test func missingFieldsKeepCurrentValues() throws {
        let b = AppSettings(defaults: TestSupport.freshDefaults())
        b.breakInterval = 90
        let json = #"{"format":"pinok.settings","version":1,"idleMinutes":15}"#
        try b.importBackup(Data(json.utf8), filesDir: tempDir())
        #expect(b.idleMinutes == 15)
        #expect(b.breakInterval == 90)
    }

    @Test func comboDropsUnknownReminders() throws {
        let a = AppSettings(defaults: TestSupport.freshDefaults())
        let r = Reminder(title: "A", caption: "A", animation: .bell, interval: 15, sound: "Pop")
        a.reminders = [r]
        a.sets = [ReminderSet(name: "C", reminderIDs: [r.id, UUID()])]
        let b = AppSettings(defaults: TestSupport.freshDefaults())
        try b.importBackup(a.exportBackup(), filesDir: tempDir())
        #expect(b.sets.first?.reminderIDs == [r.id])
    }

    @Test func rejectsOtherFiles() {
        let b = AppSettings(defaults: TestSupport.freshDefaults())
        #expect(throws: SettingsBackup.BackupError.notPinokFile) {
            try b.importBackup(Data(#"{"hello":1}"#.utf8), filesDir: tempDir())
        }
        #expect(throws: SettingsBackup.BackupError.notPinokFile) {
            try b.importBackup(Data("not json".utf8), filesDir: tempDir())
        }
        #expect(throws: SettingsBackup.BackupError.newerVersion) {
            try b.importBackup(Data(#"{"format":"pinok.settings","version":99}"#.utf8), filesDir: tempDir())
        }
    }
}
