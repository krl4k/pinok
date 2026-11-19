import Foundation
import Testing
@testable import PinokKit

/// Статистики больше нет: старые записи удаляются один раз, остальные настройки остаются.
@MainActor
@Suite("Old stats cleanup")
struct OldStatsTests {
    @Test func removesOnlyStatsKeysOnce() {
        let d = TestSupport.freshDefaults()
        d.set(42, forKey: "stats.2026-11-18.active")
        d.set(["com.apple.Safari": 600], forKey: "stats.2026-11-18.apps")
        d.set(true, forKey: "haptics")

        AppSettings.removeOldStats(d)
        #expect(d.object(forKey: "stats.2026-11-18.active") == nil)
        #expect(d.object(forKey: "stats.2026-11-18.apps") == nil)
        #expect(d.bool(forKey: "haptics"))

        // Второй раз ничего не трогаем.
        d.set(1, forKey: "stats.later")
        AppSettings.removeOldStats(d)
        #expect(d.integer(forKey: "stats.later") == 1)
    }
}
