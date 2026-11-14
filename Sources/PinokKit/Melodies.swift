import AVFoundation

/// Короткие мелодии (~2,5 с), которые звучат, пока идёт анимация.
/// Синтезируются в приложении — файлы не нужны.
enum Melodies {
    /// Нота: когда начать (с), частота (Гц), сколько затухать (с).
    struct Note {
        let time: Double
        let freq: Double
        var decay: Double = 0.9
        var attack: Double = 0.008
        /// Сколько секунд нота держится на полной громкости перед затуханием.
        var hold: Double = 0
    }

    /// Тембр.
    enum Voice {
        /// Колокольчик: основной тон и обертоны.
        case bell
        /// Мягкий: только основной тон.
        case soft
        /// «Бытовая техника»: чистый писк с лёгкой квадратной окраской.
        case beep
    }

    struct Melody: Identifiable {
        let id: String
        let title: String
        let notes: [Note]
        var voice: Voice = .bell
    }

    static let prefix = "melody."

    /// Ноты: C5 = 523.25 и т. д.
    private static let c5 = 523.25, d5 = 587.33, e5 = 659.25, g5 = 783.99, a5 = 880.0
    private static let c6 = 1046.5, e6 = 1318.5, g6 = 1568.0, a4 = 440.0, e4 = 329.63, a3 = 220.0

    private static let g4 = 392.0, b5 = 987.77, f5 = 698.46, d6 = 1174.7

    /// Бодрый джингл в духе бытовой техники (своя мелодия).
    private static func beep(_ time: Double, _ freq: Double, hold: Double = 0.11, decay: Double = 0.16) -> Note {
        Note(time: time, freq: freq, decay: decay, attack: 0.006, hold: hold)
    }

    static let all: [Melody] = [
        Melody(id: "jingle", title: "Jingle", notes: [
            beep(0.00, g5), beep(0.18, c6), beep(0.36, e6), beep(0.54, d6),
            beep(0.72, c6), beep(0.90, e6), beep(1.08, g6, hold: 0.3, decay: 0.35),
            beep(1.62, e6), beep(1.80, d6), beep(1.98, c6, hold: 0.45, decay: 0.5),
        ], voice: .beep),
        Melody(id: "done", title: "Done", notes: [
            beep(0.00, c6), beep(0.16, e6), beep(0.32, g6),
            beep(0.56, c6 * 2, hold: 0.5, decay: 0.6),
        ], voice: .beep),
        // Поднимается вместе со стрелкой
        Melody(id: "rise", title: "Rise", notes: [
            Note(time: 0.00, freq: c5), Note(time: 0.45, freq: e5), Note(time: 0.90, freq: g5),
            Note(time: 1.40, freq: c6, decay: 1.3),
        ]),
        // Светлый перезвон
        Melody(id: "chime", title: "Chime", notes: [
            Note(time: 0.00, freq: g5, decay: 1.2), Note(time: 0.30, freq: c6, decay: 1.2),
            Note(time: 0.60, freq: e6, decay: 1.6),
        ]),
        // Спокойные редкие ноты
        Melody(id: "calm", title: "Calm", notes: [
            Note(time: 0.00, freq: a4, decay: 1.6), Note(time: 0.80, freq: e5, decay: 1.6),
            Note(time: 1.60, freq: d5, decay: 1.8),
        ], voice: .soft),
        // Вдох и выдох — аккорд медленно нарастает и уходит
        Melody(id: "breath", title: "Breath", notes: [
            Note(time: 0.0, freq: a3, decay: 1.4, attack: 1.1), Note(time: 0.0, freq: e4, decay: 1.4, attack: 1.1),
            Note(time: 0.0, freq: a4, decay: 1.4, attack: 1.1),
        ], voice: .soft),
        // Быстрые искорки
        Melody(id: "sparkle", title: "Sparkle", notes: [
            Note(time: 0.00, freq: c6, decay: 0.5), Note(time: 0.12, freq: e6, decay: 0.5),
            Note(time: 0.24, freq: g6, decay: 0.5), Note(time: 0.50, freq: e6, decay: 0.5),
            Note(time: 0.62, freq: g6, decay: 0.5), Note(time: 0.74, freq: c6 * 2, decay: 1.2),
        ]),
    ]

    static func melody(for sound: String) -> Melody? {
        guard sound.hasPrefix(prefix) else { return nil }
        let id = String(sound.dropFirst(prefix.count))
        return all.first { $0.id == id }
    }

    static func isMelody(_ sound: String) -> Bool { melody(for: sound) != nil }

    // MARK: Синтез

    static let sampleRate = 44_100.0

    /// Сэмплы мелодии (моно, -1…1).
    static func render(_ melody: Melody) -> [Float] {
        let tail = melody.notes.map { $0.time + $0.attack + $0.hold + $0.decay * 4 }.max() ?? 1
        let count = Int(min(tail, 3.5) * sampleRate)
        var out = [Float](repeating: 0, count: count)

        for note in melody.notes {
            let start = Int(note.time * sampleRate)
            for i in start..<count {
                let t = Double(i - start) / sampleRate
                let sustainEnd = note.attack + note.hold
                let env = t < note.attack
                    ? t / note.attack
                    : (t < sustainEnd ? 1 : exp(-(t - sustainEnd) / note.decay))
                if env < 0.0005, t > sustainEnd { break }
                let w = 2 * Double.pi * note.freq * t
                var v = sin(w)
                switch melody.voice {
                case .bell: v += 0.35 * sin(2 * w) + 0.12 * sin(3 * w)
                case .soft: break
                case .beep: v += 0.22 * sin(3 * w) + 0.08 * sin(5 * w) // нечётные гармоники — «писк»
                }
                out[i] += Float(v * env)
            }
        }

        // Нормализуем, чтобы не было хрипа, и мягко гасим конец.
        let peak = out.map(abs).max() ?? 1
        let gain: Float = peak > 0 ? 0.55 / peak : 1
        let fade = Int(0.15 * sampleRate)
        for i in out.indices {
            out[i] *= gain
            if i > count - fade { out[i] *= Float(count - i) / Float(fade) }
        }
        return out
    }
}

/// Проигрывание мелодий через AVAudioEngine.
@MainActor
final class MelodyPlayer {
    static let shared = MelodyPlayer()

    private let engine = AVAudioEngine()
    private let player = AVAudioPlayerNode()
    private let format = AVAudioFormat(standardFormatWithSampleRate: Melodies.sampleRate, channels: 1)!
    private var cache: [String: AVAudioPCMBuffer] = [:]
    private var stopWork: DispatchWorkItem?

    private init() {
        engine.attach(player)
        engine.connect(player, to: engine.mainMixerNode, format: format)
    }

    /// Мелодия сейчас играет.
    private(set) var isPlaying = false

    func stop() {
        stopWork?.cancel()
        player.stop()
        engine.stop()
        isPlaying = false
    }

    func play(_ melody: Melodies.Melody, volume: Float) {
        guard let buffer = buffer(for: melody) else { return }
        if !engine.isRunning { try? engine.start() }
        player.stop()
        player.volume = volume
        player.scheduleBuffer(buffer, at: nil, options: .interrupts)
        player.play()
        isPlaying = true

        // Останавливаем движок, когда мелодия закончилась, — не тратим ресурсы.
        stopWork?.cancel()
        let work = DispatchWorkItem { [weak self] in
            self?.player.stop()
            self?.engine.stop()
            self?.isPlaying = false
        }
        stopWork = work
        let seconds = Double(buffer.frameLength) / Melodies.sampleRate + 0.2
        DispatchQueue.main.asyncAfter(deadline: .now() + seconds, execute: work)
    }

    private func buffer(for melody: Melodies.Melody) -> AVAudioPCMBuffer? {
        if let b = cache[melody.id] { return b }
        let samples = Melodies.render(melody)
        guard let b = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(samples.count)),
              let channel = b.floatChannelData?[0] else { return nil }
        b.frameLength = AVAudioFrameCount(samples.count)
        samples.withUnsafeBufferPointer { channel.update(from: $0.baseAddress!, count: samples.count) }
        cache[melody.id] = b
        return b
    }
}
