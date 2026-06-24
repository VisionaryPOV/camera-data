import XCTest
import SwiftData
import CameraDataData
import CameraDataDomain
import CameraDataServices

final class ServicesTests: XCTestCase {
    func testExportServiceCSVContainsHeaderAndRow() {
        let entries = [LogEntryDraft(scene: "4", take: 2, lens: "40mm", iso: 500)]
        let data = ExportService.csvData(from: entries)
        let text = String(decoding: data, as: UTF8.self)
        XCTAssertTrue(text.contains("Scene,Take,Lens"))
        XCTAssertTrue(text.contains("4,2,40mm"))
    }

    func testExportServiceJSONParses() throws {
        let entries = [LogEntryDraft(scene: "9", take: 1, lens: "65mm")]
        let data = ExportService.jsonData(from: entries)
        let json = try JSONSerialization.jsonObject(with: data) as? [[String: Any]]
        XCTAssertEqual(json?.first?["scene"] as? String, "9")
        XCTAssertEqual(json?.first?["lens"] as? String, "65mm")
    }

    func testExportServicePDFGeneratesBytes() {
        let entries = [LogEntryDraft(scene: "1", take: 1, lens: "50mm")]
        let branding = ExportBranding(productionName: "Night Shoot")
        let data = ExportService.pdfData(from: entries, branding: branding)
        XCTAssertGreaterThan(data.count, 100)
        XCTAssertEqual(String(data: data.prefix(4), encoding: .ascii), "%PDF")
    }

    func testSyncEngineQueuesAndFlushes() async {
        let engine = SyncEngine(cloudKitAvailable: true)
        await engine.enqueue(entryId: UUID(), syncVersion: 1)
        await engine.enqueue(entryId: UUID(), syncVersion: 2)
        let pending = await engine.pendingCount()
        XCTAssertEqual(pending, 2)
        let flushed = await engine.flushOfflineQueue()
        XCTAssertEqual(flushed, 2)
        let remaining = await engine.pendingCount()
        XCTAssertEqual(remaining, 0)
    }

    func testSyncEngineResolvesConflictPreferRemote() async {
        let engine = SyncEngine()
        let local = LogEntryDraft(scene: "1", take: 1, lens: "50mm")
        let remote = LogEntryDraft(scene: "1", take: 1, lens: "75mm")
        let merged = await engine.resolveConflict(local: local, remote: remote, preferRemote: true)
        XCTAssertEqual(merged.lens, "75mm")
    }

    func testPresenceServiceHeartbeat() async {
        let service = PresenceService()
        await service.heartbeat(userId: "u1", displayName: "Sarah", editingEntryLabel: "Take 4")
        let label = await service.presenceLabel(for: "u1")
        XCTAssertEqual(label, "Sarah is editing Take 4")
    }

    func testVoiceLoggingServiceProcessesTranscript() {
        let (draft, flags) = VoiceLoggingService.processTranscript("take 5 scene 3 circled")
        XCTAssertEqual(draft.scene, "3")
        XCTAssertEqual(draft.take, 5)
        XCTAssertTrue(draft.isCircled)
        XCTAssertTrue(flags.contains("CIRCLED"))
    }

    func testFrameIOExportHookPayload() throws {
        let entries = [LogEntryDraft(scene: "1", take: 1)]
        let payload = FrameIOExportHook.buildPayload(
            productionName: "Show",
            entries: entries,
            format: .json,
            webhookURL: "https://example.com/hook"
        )
        let data = try FrameIOExportHook.encode(payload)
        let decoded = try JSONDecoder().decode(FrameIOExportPayload.self, from: data)
        XCTAssertEqual(decoded.productionName, "Show")
        XCTAssertEqual(decoded.entryCount, 1)
    }

    func testMetadataCaptureServiceBuildsContext() {
        let context = MetadataCaptureService.captureContext(
            location: nil,
            motion: DeviceMotionSnapshot(pitch: 1, roll: 2, yaw: 3)
        )
        XCTAssertEqual(context.pitch, 1)
        XCTAssertEqual(context.roll, 2)
    }

    @MainActor
    func testOnSetSimulationBurstLogging() throws {
        let container = try ModelContainerFactory.makeInMemory()
        let context = container.mainContext
        let production = ProductionModel(name: "Burst Test")
        let camera = CameraUnitModel(label: "A")
        let day = ShootDayModel(dayNumber: 1)
        camera.production = production
        day.production = production
        context.insert(production)
        context.insert(camera)
        context.insert(day)

        let repo = LogEntryRepository(context: context)
        let useCase = LogTakeUseCase(entryRepository: repo)

        var draft = LogEntryDraft(scene: "100", take: 1, lens: "50mm")
        for i in 1...50 {
            draft.take = i
            _ = try useCase.logAndNext(
                draft: draft,
                production: production,
                camera: camera,
                day: day,
                existing: nil,
                modifiedBy: "burst"
            )
            draft = LogEntryDraft(scene: "100", take: i + 1, lens: "50mm")
        }

        let fetched = try repo.fetchEntries(
            production: production,
            camera: camera,
            day: day,
            limit: 100,
            offset: 0
        )
        XCTAssertEqual(fetched.count, 50)
    }
}