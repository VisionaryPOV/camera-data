import XCTest
import SwiftUI
import UIKit
@testable import CameraDataDomain
@testable import CameraDataFeatures

@MainActor
final class DigitalSlateTests: XCTestCase {
    func testSlateTimecodeFormatsHoursMinutesSecondsFrames() {
        let origin = Date(timeIntervalSince1970: 0)
        let date = Date(timeIntervalSince1970: 3661.5)
        let groups = SlateTimecode.digitGroups(from: date, origin: origin, fps: 24)

        XCTAssertEqual(groups, ["01", "01", "01", "12"])
    }

    func testSlateTimecodeFractionalFrameRates() {
        XCTAssertEqual(SlateTimecode.framesPerSecond(for: 23.976), 24)
        XCTAssertEqual(SlateTimecode.framesPerSecond(for: 29.97), 30)

        let origin = Date(timeIntervalSince1970: 0)
        let at23976 = SlateTimecode.components(
            from: Date(timeIntervalSince1970: 1 + (23.0 / 23.976)),
            origin: origin,
            fps: 23.976
        )
        XCTAssertEqual(at23976.frames, 23)
    }

    func testSlateTimecodeUsesSelectedFrameRateForFrames() {
        let origin = Date(timeIntervalSince1970: 0)
        let at24 = SlateTimecode.components(
            from: Date(timeIntervalSince1970: 1 + (23.0 / 24.0)),
            origin: origin,
            fps: 24
        )
        let at60 = SlateTimecode.components(
            from: Date(timeIntervalSince1970: 1 + (59.0 / 60.0)),
            origin: origin,
            fps: 60
        )

        XCTAssertEqual(at24.frames, 23)
        XCTAssertEqual(at60.frames, 59)
    }

    func testSlateSettingsResolverUsesManualValues() {
        XCTAssertEqual(
            SlateSettingsResolver.resolvedFPS(presetID: "manual", manualFPS: 47.952),
            47.952,
            accuracy: 0.001
        )
        XCTAssertEqual(
            SlateSettingsResolver.resolvedWhiteBalanceLabel(presetID: "manual", manualKelvin: 4900),
            "4900K"
        )
    }

    func testSlateSessionControllerPresentDismissIncrementRolling() {
        let session = ProductionSession()
        session.slateTake = 4
        let controller = SlateSessionController(session: session)

        controller.present()
        XCTAssertTrue(controller.isPresented)

        controller.toggleRolling()
        XCTAssertTrue(session.slateIsRolling)
        XCTAssertNotNil(session.slateRollOrigin)

        controller.incrementTake()
        XCTAssertEqual(session.slateTake, 5)

        controller.dismiss()
        XCTAssertFalse(controller.isPresented)
        XCTAssertFalse(session.slateIsRolling)
        XCTAssertNil(session.slateRollOrigin)
    }

    func testSlateBindingsDriveSessionFromEntryPoint() {
        let session = ProductionSession()
        let controller = SlateSessionController(session: session)
        let bindings = controller.bindings()

        bindings.scene.wrappedValue = "24A"
        bindings.take.wrappedValue = 7
        bindings.rollNumber.wrappedValue = "A001"
        bindings.frameRatePresetID.wrappedValue = "23.976"
        bindings.whiteBalancePresetID.wrappedValue = "3200"
        bindings.isRolling.wrappedValue = true

        XCTAssertEqual(session.slateScene, "24A")
        XCTAssertEqual(session.slateTake, 7)
        XCTAssertEqual(session.slateRollNumber, "A001")
        XCTAssertEqual(session.slateFrameRatePresetID, "23.976")
        XCTAssertEqual(session.slateWhiteBalancePresetID, "3200")
        XCTAssertTrue(session.slateIsRolling)
    }

    func testDigitalSlateViewOnAppearFiresObservableCallback() {
        var appeared = false
        var scene = "18"
        var take = 6
        var roll = "A01"
        var rolling = false
        var fpsPreset = "24"
        var manualFPS = 24.0
        var wbPreset = "5600"
        var manualWB = 5600

        let view = DigitalSlateView(
            scene: Binding(get: { scene }, set: { scene = $0 }),
            take: Binding(get: { take }, set: { take = $0 }),
            rollNumber: Binding(get: { roll }, set: { roll = $0 }),
            isRolling: Binding(get: { rolling }, set: { rolling = $0 }),
            frameRatePresetID: Binding(get: { fpsPreset }, set: { fpsPreset = $0 }),
            manualFrameRate: Binding(get: { manualFPS }, set: { manualFPS = $0 }),
            whiteBalancePresetID: Binding(get: { wbPreset }, set: { wbPreset = $0 }),
            manualWhiteBalanceKelvin: Binding(get: { manualWB }, set: { manualWB = $0 }),
            rollOrigin: nil,
            onIncrementTake: { take += 1 },
            onDismiss: {},
            onViewAppeared: { appeared = true }
        )

        let host = UIHostingController(rootView: view)
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 400, height: 800))
        window.rootViewController = host
        window.makeKeyAndVisible()
        host.view.setNeedsLayout()
        host.view.layoutIfNeeded()
        RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.1))

        XCTAssertTrue(appeared, "DigitalSlateView body onAppear must execute for fullScreenCover path")
        window.isHidden = true
    }

    func testDigitalSlateViewHostsAndReflectsBindingUpdates() {
        var scene = "18"
        var take = 6
        var roll = ""
        var rolling = false
        var fpsPreset = "24"
        var manualFPS = 24.0
        var wbPreset = "5600"
        var manualWB = 5600

        let view = DigitalSlateView(
            scene: Binding(get: { scene }, set: { scene = $0 }),
            take: Binding(get: { take }, set: { take = $0 }),
            rollNumber: Binding(get: { roll }, set: { roll = $0 }),
            isRolling: Binding(get: { rolling }, set: { rolling = $0 }),
            frameRatePresetID: Binding(get: { fpsPreset }, set: { fpsPreset = $0 }),
            manualFrameRate: Binding(get: { manualFPS }, set: { manualFPS = $0 }),
            whiteBalancePresetID: Binding(get: { wbPreset }, set: { wbPreset = $0 }),
            manualWhiteBalanceKelvin: Binding(get: { manualWB }, set: { manualWB = $0 }),
            rollOrigin: nil,
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
            rollNumber: Binding(get: { roll }, set: { roll = $0 }),
            isRolling: Binding(get: { rolling }, set: { rolling = $0 }),
            frameRatePresetID: Binding(get: { fpsPreset }, set: { fpsPreset = $0 }),
            manualFrameRate: Binding(get: { manualFPS }, set: { manualFPS = $0 }),
            whiteBalancePresetID: Binding(get: { wbPreset }, set: { wbPreset = $0 }),
            manualWhiteBalanceKelvin: Binding(get: { manualWB }, set: { manualWB = $0 }),
            rollOrigin: Date(),
            onIncrementTake: { take += 1 },
            onDismiss: {}
        )
        host.view.layoutIfNeeded()

        XCTAssertEqual(scene, "22")
        XCTAssertEqual(take, 9)
        XCTAssertTrue(rolling)
    }

    func testSlateLaunchHookPresentationSequence() async {
        let session = ProductionSession()
        let controller = SlateSessionController(session: session)

        XCTAssertFalse(controller.isPresented)
        await Task.yield()
        try? await Task.sleep(nanoseconds: 100_000_000)

        controller.present()
        XCTAssertTrue(controller.isPresented)

        controller.toggleRolling()
        XCTAssertTrue(session.slateIsRolling)

        controller.incrementTake()
        XCTAssertEqual(session.slateTake, 2)

        controller.dismiss()
        XCTAssertFalse(controller.isPresented)
        XCTAssertFalse(session.slateIsRolling)
    }
}