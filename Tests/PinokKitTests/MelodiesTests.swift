import Foundation
import Testing
@testable import PinokKit

enum MelodyMath {
    static func rms(_ s: [Float], from a: Int, to b: Int) -> Double {
        let lo = max(0, a), hi = min(s.count, b)
        guard hi > lo else { return 0 }
        var sum = 0.0
        for i in lo..<hi { sum += Double(s[i]) * Double(s[i]) }
        return (sum / Double(hi - lo)).squareRoot()
    }

    static func index(_ seconds: Double) -> Int { Int(seconds * Melodies.sampleRate) }
}

@Suite("Melodies")
struct MelodiesTests {

    // MARK: Catalog

    @Test func idsAreUnique() {
        let ids = Melodies.all.map(\.id)
        #expect(!ids.isEmpty)
        #expect(Set(ids).count == ids.count, "Duplicate melody ids: \(ids)")
    }

    @Test func titlesAreUniqueAndNotEmpty() {
        let titles = Melodies.all.map(\.title)
        #expect(titles.allSatisfy { !$0.isEmpty })
        #expect(Set(titles).count == titles.count)
    }

    @Test(arguments: Melodies.all.map(\.id))
    func everyMelodyHasSaneNotes(id: String) throws {
        let m = try #require(Melodies.all.first { $0.id == id })
        #expect(!m.notes.isEmpty)
        for n in m.notes {
            #expect(n.time >= 0)
            #expect(n.freq > 20 && n.freq < 20_000)
            #expect(n.decay > 0)
            #expect(n.attack > 0)
        }
    }

    @Test(arguments: Melodies.all.map(\.id))
    func lookupByPrefixedName(id: String) {
        let found = Melodies.melody(for: "melody.\(id)")
        #expect(found?.id == id)
        #expect(Melodies.isMelody("melody.\(id)"))
    }

    @Test(arguments: ["", "Pop", "Glass", "melody.", "melody.unknown", "rise", "Melody.rise", " melody.rise"])
    func nonMelodyNames(name: String) {
        #expect(Melodies.melody(for: name) == nil)
        #expect(!Melodies.isMelody(name))
    }

    @Test func systemSoundsAreNotMelodies() {
        for name in Sounds.all { #expect(!Melodies.isMelody(name), "\(name)") }
    }

    @Test func templateAndSetSoundsAreKnownMelodies() {
        for tpl in ReminderLibrary.all where tpl.sound.hasPrefix(Melodies.prefix) {
            #expect(Melodies.isMelody(tpl.sound), "Template \(tpl.id) uses unknown melody \(tpl.sound)")
        }
        #expect(Melodies.isMelody(ReminderSet(name: "x").sound))
    }

    // MARK: Rendering

    @Test(arguments: Melodies.all.map(\.id))
    func renderedSamplesAreWellFormed(id: String) throws {
        let m = try #require(Melodies.melody(for: "melody.\(id)"))
        let s = Melodies.render(m)
        #expect(!s.isEmpty)

        let seconds = Double(s.count) / Melodies.sampleRate
        #expect(seconds <= 3.5 + 1e-9, "\(id) lasts \(seconds) s")
        #expect(seconds >= 1.5, "\(id) is too short: \(seconds) s — it should play during the animation")

        #expect(s.allSatisfy { $0.isFinite }, "\(id) has NaN/inf samples")
        let peak = s.map(abs).max() ?? 0
        #expect(peak <= 0.56, "\(id) peak \(peak)")
        #expect(peak > 0.1, "\(id) peak \(peak)")
        #expect(abs(peak - 0.55) < 0.01, "\(id) should be normalized to 0.55, got \(peak)")
    }

    @Test(arguments: Melodies.all.map(\.id))
    func endFadesToSilence(id: String) throws {
        let m = try #require(Melodies.melody(for: "melody.\(id)"))
        let s = Melodies.render(m)
        let tail = s.suffix(20)
        #expect(tail.allSatisfy { abs($0) < 0.01 }, "\(id) tail: \(Array(tail.suffix(3)))")
        #expect(abs(s.last ?? 1) < 0.001)
    }

    @Test(arguments: Melodies.all.map(\.id))
    func soundStartsAtTheFirstNote(id: String) throws {
        let m = try #require(Melodies.melody(for: "melody.\(id)"))
        let s = Melodies.render(m)
        let first = m.notes.map(\.time).min()!
        let start = MelodyMath.index(first)
        // Nothing before the first note.
        #expect(MelodyMath.rms(s, from: 0, to: start) < 1e-6)
        // Audible soon after it (attack + 50 ms).
        let attack = m.notes.filter { $0.time == first }.map(\.attack).max()!
        let after = MelodyMath.rms(s, from: start, to: MelodyMath.index(first + attack + 0.05))
        #expect(after > 0.01, "\(id) is silent right after its first note (rms \(after))")
    }

    @Test(arguments: Melodies.all.map(\.id))
    func everyLaterNoteAddsEnergyAtItsStart(id: String) throws {
        let m = try #require(Melodies.melody(for: "melody.\(id)"))
        let s = Melodies.render(m)
        let window = 0.03
        for n in m.notes where n.time > 0 && n.attack < 0.05 && n.time + window < Double(s.count) / Melodies.sampleRate {
            let i = MelodyMath.index(n.time)
            let before = MelodyMath.rms(s, from: i - MelodyMath.index(window), to: i)
            let after = MelodyMath.rms(s, from: i + MelodyMath.index(n.attack), to: i + MelodyMath.index(n.attack + window))
            #expect(after > before, "\(id): note at \(n.time) s does not start there (before \(before), after \(after))")
        }
    }

    @Test func delayedNoteIsSilentBeforeItsTime() {
        let m = Melodies.Melody(id: "test", title: "Test", notes: [.init(time: 0.5, freq: 440, decay: 0.3)])
        let s = Melodies.render(m)
        let start = MelodyMath.index(0.5)
        #expect(s[..<start].allSatisfy { $0 == 0 }, "Samples before the note start must be silent")
        #expect(MelodyMath.rms(s, from: start, to: start + MelodyMath.index(0.05)) > 0.05)
        // tail = 0.5 + 0.008 + 0.3 * 4
        #expect(s.count == Int((0.5 + 0.008 + 1.2) * Melodies.sampleRate))
    }

    @Test func longMelodyIsCappedAt3_5Seconds() {
        let m = Melodies.Melody(id: "long", title: "Long", notes: [.init(time: 0, freq: 440, decay: 5)])
        #expect(Melodies.render(m).count == Int(3.5 * Melodies.sampleRate))
    }

    @Test func softMelodyHasNoOvertonesButIsStillNormalized() {
        let notes = [Melodies.Note(time: 0, freq: 440, decay: 0.5)]
        let soft = Melodies.render(.init(id: "s", title: "S", notes: notes, voice: .soft))
        let bell = Melodies.render(.init(id: "b", title: "B", notes: notes, voice: .bell))
        let beep = Melodies.render(.init(id: "p", title: "P", notes: notes, voice: .beep))
        #expect(soft.count == bell.count)
        #expect(beep.count == bell.count)
        for samples in [soft, bell, beep] {
            #expect(abs((samples.map(abs).max() ?? 0) - 0.55) < 0.01)
        }
        #expect(soft != bell)
        #expect(beep != bell)
        #expect(beep != soft)
    }

    @Test func holdKeepsTheNoteLoud() {
        // С «удержанием» нота дольше звучит на полной громкости.
        let short = Melodies.render(.init(id: "a", title: "A", notes: [.init(time: 0, freq: 880, decay: 0.1)], voice: .beep))
        let held = Melodies.render(.init(id: "b", title: "B", notes: [.init(time: 0, freq: 880, decay: 0.1, hold: 0.3)], voice: .beep))
        let at = Int(0.25 * Melodies.sampleRate)
        let window = at..<(at + 400)
        let shortEnergy = window.map { abs(short[$0]) }.max() ?? 0
        let heldEnergy = window.map { abs(held[$0]) }.max() ?? 0
        #expect(heldEnergy > shortEnergy * 3)
    }

    @Test func applianceMelodiesExistAndAreDefaults() {
        #expect(Melodies.melody(for: "melody.jingle") != nil)
        #expect(Melodies.melody(for: "melody.done") != nil)
        #expect(ReminderLibrary.template("posture")?.sound == "melody.jingle")
    }

    @Test func renderIsDeterministic() throws {
        let m = try #require(Melodies.all.first)
        #expect(Melodies.render(m) == Melodies.render(m))
    }
}
