import Foundation
import CameraDataDomain

public protocol SpeechTranscribing: Sendable {
    func transcribe(_ audioData: Data) async throws -> String
}

public struct SpeechFrameworkTranscriber: SpeechTranscribing {
    public init() {}

    public func transcribe(_ audioData: Data) async throws -> String {
        try await SpeechRecognitionService.transcribe(audioData: audioData)
    }
}

public struct StubSpeechTranscriber: SpeechTranscribing {
    public init() {}
    public func transcribe(_ audioData: Data) async throws -> String {
        guard !audioData.isEmpty else { return "" }
        return "log take 3 for scene 12 circled"
    }
}

public struct FixedSpeechTranscriber: SpeechTranscribing, Sendable {
    public let text: String

    public init(text: String) {
        self.text = text
    }

    public func transcribe(_ audioData: Data) async throws -> String {
        guard !audioData.isEmpty else { return "" }
        return text
    }
}

public enum VoiceLoggingService {
    public static func processTranscript(_ text: String) -> (draft: LogEntryDraft, flags: [String]) {
        let parsed = FilmTerminologyLexicon.processTranscript(text)
        var draft = LogEntryDraft()
        if let scene = parsed.scene { draft.scene = scene }
        if let take = parsed.take { draft.take = take }
        if parsed.flags.contains("CIRCLED") { draft.isCircled = true }
        if parsed.flags.contains("MOS") { draft.isMOS = true }
        if parsed.flags.contains("PU") { draft.isPickup = true }
        if parsed.flags.contains("TAILS") { draft.isTail = true }
        if parsed.flags.contains("HOLD") { draft.isHold = true }
        if parsed.flags.contains("BAD") { draft.isBad = true }
        if parsed.flags.contains("SERIES") { draft.isSeries = true }
        return (draft, parsed.flags)
    }

    public static func processAudio(_ data: Data, transcriber: SpeechTranscribing) async throws -> (draft: LogEntryDraft, flags: [String]) {
        let text = try await transcriber.transcribe(data)
        return processTranscript(text)
    }

    public static func processAudioWithSpeechFramework(_ data: Data) async throws -> (draft: LogEntryDraft, flags: [String]) {
        try await processAudio(data, transcriber: SpeechFrameworkTranscriber())
    }
}