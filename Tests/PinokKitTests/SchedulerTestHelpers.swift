import Foundation
@testable import PinokKit

/// Собирает Scheduler с ручными часами, заглушкой показа и управляемыми idle/busy.
@MainActor
final class SchedulerHarness {
    let clock = TestClock()
    /// Секунды без ввода. 10 с — человек за компьютером, но не печатает.
    var idle: TimeInterval = 10
    var busy: BusyReason?
    let settings: AppSettings
    let presenter = FakePresenter()
    private(set) var scheduler: Scheduler!
    let start: Date

    /// По умолчанию: без напоминаний, без перерывов, без smart timing и отсчёта у курсора.
    init() {
        settings = AppSettings(defaults: TestSupport.freshDefaults())
        L10n.isRussian = false
        let clock = self.clock
        start = clock.now
        settings.reminders = []
        settings.sets = []
        settings.breakEnabled = false
        settings.breakInterval = 60
        settings.breakDuration = 5
        settings.breakWarning = 0
        settings.floatingCountdown = false
        settings.smartTiming = false
        settings.idleMinutes = 5
        settings.breakStartSound = "Glass"
        settings.breakEndSound = "Hero"
        scheduler = Scheduler(settings: settings, presenter: presenter,
                              clock: { clock.now },
                              idleSeconds: { [unowned self] in self.idle },
                              jitter: { 0 },
                              detectBusy: { [unowned self] _ in self.busy })
    }

    /// Применить настройки и начать отсчёт заново с текущего момента.
    func reset() { scheduler.resetAll() }

    /// Перейти к моменту `start + seconds` и сделать один тик.
    func tick(at seconds: TimeInterval) {
        clock.now = start.addingTimeInterval(seconds)
        scheduler.tick()
    }

    /// Сдвинуть время и сделать один тик.
    func advanceAndTick(_ seconds: TimeInterval) {
        clock.advance(seconds)
        scheduler.tick()
    }

    /// Тикать раз в секунду `count` раз.
    func run(seconds count: Int) {
        for _ in 0..<count { advanceAndTick(1) }
    }

    /// Дата `start + seconds`.
    func at(_ seconds: TimeInterval) -> Date { start.addingTimeInterval(seconds) }

    static func reminder(_ title: String, every minutes: Int, sound: String = "Pop") -> Reminder {
        Reminder(title: title, caption: title, animation: .bell, interval: minutes, sound: sound)
    }
}
