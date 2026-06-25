import SwiftUI
import CameraDataDesignSystem
import CameraDataDomain
import CameraDataData

public struct RootView: View {
    public var dependencies: AppDependencies
    @Environment(\.scenePhase) private var scenePhase
    @State private var dashboardViewModel: DashboardViewModel
    @State private var activeSheet: RootActiveSheet?
    @State private var showSlate = false
    @State private var searchQuery = ""
    @State private var productionEditorViewModel: ProductionEditorViewModel
    @State private var productionsList: [ProductionModel] = []

    public init(dependencies: AppDependencies) {
        self.dependencies = dependencies
        _dashboardViewModel = State(initialValue: DashboardViewModel(
            entryRepository: dependencies.logEntryRepository,
            session: dependencies.session,
            smartSuggestor: dependencies.smartSuggestor
        ))
        _productionEditorViewModel = State(initialValue: ProductionEditorViewModel(
            productionRepository: dependencies.productionRepository,
            session: dependencies.session
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
                isRolling: slateIsRollingBinding,
                onIncrementTake: incrementSlateTake,
                onDismiss: { showSlate = false }
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
        .onChange(of: scenePhase) { _, phase in
            if phase == .background {
                Task { _ = await dependencies.flushSyncQueue() }
            }
        }
        .onChange(of: dependencies.session.pendingConflicts.count) { _, count in
            if count > 0 {
                activeSheet = .conflicts
            }
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
                    productionEditor: productionEditorViewModel,
                    onCloneTemplate: cloneTemplate,
                    onReviewConflicts: {
                        if !dependencies.session.pendingConflicts.isEmpty {
                            activeSheet = .conflicts
                        }
                    },
                    onManageProductions: {
                        reloadProductionsList()
                        activeSheet = .productions
                    }
                )
            }

        case .productions:
            NavigationStack {
                ProductionsListView(
                    productions: productionsList,
                    activeProductionId: dependencies.session.activeProduction?.id,
                    onSelect: selectProduction,
                    onCreate: createProduction,
                    onArchive: archiveProduction
                )
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Done") { activeSheet = .settings }
                    }
                }
            }
            .onAppear { reloadProductionsList() }

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

    private var slateIsRollingBinding: Binding<Bool> {
        Binding(
            get: { dependencies.session.slateIsRolling },
            set: { dependencies.session.slateIsRolling = $0 }
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
        _ = try? dependencies.templateRepository.cloneProduction(from: source, newName: "\(source.displayTitle) Copy")
        reloadProductionsList()
    }

    private func reloadProductionsList() {
        productionsList = (try? dependencies.productionRepository.fetchAll(includeArchived: false)) ?? []
    }

    private func createProduction() {
        guard let production = try? dependencies.productionRepository.create(name: "Untitled Production") else { return }
        try? dependencies.activateProduction(production)
        productionEditorViewModel.reloadFromSession()
        reloadProductionsList()
        try? dashboardViewModel.reload()
        activeSheet = .settings
    }

    private func selectProduction(_ production: ProductionModel, startNewDay: Bool) {
        do {
            if startNewDay {
                let day = try dependencies.productionRepository.addShootDay(to: production)
                try dependencies.activateProduction(production, shootDay: day)
            } else {
                try dependencies.activateProduction(production)
            }
            productionEditorViewModel.reloadFromSession()
            try dashboardViewModel.reload()
            reloadProductionsList()
            activeSheet = .settings
        } catch {
            return
        }
    }

    private func archiveProduction(_ production: ProductionModel) {
        try? dependencies.productionRepository.archive(production)
        reloadProductionsList()
        if dependencies.session.activeProduction?.id == production.id,
           let next = productionsList.first {
            try? dependencies.activateProduction(next)
            productionEditorViewModel.reloadFromSession()
            try? dashboardViewModel.reload()
        }
    }

    private func resolveConflicts(_ resolutions: [String: ConflictResolutionChoice]) {
        try? dependencies.resolvePendingConflict(resolutions: resolutions)
        try? dashboardViewModel.reload()
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