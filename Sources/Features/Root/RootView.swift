import SwiftUI
import CameraDataDesignSystem
import CameraDataDomain
import CameraDataData

public struct RootView: View {
    public var dependencies: AppDependencies
    @State private var dashboardViewModel: DashboardViewModel
    @State private var activeSheet: RootActiveSheet?
    @State private var showSlate = false
    @State private var searchQuery = ""

    public init(dependencies: AppDependencies) {
        self.dependencies = dependencies
        _dashboardViewModel = State(initialValue: DashboardViewModel(
            entryRepository: dependencies.logEntryRepository,
            session: dependencies.session,
            smartSuggestor: dependencies.smartSuggestor
        ))
    }

    public var body: some View {
        NavigationStack {
            DashboardView(
                viewModel: dashboardViewModel,
                session: dependencies.session,
                onLogTake: { activeSheet = .editor },
                onOpenReports: { activeSheet = .reports },
                onOpenSettings: { activeSheet = .settings },
                onSelectEntry: { entry in
                    activeSheet = .audit(entryId: entry.id)
                }
            )
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button { activeSheet = .search } label: {
                        Image(systemName: "magnifyingglass")
                    }
                }
                ToolbarItem(placement: .topBarLeading) {
                    Button { showSlate = true } label: {
                        Image(systemName: "rectangle.split.3x1")
                    }
                }
            }
        }
        .preferredColorScheme(.dark)
        .environment(\.cinematicTheme, dependencies.session.themeMode)
        .sheet(item: $activeSheet) { sheet in
            sheetContent(for: sheet)
        }
        .fullScreenCover(isPresented: $showSlate) {
            DigitalSlateView(
                scene: slateSceneBinding,
                take: slateTakeBinding,
                isRolling: .constant(false),
                onIncrementTake: incrementSlateTake
            )
        }
        .overlay {
            if !dependencies.session.isOnboarded {
                OnboardingView {
                    completeOnboarding()
                }
            }
        }
        .task {
            await refreshPresence()
        }
    }

    @ViewBuilder
    private func sheetContent(for sheet: RootActiveSheet) -> some View {
        switch sheet {
        case .editor:
            NavigationStack {
                EntryEditorView(
                    viewModel: entryEditorViewModel,
                    onDismiss: {
                        activeSheet = nil
                        try? dashboardViewModel.reload()
                    }
                )
            }
            .presentationBackground(.ultraThinMaterial)

        case .reports:
            NavigationStack {
                ReportsView(
                    production: dependencies.session.activeProduction,
                    entries: dashboardViewModel.entries,
                    role: dependencies.session.currentRole
                )
            }

        case .settings:
            NavigationStack {
                SettingsView(
                    session: dependencies.session,
                    onCloneTemplate: cloneTemplate,
                    onReviewConflicts: {
                        dependencies.session.seedSampleConflict()
                        activeSheet = .conflicts
                    }
                )
            }

        case .search:
            SearchView(query: $searchQuery, entries: dashboardViewModel.entryModels)

        case .conflicts:
            NavigationStack {
                ConflictResolutionView(conflicts: dependencies.session.pendingConflicts) { resolutions in
                    resolveConflicts(resolutions)
                    activeSheet = nil
                }
            }

        case .audit(let entryId):
            if let entry = dashboardViewModel.entryModels.first(where: { $0.id == entryId }) {
                NavigationStack {
                    AuditHistoryView(entry: entry)
                }
            }
        }
    }

    private var slateSceneBinding: Binding<String> {
        Binding(
            get: { dependencies.session.slateScene },
            set: { dependencies.session.slateScene = $0 }
        )
    }

    private var slateTakeBinding: Binding<Int> {
        Binding(
            get: { dependencies.session.slateTake },
            set: { dependencies.session.slateTake = $0 }
        )
    }

    private var entryEditorViewModel: EntryEditorViewModel {
        EntryEditorViewModel(
            useCase: dependencies.logTakeUseCase,
            session: dependencies.session,
            entryRepository: dependencies.logEntryRepository,
            smartSuggestor: dependencies.smartSuggestor
        )
    }

    private func incrementSlateTake() {
        dependencies.session.slateTake += 1
        HapticManager.medium()
    }

    private func completeOnboarding() {
        UserDefaults.standard.set(true, forKey: "hasCompletedOnboarding")
        dependencies.session.isOnboarded = true
    }

    private func cloneTemplate() {
        guard let source = dependencies.session.activeProduction else { return }
        _ = try? dependencies.templateRepository.cloneProduction(from: source, newName: "\(source.name) Copy")
    }

    private func resolveConflicts(_ resolutions: [String: ConflictResolutionChoice]) {
        guard let local = dependencies.session.conflictLocalDraft,
              let remote = dependencies.session.conflictRemoteDraft else { return }
        let merged = ConflictMerger.merge(local: local, remote: remote, resolutions: resolutions)
        dependencies.session.conflictLocalDraft = merged
        dependencies.session.pendingConflicts = []
    }

    private func refreshPresence() async {
        await dependencies.presenceService.heartbeat(
            userId: "local-user",
            displayName: "You",
            editingEntryLabel: activeSheet == .editor ? "Take" : nil
        )
        let presences = await dependencies.presenceService.activePresences()
        var messages: [String] = []
        for presence in presences {
            if let label = await dependencies.presenceService.presenceLabel(for: presence.userId) {
                messages.append(label)
            }
        }
        dependencies.session.presenceMessages = messages
    }
}