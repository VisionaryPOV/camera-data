import Foundation

public enum DashboardStatsCalculator {
    public static func compute(
        entries: [LogEntryDraft],
        shootDurationHours: Double = 1.0
    ) -> DashboardStats {
        let takeCount = entries.count
        let circledCount = entries.filter(\.isCircled).count

        let lensCounts = Dictionary(grouping: entries.map(\.lens).filter { !$0.isEmpty }, by: { $0 })
        let dominantLens = lensCounts.max(by: { $0.value.count < $1.value.count })?.key

        let hours = max(0.25, shootDurationHours)
        let takesPerHour = Double(takeCount) / hours

        return DashboardStats(
            takeCount: takeCount,
            circledCount: circledCount,
            dominantLens: dominantLens,
            takesPerHour: takesPerHour
        )
    }
}

public enum RoleFilter {
    public static func filterEntries(
        _ drafts: [(draft: LogEntryDraft, vfxNotes: String)],
        role: ProductionRole
    ) -> [LogEntryDraft] {
        switch role {
        case .vfx:
            return drafts.map { entry in
                var d = entry.draft
                d.vfxNotes = entry.vfxNotes
                d.notes = entry.vfxNotes.isEmpty ? d.notes : entry.vfxNotes
                return d
            }
        case .readOnly, .admin, .editor:
            return drafts.map(\.draft)
        }
    }
}