import CloudKit
import XCTest
@testable import CameraDataFeatures
import CameraDataServices

@MainActor
final class AppBootstrapTests: XCTestCase {
    func testAppDependenciesBootstrapCreatesProductionAndLaunchState() async throws {
        let store = OfflineCloudKitRecordStore(inMemoryOnly: true)
        let deps = try AppDependencies(
            swiftDataCloudKit: false,
            syncPipelineEnabled: true,
            inMemory: true,
            offlineCloudKitStore: store
        )
        try await deps.bootstrapIfNeeded()

        XCTAssertNotNil(deps.session.activeProduction)
        XCTAssertNotNil(deps.session.selectedCamera)
        XCTAssertNotNil(deps.session.selectedDay)
        XCTAssertTrue(deps.session.launchState.hasPrefix("dashboard_ready:"))
        XCTAssertTrue(deps.syncPipelineEnabled)

        let zones = await store.zones
        XCTAssertGreaterThanOrEqual(zones.count, 2)
        XCTAssertFalse(zones.first?.pushedToCloudKit ?? true)
    }

    func testBootstrapCompletesWhenInboundSyncFails() async throws {
        let transport = RecordingCloudKitTransport()
        await transport.setFetchLogEntriesError(
            NSError(
                domain: CKError.errorDomain,
                code: CKError.Code.networkUnavailable.rawValue,
                userInfo: [NSLocalizedDescriptionKey: "Network unavailable"]
            )
        )
        let store = OfflineCloudKitRecordStore(inMemoryOnly: true)
        let deps = try AppDependencies(
            swiftDataCloudKit: false,
            syncPipelineEnabled: true,
            inMemory: true,
            syncTransport: transport,
            offlineCloudKitStore: store
        )

        try await deps.bootstrapIfNeeded()

        XCTAssertTrue(deps.session.launchState.hasPrefix("dashboard_ready:"))
    }
}