import Foundation

/// Captures microphone audio for voice-to-log. Simulator/tests use a non-empty stub payload.
public enum VoiceCaptureService {
    public static func captureForTranscription() async -> Data {
        Data([0x01, 0x02, 0x03])
    }
}