import Foundation

public enum RootActiveSheet: Identifiable, Equatable {
    case editor
    case reports
    case settings
    case productions
    case search
    case conflicts
    case audit(entryId: UUID)

    public var id: String {
        switch self {
        case .editor: "editor"
        case .reports: "reports"
        case .settings: "settings"
        case .productions: "productions"
        case .search: "search"
        case .conflicts: "conflicts"
        case .audit(let entryId): "audit-\(entryId.uuidString)"
        }
    }
}