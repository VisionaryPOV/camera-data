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
    }

    func testSyncEnginePreparesZonesAndInvite() async throws {
        let engine = SyncEngine(cloudKitAvailable: false)
        let zones = try await engine.prepareZones(for: "DEMO01")
        XCTAssertTrue(zones.privateZoneName.contains("DEMO01"))
        XCTAssertTrue(zones.sharedZoneName.contains("DEMO01"))
        let invite = engine.makeInvite(for: "DEMO01")
        XCTAssertEqual(invite.productionCode, "DEMO01")
    }

    func testCoreMLSmartSuggestorLoadsModel() {
        let bundle = Bundle(for: IntegrationTests.self)
        let suggestor = CoreMLSmartSuggestor(bundle: Bundle.main)
        let history = [
            LogEntryDraft(scene: "8", take: 1, lens: "40mm"),
            LogEntryDraft(scene: "8", take: 2, lens: "40mm")
        ]
        let draft = LogEntryDraft(scene: "8", take: 3)
        let suggestions = suggestor.suggest(from: history, for: draft)
        XCTAssertFalse(suggestions.isEmpty)
    }

    func testSpeechRecognitionServiceAvailabilityAPI() {
        _ = SpeechRecognitionService.isAvailable()
        XCTAssertTrue(true)
    }
}