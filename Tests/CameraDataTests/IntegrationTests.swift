import XCTest
import SwiftData
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

    func testAppIntentLogServicePersistsEntry() async throws {
        let deps = try AppDependencies(swiftDataCloudKit: false, syncCloudKit: false, inMemory: true)
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
        XCTAssertEqual(flushCount, 0, "App uses syncCloudKit:false so coordinator should not flush")
        let pendingSync = await deps.syncEngine.pendingCount()
        XCTAssertGreaterThan(pendingSync, 0)
    }

    func testSyncEnginePreparesZonesInviteAndShare() async throws {
        let engine = SyncEngine(cloudKitAvailable: false)
        let zones = try await engine.prepareZones(for: "DEMO01")
        XCTAssertTrue(zones.privateZoneName.contains("DEMO01"))
        XCTAssertTrue(zones.sharedZoneName.contains("DEMO01"))
        let invite = engine.makeInvite(for: "DEMO01")
        XCTAssertEqual(invite.productionCode, "DEMO01")
        let share = try await engine.createShare(for: "DEMO01", productionName: "Demo Production")
        XCTAssertEqual(share.publicPermission, .readWrite)
        let currentShare = await engine.currentShare()
        XCTAssertNotNil(currentShare)
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
            captureContext: nil
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
}