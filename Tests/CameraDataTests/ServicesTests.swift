import XCTest
import SwiftData
import CloudKit
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
        let transport = RecordingCloudKitTransport()
        let engine = SyncEngine(transport: transport)
        _ = try? await engine.prepareZones(for: "DEMO")
        await engine.enqueueLogEntry(
            entryId: UUID(),
            syncVersion: 1,
            scene: "12",
            take: 3,
            lens: "50mm",
            iso: 800,
            productionCode: "DEMO"
        )
        await engine.enqueueLogEntry(
            entryId: UUID(),
            syncVersion: 2,
            scene: "12",
            take: 4,
            lens: "75mm",
            iso: 1280,
            productionCode: "DEMO"
        )
        let pending = await engine.pendingCount()
        XCTAssertEqual(pending, 2)
        let flushed = await engine.flushOfflineQueue()
        XCTAssertEqual(flushed, 2)
        let remaining = await engine.pendingCount()
        XCTAssertEqual(remaining, 0)
        let modifyCount = await engine.modifyRecordsInvocationCount
        XCTAssertEqual(modifyCount, 1)
        let saved = await transport.savedRecords
        XCTAssertEqual(saved.count, 2)
    }

    func testSyncEngineFlushWritesRecordsWhenZonesReady() async throws {
        let transport = RecordingCloudKitTransport()
        let engine = SyncEngine(transport: transport)
        _ = try await engine.prepareZones(for: "FLUSH01")
        await engine.enqueueLogEntry(
            entryId: UUID(),
            syncVersion: 1,
            scene: "5",
            take: 1,
            lens: "32mm",
            iso: 640,
            productionCode: "FLUSH01"
        )
        let flushed = await engine.flushOfflineQueue()
        XCTAssertEqual(flushed, 1)
        let remaining = await engine.pendingCount()
        XCTAssertEqual(remaining, 0)
        let flushCount = await engine.flushInvocationCount
        XCTAssertEqual(flushCount, 1)
        let modifyCount = await engine.modifyRecordsInvocationCount
        XCTAssertEqual(modifyCount, 1)
        let saved = await transport.savedRecords
        XCTAssertEqual(saved.count, 1)
        XCTAssertEqual(saved.first?.ckString("scene"), "5")
        XCTAssertEqual(saved.first?.ckString("lens"), "32mm")
    }

    func testLogPostSaveCoordinatorEnqueuesAndFlushes() async throws {
        let transport = RecordingCloudKitTransport()
        let engine = SyncEngine(transport: transport)
        _ = try await engine.prepareZones(for: "COORD01")
        let coordinator = LogPostSaveCoordinator(syncEngine: engine, flushAfterEnqueue: true)

        await coordinator.handle(
            entryId: UUID(),
            syncVersion: 1,
            scene: "1",
            take: 1,
            lens: "40mm",
            iso: 800,
            productionCode: "COORD01"
        )

        let flushCount = await engine.flushInvocationCount
        XCTAssertEqual(flushCount, 1)
        let modifyCount = await engine.modifyRecordsInvocationCount
        XCTAssertEqual(modifyCount, 1)
        let pending = await engine.pendingCount()
        XCTAssertEqual(pending, 0)
        let saved = await transport.savedRecords
        XCTAssertEqual(saved.count, 1)
    }

    func testSyncEngineResolvesConflictPreferRemote() async {
        let engine = SyncEngine(transport: RecordingCloudKitTransport())
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
    func testOnSetSimulationBurstLogging() async throws {
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
        let transport = RecordingCloudKitTransport()
        let syncEngine = SyncEngine(transport: transport)
        _ = try await syncEngine.prepareZones(for: production.code)
        let coordinator = LogPostSaveCoordinator(syncEngine: syncEngine, flushAfterEnqueue: true)
        let useCase = LogTakeUseCase(
            entryRepository: repo,
            postSaveCoordinator: coordinator,
            metadataProvider: FixedMetadataProvider()
        )

        var draft = LogEntryDraft(scene: "100", take: 1, lens: "50mm")
        for i in 1...50 {
            draft.take = i
            _ = try await useCase.logAndNext(
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

        let modifyCount = await syncEngine.modifyRecordsInvocationCount
        XCTAssertEqual(modifyCount, 50)
    }

    func testSyncEngineRetainsQueueWhenZonesUnavailable() async {
        let store = OfflineCloudKitRecordStore(inMemoryOnly: true)
        let engine = SyncEngine(transport: RecordingCloudKitTransport(), offlineStore: store)
        await engine.enqueueLogEntry(
            entryId: UUID(),
            syncVersion: 1,
            scene: "1",
            take: 1,
            lens: "50mm",
            iso: 800,
            productionCode: "NOZONE"
        )
        let flushed = await engine.flushOfflineQueue()
        XCTAssertEqual(flushed, 0)
        let remaining = await engine.pendingCount()
        XCTAssertEqual(remaining, 1)
        let pending = await store.pendingOperations()
        XCTAssertEqual(pending.count, 1)
    }

    func testSyncEngineRetainsQueueOnFlushFailure() async throws {
        let store = OfflineCloudKitRecordStore(inMemoryOnly: true)
        let transport = RecordingCloudKitTransport()
        await transport.setShouldFailModifyRecords(true)
        let engine = SyncEngine(transport: transport, offlineStore: store)
        _ = try await engine.prepareZones(for: "FAIL01")
        await engine.enqueueLogEntry(
            entryId: UUID(),
            syncVersion: 1,
            scene: "2",
            take: 1,
            lens: "32mm",
            iso: 640,
            productionCode: "FAIL01"
        )
        let flushed = await engine.flushOfflineQueue()
        XCTAssertEqual(flushed, 0)
        let remaining = await engine.pendingCount()
        XCTAssertEqual(remaining, 1)
        let pending = await store.pendingOperations()
        XCTAssertEqual(pending.count, 1)
    }

    func testSyncEnginePullsRemoteLogEntries() async throws {
        let transport = RecordingCloudKitTransport()
        let engine = SyncEngine(transport: transport)
        _ = try await engine.prepareZones(for: "INBOUND")

        let entryId = UUID()
        let zoneID = CKRecordZone.ID(zoneName: "Production-INBOUND-Private", ownerName: CKCurrentUserDefaultName)
        let record = CKRecord(
            recordType: "LogEntry",
            recordID: CKRecord.ID(recordName: "entry-\(entryId.uuidString)", zoneID: zoneID)
        )
        record["scene"] = "99" as CKRecordValue
        record["take"] = 7 as CKRecordValue
        record["lens"] = "40mm" as CKRecordValue
        record["syncVersion"] = 2 as CKRecordValue
        await transport.seedRemoteRecords([record])

        let remote = try await engine.pullRemoteLogEntries()
        XCTAssertEqual(remote.count, 1)
        XCTAssertEqual(remote.first?.entryId, entryId)
        XCTAssertEqual(remote.first?.draft.scene, "99")
        XCTAssertEqual(remote.first?.draft.take, 7)
    }

    func testOfflineCloudKitRecordStorePersistsAcrossInstances() async throws {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("offline-store-\(UUID().uuidString).json")
        defer { try? FileManager.default.removeItem(at: url) }

        let store1 = OfflineCloudKitRecordStore(storageURL: url)
        let zone = CKRecordZone(zoneName: "Persisted-Zone")
        await store1.persist(zones: [zone], pushedToCloudKit: false)
        await store1.setPendingOperations([
            PendingSyncOperation(entryId: UUID(), syncVersion: 1, scene: "1", take: 1)
        ])

        let store2 = OfflineCloudKitRecordStore(storageURL: url)
        let zones = await store2.zones
        XCTAssertEqual(zones.count, 1)
        let pending = await store2.pendingOperations()
        XCTAssertEqual(pending.count, 1)
        XCTAssertEqual(pending.first?.scene, "1")
    }
}