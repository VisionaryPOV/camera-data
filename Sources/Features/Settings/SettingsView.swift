import SwiftUI
import CameraDataDesignSystem
import CameraDataDomain
import CameraDataData
import CameraDataServices

public struct SettingsView: View {
    @Bindable public var session: ProductionSession
    @Bindable public var productionEditor: ProductionEditorViewModel
    public var onCloneTemplate: () -> Void
    public var onReviewConflicts: () -> Void
    public var onManageProductions: () -> Void

    public init(
        session: ProductionSession,
        productionEditor: ProductionEditorViewModel,
        onCloneTemplate: @escaping () -> Void,
        onReviewConflicts: @escaping () -> Void,
        onManageProductions: @escaping () -> Void
    ) {
        self.session = session
        self.productionEditor = productionEditor
        self.onCloneTemplate = onCloneTemplate
        self.onReviewConflicts = onReviewConflicts
        self.onManageProductions = onManageProductions
    }

    public var body: some View {
        Form {
            ProductionEditorView(
                viewModel: productionEditor,
                onManageProductions: onManageProductions
            )

            Section("Appearance") {
                Picker("Theme", selection: $session.themeMode) {
                    Text("Cinematic Dark").tag(ThemeMode.cinematicDark)
                    Text("Night / Red").tag(ThemeMode.nightRed)
                }
            }
            Section("Role (Phase 2)") {
                Picker("Access", selection: $session.currentRole) {
                    ForEach(ProductionRole.allCases, id: \.self) { role in
                        Text(role.rawValue).tag(role)
                    }
                }
                Text(roleDescription)
                    .font(.caption)
                    .foregroundStyle(ThemeTokens.textSecondary)
            }
            Section("Templates") {
                Button("Clone Production Template", action: onCloneTemplate)
            }
            Section("Collaboration") {
                Button("Review Sync Conflicts", action: onReviewConflicts)
                    .disabled(session.pendingConflicts.isEmpty)
                if session.pendingConflicts.isEmpty {
                    Text("No sync conflicts")
                        .font(.caption)
                        .foregroundStyle(ThemeTokens.textSecondary)
                } else {
                    Text("\(session.pendingConflicts.count) conflicts pending")
                        .foregroundStyle(ThemeTokens.accent)
                }
            }
            Section("Security") {
                Toggle("Require Unlock", isOn: $session.securityEnabled)
                    .onChange(of: session.securityEnabled) { _, _ in
                        session.persistSecuritySettings()
                    }
                SecureField("Production PIN", text: $session.productionPIN)
                    .onChange(of: session.productionPIN) { _, _ in
                        session.persistSecuritySettings()
                    }
                if SecurityService.canUseBiometrics() {
                    Button("Test Face ID Unlock") {
                        Task {
                            let ok = await SecurityService.authenticate(reason: "Verify Camera Data unlock")
                            if ok { session.isUnlocked = true }
                        }
                    }
                } else {
                    Label("Biometrics Unavailable", systemImage: "faceid")
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background(ThemeTokens.background)
        .navigationTitle("Settings")
    }

    private var roleDescription: String {
        switch session.currentRole {
        case .admin, .editor:
            return "Full dashboard, logging, and export access."
        case .readOnly:
            return "View-only — logging and editing disabled."
        case .vfx:
            return "VFX notes surfaced in dashboard and exports."
        }
    }
}