import XCTest
@testable import CameraDataFeatures
import CameraDataServices

@MainActor
final class AppBootstrapTests: XCTestCase {
    func testAppDependenciesBootstrapCreatesProductionAndLaunchState() async throws {
        let transport = RecordingCloudKitTransport()
        let deps = try AppDependencies(
            swiftDataCloudKit: false,
            syncPipelineEnabled: true,
            inMemory: true,
            syncTransport: transport
        )
        try await deps.bootstrapIfNeeded()

        XCTAssertNotNil(deps.session.activeProduction)
        XCTAssertNotNil(deps.session.selectedCamera)
        XCTAssertNotNil(deps.session.selectedDay)
        XCTAssertTrue(deps.session.launchState.hasPrefix("dashboard_ready:"))
        XCTAssertTrue(deps.syncPipelineEnabled)

        let zoneCount = await transport.modifyRecordZonesInvocationCount
        XCTAssertGreaterThanOrEqual(zoneCount, 1)
    }
}