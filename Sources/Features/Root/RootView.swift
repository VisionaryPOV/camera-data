import SwiftUI
import CameraDataDesignSystem

public struct RootView: View {
    public var dependencies: AppDependencies
    @State private var showEditor = false
    @State private var showReports = false
    @State private var showSettings = false
    @State private var showSlate = false
    @State private var showSearch = false
    @State private var searchQuery = ""

    public init(dependencies: AppDependencies) {
        self.dependencies = dependencies
    }

    public var body: some View {
        NavigationStack {
            DashboardView(
                viewModel: dashboardViewModel,
                session: dependencies.session,
                onLogTake: { showEditor = true },
                onOpenReports: { showReports = true },
                onOpenSettings: { showSettings = true }
            )
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        showSearch = true
                    } label: {
                        Image(systemName: "magnifyingglass")
                    }
                }
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        showSlate = true
                    } label: {
                        Image(systemName: "rectangle.split.3x1")
                    }
                }
            }
        }
        .preferredColorScheme(.dark)
        .environment(\.cinematicTheme, dependencies.session.themeMode)
        .sheet(isPresented: $showEditor) {
            NavigationStack {
                EntryEditorView(
                    viewModel: entryEditorViewModel,
                    onDismiss: { showEditor = false }
                )
            }
            .presentationBackground(.ultraThinMaterial)
        }
        .sheet(isPresented: $showReports) {
            NavigationStack {
                ReportsView(
                    production: dependencies.session.activeProduction,
                    entries: dashboardViewModel.entries
                )
            }
        }
        .sheet(isPresented: $showSettings) {
            NavigationStack {
                SettingsView(session: dependencies.session) {
                    cloneTemplate()
                }
            }
        }
        .sheet(isPresented: $showSearch) {
            SearchView(query: $searchQuery, entries: dashboardViewModel.entries)
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

    private var dashboardViewModel: DashboardViewModel {
        DashboardViewModel(
            entryRepository: dependencies.logEntryRepository,
            session: dependencies.session
        )
    }

    private var entryEditorViewModel: EntryEditorViewModel {
        EntryEditorViewModel(
            useCase: dependencies.logTakeUseCase,
            session: dependencies.session,
            entryRepository: dependencies.logEntryRepository
        )
    }

    private var slateSceneBinding: Binding<String> {
        Binding(
            get: { dependencies.session.activeProduction?.name ?? "" },
            set: { _ in }
        )
    }

    private var slateTakeBinding: Binding<Int> {
        Binding(
            get: { dashboardViewModel.entries.first?.take ?? 1 },
            set: { _ in }
        )
    }

    private func incrementSlateTake() {
        // Slate mode auto-increment handled in UI binding refresh via dashboard reload
        try? dashboardViewModel.reload()
    }

    private func completeOnboarding() {
        UserDefaults.standard.set(true, forKey: "hasCompletedOnboarding")
        dependencies.session.isOnboarded = true
    }

    private func cloneTemplate() {
        guard let source = dependencies.session.activeProduction else { return }
        _ = try? dependencies.templateRepository.cloneProduction(from: source, newName: "\(source.name) Copy")
    }

    private func refreshPresence() async {
        await dependencies.presenceService.heartbeat(
            userId: "local-user",
            displayName: "You",
            editingEntryLabel: showEditor ? "Take" : nil
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