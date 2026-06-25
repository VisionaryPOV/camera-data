import AVFoundation
import Foundation

public enum VoiceCaptureError: Error, Equatable {
    case microphoneDenied
    case recorderFailed
    case emptyRecording
}

/// Captures microphone audio via AVAudioRecorder for Speech framework transcription.
public enum VoiceCaptureService {
    public static func requestMicrophoneAccess() async -> Bool {
        await withCheckedContinuation { continuation in
            AVAudioApplication.requestRecordPermission { granted in
                continuation.resume(returning: granted)
            }
        }
    }

    public static func captureForTranscription(duration: TimeInterval = 2.5) async throws -> Data {
        guard await requestMicrophoneAccess() else {
            throw VoiceCaptureError.microphoneDenied
        }

        let audioSession = AVAudioSession.sharedInstance()
        try audioSession.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker])
        try audioSession.setActive(true)

        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("voice-log-\(UUID().uuidString).m4a")

        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 44_100,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.medium.rawValue
        ]

        let recorder = try AVAudioRecorder(url: url, settings: settings)
        guard recorder.prepareToRecord() else {
            throw VoiceCaptureError.recorderFailed
        }
        guard recorder.record(forDuration: duration) else {
            throw VoiceCaptureError.recorderFailed
        }

        try await Task.sleep(nanoseconds: UInt64((duration + 0.15) * 1_000_000_000))
        recorder.stop()
        try audioSession.setActive(false, options: .notifyOthersOnDeactivation)

        let data = try Data(contentsOf: url)
        try? FileManager.default.removeItem(at: url)
        guard !data.isEmpty else { throw VoiceCaptureError.emptyRecording }
        return data
    }
}