import XCTest
import SwiftData
@testable import CameraDataFeatures
import CameraDataDomain
import CameraDataData
import CameraDataServices

@MainActor
final class EntryEditorViewModelTests: XCTestCase {
    private func unlockedSession() -> ProductionSession {
        let session = ProductionSession(isOnboarded: true)
        session.securityEnabled = false
        session.isUnlocked = true
        return session
    }

    private func makeViewModel() throws -> EntryEditorViewModel {
        let container = try ModelContainerFactory.makeInMemory()
        let context = container.mainContext
        let production = ProductionModel(name: "Test")
        let camera = CameraUnitModel(label: "A")
        let day = ShootDayModel(dayNumber: 1)
        camera.production = production
        day.production = production
        production.cameras = [camera]
        production.days = [day]
        context.insert(production)
        try context.save()

        let repository = LogEntryRepository(context: context)
        let session = unlockedSession()
        session.activeProduction = production
        session.selectedCamera = camera
        session.selectedDay = day

        return EntryEditorViewModel(
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
    }

    func testAlphabeticKeypadEntersMixedSceneValue() async throws {
        let viewModel = try makeViewModel()
        try viewModel.onAppear()
        viewModel.focus(.scene)
        viewModel.toggleInputMode()
        viewModel.inputKey("2")
        viewModel.inputKey("4")
        viewModel.inputKey("A")
        XCTAssertEqual(viewModel.draft.scene, "24A")
    }

    func testAlphabeticKeypadEntersTimecodeColon() async throws {
        let viewModel = try makeViewModel()
        try viewModel.onAppear()
        viewModel.focus(.timecodeIn)
        viewModel.toggleInputMode()
        viewModel.inputKey("1")
        viewModel.inputKey(":")
        viewModel.inputKey("0")
        viewModel.inputKey("0")
        XCTAssertEqual(viewModel.draft.timecodeIn, "1:00")
    }

    func testDraftPersistsOnSameViewModelInstance() async throws {
        let viewModel = try makeViewModel()
        try viewModel.onAppear()
        viewModel.focus(.scene)
        viewModel.inputKey("1")
        viewModel.inputKey("8")
        XCTAssertEqual(viewModel.draft.scene, "18")
        viewModel.inputKey("A")
        XCTAssertEqual(viewModel.draft.scene, "18A")
    }

    func testToggleInputModeSwitchesBetweenKeypadAndKeyboard() async throws {
        let container = try ModelContainerFactory.makeInMemory()
        let context = container.mainContext
        let production = ProductionModel(name: "Test")
        let camera = CameraUnitModel(label: "A")
        let day = ShootDayModel(dayNumber: 1)
        camera.production = production
        day.production = production
        production.cameras = [camera]
        production.days = [day]
        context.insert(production)
        try context.save()

        let repository = LogEntryRepository(context: context)
        let session = unlockedSession()
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

        try viewModel.onAppear()
        XCTAssertEqual(viewModel.inputMode, .keypad)

        viewModel.toggleInputMode()
        XCTAssertEqual(viewModel.inputMode, .keyboard)

        viewModel.inputKey("G")
        XCTAssertEqual(viewModel.draft.scene, "G")

        viewModel.toggleInputMode()
        XCTAssertEqual(viewModel.inputMode, .keypad)
    }

    func testRollNumberHelperIncrements() {
        XCTAssertEqual(RollNumberHelper.increment("A27"), "A28")
        XCTAssertEqual(RollNumberHelper.increment("C1"), "C2")
        XCTAssertEqual(RollNumberHelper.increment("A027"), "A028")
        XCTAssertEqual(RollNumberHelper.increment(""), "A001")
    }

    func testFocusedInputRoutesToRollNumber() async throws {
        let container = try ModelContainerFactory.makeInMemory()
        let context = container.mainContext
        let production = ProductionModel(name: "Test")
        let camera = CameraUnitModel(label: "A")
        let day = ShootDayModel(dayNumber: 1)
        camera.production = production
        day.production = production
        production.cameras = [camera]
        production.days = [day]
        context.insert(production)
        try context.save()

        let repository = LogEntryRepository(context: context)
        let session = unlockedSession()
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

        try viewModel.onAppear()
        viewModel.focus(.rollNumber)
        viewModel.inputKey("A")
        viewModel.inputKey("2")
        viewModel.inputKey("7")
        XCTAssertEqual(viewModel.draft.rollNumber, "A27")

        viewModel.deleteBackward()
        XCTAssertEqual(viewModel.draft.rollNumber, "A2")

        viewModel.advanceRollNumber()
        XCTAssertEqual(viewModel.draft.rollNumber, "A3")
    }

    func testPrefilledTakeUsesReplaceModeForFirstDigit() async throws {
        let container = try ModelContainerFactory.makeInMemory()
        let context = container.mainContext
        let production = ProductionModel(name: "Test")
        let camera = CameraUnitModel(label: "A")
        let day = ShootDayModel(dayNumber: 1)
        camera.production = production
        day.production = production
        production.cameras = [camera]
        production.days = [day]
        context.insert(production)
        try context.save()

        let repository = LogEntryRepository(context: context)
        let session = unlockedSession()
        session.slateTake = 5
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

        try viewModel.onAppear()
        XCTAssertEqual(viewModel.draft.take, 5)
        viewModel.focus(.take)
        XCTAssertEqual(viewModel.displayValue(for: .take), "5")
        viewModel.inputKey("2")
        XCTAssertEqual(viewModel.draft.take, 2)
        viewModel.inputKey("1")
        XCTAssertEqual(viewModel.draft.take, 21)
    }

    func testDeleteBackwardOnTake() async throws {
        let container = try ModelContainerFactory.makeInMemory()
        let context = container.mainContext
        let production = ProductionModel(name: "Test")
        let camera = CameraUnitModel(label: "A")
        let day = ShootDayModel(dayNumber: 1)
        camera.production = production
        day.production = production
        production.cameras = [camera]
        production.days = [day]
        context.insert(production)
        try context.save()

        let repository = LogEntryRepository(context: context)
        let session = unlockedSession()
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

        try viewModel.onAppear()
        viewModel.draft.take = 0
        viewModel.focus(.take)
        viewModel.inputKey("1")
        viewModel.inputKey("2")
        XCTAssertEqual(viewModel.draft.take, 12)
        viewModel.deleteBackward()
        XCTAssertEqual(viewModel.draft.take, 1)
        viewModel.deleteBackward()
        XCTAssertEqual(viewModel.draft.take, 0)
    }
}