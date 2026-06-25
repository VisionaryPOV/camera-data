import XCTest
import CameraDataDomain
import CameraDataData
import CameraDataServices
import CameraDataFeatures

@MainActor
final class VoicePipelineIntegrationTests: XCTestCase {
    func testVoicePipelineFixedCaptureMergesDraftViaApplyVoiceAudio() async throws {
        let deps = try AppDependencies(
            swiftDataCloudKit: false,
            syncPipelineEnabled: false,
            inMemory: true,
            speechTranscriber: FixedSpeechTranscriber(text: "log take 3 for scene 12 circled"),
            voiceCapture: FixedVoiceCapture(data: Data([0x01, 0x02, 0x03, 0x04]))
        )

        let result = try await VoicePipeline.captureAndApply(
            to: LogEntryDraft(),
            useCase: deps.logTakeUseCase,
            transcriber: deps.speechTranscriber,
            voiceCapture: deps.voiceCapture,
            duration: 0.15
        )

        XCTAssertEqual(result.draft.scene, "12")
        XCTAssertEqual(result.draft.take, 3)
        XCTAssertTrue(result.draft.isCircled)
        XCTAssertTrue(result.flags.contains("CIRCLED"))
    }

    func testAppDependenciesUsesLiveVoiceCaptureByDefault() throws {
        let deps = try AppDependencies(
            swiftDataCloudKit: false,
            syncPipelineEnabled: false,
            inMemory: true
        )
        XCTAssertTrue(deps.voiceCapture is LiveVoiceCapture)
    }
}