import XCTest
import SwiftData
import CameraDataDomain
import CameraDataData
import CameraDataServices
import CameraDataFeatures

@MainActor
final class LogTakePipelineIntegrationTests: XCTestCase {
    func testLogAndNextCapturesMetadataEnqueuesAndFlushes() async throws {
        let container = try ModelContainerFactory.makeInMemory()
        let context = container.mainContext
        let production = ProductionModel(name: "Pipeline Test")
        let camera = CameraUnitModel(label: "A")
        let day = ShootDayModel(dayNumber: 1)
        camera.production = production
        day.production = production
        production.cameras = [camera]
        production.days = [day]
        context.insert(production)
        try context.save()

        let repository = LogEntryRepository(context: context)
        let syncEngine = SyncEngine(cloudKitAvailable: false)
        _ = try await syncEngine.prepareZones(for: production.code)

        let coordinator = LogPostSaveCoordinator(syncEngine: syncEngine, flushWhenCloudKitEnabled: true)
        let metadata = FixedMetadataProvider(
            latitude: 34.05,
            longitude: -118.25,
            pitch: 1.5,
            roll: 2.5,
            yaw: 3.5
        )
        let useCase = LogTakeUseCase(
            entryRepository: repository,
            postSaveCoordinator: coordinator,
            metadataProvider: metadata
        )

        let draft = LogEntryDraft(scene: "55", take: 1, lens: "50mm")
        let result = try await useCase.logAndNext(
            draft: draft,
            production: production,
            camera: camera,
            day: day,
            existing: nil,
            modifiedBy: "pipeline-test"
        )

        XCTAssertEqual(result.saved.scene, "55")
        XCTAssertEqual(result.saved.pitch, 1.5)
        XCTAssertEqual(result.saved.roll, 2.5)
        XCTAssertEqual(result.saved.yaw, 3.5)
        XCTAssertEqual(result.saved.latitude, 34.05)
        XCTAssertEqual(result.saved.productionId, production.id)
        XCTAssertEqual(result.saved.cameraId, camera.id)
        XCTAssertEqual(result.saved.dayId, day.id)

        let flushCount = await syncEngine.flushInvocationCount
        XCTAssertEqual(flushCount, 1)

        let pending = await syncEngine.pendingCount()
        XCTAssertEqual(pending, 0)
    }

    func testAppDependenciesUsesLiveMetadataProvider() throws {
        let deps = try AppDependencies(swiftDataCloudKit: false, syncCloudKit: false, inMemory: true)
        XCTAssertTrue(deps.metadataProvider is LiveMetadataProvider)
    }
}