import Foundation
import CoreLocation
import CameraDataDomain

public struct DeviceMotionSnapshot: Sendable {
    public var pitch: Double
    public var roll: Double
    public var yaw: Double

    public init(pitch: Double, roll: Double, yaw: Double) {
        self.pitch = pitch
        self.roll = roll
        self.yaw = yaw
    }
}

public enum MetadataCaptureService {
    public static func captureContext(
        location: CLLocation?,
        motion: DeviceMotionSnapshot?
    ) -> CaptureContext {
        CaptureContext(
            latitude: location?.coordinate.latitude,
            longitude: location?.coordinate.longitude,
            altitude: location?.altitude,
            pitch: motion?.pitch,
            roll: motion?.roll,
            yaw: motion?.yaw
        )
    }
}