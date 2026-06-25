import SwiftUI
import CameraDataDesignSystem
import CameraDataData
import CameraDataServices

public struct AuditHistoryView: View {
    public let entry: LogEntryModel
    public var onRestore: (String, String) -> Void

    public init(entry: LogEntryModel, onRestore: @escaping (String, String) -> Void) {
        self.entry = entry
        self.onRestore = onRestore
    }

    public var body: some View {
        List {
            ForEach(AuditService.history(for: entry), id: \.at) { event in
                VStack(alignment: .leading, spacing: 8) {
                    Text(event.field).font(.headline)
                    Text("\(event.old) → \(event.new)")
                        .font(.caption.monospaced())
                    Text(event.at.formatted()).font(.caption2).foregroundStyle(ThemeTokens.textSecondary)
                    Button("Restore \(event.old)") {
                        onRestore(event.field, event.old)
                    }
                    .font(.caption.weight(.semibold))
                }
            }
        }
        .navigationTitle("History")
        .background(ThemeTokens.background)
    }
}