import Foundation

public protocol VoiceCapturing: Sendable {
    func captureForTranscription(duration: TimeInterval) async throws -> Data
}

public struct LiveVoiceCapture: VoiceCapturing {
    public init() {}

    public func captureForTranscription(duration: TimeInterval = 2.5) async throws -> Data {
        try await VoiceCaptureService.captureForTranscription(duration: duration)
    }
}

public struct FixedVoiceCapture: VoiceCapturing {
    public let data: Data

    public init(data: Data) {
        self.data = data
    }

    public func captureForTranscription(duration: TimeInterval) async throws -> Data {
        data
    }
}