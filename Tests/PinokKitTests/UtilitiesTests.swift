import Foundation
import SwiftUI
import Testing
@testable import PinokKit

enum ShapeCheck {
    /// The path's bounding box lies inside `rect` (with a small tolerance).
    static func fits(_ path: Path, in rect: CGRect, tolerance: CGFloat = 0.5) -> Bool {
        rect.insetBy(dx: -tolerance, dy: -tolerance).contains(path.boundingRect)
    }

    static let rects: [CGRect] = [
        CGRect(x: 0, y: 0, width: 100, height: 100),
        CGRect(x: 10, y: 20, width: 300, height: 120),
        CGRect(x: -50, y: 40, width: 60, height: 240),
    ]
}

@Suite("Utilities")
struct UtilitiesTests {

    // MARK: formatCountdown

    @Test(arguments: [
        (0.0, "0:00"),
        (-5.0, "0:00"),
        (-0.4, "0:00"),
        (0.2, "0:01"),
        (1.0, "0:01"),
        (59.0, "0:59"),
        (59.2, "1:00"),
        (60.0, "1:00"),
        (61.0, "1:01"),
        (599.0, "9:59"),
        (3599.0, "59:59"),
        (3599.5, "1:00:00"),
        (3600.0, "1:00:00"),
        (3725.0, "1:02:05"),
        (36_000.0, "10:00:00"),
    ])
    func formatCountdownValues(seconds: Double, expected: String) {
        #expect(formatCountdown(seconds) == expected)
    }

    // MARK: Sounds

    @Test func soundsAllHas14UniqueNames() {
        #expect(Sounds.all.count == 14)
        #expect(Set(Sounds.all).count == 14)
        #expect(Sounds.all.allSatisfy { !$0.isEmpty })
    }

    // MARK: Shapes

    @Test func arrowAtZeroProgressIsEmpty() {
        for r in ShapeCheck.rects {
            #expect(ArrowShape(progress: 0).path(in: r).isEmpty)
            #expect(ArrowShape(progress: 0.0005).path(in: r).isEmpty)
        }
    }

    @Test(arguments: [0.01, 0.25, 0.5, 1.0])
    func arrowFitsItsRect(progress: Double) {
        for r in ShapeCheck.rects {
            let p = ArrowShape(progress: progress).path(in: r)
            #expect(!p.isEmpty)
            #expect(ShapeCheck.fits(p, in: r), "progress \(progress) rect \(r) bounds \(p.boundingRect)")
        }
    }

    @Test func fullArrowReachesTheTop() {
        let r = CGRect(x: 0, y: 0, width: 100, height: 200)
        let b = ArrowShape(progress: 1).path(in: r).boundingRect
        #expect(abs(b.minY - r.minY) < 0.5)
        #expect(abs(b.maxY - r.maxY) < 0.5)
        #expect(abs(b.midX - r.midX) < 0.5)
    }

    @Test func arrowAnimatableDataIsProgress() {
        var a = ArrowShape(progress: 0.3)
        #expect(a.animatableData == 0.3)
        a.animatableData = 0.8
        #expect(a.progress == 0.8)
    }

    @Test func mouthFitsItsRect() {
        for r in ShapeCheck.rects {
            let p = MouthShape().path(in: r)
            #expect(!p.isEmpty)
            #expect(ShapeCheck.fits(p, in: r), "rect \(r) bounds \(p.boundingRect)")
        }
    }

    @Test func eyeFitsItsRect() {
        for r in ShapeCheck.rects {
            let p = EyeShape().path(in: r)
            #expect(!p.isEmpty)
            #expect(ShapeCheck.fits(p, in: r), "rect \(r) bounds \(p.boundingRect)")
        }
    }

    // MARK: Break backgrounds

    @Test func breakGradientsHaveTitlesAndTwoColors() {
        #expect(!BreakGradient.allCases.isEmpty)
        for g in BreakGradient.allCases {
            #expect(!g.title.isEmpty)
            #expect(g.colors.count == 2, "\(g)")
            #expect(g.id == g.rawValue)
        }
        #expect(Set(BreakGradient.allCases.map(\.title)).count == BreakGradient.allCases.count)
        #expect(BreakGradient.sunset.title == "Sunset")
    }

    @Test func breakBackgroundsHaveTitles() {
        for b in BreakBackground.allCases {
            #expect(!b.title.isEmpty)
            #expect(b.id == b.rawValue)
        }
    }

    @Test func breakTipsDefaultsAreUniqueAndNotEmpty() {
        #expect(!BreakTips.defaults.isEmpty)
        #expect(BreakTips.defaults.allSatisfy { !$0.trimmingCharacters(in: .whitespaces).isEmpty })
        #expect(Set(BreakTips.defaults).count == BreakTips.defaults.count)
    }
}

/// Tests that read the global language. They live inside the serialized
/// LocalizationTests suite so they never race with tests that switch to Russian.
extension LocalizationTests {
    @Suite("Utilities · translated titles")
    struct UtilitiesTranslatedTitles {
        @Test(arguments: [false, true])
        func soundsTitle(russian: Bool) {
            defer { L10n.isRussian = false }
            L10n.isRussian = russian
            for m in Melodies.all {
                #expect(Sounds.title("melody.\(m.id)") == "♪ " + t(m.title))
            }
            #expect(Sounds.title("melody.rise") == (russian ? "♪ Подъём" : "♪ Rise"))
            #expect(Sounds.title("") == (russian ? "Без звука" : "None"))
            for name in Sounds.all { #expect(Sounds.title(name) == name) }
            #expect(Sounds.title("melody.unknown") == "melody.unknown")
        }

        @Test(arguments: [false, true])
        func breakBackgroundTitles(russian: Bool) {
            defer { L10n.isRussian = false }
            L10n.isRussian = russian
            #expect(BreakBackground.blur.title == (russian ? "Размытие" : "Blur screen"))
            #expect(BreakBackground.wallpaper.title == (russian ? "Обои" : "Wallpaper"))
            #expect(BreakBackground.gradient.title == (russian ? "Градиент" : "Gradient"))
            #expect(BreakBackground.image.title == (russian ? "Картинка" : "Image"))
        }

        @Test(arguments: [false, true])
        func reminderLibraryLabel(russian: Bool) {
            defer { L10n.isRussian = false }
            L10n.isRussian = russian
            #expect(ReminderLibrary.label(20) == (russian ? "20 мин" : "20 min"))
            #expect(ReminderLibrary.label(180) == (russian ? "3 ч" : "3 h"))
        }
    }
}
