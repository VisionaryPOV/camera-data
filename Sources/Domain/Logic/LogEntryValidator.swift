import Foundation

public enum LogEntryValidationError: Error, Equatable, Sendable {
    case missingScene
    case invalidTake
    case duplicateSceneTake(scene: String, take: Int)
}

public enum LogEntryValidator {
    public static func validate(
        _ draft: LogEntryDraft,
        existingSceneTakes: [(scene: String, take: Int)],
        excludingTake: Int? = nil
    ) throws {
        let scene = draft.scene.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !scene.isEmpty else { throw LogEntryValidationError.missingScene }
        guard draft.take >= 1 else { throw LogEntryValidationError.invalidTake }

        let duplicate = existingSceneTakes.contains { pair in
            pair.scene == scene && pair.take == draft.take && pair.take != excludingTake
        }
        if duplicate {
            throw LogEntryValidationError.duplicateSceneTake(scene: scene, take: draft.take)
        }
    }
}