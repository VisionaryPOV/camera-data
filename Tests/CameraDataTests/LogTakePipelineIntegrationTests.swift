import XCTest
import SwiftData
import CameraDataDomain
import CameraDataData
import CameraDataServices
import CameraDataFeatures

@MainActor
final class LogTakePipelineIntegrationTests: XCTestCase {
    func testLogAndNextCapturesMetadataEnqueuesFlushesAndModifyRecords() async throws {
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
        let transport = RecordingCloudKitTransport()
        let syncEngine = SyncEngine(transport: transport)
        _ = try await syncEngine.prepareZones(for: production.code)

        let coordinator = LogPostSaveCoordinator(syncEngine: syncEngine, flushAfterEnqueue: true)
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

        let modifyCount = await syncEngine.modifyRecordsInvocationCount
        XCTAssertEqual(modifyCount, 1)

        let pending = await syncEngine.pendingCount()
        XCTAssertEqual(pending, 0)

        let savedRecords = await transport.savedRecords
        XCTAssertEqual(savedRecords.count, 1)
        XCTAssertEqual(savedRecords.first?.ckString("scene"), "55")
        XCTAssertEqual(savedRecords.first?.ckInt("take"), 1)
        XCTAssertEqual(savedRecords.first?.ckString("lens"), "50mm")
    }

    func testLogAndNextUsesLiveTransportOfflineStoreInProductionPath() async throws {
        let store = OfflineCloudKitRecordStore()
        let deps = try AppDependencies(
            swiftDataCloudKit: false,
            syncPipelineEnabled: true,
            inMemory: true,
            offlineCloudKitStore: store
        )
        try await deps.bootstrapIfNeeded()

        guard let production = deps.session.activeProduction,
              let camera = deps.session.selectedCamera,
              let day = deps.session.selectedDay else {
            XCTFail("Missing production context")
            return
        }

        let draft = LogEntryDraft(scene: "88", take: 1, lens: "75mm")
        _ = try await deps.logTakeUseCase.logAndNext(
            draft: draft,
            production: production,
            camera: camera,
            day: day,
            existing: nil,
            modifiedBy: "live-path-test"
        )

        let logEntries = await store.logEntries()
        XCTAssertEqual(logEntries.count, 1)
        XCTAssertEqual(logEntries.first?.scene, "88")
        XCTAssertEqual(logEntries.first?.lens, "75mm")
        XCTAssertFalse(logEntries.first?.pushedToCloudKit ?? true)

        let flushCount = await deps.syncEngine.flushInvocationCount
        XCTAssertEqual(flushCount, 1)
    }

    func testAppDependenciesDefaultEnablesSyncPipeline() throws {
        let transport = RecordingCloudKitTransport()
        let deps = try AppDependencies(
            swiftDataCloudKit: false,
            inMemory: true,
            syncTransport: transport
        )
        XCTAssertTrue(deps.syncPipelineEnabled)
    }

    func testAppDependenciesUsesInjectedMetadataProvider() throws {
        let fixed = FixedMetadataProvider(pitch: 9, roll: 8, yaw: 7)
        let deps = try AppDependencies(
            swiftDataCloudKit: false,
            inMemory: true,
            syncTransport: RecordingCloudKitTransport(),
            metadataProvider: fixed
        )
        XCTAssertEqual(deps.metadataProvider.captureContext().pitch, 9)
    }

    func testAppDependenciesUsesLiveMetadataProviderByDefault() throws {
        let deps = try AppDependencies(
            swiftDataCloudKit: false,
            inMemory: true,
            syncTransport: RecordingCloudKitTransport()
        )
        XCTAssertTrue(deps.metadataProvider is LiveMetadataProvider)
    }
}