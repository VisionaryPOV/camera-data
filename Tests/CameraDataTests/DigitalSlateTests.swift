import XCTest
@testable import CameraDataDomain
@testable import CameraDataFeatures

@MainActor
final class DigitalSlateTests: XCTestCase {
    func testSlateTimeFormatterFormats24HourTime() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let date = calendar.date(from: DateComponents(year: 2026, month: 6, day: 25, hour: 14, minute: 7))!

        XCTAssertEqual(SlateTimeFormatter.timeOfDay(from: date, calendar: calendar), "14:07")
    }

    func testSlateSessionControllerPresentDismissIncrementRolling() {
        let session = ProductionSession()
        session.slateTake = 4
        let controller = SlateSessionController(session: session)

        controller.present()
        XCTAssertTrue(controller.isPresented)

        controller.toggleRolling()
        XCTAssertTrue(session.slateIsRolling)

        controller.incrementTake()
        XCTAssertEqual(session.slateTake, 5)

        controller.dismiss()
        XCTAssertFalse(controller.isPresented)
        XCTAssertFalse(session.slateIsRolling)
    }

    func testSlateBindingsDriveSessionFromEntryPoint() {
        let session = ProductionSession()
        let controller = SlateSessionController(session: session)
        let bindings = controller.bindings()

        bindings.scene.wrappedValue = "24A"
        bindings.take.wrappedValue = 7
        bindings.isRolling.wrappedValue = true

        XCTAssertEqual(session.slateScene, "24A")
        XCTAssertEqual(session.slateTake, 7)
        XCTAssertTrue(session.slateIsRolling)
    }
}