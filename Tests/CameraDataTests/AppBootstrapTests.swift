import XCTest
@testable import CameraDataFeatures

@MainActor
final class AppBootstrapTests: XCTestCase {
    func testAppDependenciesBootstrapCreatesProductionAndLaunchState() async throws {
        let deps = try AppDependencies(swiftDataCloudKit: false, syncCloudKit: false, inMemory: true)
        try await deps.bootstrapIfNeeded()

        XCTAssertNotNil(deps.session.activeProduction)
        XCTAssertNotNil(deps.session.selectedCamera)
        XCTAssertNotNil(deps.session.selectedDay)
        XCTAssertTrue(deps.session.launchState.hasPrefix("dashboard_ready:"))
    }
}