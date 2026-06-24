import Foundation
import LocalAuthentication

public enum SecurityService {
    public static func canUseBiometrics() -> Bool {
        let context = LAContext()
        var error: NSError?
        return context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error)
    }

    public static func authenticate(reason: String) async -> Bool {
        let context = LAContext()
        do {
            return try await context.evaluatePolicy(
                .deviceOwnerAuthenticationWithBiometrics,
                localizedReason: reason
            )
        } catch {
            return false
        }
    }

    public static func validatePIN(_ entered: String, expected: String?) -> Bool {
        guard let expected, !expected.isEmpty else { return true }
        return entered == expected
    }
}