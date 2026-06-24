import SwiftUI
import CameraDataDesignSystem
import CameraDataData
import CameraDataServices

public struct AuditHistoryView: View {
    public let entry: LogEntryModel

    public init(entry: LogEntryModel) {
        self.entry = entry
    }

    public var body: some View {
        List {
            ForEach(AuditService.history(for: entry), id: \.at) { event in
                VStack(alignment: .leading, spacing: 4) {
                    Text(event.field).font(.headline)
                    Text("\(event.old) → \(event.new)")
                        .font(.caption.monospaced())
                    Text(event.at.formatted()).font(.caption2).foregroundStyle(ThemeTokens.textSecondary)
                }
            }
        }
        .navigationTitle("History")
        .background(ThemeTokens.background)
    }
}