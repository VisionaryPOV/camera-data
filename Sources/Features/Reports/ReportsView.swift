import SwiftUI
import CameraDataDesignSystem
import CameraDataData
import CameraDataServices
import CameraDataDomain

public struct ReportsView: View {
    public let production: ProductionModel?
    public let entries: [DashboardEntry]
    public let role: ProductionRole
    @State private var exportMessage: String = ""

    public init(production: ProductionModel?, entries: [DashboardEntry], role: ProductionRole = .editor) {
        self.production = production
        self.entries = entries
        self.role = role
    }

    public var body: some View {
        VStack(spacing: 16) {
            Text("Reports")
                .font(.title2)
                .foregroundStyle(ThemeTokens.textPrimary)

            GlassCard {
                Text("\(drafts.count) entries ready for export (\(role.rawValue))")
                    .foregroundStyle(ThemeTokens.textSecondary)
            }

            HStack {
                GlassButton("Export PDF") { exportPDF() }
                GlassButton("Export CSV") { exportCSV() }
            }
            HStack {
                GlassButton("Export JSON") { exportJSON() }
                GlassButton("Daily Wrap") { exportWrap() }
            }

            if !exportMessage.isEmpty {
                Text(exportMessage).font(.caption).foregroundStyle(ThemeTokens.accent)
            }

            Spacer()
        }
        .padding()
        .background(ThemeTokens.background)
    }

    private var drafts: [LogEntryDraft] {
        entries.map(\.displayDraft)
    }

    private func exportPDF() {
        let branding = ExportBranding(productionName: production?.name ?? "Production")
        let data = ExportService.pdfData(from: drafts, branding: branding)
        exportMessage = "PDF generated (\(data.count) bytes)"
    }

    private func exportCSV() {
        let data = ExportService.csvData(from: drafts)
        exportMessage = "CSV generated (\(data.count) bytes)"
    }

    private func exportJSON() {
        let data = ExportService.jsonData(from: drafts)
        exportMessage = "JSON generated (\(data.count) bytes)"
    }

    private func exportWrap() {
        let stats = DashboardStatsCalculator.compute(entries: drafts)
        let summary = DailyWrapSummary(
            productionName: production?.name ?? "Production",
            dayNumber: 1,
            stats: stats
        )
        let data = ExportService.dailyWrapPDF(summary: summary)
        exportMessage = "Daily wrap PDF (\(data.count) bytes)"
    }
}