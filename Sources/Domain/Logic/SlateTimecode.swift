import Foundation

public struct SlateTimecodeComponents: Equatable, Sendable {
    public let hours: Int
    public let minutes: Int
    public let seconds: Int
    public let frames: Int

    public init(hours: Int, minutes: Int, seconds: Int, frames: Int) {
        self.hours = hours
        self.minutes = minutes
        self.seconds = seconds
        self.frames = frames
    }
}

public enum SlateTimecode {
    public static func elapsedSeconds(from date: Date, origin: Date?) -> TimeInterval {
        guard let origin else { return 0 }
        return max(0, date.timeIntervalSince(origin))
    }

    public static func framesPerSecond(for fps: Double) -> Int {
        max(1, Int(ceil(fps - 0.001)))
    }

    public static func components(elapsed: TimeInterval, fps: Double) -> SlateTimecodeComponents {
        let safeFPS = max(fps, 1)
        let totalSeconds = Int(elapsed.rounded(.down))
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        let seconds = totalSeconds % 60
        let fractional = elapsed - Double(totalSeconds)
        let maxFrame = framesPerSecond(for: safeFPS) - 1
        let frames = min(max(0, Int((fractional * safeFPS).rounded(.down))), max(0, maxFrame))
        return SlateTimecodeComponents(hours: hours, minutes: minutes, seconds: seconds, frames: frames)
    }

    public static func components(from date: Date, origin: Date?, fps: Double) -> SlateTimecodeComponents {
        components(elapsed: elapsedSeconds(from: date, origin: origin), fps: fps)
    }

    public static func digitGroups(from date: Date, origin: Date?, fps: Double) -> [String] {
        let parts = components(from: date, origin: origin, fps: fps)
        return [
            String(format: "%02d", parts.hours),
            String(format: "%02d", parts.minutes),
            String(format: "%02d", parts.seconds),
            String(format: "%02d", parts.frames)
        ]
    }

    public static func formatted(from date: Date, origin: Date?, fps: Double) -> String {
        digitGroups(from: date, origin: origin, fps: fps).joined(separator: " ")
    }

    public static func timelineInterval(fps: Double) -> TimeInterval {
        1 / max(fps, 1)
    }
}