import Foundation

public enum ConflictMerger {
    public static func detectConflicts(
        local: LogEntryDraft,
        remote: LogEntryDraft
    ) -> [ConflictField] {
        var conflicts: [ConflictField] = []
        compare(&conflicts, key: "scene", local: local.scene, remote: remote.scene)
        compare(&conflicts, key: "take", local: String(local.take), remote: String(remote.take))
        compare(&conflicts, key: "lens", local: local.lens, remote: remote.lens)
        compare(&conflicts, key: "iso", local: String(local.iso), remote: String(remote.iso))
        compare(&conflicts, key: "notes", local: local.notes, remote: remote.notes)
        return conflicts
    }

    public static func merge(
        local: LogEntryDraft,
        remote: LogEntryDraft,
        resolutions: [String: ConflictResolutionChoice]
    ) -> LogEntryDraft {
        var merged = local
        for (key, choice) in resolutions {
            switch key {
            case "scene":
                merged.scene = choice == .remote ? remote.scene : local.scene
            case "take":
                merged.take = choice == .remote ? remote.take : local.take
            case "lens":
                merged.lens = choice == .remote ? remote.lens : local.lens
            case "iso":
                merged.iso = choice == .remote ? remote.iso : local.iso
            case "notes":
                merged.notes = choice == .remote ? remote.notes : local.notes
            default:
                break
            }
        }
        return merged
    }

    private static func compare(
        _ conflicts: inout [ConflictField],
        key: String,
        local: String,
        remote: String
    ) {
        guard local != remote else { return }
        conflicts.append(ConflictField(key: key, localValue: local, remoteValue: remote))
    }
}

public enum ConflictResolutionChoice: String, Sendable {
    case local, remote
}