import SwiftUI
import CameraDataDesignSystem
import CameraDataData

public struct DashboardView: View {
    @Bindable public var viewModel: DashboardViewModel
    @Bindable public var session: ProductionSession
    public var onLogTake: () -> Void
    public var onOpenReports: () -> Void
    public var onOpenSettings: () -> Void
    public var onSelectEntry: (LogEntryModel) -> Void

    public init(
        viewModel: DashboardViewModel,
        session: ProductionSession,
        onLogTake: @escaping () -> Void,
        onOpenReports: @escaping () -> Void,
        onOpenSettings: @escaping () -> Void,
        onSelectEntry: @escaping (LogEntryModel) -> Void
    ) {
        self.viewModel = viewModel
        self.session = session
        self.onLogTake = onLogTake
        self.onOpenReports = onOpenReports
        self.onOpenSettings = onOpenSettings
        self.onSelectEntry = onSelectEntry
    }

    public var body: some View {
        ZStack(alignment: .bottomTrailing) {
            ThemeTokens.background.ignoresSafeArea()

            VStack(spacing: 16) {
                header
                searchRow
                cameraPicker
                statsRow
                presenceRow
                entryList
            }
            .padding()

            if viewModel.canEdit {
                FloatingLogButton(action: onLogTake)
                    .padding()
            }
        }
        .navigationTitle(session.activeProduction?.displayTitle ?? "Camera Data")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Reports", action: onOpenReports)
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button("Settings", action: onOpenSettings)
            }
        }
        .onAppear {
            try? viewModel.reload()
        }
        .onChange(of: session.currentRole) {
            try? viewModel.reload()
        }
    }

    private var header: some View {
        HStack {
            if let production = session.activeProduction {
                GlassChip(production.displayTitle, isSelected: false)
                if !production.episodeOrProductionNumber.isEmpty {
                    GlassChip("Ep \(production.episodeOrProductionNumber)", isSelected: false)
                }
            }
            if let day = session.selectedDay {
                GlassChip("Day \(day.dayNumber)", isSelected: true)
            }
            GlassChip(session.currentRole.rawValue, isSelected: false)
            Spacer()
        }
    }

    private var searchRow: some View {
        VStack(spacing: 8) {
            TextField("Search scenes, lenses, notes…", text: $viewModel.searchText)
                .textFieldStyle(.roundedBorder)
            Toggle("Circled only", isOn: $viewModel.showCircledOnly)
                .tint(ThemeTokens.accent)
                .font(.subheadline)
        }
    }

    private var cameraPicker: some View {
        HStack(spacing: 8) {
            ForEach(session.activeProduction?.cameras.sorted(by: { $0.sortOrder < $1.sortOrder }) ?? [], id: \.id) { camera in
                Button {
                    try? viewModel.selectCamera(camera)
                    HapticManager.light()
                } label: {
                    GlassChip("Cam \(camera.label)", isSelected: session.selectedCamera?.id == camera.id)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var statsRow: some View {
        HStack(spacing: 12) {
            GlassCard {
                VStack(alignment: .leading) {
                    Text("Takes").font(.caption).foregroundStyle(ThemeTokens.textSecondary)
                    Text("\(viewModel.stats.takeCount)").font(.title2.monospacedDigit())
                }
            }
            GlassCard {
                VStack(alignment: .leading) {
                    Text("Circled").font(.caption).foregroundStyle(ThemeTokens.textSecondary)
                    Text("\(viewModel.stats.circledCount)").font(.title2.monospacedDigit())
                }
            }
            GlassCard {
                VStack(alignment: .leading) {
                    Text("Lens").font(.caption).foregroundStyle(ThemeTokens.textSecondary)
                    Text(viewModel.stats.dominantLens ?? "—").font(.subheadline)
                }
            }
        }
    }

    private var presenceRow: some View {
        Group {
            if !session.presenceMessages.isEmpty {
                GlassCard {
                    VStack(alignment: .leading, spacing: 4) {
                        ForEach(session.presenceMessages, id: \.self) { msg in
                            Text(msg).font(.caption).foregroundStyle(ThemeTokens.accent)
                        }
                    }
                }
            }
        }
    }

    private var entryList: some View {
        List {
            ForEach(viewModel.entries) { entry in
                Button {
                    onSelectEntry(entry.model)
                } label: {
                    HStack {
                        VStack(alignment: .leading) {
                            Text("Scene \(entry.displayDraft.scene) / Take \(entry.displayDraft.take)")
                                .font(.headline)
                            Text(entry.displayDraft.lens.isEmpty ? "No lens" : entry.displayDraft.lens)
                                .font(.subheadline)
                                .foregroundStyle(ThemeTokens.textSecondary)
                            if !entry.displayDraft.notes.isEmpty {
                                Text(entry.displayDraft.notes)
                                    .font(.caption)
                                    .foregroundStyle(ThemeTokens.textSecondary)
                                    .lineLimit(1)
                            }
                        }
                        Spacer()
                        if entry.displayDraft.isCircled {
                            Image(systemName: "circle.fill")
                                .foregroundStyle(ThemeTokens.circled)
                        }
                    }
                }
                .buttonStyle(.plain)
                .listRowBackground(ThemeTokens.surface.opacity(0.5))
            }
        }
        .scrollContentBackground(.hidden)
    }
}