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

    func testSlateTakeIncrementUpdatesSession() {
        let session = ProductionSession()
        session.slateTake = 3

        session.slateTake += 1

        XCTAssertEqual(session.slateTake, 4)
    }

    func testSlateRollingTogglePersistsOnSession() {
        let session = ProductionSession()
        XCTAssertFalse(session.slateIsRolling)

        session.slateIsRolling = true
        XCTAssertTrue(session.slateIsRolling)
    }
}