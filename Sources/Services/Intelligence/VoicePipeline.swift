import Foundation
import CameraDataDomain

@MainActor
public enum VoicePipeline {
    public typealias CaptureProvider = @Sendable () async throws -> Data

    public static func captureAndApply(
        to draft: LogEntryDraft,
        useCase: LogTakeUseCase,
        transcriber: SpeechTranscribing,
        capture: CaptureProvider = { try await VoiceCaptureService.captureForTranscription() }
    ) async throws -> (draft: LogEntryDraft, flags: [String]) {
        let audio = try await capture()
        return try await useCase.applyVoiceAudio(audio, to: draft, transcriber: transcriber)
    }
}