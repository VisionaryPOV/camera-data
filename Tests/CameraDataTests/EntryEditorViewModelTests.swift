import XCTest
import SwiftData
@testable import CameraDataFeatures
import CameraDataDomain
import CameraDataData
import CameraDataServices

@MainActor
final class EntryEditorViewModelTests: XCTestCase {
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
        let session = ProductionSession(isOnboarded: true)
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
        let session = ProductionSession(isOnboarded: true)
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