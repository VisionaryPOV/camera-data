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
    private func bootstrap() async {
        do {
            let deps = try AppDependencies(swiftDataCloudKit: false, syncCloudKit: false, inMemory: false)
            try await deps.bootstrapIfNeeded()
            dependencies = deps
            NSLog("[CameraData] launchState=%@", deps.session.launchState)
        } catch {
            bootstrapError = error.localizedDescription
            NSLog("[CameraData] bootstrap_error=%@", error.localizedDescription)
        }
    }
}