import Foundation
import SwiftData
import CameraDataDomain
import CameraDataData

public final class AuditService: AuditTracking, @unchecked Sendable {
    public init() {}

    public func recordChanges(
        entry: LogEntryModel,
        before: LogEntryDraft,
        after: LogEntryDraft,
        userId: String,
        context: ModelContext
    ) {
        let tracked: [(String, String, String)] = [
            ("scene", before.scene, after.scene),
            ("take", String(before.take), String(after.take)),
            ("lens", before.lens, after.lens),
            ("iso", String(before.iso), String(after.iso)),
            ("notes", before.notes, after.notes)
        ]

        for (key, old, new) in tracked where old != new {
            let event = AuditEventModel(
                fieldKey: key,
                oldValue: old,
                newValue: new,
                userId: userId,
                deviceId: entry.deviceId
            )
            event.entry = entry
            context.insert(event)
            entry.auditTrail.append(event)
        }
    }

    public static func history(for entry: LogEntryModel) -> [(field: String, old: String, new: String, at: Date)] {
        entry.auditTrail
            .sorted { $0.timestamp < $1.timestamp }
            .map { ($0.fieldKey, $0.oldValue, $0.newValue, $0.timestamp) }
    }
}