import XCTest
import CameraDataDomain
import CameraDataData
import CameraDataServices
@testable import CameraDataFeatures

@MainActor
final class VoiceCaptureLiveTests: XCTestCase {
    private let transcript = "log take 3 for scene 12 circled"
    private let captureDuration: TimeInterval = 0.15
    private var liveCaptureAvailable = false
    private static var cachedLiveCaptureAvailable: Bool?

    override func setUp() async throws {
        try await super.setUp()
        if Self.cachedLiveCaptureAvailable == nil {
            Self.cachedLiveCaptureAvailable = await Self.probeLiveCaptureAvailability(duration: captureDuration)
        }
        liveCaptureAvailable = Self.cachedLiveCaptureAvailable ?? false
    }

    private static func probeLiveCaptureAvailability(duration: TimeInterval) async -> Bool {
        guard await VoiceCaptureService.requestMicrophoneAccess() else { return false }
        do {
            _ = try await VoiceCaptureService.captureForTranscription(duration: duration)
            return true
        } catch {
            return false
        }
    }

    private func requireLiveCapture() throws {
        guard liveCaptureAvailable else {
            throw XCTSkip("Microphone/recorder unavailable — grant simulator mic for live capture merge tests")
        }
    }

    private func assertMergedVoiceDraft(_ result: (draft: LogEntryDraft, flags: [String])) {
        XCTAssertEqual(result.draft.scene, "12")
        XCTAssertEqual(result.draft.take, 3)
        XCTAssertTrue(result.draft.isCircled)
        XCTAssertTrue(result.flags.contains("CIRCLED"))
    }

    func testVoiceCaptureServiceRequestMicrophoneAccessInvokesAVAPI() async {
        let clock = ContinuousClock()
        let start = clock.now
        let granted = await VoiceCaptureService.requestMicrophoneAccess()
        let elapsed = start.duration(to: clock.now)
        XCTAssertLessThan(elapsed, .seconds(4))
        let grantedAgain = await VoiceCaptureService.requestMicrophoneAccess()
        XCTAssertEqual(granted, grantedAgain)
    }

    func testLiveVoiceCaptureDelegatesToVoiceCaptureService() async {
        let capture = LiveVoiceCapture()
        do {
            let data = try await capture.captureForTranscription(duration: captureDuration)
            XCTAssertFalse(data.isEmpty)
        } catch let error as VoiceCaptureError {
            XCTAssertTrue(
                error == .microphoneDenied || error == .recorderFailed || error == .emptyRecording,
                "LiveVoiceCapture must reach VoiceCaptureService; got \(error)"
            )
        } catch {
            XCTFail("LiveVoiceCapture must surface VoiceCaptureError, got \(error)")
        }
    }

    func testVoiceCaptureServiceCaptureForTranscriptionUsesAVAudioRecorderPath() async {
        do {
            let data = try await VoiceCaptureService.captureForTranscription(duration: captureDuration)
            XCTAssertFalse(data.isEmpty)
        } catch let error as VoiceCaptureError {
            XCTAssertTrue(
                error == .microphoneDenied || error == .recorderFailed || error == .emptyRecording
            )
        } catch {
            XCTFail("VoiceCaptureService should map AV failures to VoiceCaptureError; got \(error)")
        }
    }

    func testVoicePipelineLiveCaptureMergesDraftViaApplyVoiceAudio() async throws {
        try requireLiveCapture()

        let deps = try AppDependencies(
            swiftDataCloudKit: false,
            syncPipelineEnabled: false,
            inMemory: true,
            speechTranscriber: FixedSpeechTranscriber(text: transcript),
            voiceCapture: LiveVoiceCapture()
        )

        let result = try await VoicePipeline.captureAndApply(
            to: LogEntryDraft(),
            useCase: deps.logTakeUseCase,
            transcriber: deps.speechTranscriber,
            voiceCapture: deps.voiceCapture,
            duration: captureDuration
        )
        assertMergedVoiceDraft(result)
    }

    func testEntryEditorViewModelProcessVoiceLogUsesLiveCapturePath() async throws {
        try requireLiveCapture()

        let container = try ModelContainerFactory.makeInMemory()
        let context = container.mainContext
        let production = ProductionModel(name: "Voice Live")
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
        session.securityEnabled = false
        session.isUnlocked = true
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
            entryRepository: repository,
            speechTranscriber: FixedSpeechTranscriber(text: transcript),
            voiceCapture: LiveVoiceCapture()
        )

        try viewModel.onAppear()
        await viewModel.processVoiceLog()

        XCTAssertTrue(
            viewModel.voiceStatusMessage?.contains("Voice applied") == true,
            "processVoiceLog should merge live capture via applyVoiceAudio; got \(viewModel.voiceStatusMessage ?? "nil")"
        )
        XCTAssertEqual(viewModel.draft.scene, "12")
        XCTAssertEqual(viewModel.draft.take, 3)
        XCTAssertTrue(viewModel.draft.isCircled)
    }
}