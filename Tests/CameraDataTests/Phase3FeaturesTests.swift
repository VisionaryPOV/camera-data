import XCTest
import SwiftData
@testable import CameraDataFeatures
import CameraDataDomain
import CameraDataData
import CameraDataServices

@MainActor
final class Phase3FeaturesTests: XCTestCase {
    func testSecurityPINBlocksEditorUntilUnlocked() async throws {
        let container = try ModelContainerFactory.makeInMemory()
        let context = container.mainContext
        let production = ProductionModel(name: "Secure")
        let camera = CameraUnitModel(label: "A")
        let day = ShootDayModel(dayNumber: 1)
        camera.production = production
        day.production = production
        production.cameras = [camera]
        production.days = [day]
        context.insert(production)
        try context.save()

        let repository = LogEntryRepository(context: context)
        let session = ProductionSession(isOnboarded: true)
        session.securityEnabled = true
        session.productionPIN = "2468"
        session.isUnlocked = false
        session.activeProduction = production
        session.selectedCamera = camera
        session.selectedDay = day

        let viewModel = EntryEditorViewModel(
            useCase: LogTakeUseCase(
                entryRepository: repository,
                postSaveCoordinator: LogPostSaveCoordinator(
                    syncEngine: SyncEngine(transport: RecordingCloudKitTransport())
                ),
                metadataProvider: FixedMetadataProvider()
            ),
            session: session,
            entryRepository: repository
        )

        XCTAssertFalse(viewModel.canEdit)
        XCTAssertTrue(SecurityService.validatePIN("2468", expected: session.productionPIN))
        session.isUnlocked = true
        XCTAssertTrue(viewModel.canEdit)
    }

    func testAppDependenciesUsesSpeechFrameworkTranscriberByDefault() throws {
        let deps = try AppDependencies(swiftDataCloudKit: false, syncPipelineEnabled: false, inMemory: true)
        XCTAssertTrue(deps.speechTranscriber is SpeechFrameworkTranscriber)
    }

    func testEnablingSecurityLocksSessionImmediately() {
        let session = ProductionSession()
        session.isUnlocked = true
        session.securityEnabled = true
        session.persistSecuritySettings()
        XCTAssertFalse(session.isUnlocked)
        session.securityEnabled = false
        session.persistSecuritySettings()
        XCTAssertTrue(session.isUnlocked)
    }

    func testAuditRestoreServiceRestoresLensValue() throws {
        let container = try ModelContainerFactory.makeInMemory()
        let context = container.mainContext
        let production = ProductionModel(name: "Audit")
        let camera = CameraUnitModel(label: "A")
        let day = ShootDayModel(dayNumber: 1)
        camera.production = production
        day.production = production
        production.cameras = [camera]
        production.days = [day]
        context.insert(production)
        try context.save()

        let audit = AuditService()
        let repository = LogEntryRepository(context: context, auditService: audit)
        var draft = LogEntryDraft(scene: "8", take: 1, lens: "50mm")
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

        draft.lens = "75mm"
        _ = try repository.save(
            draft: draft,
            production: production,
            camera: camera,
            day: day,
            existing: saved,
            modifiedBy: "tester",
            captureContext: nil,
            preferredId: nil
        )

        let restored = try AuditRestoreService.restore(
            entry: saved,
            field: "lens",
            value: "50mm",
            repository: repository,
            modifiedBy: "tester"
        )

        XCTAssertEqual(restored.lens, "50mm")
        XCTAssertGreaterThan(restored.auditTrail.count, 1)

        let restoredLatest = try AuditRestoreService.restore(
            entry: restored,
            field: "lens",
            value: "75mm",
            repository: repository,
            modifiedBy: "tester"
        )
        XCTAssertEqual(restoredLatest.lens, "75mm")
    }

    func testMakePersistentRecoversFromCorruptStoreFile() throws {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("corrupt-\(UUID().uuidString).store")
        try Data("CORRUPT".utf8).write(to: url)

        let container = try ModelContainerFactory.makePersistent(storeURL: url)
        let context = container.mainContext
        let production = ProductionModel(name: "Recovered")
        context.insert(production)
        try context.save()

        XCTAssertTrue(FileManager.default.fileExists(atPath: url.path))
        let fetched = try context.fetch(FetchDescriptor<ProductionModel>())
        XCTAssertEqual(fetched.first?.name, "Recovered")
    }

    func testEntryEditorFocusIncludesRichMetadataFields() {
        let labels = Set(EntryEditorFocus.allCases.map(\.label))
        XCTAssertTrue(labels.contains("TC In"))
        XCTAssertTrue(labels.contains("Resolution"))
        XCTAssertTrue(labels.contains("Codec"))
        XCTAssertTrue(labels.contains("Duration"))
        XCTAssertTrue(labels.contains("Shutter °"))
    }
}