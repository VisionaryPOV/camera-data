import Foundation
import Observation
import CameraDataDomain
import CameraDataData
import CameraDataServices

@MainActor
@Observable
public final class DashboardViewModel {
    public var entries: [LogEntryModel] = []
    public var stats: DashboardStats = DashboardStats(takeCount: 0, circledCount: 0, dominantLens: nil, takesPerHour: 0)
    public var searchText: String = ""
    public var showCircledOnly: Bool = false
    public var pageSize: Int = 50
    public var isLoading: Bool = false

    private let entryRepository: LogEntryRepositoryProtocol
    private let session: ProductionSession

    public init(entryRepository: LogEntryRepositoryProtocol, session: ProductionSession) {
        self.entryRepository = entryRepository
        self.session = session
    }

    public func reload() throws {
        guard let production = session.activeProduction else { return }
        isLoading = true
        defer { isLoading = false }

        entries = try entryRepository.fetchEntries(
            production: production,
            camera: session.selectedCamera,
            day: session.selectedDay,
            limit: pageSize,
            offset: 0
        )

        let drafts = entries.map(LogEntryMapper.toDraft)
        stats = DashboardStatsCalculator.compute(entries: drafts, shootDurationHours: 8)

        if !searchText.isEmpty {
            let parsed = NLPQueryParser.parse(searchText)
            let filtered = drafts.enumerated().filter { NLPQueryParser.matches($0.element, query: parsed) }
            entries = filtered.map { entries[$0.offset] }
        }

        if showCircledOnly {
            entries = entries.filter(\.isCircled)
        }
    }

    public func selectCamera(_ camera: CameraUnitModel) throws {
        session.selectedCamera = camera
        try reload()
    }
}