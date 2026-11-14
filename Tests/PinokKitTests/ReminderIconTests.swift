import AppKit
import Foundation
import Testing
@testable import PinokKit

@Suite("ReminderIconTests", .serialized)
@MainActor
struct ReminderIconTests {
    @Test func everyIconInTheListExists() {
        let missing = ReminderIcons.symbols.filter { NSImage(systemSymbolName: $0, accessibilityDescription: nil) == nil }
        #expect(missing.isEmpty, "Missing SF Symbols: \(missing)")
        #expect(Set(ReminderIcons.symbols).count == ReminderIcons.symbols.count)
    }

    @Test func everyAnimationSymbolExists() {
        for a in ReminderAnimation.allCases {
            #expect(NSImage(systemSymbolName: a.symbol, accessibilityDescription: nil) != nil, "\(a)")
        }
        for e in BreakExercise.allCases {
            #expect(NSImage(systemSymbolName: e.symbol, accessibilityDescription: nil) != nil, "\(e)")
        }
    }

    @Test func iconFallsBackToTheAnimationSymbol() {
        var r = Reminder(template: nil, title: "A", caption: "B", animation: .water, interval: 30, sound: "")
        #expect(r.iconSymbol == ReminderAnimation.water.symbol)
        r.symbol = "heart.fill"
        #expect(r.iconSymbol == "heart.fill")
    }

    @Test func oldRemindersWithoutIconStillDecode() throws {
        let old = #"[{"id":"\#(UUID().uuidString)","title":"Old","caption":"x","animation":"bell","interval":30,"enabled":true,"showCaption":true,"sound":"Pop"}]"#
        let list = try JSONDecoder().decode([Reminder].self, from: Data(old.utf8))
        #expect(list.first?.symbol == nil)
        #expect(list.first?.imagePath == nil)
    }

    @Test func iconFieldsRoundTrip() throws {
        let r = Reminder(template: nil, title: "A", caption: "B", animation: .icon, interval: 30, sound: "",
                         symbol: "leaf.fill", imagePath: "/tmp/x.png")
        let back = try JSONDecoder().decode(Reminder.self, from: JSONEncoder().encode(r))
        #expect(back == r)
    }

    @Test func importedImageIsASquare256Png() throws {
        // Картинка 400×200 — после импорта квадрат 256×256.
        let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: 400, pixelsHigh: 200, bitsPerSample: 8,
                                   samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB,
                                   bytesPerRow: 0, bitsPerPixel: 0)!
        let src = FileManager.default.temporaryDirectory.appendingPathComponent("pinok-icon-test.png")
        try rep.representation(using: .png, properties: [:])!.write(to: src)
        defer { try? FileManager.default.removeItem(at: src) }

        let path = try #require(ReminderIcons.importImage(src))
        defer { try? FileManager.default.removeItem(atPath: path) }
        let out = try #require(NSBitmapImageRep(data: Data(contentsOf: URL(fileURLWithPath: path))))
        #expect(out.pixelsWide == 256)
        #expect(out.pixelsHigh == 256)
        #expect(path.hasSuffix(".png"))
    }

    @Test func importOfANonImageFails() throws {
        let src = FileManager.default.temporaryDirectory.appendingPathComponent("pinok-not-image.txt")
        try Data("hello".utf8).write(to: src)
        defer { try? FileManager.default.removeItem(at: src) }
        #expect(ReminderIcons.importImage(src) == nil)
    }
}

@Suite("CaptionPoolTests", .serialized)
@MainActor
struct CaptionPoolTests {
    private func reminder(_ extras: [String]?) -> Reminder {
        Reminder(template: nil, title: "A", caption: "Main text", animation: .bell, interval: 30, sound: "",
                 extraCaptions: extras)
    }

    @Test func withoutExtrasOnlyTheMainText() {
        L10n.isRussian = false
        #expect(reminder(nil).captionPool == ["Main text"])
        #expect(reminder([]).randomCaption() == "Main text")
    }

    @Test func blankExtrasAreIgnored() {
        #expect(reminder(["  ", "", "One"]).captionPool == ["Main text", "One"])
    }

    @Test func randomCaptionComesFromThePool() {
        let r = reminder(["One", "Two"])
        var seen = Set<String>()
        for _ in 0..<200 { seen.insert(r.randomCaption()) }
        #expect(seen == ["Main text", "One", "Two"])
    }

    @Test func oldRemindersWithoutExtrasDecode() throws {
        let old = #"[{"id":"\#(UUID().uuidString)","title":"Old","caption":"x","animation":"bell","interval":30,"enabled":true,"showCaption":true,"sound":"Pop"}]"#
        let list = try JSONDecoder().decode([Reminder].self, from: Data(old.utf8))
        #expect(list.first?.extraCaptions == nil)
    }
}
