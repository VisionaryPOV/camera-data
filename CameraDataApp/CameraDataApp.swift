import SwiftUI
import CameraDataData
import CameraDataFeatures

@main
struct CameraDataApp: App {
    @State private var dependencies: AppDependencies?
    @State private var bootstrapError: String?

    var body: some Scene {
        WindowGroup {
            Group {
                if let dependencies {
                    RootView(dependencies: dependencies)
                } else if let bootstrapError {
                    Text("Failed to start: \(bootstrapError)")
                        .foregroundStyle(.red)
                        .padding()
                } else {
                    ProgressView("Loading Camera Data…")
                }
            }
            .task {
                await bootstrap()
            }
        }
    }

    @MainActor
    private func runLaunchVerificationHooks(session: ProductionSession) {
        let args = ProcessInfo.processInfo.arguments
        if args.contains("-ui_testing_security") {
            session.securityEnabled = true
            session.productionPIN = "0000"
            session.persistSecuritySettings()
        }
        if args.contains("-ui_testing_slate") {
            let controller = SlateSessionController(session: session)
            controller.present()
            controller.toggleRolling()
            controller.incrementTake()
            controller.dismiss()
        }
    }

    @MainActor
    private func bootstrap() async {
        do {
            let deps = try AppDependencies(
                swiftDataCloudKit: false,
                syncPipelineEnabled: true,
                inMemory: false
            )
            try await deps.bootstrapIfNeeded()
            dependencies = deps
            NSLog("[CameraData] launchState=%@", deps.session.launchState)
            runLaunchVerificationHooks(session: deps.session)
        } catch {
            bootstrapError = error.localizedDescription
            NSLog("[CameraData] bootstrap_error=%@", error.localizedDescription)
        }
    }
}