import AppKit

/// Вибрация трекпада (Force Touch). Чувствуется, только если палец лежит на трекпаде.
@MainActor
enum Haptics {
    enum Kind {
        /// Короткий «тык».
        case tap
        /// Щелчок, как при выравнивании.
        case click
        /// Плотная «ступенька».
        case strong

        var pattern: NSHapticFeedbackManager.FeedbackPattern {
            switch self {
            case .tap: .generic
            case .click: .alignment
            case .strong: .levelChange
            }
        }
    }

    /// Можно подменить в тестах.
    static var perform: (NSHapticFeedbackManager.FeedbackPattern) -> Void = { pattern in
        NSHapticFeedbackManager.defaultPerformer.perform(pattern, performanceTime: .now)
    }

    static func play(_ kind: Kind) {
        guard AppSettings.shared.haptics else { return }
        perform(kind.pattern)
    }

    /// Несколько щелчков подряд: `count` раз через `interval` секунд, начиная через `delay`.
    static func rhythm(_ kind: Kind, count: Int, interval: TimeInterval, delay: TimeInterval = 0) {
        for i in 0..<max(0, count) {
            DispatchQueue.main.asyncAfter(deadline: .now() + delay + Double(i) * interval) {
                play(kind)
            }
        }
    }
}
