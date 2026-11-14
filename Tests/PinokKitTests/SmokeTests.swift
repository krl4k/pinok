import Testing
@testable import PinokKit

@Suite("Smoke")
struct SmokeTests {
    @Test func libraryHasPostureAndTongue() {
        #expect(ReminderLibrary.template("posture") != nil)
        #expect(ReminderLibrary.template("tongue") != nil)
    }
}
