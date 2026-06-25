import AVFoundation
import Foundation

public enum VoiceCaptureError: Error, Equatable {
    case microphoneDenied
    case recorderFailed
    case emptyRecording
}

/// Captures microphone audio via AVAudioRecorder for Speech framework transcription.
public enum VoiceCaptureService {
    private static let permissionTimeout: TimeInterval = 3
    private static let captureGrace: TimeInterval = 1

    public static func requestMicrophoneAccess() async -> Bool {
        await withTaskGroup(of: Bool.self) { group in
            group.addTask {
                await withCheckedContinuation { continuation in
                    AVAudioApplication.requestRecordPermission { granted in
                        continuation.resume(returning: granted)
                    }
                }
            }
            group.addTask {
                try? await Task.sleep(nanoseconds: UInt64(permissionTimeout * 1_000_000_000))
                return false
            }
            let granted = await group.next() ?? false
            group.cancelAll()
            return granted
        }
    }

    public static func captureForTranscription(duration: TimeInterval = 2.5) async throws -> Data {
        try await withThrowingTaskGroup(of: Data.self) { group in
            group.addTask {
                try await performCapture(duration: duration)
            }
            group.addTask {
                try await Task.sleep(nanoseconds: UInt64((duration + captureGrace) * 1_000_000_000))
                throw VoiceCaptureError.recorderFailed
            }
            guard let data = try await group.next() else {
                throw VoiceCaptureError.recorderFailed
            }
            group.cancelAll()
            return data
        }
    }

    private static func performCapture(duration: TimeInterval) async throws -> Data {
        guard await requestMicrophoneAccess() else {
            throw VoiceCaptureError.microphoneDenied
        }

        let audioSession = AVAudioSession.sharedInstance()
        try audioSession.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker])
        try audioSession.setActive(true)
        defer { try? audioSession.setActive(false, options: .notifyOthersOnDeactivation) }

        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("voice-log-\(UUID().uuidString).m4a")
        defer { try? FileManager.default.removeItem(at: url) }

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

        try await Task.sleep(nanoseconds: UInt64((duration + 0.05) * 1_000_000_000))
        recorder.stop()

        let data = try Data(contentsOf: url)
        guard !data.isEmpty else { throw VoiceCaptureError.emptyRecording }
        return data
    }
}