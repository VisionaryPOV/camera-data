import Foundation
import CameraDataDomain
import CameraDataData

public struct DashboardEntry: Identifiable {
    public var id: UUID { model.id }
    public let model: LogEntryModel
    public let displayDraft: LogEntryDraft

    public init(model: LogEntryModel, displayDraft: LogEntryDraft) {
        self.model = model
        self.displayDraft = displayDraft
    }

    public static func project(_ models: [LogEntryModel], role: ProductionRole) -> [DashboardEntry] {
        let pairs = models.map { (draft: LogEntryMapper.toDraft($0), vfxNotes: $0.vfxNotes) }
        let projected = RoleFilter.filterEntries(pairs, role: role)
        return zip(models, projected).map { DashboardEntry(model: $0.0, displayDraft: $0.1) }
    }
}