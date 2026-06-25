import Foundation
import CameraDataDomain
import CameraDataData

public enum AuditRestoreService {
    @MainActor
    public static func applyRestoredValue(_ value: String, field: String, to draft: inout LogEntryDraft) {
        switch field {
        case "scene": draft.scene = value
        case "take": draft.take = Int(value) ?? draft.take
        case "lens": draft.lens = value
        case "iso": draft.iso = Int(value) ?? draft.iso
        case "notes": draft.notes = value
        case "resolution": draft.resolution = value
        case "codec": draft.codec = value
        case "timecodeIn": draft.timecodeIn = value
        case "timecodeOut": draft.timecodeOut = value
        case "duration": draft.duration = value
        case "shutterSpeed": draft.shutterSpeed = value
        case "shutterAngle": draft.shutterAngle = Double(value)
        default: break
        }
    }

    @MainActor
    public static func restore(
        entry: LogEntryModel,
        field: String,
        value: String,
        repository: LogEntryRepositoryProtocol,
        modifiedBy: String
    ) throws -> LogEntryModel {
        guard let production = entry.production,
              let camera = entry.camera,
              let day = entry.day else {
            throw AuditRestoreError.missingRelationships
        }

        var draft = LogEntryMapper.toDraft(entry)
        applyRestoredValue(value, field: field, to: &draft)
        return try repository.save(
            draft: draft,
            production: production,
            camera: camera,
            day: day,
            existing: entry,
            modifiedBy: modifiedBy,
            captureContext: nil,
            preferredId: nil
        )
    }
}

public enum AuditRestoreError: Error {
    case missingRelationships
}