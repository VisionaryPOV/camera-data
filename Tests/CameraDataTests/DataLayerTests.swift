import XCTest
import SwiftData
@testable import CameraDataData
@testable import CameraDataDomain
@testable import CameraDataServices

@MainActor
final class DataLayerTests: XCTestCase {
    private var container: ModelContainer!
    private var context: ModelContext!
    private var production: ProductionModel!
    private var camera: CameraUnitModel!
    private var day: ShootDayModel!
    private var repository: LogEntryRepository!

    override func setUp() async throws {
        container = try ModelContainerFactory.makeInMemory()
        context = container.mainContext
        production = ProductionModel(name: "Test Show")
        camera = CameraUnitModel(label: "A")
        day = ShootDayModel(dayNumber: 1)
        camera.production = production
        day.production = production
        production.cameras = [camera]
        production.days = [day]
        context.insert(production)
        try context.save()

        repository = LogEntryRepository(context: context, auditService: AuditService())
    }

    func testLogEntryRoundTripSaveAndFetch() throws {
        var draft = LogEntryDraft(scene: "15", take: 1, lens: "32mm", iso: 640)
        let saved = try repository.save(
            draft: draft,
            production: production,
            camera: camera,
            day: day,
            existing: nil,
            modifiedBy: "tester",
            captureContext: nil,
            preferredId: nil
        )

        XCTAssertEqual(saved.scene, "15")
        XCTAssertEqual(saved.sortKey, SortKeyGenerator.make(scene: "15", take: 1))
        XCTAssertEqual(saved.syncVersion, 1)

        let fetched = try repository.fetchEntries(
            production: production,
            camera: camera,
            day: day,
            limit: 10,
            offset: 0
        )
        XCTAssertEqual(fetched.count, 1)
        XCTAssertEqual(LogEntryMapper.toDraft(fetched[0]).lens, "32mm")
    }

    func testLogTakeUseCaseLogAndNextIncrementsTake() async throws {
        let transport = RecordingCloudKitTransport()
        let syncEngine = SyncEngine(transport: transport)
        _ = try await syncEngine.prepareZones(for: production.code)
        let coordinator = LogPostSaveCoordinator(syncEngine: syncEngine, flushAfterEnqueue: true)
        let metadata = FixedMetadataProvider(pitch: 1.5, roll: 2.5, yaw: 3.5)
        let useCase = LogTakeUseCase(
            entryRepository: repository,
            postSaveCoordinator: coordinator,
            metadataProvider: metadata
        )
        var draft = LogEntryDraft(scene: "20", take: 1, lens: "50mm")
        let first = try await useCase.logAndNext(
            draft: draft,
            production: production,
            camera: camera,
            day: day,
            existing: nil,
            modifiedBy: "tester"
        )
        XCTAssertEqual(first.saved.take, 1)
        XCTAssertEqual(first.saved.pitch, 1.5)
        let flushAfterFirst = await syncEngine.flushInvocationCount
        XCTAssertEqual(flushAfterFirst, 1)

        draft = LogEntryDraft(scene: "20", take: 2, lens: "50mm")
        let second = try await useCase.logAndNext(
            draft: draft,
            production: production,
            camera: camera,
            day: day,
            existing: nil,
            modifiedBy: "tester"
        )
        XCTAssertEqual(second.saved.take, 2)
        XCTAssertEqual(second.nextDraft.take, 3)
        let flushAfterSecond = await syncEngine.flushInvocationCount
        XCTAssertEqual(flushAfterSecond, 2)

        let modifyCount = await syncEngine.modifyRecordsInvocationCount
        XCTAssertEqual(modifyCount, 2)

        let savedRecords = await transport.savedRecords
        XCTAssertEqual(savedRecords.count, 2)
    }

    func testFetchEntriesScopesToProduction() throws {
        let otherProduction = ProductionModel(name: "Other Show")
        let otherCamera = CameraUnitModel(label: "B")
        otherCamera.production = otherProduction
        otherProduction.cameras = [otherCamera]
        context.insert(otherProduction)
        try context.save()

        _ = try repository.save(
            draft: LogEntryDraft(scene: "1", take: 1),
            production: production,
            camera: camera,
            day: day,
            existing: nil,
            modifiedBy: "tester",
            captureContext: nil,
            preferredId: nil
        )
        _ = try repository.save(
            draft: LogEntryDraft(scene: "2", take: 1),
            production: otherProduction,
            camera: otherCamera,
            day: day,
            existing: nil,
            modifiedBy: "tester",
            captureContext: nil,
            preferredId: nil
        )

        let scoped = try repository.fetchEntries(
            production: production,
            camera: nil,
            day: nil,
            limit: 100,
            offset: 0
        )
        XCTAssertEqual(scoped.count, 1)
        XCTAssertEqual(scoped.first?.scene, "1")
    }

    func testProductionTemplateCloneCopiesCamerasAndFields() throws {
        let field = CustomFieldDefinitionModel(key: "filter2", label: "Filter 2", fieldType: .text)
        field.production = production
        production.customFields = [field]
        try context.save()

        let templateRepo = ProductionTemplateRepository(context: context)
        let clone = try templateRepo.cloneProduction(from: production, newName: "Clone")
        XCTAssertEqual(clone.cameras.count, 1)
        XCTAssertEqual(clone.customFields.count, 1)
        XCTAssertEqual(clone.name, "Clone")
    }

    func testAuditServiceRecordsFieldChanges() throws {
        var draft = LogEntryDraft(scene: "3", take: 1, lens: "25mm")
        let entry = try repository.save(
            draft: draft,
            production: production,
            camera: camera,
            day: day,
            existing: nil,
            modifiedBy: "tester",
            captureContext: nil,
            preferredId: nil
        )

        draft.lens = "32mm"
        draft.iso = 1600
        _ = try repository.save(
            draft: draft,
            production: production,
            camera: camera,
            day: day,
            existing: entry,
            modifiedBy: "tester",
            captureContext: nil,
            preferredId: nil
        )

        let history = AuditService.history(for: entry)
        XCTAssertTrue(history.contains { $0.field == "lens" && $0.new == "32mm" })
    }
}