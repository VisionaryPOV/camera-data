import Foundation

public enum RollNumberHelper {
    public static func increment(_ roll: String) -> String {
        let trimmed = roll.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "A001" }

        let letters = String(trimmed.prefix(while: { $0.isLetter }))
        let digits = String(trimmed.dropFirst(letters.count))
        let prefix = letters.isEmpty ? "A" : letters.uppercased()

        if let number = Int(digits), !digits.isEmpty {
            let next = number + 1
            if digits.count > 1, digits.hasPrefix("0") {
                return "\(prefix)\(String(format: "%0\(digits.count)d", next))"
            }
            return "\(prefix)\(next)"
        }

        return "\(prefix)1"
    }
}