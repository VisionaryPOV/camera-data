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

        let box = TranscriptionResultBox()
        return try await withCheckedThrowingContinuation { continuation in
            box.store(continuation)
            let speechTask = recognizer.recognitionTask(with: request) { result, error in
                if let error {
                    box.finish(.failure(error))
                    return
                }
                guard let result, result.isFinal else { return }
                let text = result.bestTranscription.formattedString
                if text.isEmpty {
                    box.finish(.failure(SpeechRecognitionError.noTranscription))
                } else {
                    box.finish(.success(text))
                }
            }
            box.setTask(speechTask)

            let timeoutTask = Task {
                do {
                    try await Task.sleep(nanoseconds: 1_000_000_000)
                    box.finish(.failure(SpeechRecognitionError.recognitionTimedOut))
                } catch {
                    // Cancelled when recognition completes first.
                }
            }
            box.setTimeoutTask(timeoutTask)
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
    case recognitionTimedOut
    case noTranscription
}

private final class TranscriptionResultBox: @unchecked Sendable {
    private let lock = NSLock()
    private var continuation: CheckedContinuation<String, Error>?
    private var recognitionTask: SFSpeechRecognitionTask?
    private var timeoutTask: Task<Void, Never>?

    func store(_ continuation: CheckedContinuation<String, Error>) {
        lock.lock()
        self.continuation = continuation
        lock.unlock()
    }

    func setTask(_ task: SFSpeechRecognitionTask) {
        lock.lock()
        recognitionTask = task
        lock.unlock()
    }

    func setTimeoutTask(_ task: Task<Void, Never>) {
        lock.lock()
        timeoutTask = task
        lock.unlock()
    }

    func finish(_ result: Result<String, Error>) {
        lock.lock()
        let continuation = self.continuation
        self.continuation = nil
        recognitionTask?.cancel()
        recognitionTask = nil
        let timeout = timeoutTask
        timeoutTask = nil
        lock.unlock()
        timeout?.cancel()
        continuation?.resume(with: result)
    }
}