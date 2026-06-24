import SwiftUI
import CameraDataDesignSystem
import CameraDataData

public struct DashboardView: View {
    @Bindable public var viewModel: DashboardViewModel
    @Bindable public var session: ProductionSession
    public var onLogTake: () -> Void
    public var onOpenReports: () -> Void
    public var onOpenSettings: () -> Void

    public init(
        viewModel: DashboardViewModel,
        session: ProductionSession,
        onLogTake: @escaping () -> Void,
        onOpenReports: @escaping () -> Void,
        onOpenSettings: @escaping () -> Void
    ) {
        self.viewModel = viewModel
        self.session = session
        self.onLogTake = onLogTake
        self.onOpenReports = onOpenReports
        self.onOpenSettings = onOpenSettings
    }

    public var body: some View {
        ZStack(alignment: .bottomTrailing) {
            ThemeTokens.background.ignoresSafeArea()

            VStack(spacing: 16) {
                header
                cameraPicker
                statsRow
                presenceRow
                entryList
            }
            .padding()

            FloatingLogButton(action: onLogTake)
                .padding()
        }
        .navigationTitle(session.activeProduction?.name ?? "Camera Data")
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
    }

    private var header: some View {
        HStack {
            if let day = session.selectedDay {
                GlassChip("Day \(day.dayNumber)", isSelected: true)
            }
            Spacer()
            Text("Launch: \(session.launchState)")
                .font(.caption2)
                .foregroundStyle(ThemeTokens.textSecondary)
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
            ForEach(viewModel.entries, id: \.id) { entry in
                HStack {
                    VStack(alignment: .leading) {
                        Text("Scene \(entry.scene) / Take \(entry.take)")
                            .font(.headline)
                        Text(entry.lens.isEmpty ? "No lens" : entry.lens)
                            .font(.subheadline)
                            .foregroundStyle(ThemeTokens.textSecondary)
                    }
                    Spacer()
                    if entry.isCircled {
                        Image(systemName: "circle.fill")
                            .foregroundStyle(ThemeTokens.circled)
                    }
                }
                .listRowBackground(ThemeTokens.surface.opacity(0.5))
            }
        }
        .scrollContentBackground(.hidden)
    }
}