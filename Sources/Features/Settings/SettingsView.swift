import SwiftUI
import CameraDataDesignSystem
import CameraDataDomain
import CameraDataData
import CameraDataServices

public struct SettingsView: View {
    @Bindable public var session: ProductionSession
    public var onCloneTemplate: () -> Void
    public var onReviewConflicts: () -> Void

    public init(
        session: ProductionSession,
        onCloneTemplate: @escaping () -> Void,
        onReviewConflicts: @escaping () -> Void
    ) {
        self.session = session
        self.onCloneTemplate = onCloneTemplate
        self.onReviewConflicts = onReviewConflicts
    }

    public var body: some View {
        Form {
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
            }
            Section("Production") {
                Button("Clone Production Template", action: onCloneTemplate)
            }
            Section("Collaboration") {
                Button("Review Sync Conflicts", action: onReviewConflicts)
                if !session.pendingConflicts.isEmpty {
                    Text("\(session.pendingConflicts.count) conflicts pending")
                        .foregroundStyle(ThemeTokens.accent)
                }
            }
            Section("Security") {
                Label(
                    SecurityService.canUseBiometrics() ? "Biometrics Available" : "Biometrics Unavailable",
                    systemImage: "faceid"
                )
            }
        }
        .scrollContentBackground(.hidden)
        .background(ThemeTokens.background)
        .navigationTitle("Settings")
    }
}