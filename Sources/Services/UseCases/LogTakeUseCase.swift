import Foundation
import CameraDataDomain
import CameraDataData

@MainActor
public final class LogTakeUseCase {
    private let entryRepository: LogEntryRepositoryProtocol

    public init(entryRepository: LogEntryRepositoryProtocol) {
        self.entryRepository = entryRepository
    }

    public func prepareDraft(
        current: LogEntryDraft,
        lastEntry: LogEntryDraft?,
        cameraDefaults: LogEntryDraft?
    ) -> LogEntryDraft {
        SmartFillEngine.apply(to: current, lastEntry: lastEntry, cameraDefaults: cameraDefaults)
    }

    public func logAndNext(
        draft: LogEntryDraft,
        production: ProductionModel,
        camera: CameraUnitModel,
        day: ShootDayModel,
        existing: LogEntryModel?,
        modifiedBy: String
    ) throws -> (saved: LogEntryModel, nextDraft: LogEntryDraft) {
        let saved = try entryRepository.save(
            draft: draft,
            production: production,
            camera: camera,
            day: day,
            existing: existing,
            modifiedBy: modifiedBy
        )

        let sceneTakes = try entryRepository.fetchSceneTakes(production: production, camera: camera)
        let nextTake = TakeIncrementer.nextTake(after: draft.take, existingTakesForScene: sceneTakes.filter { $0.scene == draft.scene }.map(\.take))

        var next = LogEntryDraft(scene: draft.scene, take: nextTake)
        next = SmartFillEngine.apply(to: next, lastEntry: draft, cameraDefaults: cameraDefaults(from: camera))
        return (saved, next)
    }

    private func cameraDefaults(from camera: CameraUnitModel) -> LogEntryDraft {
        LogEntryDraft(
            lens: camera.defaultLens,
            iso: camera.defaultISO,
            whiteBalance: camera.defaultWhiteBalance,
            fps: camera.defaultFPS,
            resolution: camera.defaultResolution,
            codec: camera.defaultCodec
        )
    }
}