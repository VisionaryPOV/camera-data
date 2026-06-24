import Foundation
import CameraDataDomain
import CameraDataData
import CameraDataServices

@MainActor
public enum AppIntentLogService {
    private static var cachedDependencies: AppDependencies?

    public static func register(_ dependencies: AppDependencies) {
        cachedDependencies = dependencies
    }

    public static func resetCachedDependenciesForTesting() {
        cachedDependencies = nil
    }

    public static func logTake(scene: String, take: Int, cameraLabel: String?) async throws -> String {
        let deps: AppDependencies
        if let cachedDependencies {
            deps = cachedDependencies
        } else {
            let fresh = try AppDependencies(
                swiftDataCloudKit: false,
                syncPipelineEnabled: true,
                inMemory: false
            )
            try await fresh.bootstrapIfNeeded()
            cachedDependencies = fresh
            deps = fresh
        }

        guard let production = deps.session.activeProduction,
              let day = deps.session.selectedDay else {
            throw AppIntentLogError.missingProduction
        }

        let camera = production.cameras.first { $0.label == (cameraLabel ?? "A") }
            ?? deps.session.selectedCamera
            ?? production.cameras.sorted(by: { $0.sortOrder < $1.sortOrder }).first

        guard let camera else { throw AppIntentLogError.missingCamera }

        var draft = LogEntryDraft(scene: scene, take: take)
        draft = deps.logTakeUseCase.prepareDraft(current: draft, lastEntry: nil, cameraDefaults: nil)

        let result = try await deps.logTakeUseCase.logAndNext(
            draft: draft,
            production: production,
            camera: camera,
            day: day,
            existing: nil,
            modifiedBy: "siri-intent"
        )

        let count = try deps.logEntryRepository.fetchEntries(
            production: production,
            camera: camera,
            day: day,
            limit: 10_000,
            offset: 0
        ).count
        AppGroupStore.writeWidgetSnapshot(takeCount: count, productionName: production.name)

        return "Logged take \(take) for scene \(scene) on Camera \(camera.label)"
    }
}

public enum AppIntentLogError: Error, LocalizedError {
    case missingProduction
    case missingCamera

    public var errorDescription: String? {
        switch self {
        case .missingProduction: "No active production"
        case .missingCamera: "No camera configured"
        }
    }
}