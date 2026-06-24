import SwiftUI
import CameraDataDesignSystem
import CameraDataDomain
import CameraDataData
import CameraDataServices

public struct SettingsView: View {
    @Bindable public var session: ProductionSession
    public var onCloneTemplate: () -> Void

    public init(session: ProductionSession, onCloneTemplate: @escaping () -> Void) {
        self.session = session
        self.onCloneTemplate = onCloneTemplate
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
            Section("Security") {
                Label(
                    SecurityStatusLabel.canUseBiometrics ? "Biometrics Available" : "Biometrics Unavailable",
                    systemImage: "faceid"
                )
            }
        }
        .scrollContentBackground(.hidden)
        .background(ThemeTokens.background)
        .navigationTitle("Settings")
    }
}

private enum SecurityStatusLabel {
    static var canUseBiometrics: Bool {
        SecurityService.canUseBiometrics()
    }
}