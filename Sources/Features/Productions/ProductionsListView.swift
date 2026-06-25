import SwiftUI
import CameraDataDesignSystem
import CameraDataData

public struct ProductionsListView: View {
    public var productions: [ProductionModel]
    public var activeProductionId: UUID?
    public var onSelect: (ProductionModel, Bool) -> Void
    public var onCreate: () -> Void
    public var onArchive: (ProductionModel) -> Void

    @State private var pendingProduction: ProductionModel?
    @State private var showDayChoice = false

    public init(
        productions: [ProductionModel],
        activeProductionId: UUID?,
        onSelect: @escaping (ProductionModel, Bool) -> Void,
        onCreate: @escaping () -> Void,
        onArchive: @escaping (ProductionModel) -> Void
    ) {
        self.productions = productions
        self.activeProductionId = activeProductionId
        self.onSelect = onSelect
        self.onCreate = onCreate
        self.onArchive = onArchive
    }

    public var body: some View {
        List {
            if productions.isEmpty {
                ContentUnavailableView(
                    "No Productions",
                    systemImage: "film.stack",
                    description: Text("Create a production to save title, director, DP, and episode info.")
                )
            } else {
                ForEach(productions, id: \.id) { production in
                    Button {
                        pendingProduction = production
                        showDayChoice = true
                    } label: {
                        productionRow(production)
                    }
                    .buttonStyle(.plain)
                    .swipeActions(edge: .trailing) {
                        Button("Archive") { onArchive(production) }
                    }
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background(ThemeTokens.background)
        .navigationTitle("Productions")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("New", action: onCreate)
            }
        }
        .confirmationDialog(
            "Open Production",
            isPresented: $showDayChoice,
            presenting: pendingProduction
        ) { production in
            Button("Continue Latest Day (\(production.latestShootDay?.dayNumber ?? 1))") {
                onSelect(production, false)
            }
            Button("Start New Shoot Day") {
                onSelect(production, true)
            }
            Button("Cancel", role: .cancel) {}
        } message: { production in
            Text("Switch to \(production.displayTitle)?")
        }
    }

    private func productionRow(_ production: ProductionModel) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(production.displayTitle)
                    .font(.headline)
                    .foregroundStyle(ThemeTokens.textPrimary)
                if !production.episodeOrProductionNumber.isEmpty {
                    Text("Ep/Prod \(production.episodeOrProductionNumber)")
                        .font(.caption)
                        .foregroundStyle(ThemeTokens.textSecondary)
                }
                if !production.directorName.isEmpty || !production.dpName.isEmpty {
                    Text([production.directorName, production.dpName].filter { !$0.isEmpty }.joined(separator: " • "))
                        .font(.caption2)
                        .foregroundStyle(ThemeTokens.textSecondary)
                }
                if let day = production.latestShootDay {
                    Text("Last: Day \(day.dayNumber)")
                        .font(.caption2)
                        .foregroundStyle(ThemeTokens.textSecondary)
                }
            }
            Spacer()
            if production.id == activeProductionId {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(ThemeTokens.accent)
            }
        }
        .padding(.vertical, 4)
    }
}