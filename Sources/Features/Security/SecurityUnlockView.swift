import SwiftUI
import CameraDataDesignSystem
import CameraDataServices

public struct SecurityUnlockView: View {
    @Bindable public var session: ProductionSession
    @State private var enteredPIN = ""
    @State private var errorMessage: String?

    public init(session: ProductionSession) {
        self.session = session
    }

    public var body: some View {
        ZStack {
            Color.black.opacity(0.92).ignoresSafeArea()
            VStack(spacing: 20) {
                Image(systemName: "lock.shield")
                    .font(.system(size: 48))
                    .foregroundStyle(ThemeTokens.accent)
                Text("Production Locked")
                    .font(.title2.weight(.semibold))
                SecureField("Production PIN", text: $enteredPIN)
                    .textContentType(.password)
                    .keyboardType(.numberPad)
                    .padding()
                    .background(ThemeTokens.surface)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .frame(maxWidth: 280)
                if SecurityService.canUseBiometrics() {
                    GlassButton("Unlock with Face ID", isPrimary: true) {
                        Task { await unlockWithBiometrics() }
                    }
                    .frame(maxWidth: 280)
                }
                GlassButton("Unlock with PIN", isPrimary: false) {
                    unlockWithPIN()
                }
                .frame(maxWidth: 280)
                if let errorMessage {
                    Text(errorMessage)
                        .font(.caption)
                        .foregroundStyle(.red)
                }
            }
            .padding()
        }
    }

    private func unlockWithPIN() {
        if SecurityService.validatePIN(enteredPIN, expected: session.productionPIN) {
            session.isUnlocked = true
            errorMessage = nil
            HapticManager.success()
        } else {
            errorMessage = "Incorrect PIN"
            HapticManager.light()
        }
    }

    private func unlockWithBiometrics() async {
        let ok = await SecurityService.authenticate(reason: "Unlock Camera Data production")
        if ok {
            session.isUnlocked = true
            errorMessage = nil
            HapticManager.success()
        } else {
            errorMessage = "Biometric authentication failed"
        }
    }
}