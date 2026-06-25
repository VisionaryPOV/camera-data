import Foundation
import CameraDataDomain

@MainActor
public enum VoicePipeline {
    public static func captureAndApply(
        to draft: LogEntryDraft,
        useCase: LogTakeUseCase,
        transcriber: SpeechTranscribing,
        voiceCapture: any VoiceCapturing,
        duration: TimeInterval = 2.5
    ) async throws -> (draft: LogEntryDraft, flags: [String]) {
        let audio = try await voiceCapture.captureForTranscription(duration: duration)
        return try await useCase.applyVoiceAudio(audio, to: draft, transcriber: transcriber)
    }
}