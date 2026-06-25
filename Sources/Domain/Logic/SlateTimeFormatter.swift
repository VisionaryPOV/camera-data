import Foundation

public enum SlateTimeFormatter {
    /// Formats a date as production time-of-day (24-hour, no seconds).
    public static func timeOfDay(from date: Date, calendar: Calendar = .current) -> String {
        let components = calendar.dateComponents([.hour, .minute], from: date)
        let hour = components.hour ?? 0
        let minute = components.minute ?? 0
        return String(format: "%02d:%02d", hour, minute)
    }
}