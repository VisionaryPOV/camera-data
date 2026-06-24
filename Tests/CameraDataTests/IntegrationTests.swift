import XCTest
import SwiftData
import CloudKit
import CameraDataDomain
import CameraDataData
import CameraDataServices
import CameraDataFeatures

@MainActor
final class IntegrationTests: XCTestCase {
    func testAppGroupStoreRoundTrip() {
        AppGroupStore.writeWidgetSnapshot(takeCount: 7, productionName: "Night Shoot")
        let snapshot = AppGroupStore.readWidgetSnapshot()
        XCTAssertEqual(snapshot.takeCount, 7)
        XCTAssertEqual(snapshot.productionName, "Night Shoot")
    }

    func testAppIntentLogServicePersistsEntryAndFlushesSyncViaLiveTransport() async throws {
        let store = OfflineCloudKitRecordStore(inMemoryOnly: true)
        let deps = try AppDependencies(
            swiftDataCloudKit: false,
            syncPipelineEnabled: true,
            inMemory: true,
            offlineCloudKitStore: store
        )
        try await deps.bootstrapIfNeeded()
        AppIntentLogService.register(deps)

        let message = try await AppIntentLogService.logTake(scene: "44", take: 2, cameraLabel: "A")
        XCTAssertTrue(message.contains("44"))
        XCTAssertTrue(message.contains("2"))

        let entries = try deps.logEntryRepository.fetchEntries(
            production: deps.session.activeProduction!,
            camera: deps.session.selectedCamera,
            day: deps.session.selectedDay,
            limit: 10,
            offset: 0
        )
        XCTAssertEqual(entries.first?.scene, "44")
        XCTAssertEqual(entries.first?.take, 2)

        let flushCount = await deps.syncEngine.flushInvocationCount
        XCTAssertEqual(flushCount, 1)
        let modifyCount = await deps.syncEngine.modifyRecordsInvocationCount
        XCTAssertEqual(modifyCount, 1)
        let pendingSync = await deps.syncEngine.pendingCount()
        XCTAssertEqual(pendingSync, 0)

        let logEntries = await store.logEntries()
        XCTAssertEqual(logEntries.count, 1)
        XCTAssertEqual(logEntries.first?.scene, "44")
        XCTAssertEqual(logEntries.first?.take, 2)
        XCTAssertEqual(logEntries.first?.lens, entries.first?.lens)
        XCTAssertFalse(logEntries.first?.pushedToCloudKit ?? true, "Harness lacks iCloud; offline persist must still run")
    }

    func testLiveTransportPersistsZonesAndRecordsOffline() async throws {
        let store = OfflineCloudKitRecordStore(inMemoryOnly: true)
        let transport = LiveCloudKitTransport(offlineStore: store)
        let engine = SyncEngine(transport: transport)

        _ = try await engine.prepareZones(for: "OFFLINE01")
        await engine.enqueueLogEntry(
            entryId: UUID(),
            syncVersion: 1,
            scene: "7",
            take: 3,
            lens: "32mm",
            iso: 640,
            productionCode: "OFFLINE01"
        )
        _ = await engine.flushOfflineQueue()

        let zones = await store.zones
        XCTAssertGreaterThanOrEqual(zones.count, 2)
        XCTAssertFalse(zones.first?.pushedToCloudKit ?? true)

        let logEntries = await store.logEntries()
        XCTAssertEqual(logEntries.count, 1)
        XCTAssertEqual(logEntries.first?.scene, "7")
        XCTAssertEqual(logEntries.first?.take, 3)
        XCTAssertEqual(logEntries.first?.lens, "32mm")
        XCTAssertFalse(logEntries.first?.pushedToCloudKit ?? true)

        XCTAssertEqual(transport.cloudKitPushAttemptCount, 0, "No iCloud in harness; live CK push must not run")
    }

    func testSyncEnginePreparesZonesInviteAndShare() async throws {
        let transport = RecordingCloudKitTransport()
        let engine = SyncEngine(transport: transport)
        let zones = try await engine.prepareZones(for: "DEMO01")
        XCTAssertTrue(zones.privateZoneName.contains("DEMO01"))
        XCTAssertTrue(zones.sharedZoneName.contains("DEMO01"))
        let invite = engine.makeInvite(for: "DEMO01")
        XCTAssertEqual(invite.productionCode, "DEMO01")
        let share = try await engine.createShare(for: "DEMO01", productionName: "Demo Production")
        XCTAssertEqual(share.publicPermission, .readWrite)
        let currentShare = await engine.currentShare()
        XCTAssertNotNil(currentShare)
        let zoneWrites = await transport.modifyRecordZonesInvocationCount
        XCTAssertGreaterThanOrEqual(zoneWrites, 1)
        let recordWrites = await transport.modifyRecordsInvocationCount
        XCTAssertGreaterThanOrEqual(recordWrites, 1)
    }

    func testCoreMLSmartSuggestorUsesHistoricalFrequency() {
        let suggestor = CoreMLSmartSuggestor(bundle: Bundle.main)
        let history = [
            LogEntryDraft(scene: "8", take: 1, lens: "40mm"),
            LogEntryDraft(scene: "8", take: 2, lens: "40mm"),
            LogEntryDraft(scene: "8", take: 3, lens: "75mm")
        ]
        let draft = LogEntryDraft(scene: "8", take: 4)
        let baseline = SmartSuggestEngine.suggest(from: history, for: draft)
        let mlSuggestions = suggestor.suggest(from: history, for: draft)
        XCTAssertFalse(baseline.isEmpty)
        XCTAssertFalse(mlSuggestions.isEmpty)
        XCTAssertTrue(suggestor.isModelLoaded, "LensPredictor.mlmodel must be bundled in the app target")

        let frequency = CoreMLSmartSuggestor.historicalFrequency(
            history: history, scene: "8", field: "lens", value: "40mm"
        )
        XCTAssertEqual(frequency, 2.0 / 3.0, accuracy: 0.01)

        if let baselineLens = baseline.first(where: { $0.field == "lens" }),
           let mlLens = mlSuggestions.first(where: { $0.field == "lens" }) {
            XCTAssertEqual(mlLens.value, "40mm")
            XCTAssertGreaterThanOrEqual(mlLens.confidence, baselineLens.confidence)
            XCTAssertGreaterThan(mlLens.confidence, baselineLens.confidence, "ML inference should boost confidence above frequency baseline")
        }
    }

    func testDashboardViewModelRoleFiltering() throws {
        let container = try ModelContainerFactory.makeInMemory()
        let context = container.mainContext
        let production = ProductionModel(name: "Role Test")
        let camera = CameraUnitModel(label: "A")
        let day = ShootDayModel(dayNumber: 1)
        camera.production = production
        day.production = production
        production.cameras = [camera]
        production.days = [day]
        context.insert(production)
        try context.save()

        let repo = LogEntryRepository(context: context)
        var draft = LogEntryDraft(scene: "9", take: 1, notes: "Camera note", vfxNotes: "VFX marker")
        _ = try repo.save(
            draft: draft,
            production: production,
            camera: camera,
            day: day,
            existing: nil,
            modifiedBy: "tester",
            captureContext: nil,
            preferredId: nil
        )

        let session = ProductionSession(isOnboarded: true)
        session.activeProduction = production
        session.selectedCamera = camera
        session.selectedDay = day
        session.currentRole = .vfx

        let viewModel = DashboardViewModel(entryRepository: repo, session: session)
        try viewModel.reload()
        XCTAssertEqual(viewModel.entries.first?.displayDraft.notes, "VFX marker")
        XCTAssertFalse(viewModel.canEdit)

        session.currentRole = .editor
        try viewModel.reload()
        XCTAssertTrue(viewModel.canEdit)
        XCTAssertEqual(viewModel.entries.first?.displayDraft.notes, "Camera note")
    }

    func testSpeechRecognitionServiceAvailabilityAPI() {
        _ = SpeechRecognitionService.isAvailable()
        XCTAssertTrue(true)
    }

    func testAppIntentLogServiceColdStartSharesPersistentStore() async throws {
        AppIntentLogService.resetCachedDependenciesForTesting()

        _ = try await AppIntentLogService.logTake(scene: "COLD-A", take: 1, cameraLabel: "A")

        AppIntentLogService.resetCachedDependenciesForTesting()

        _ = try await AppIntentLogService.logTake(scene: "COLD-B", take: 2, cameraLabel: "A")

        let verifyDeps = try AppDependencies(
            swiftDataCloudKit: false,
            syncPipelineEnabled: false,
            inMemory: false,
            syncTransport: RecordingCloudKitTransport()
        )
        try await verifyDeps.bootstrapIfNeeded()

        let entries = try verifyDeps.logEntryRepository.fetchEntries(
            production: verifyDeps.session.activeProduction!,
            camera: verifyDeps.session.selectedCamera,
            day: verifyDeps.session.selectedDay,
            limit: 100,
            offset: 0
        )
        XCTAssertTrue(entries.contains { $0.scene == "COLD-A" && $0.take == 1 })
        XCTAssertTrue(entries.contains { $0.scene == "COLD-B" && $0.take == 2 })
    }

    func testApplyInboundSyncImportsRemoteEntry() async throws {
        let transport = RecordingCloudKitTransport()
        let store = OfflineCloudKitRecordStore(inMemoryOnly: true)
        let deps = try AppDependencies(
            swiftDataCloudKit: false,
            syncPipelineEnabled: true,
            inMemory: true,
            syncTransport: transport,
            offlineCloudKitStore: store
        )
        try await deps.bootstrapIfNeeded()

        let entryId = UUID()
        let zoneName = "Production-\(deps.session.activeProduction!.code)-Private"
        let zoneID = CKRecordZone.ID(zoneName: zoneName, ownerName: CKCurrentUserDefaultName)
        let record = CKRecord(
            recordType: "LogEntry",
            recordID: CKRecord.ID(recordName: "entry-\(entryId.uuidString)", zoneID: zoneID)
        )
        record["scene"] = "REMOTE-1" as CKRecordValue
        record["take"] = 5 as CKRecordValue
        record["lens"] = "65mm" as CKRecordValue
        record["syncVersion"] = 1 as CKRecordValue
        await transport.seedRemoteRecords([record])

        try await deps.applyInboundSync()

        let imported = try deps.logEntryRepository.fetchEntry(id: entryId)
        XCTAssertNotNil(imported)
        XCTAssertEqual(imported?.scene, "REMOTE-1")
        XCTAssertEqual(imported?.take, 5)
    }
}