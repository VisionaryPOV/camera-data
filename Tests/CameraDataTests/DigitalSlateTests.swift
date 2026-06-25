import XCTest
import SwiftUI
import UIKit
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

    func testDigitalSlateViewHostsAndReflectsBindingUpdates() {
        var scene = "18"
        var take = 6
        var rolling = false

        let view = DigitalSlateView(
            scene: Binding(get: { scene }, set: { scene = $0 }),
            take: Binding(get: { take }, set: { take = $0 }),
            isRolling: Binding(get: { rolling }, set: { rolling = $0 }),
            onIncrementTake: { take += 1 },
            onDismiss: {}
        )

        let host = UIHostingController(rootView: view)
        host.loadViewIfNeeded()
        host.beginAppearanceTransition(true, animated: false)
        host.endAppearanceTransition()

        XCTAssertNotNil(host.view)

        scene = "22"
        take = 9
        rolling = true
        host.rootView = DigitalSlateView(
            scene: Binding(get: { scene }, set: { scene = $0 }),
            take: Binding(get: { take }, set: { take = $0 }),
            isRolling: Binding(get: { rolling }, set: { rolling = $0 }),
            onIncrementTake: { take += 1 },
            onDismiss: {}
        )
        host.view.layoutIfNeeded()

        XCTAssertEqual(scene, "22")
        XCTAssertEqual(take, 9)
        XCTAssertTrue(rolling)
    }
}