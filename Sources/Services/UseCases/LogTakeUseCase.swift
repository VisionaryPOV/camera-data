import Foundation
import CameraDataDomain
import CameraDataData

@MainActor
public final class LogTakeUseCase {
    private let entryRepository: LogEntryRepositoryProtocol
    private let syncEngine: SyncEngine?
    private let metadataProvider: () -> CaptureContext

    public init(
        entryRepository: LogEntryRepositoryProtocol,
        syncEngine: SyncEngine? = nil,
        metadataProvider: @escaping () -> CaptureContext = {
            MetadataCaptureService.captureContext(location: nil, motion: nil)
        }
    ) {
        self.entryRepository = entryRepository
        self.syncEngine = syncEngine
        self.metadataProvider = metadataProvider
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
    ) async throws -> (saved: LogEntryModel, nextDraft: LogEntryDraft) {
        let captureContext = metadataProvider()
        let saved = try entryRepository.save(
            draft: draft,
            production: production,
            camera: camera,
            day: day,
            existing: existing,
            modifiedBy: modifiedBy,
            captureContext: captureContext
        )

        if let syncEngine {
            await syncEngine.enqueueLogEntry(
                entryId: saved.id,
                syncVersion: saved.syncVersion,
                scene: saved.scene,
                take: saved.take,
                lens: saved.lens,
                iso: saved.iso,
                productionCode: production.code
            )
        }

        let sceneTakes = try entryRepository.fetchSceneTakes(production: production, camera: camera)
        let nextTake = TakeIncrementer.nextTake(
            after: draft.take,
            existingTakesForScene: sceneTakes.filter { $0.scene == draft.scene }.map(\.take)
        )

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