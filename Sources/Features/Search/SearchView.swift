import SwiftUI
import CameraDataDesignSystem
import CameraDataDomain
import CameraDataData

public struct SearchView: View {
    @Binding public var query: String
    public let entries: [LogEntryModel]

    public init(query: Binding<String>, entries: [LogEntryModel]) {
        self._query = query
        self.entries = entries
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            TextField("Search takes, lenses, scenes…", text: $query)
                .textFieldStyle(.roundedBorder)
                .padding(.horizontal)

            List(filteredEntries, id: \.id) { entry in
                Text("Scene \(entry.scene) Take \(entry.take) — \(entry.lens)")
            }
        }
        .background(ThemeTokens.background)
    }

    private var filteredEntries: [LogEntryModel] {
        let parsed = NLPQueryParser.parse(query)
        return entries.filter { NLPQueryParser.matches(LogEntryMapper.toDraft($0), query: parsed) }
    }
}