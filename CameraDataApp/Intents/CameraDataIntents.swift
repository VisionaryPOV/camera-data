import AppIntents

public struct LogTakeIntent: AppIntent {
    nonisolated(unsafe) public static var title: LocalizedStringResource = "Log Take"
    nonisolated(unsafe) public static var description = IntentDescription("Log a camera take for the active production.")

    @Parameter(title: "Scene")
    public var scene: String

    @Parameter(title: "Take")
    public var take: Int

    @Parameter(title: "Camera")
    public var camera: String?

    public init() {
        self.scene = ""
        self.take = 1
    }

    public func perform() async throws -> some IntentResult & ProvidesDialog {
        let cameraLabel = camera ?? "A"
        return .result(dialog: "Logged take \(take) for scene \(scene) on Camera \(cameraLabel)")
    }
}

public struct OpenTodayIntent: AppIntent {
    nonisolated(unsafe) public static var title: LocalizedStringResource = "Open Today"
    nonisolated(unsafe) public static var description = IntentDescription("Open today's shoot day dashboard.")

    public init() {}

    public func perform() async throws -> some IntentResult {
        .result()
    }
}

public struct CameraDataShortcuts: AppShortcutsProvider {
    @AppShortcutsBuilder
    nonisolated(unsafe) public static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: LogTakeIntent(),
            phrases: [
                "Log a take in \(.applicationName)",
                "Log take with \(.applicationName)"
            ],
            shortTitle: "Log Take",
            systemImageName: "camera.fill"
        )
        AppShortcut(
            intent: OpenTodayIntent(),
            phrases: ["Open today in \(.applicationName)"],
            shortTitle: "Open Today",
            systemImageName: "calendar"
        )
    }
}