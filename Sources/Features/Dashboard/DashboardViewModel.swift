import Foundation
import Observation
import CameraDataDomain
import CameraDataData
import CameraDataServices

@MainActor
@Observable
public final class DashboardViewModel {
    public var entries: [LogEntryModel] = []
    public var roleFilteredDrafts: [LogEntryDraft] = []
    public var stats: DashboardStats = DashboardStats(takeCount: 0, circledCount: 0, dominantLens: nil, takesPerHour: 0)
    public var searchText: String = "" {
        didSet { scheduleReload() }
    }
    public var showCircledOnly: Bool = false {
        didSet { scheduleReload() }
    }
    public var pageSize: Int = 50
    public var isLoading: Bool = false

    private let entryRepository: LogEntryRepositoryProtocol
    private let session: ProductionSession
    private let smartSuggestor: CoreMLSmartSuggestor?
    private var reloadTask: Task<Void, Never>?

    public init(
        entryRepository: LogEntryRepositoryProtocol,
        session: ProductionSession,
        smartSuggestor: CoreMLSmartSuggestor? = nil
    ) {
        self.entryRepository = entryRepository
        self.session = session
        self.smartSuggestor = smartSuggestor
    }

    public var canEdit: Bool {
        session.currentRole.canEdit
    }

    public func reload() throws {
        guard let production = session.activeProduction else { return }
        isLoading = true
        defer { isLoading = false }

        var fetched = try entryRepository.fetchEntries(
            production: production,
            camera: session.selectedCamera,
            day: session.selectedDay,
            limit: pageSize,
            offset: 0
        )

        if !searchText.isEmpty {
            let parsed = NLPQueryParser.parse(searchText)
            fetched = fetched.filter { NLPQueryParser.matches(LogEntryMapper.toDraft($0), query: parsed) }
        }

        if showCircledOnly {
            fetched = fetched.filter(\.isCircled)
        }

        entries = fetched
        roleFilteredDrafts = Self.roleFilteredDrafts(from: fetched, role: session.currentRole)

        stats = DashboardStatsCalculator.compute(entries: roleFilteredDrafts, shootDurationHours: 8)

        AppGroupStore.writeWidgetSnapshot(
            takeCount: stats.takeCount,
            productionName: production.name
        )

        if let latest = entries.first {
            session.slateScene = latest.scene
            session.slateTake = latest.take
        }
    }

    public static func roleFilteredDrafts(from entries: [LogEntryModel], role: ProductionRole) -> [LogEntryDraft] {
        let pairs = entries.map { (draft: LogEntryMapper.toDraft($0), vfxNotes: $0.vfxNotes) }
        return RoleFilter.filterEntries(pairs, role: role)
    }

    public func displayNotes(for entry: LogEntryModel) -> String {
        switch session.currentRole {
        case .vfx:
            return entry.vfxNotes.isEmpty ? entry.notes : entry.vfxNotes
        case .readOnly, .admin, .editor:
            return entry.notes
        }
    }

    public func selectCamera(_ camera: CameraUnitModel) throws {
        session.selectedCamera = camera
        try reload()
    }

    public func smartSuggestions(for draft: LogEntryDraft) -> [SmartSuggestion] {
        let history = roleFilteredDrafts
        if let smartSuggestor {
            return smartSuggestor.suggest(from: history, for: draft)
        }
        return SmartSuggestService.suggestions(from: history, for: draft)
    }

    private func scheduleReload() {
        reloadTask?.cancel()
        reloadTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 200_000_000)
            try? reload()
        }
    }
}