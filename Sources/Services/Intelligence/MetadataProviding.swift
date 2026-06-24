import Foundation
import CoreLocation
import CoreMotion
import CameraDataDomain

@MainActor
public protocol MetadataProviding {
    func captureContext() -> CaptureContext
}

@MainActor
public struct FixedMetadataProvider: MetadataProviding {
    private let context: CaptureContext

    public init(context: CaptureContext) {
        self.context = context
    }

    public init(
        latitude: Double? = nil,
        longitude: Double? = nil,
        altitude: Double? = nil,
        pitch: Double? = nil,
        roll: Double? = nil,
        yaw: Double? = nil
    ) {
        self.context = CaptureContext(
            latitude: latitude,
            longitude: longitude,
            altitude: altitude,
            pitch: pitch,
            roll: roll,
            yaw: yaw
        )
    }

    public func captureContext() -> CaptureContext {
        context
    }
}

@MainActor
public final class LiveMetadataProvider: MetadataProviding {
    private let locationManager = CLLocationManager()
    private let motionManager = CMMotionManager()

    public init() {
        locationManager.desiredAccuracy = kCLLocationAccuracyNearestTenMeters
        if locationManager.authorizationStatus == .notDetermined {
            locationManager.requestWhenInUseAuthorization()
        }
    }

    public func captureContext() -> CaptureContext {
        let location = locationManager.location
        let motion = currentMotionSnapshot()
        return MetadataCaptureService.captureContext(location: location, motion: motion)
    }

    private func currentMotionSnapshot() -> DeviceMotionSnapshot? {
        guard motionManager.isDeviceMotionAvailable else { return nil }

        if motionManager.isDeviceMotionActive, let data = motionManager.deviceMotion {
            return DeviceMotionSnapshot(
                pitch: data.attitude.pitch,
                roll: data.attitude.roll,
                yaw: data.attitude.yaw
            )
        }

        motionManager.deviceMotionUpdateInterval = 0.1
        motionManager.startDeviceMotionUpdates()
        defer { motionManager.stopDeviceMotionUpdates() }

        guard let data = motionManager.deviceMotion else { return nil }
        return DeviceMotionSnapshot(
            pitch: data.attitude.pitch,
            roll: data.attitude.roll,
            yaw: data.attitude.yaw
        )
    }
}