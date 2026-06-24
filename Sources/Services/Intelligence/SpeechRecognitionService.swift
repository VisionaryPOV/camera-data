import Foundation
import Speech
import CameraDataDomain

public enum SpeechRecognitionService {
    public static func isAvailable() -> Bool {
        SFSpeechRecognizer()?.isAvailable ?? false
    }

    public static func requestAuthorization() async -> SFSpeechRecognizerAuthorizationStatus {
        await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                continuation.resume(returning: status)
            }
        }
    }

    public static func transcribe(audioURL: URL, locale: Locale = Locale(identifier: "en_US")) async throws -> String {
        let recognizer = SFSpeechRecognizer(locale: locale)
        guard let recognizer, recognizer.isAvailable else {
            throw SpeechRecognitionError.recognizerUnavailable
        }

        let request = SFSpeechURLRecognitionRequest(url: audioURL)
        request.requiresOnDeviceRecognition = true
        request.contextualStrings = FilmTerminologyLexicon.replacements.keys.map { String($0) }

        return try await withCheckedThrowingContinuation { continuation in
            recognizer.recognitionTask(with: request) { result, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }
                guard let result, result.isFinal else { return }
                continuation.resume(returning: result.bestTranscription.formattedString)
            }
        }
    }

    public static func transcribe(audioData: Data) async throws -> String {
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("voice-log-\(UUID().uuidString).caf")
        try audioData.write(to: tempURL)
        defer { try? FileManager.default.removeItem(at: tempURL) }
        return try await transcribe(audioURL: tempURL)
    }
}

public enum SpeechRecognitionError: Error, Equatable {
    case recognizerUnavailable
}