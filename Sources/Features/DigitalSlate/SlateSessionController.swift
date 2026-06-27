import Foundation
import SwiftUI
import Observation
import CameraDataDomain

@MainActor
@Observable
public final class SlateSessionController {
    public let session: ProductionSession
    public var isPresented = false

    public init(session: ProductionSession) {
        self.session = session
    }

    public func present() {
        if let camera = session.selectedCamera, session.slateFrameRatePresetID == "24" {
            session.slateManualFrameRate = camera.defaultFPS
            if let preset = SlateFrameRateOption.presets.first(where: {
                $0.value == camera.defaultFPS
            }) {
                session.slateFrameRatePresetID = preset.id
            } else {
                session.slateFrameRatePresetID = "manual"
            }
        }
        isPresented = true
        NSLog(
            "[CameraData] slate_presented=true scene=%@ take=%d rolling=%@",
            session.slateScene,
            session.slateTake,
            session.slateIsRolling ? "true" : "false"
        )
    }

    public func dismiss() {
        isPresented = false
        session.slateIsRolling = false
        session.slateRollOrigin = nil
        NSLog("[CameraData] slate_dismissed=true")
    }

    public func toggleRolling() {
        if session.slateIsRolling {
            session.slateIsRolling = false
            session.slateRollOrigin = nil
        } else {
            session.slateIsRolling = true
            session.slateRollOrigin = Date()
        }
        NSLog(
            "[CameraData] slate_rolling=%@",
            session.slateIsRolling ? "true" : "false"
        )
    }

    public func incrementTake() {
        session.slateTake += 1
        NSLog("[CameraData] slate_take=%d", session.slateTake)
    }

    public var resolvedFrameRate: Double {
        SlateSettingsResolver.resolvedFPS(
            presetID: session.slateFrameRatePresetID,
            manualFPS: session.slateManualFrameRate
        )
    }

    public var resolvedWhiteBalanceLabel: String {
        SlateSettingsResolver.resolvedWhiteBalanceLabel(
            presetID: session.slateWhiteBalancePresetID,
            manualKelvin: session.slateManualWhiteBalanceKelvin
        )
    }

    public func bindings() -> SlateViewBindings {
        SlateViewBindings(controller: self)
    }
}

@MainActor
public struct SlateViewBindings {
    private let controller: SlateSessionController

    fileprivate init(controller: SlateSessionController) {
        self.controller = controller
    }

    public var scene: Binding<String> {
        Binding(
            get: { controller.session.slateScene },
            set: { controller.session.slateScene = $0 }
        )
    }

    public var take: Binding<Int> {
        Binding(
            get: { controller.session.slateTake },
            set: { controller.session.slateTake = $0 }
        )
    }

    public var rollNumber: Binding<String> {
        Binding(
            get: { controller.session.slateRollNumber },
            set: { controller.session.slateRollNumber = $0 }
        )
    }

    public var isRolling: Binding<Bool> {
        Binding(
            get: { controller.session.slateIsRolling },
            set: { newValue in
                if newValue != controller.session.slateIsRolling {
                    controller.toggleRolling()
                }
            }
        )
    }

    public var frameRatePresetID: Binding<String> {
        Binding(
            get: { controller.session.slateFrameRatePresetID },
            set: { controller.session.slateFrameRatePresetID = $0 }
        )
    }

    public var manualFrameRate: Binding<Double> {
        Binding(
            get: { controller.session.slateManualFrameRate },
            set: { controller.session.slateManualFrameRate = $0 }
        )
    }

    public var whiteBalancePresetID: Binding<String> {
        Binding(
            get: { controller.session.slateWhiteBalancePresetID },
            set: { controller.session.slateWhiteBalancePresetID = $0 }
        )
    }

    public var manualWhiteBalanceKelvin: Binding<Int> {
        Binding(
            get: { controller.session.slateManualWhiteBalanceKelvin },
            set: { controller.session.slateManualWhiteBalanceKelvin = $0 }
        )
    }

    public var rollOrigin: Date? {
        controller.session.slateRollOrigin
    }

    public var resolvedFrameRate: Double {
        controller.resolvedFrameRate
    }

    public var resolvedWhiteBalanceLabel: String {
        controller.resolvedWhiteBalanceLabel
    }
}