import Foundation
import SwiftData
import Observation
import CameraDataDomain
import CameraDataData
import CameraDataServices

@MainActor
@Observable
public final class ProductionSession {
    public var activeProduction: ProductionModel?
    public var selectedCamera: CameraUnitModel?
    public var selectedDay: ShootDayModel?
    public var currentRole: ProductionRole = .editor
    public var themeMode: ThemeMode = .cinematicDark
    public var isOnboarded: Bool
    public var launchState: String = "initializing"
    public var presenceMessages: [String] = []
    public var slateScene: String = ""
    public var slateTake: Int = 1
    public var pendingConflicts: [ConflictField] = []
    public var conflictLocalDraft: LogEntryDraft?
    public var conflictRemoteDraft: LogEntryDraft?

    public init(isOnboarded: Bool = false) {
        self.isOnboarded = isOnboarded
    }

    public func markReady(productionName: String?) {
        launchState = "dashboard_ready:\(productionName ?? "none")"
    }

    public func seedSampleConflict() {
        conflictLocalDraft = LogEntryDraft(scene: "12", take: 4, lens: "50mm", notes: "Local notes")
        conflictRemoteDraft = LogEntryDraft(scene: "12", take: 4, lens: "75mm", notes: "Remote notes")
        if let local = conflictLocalDraft, let remote = conflictRemoteDraft {
            pendingConflicts = ConflictMerger.detectConflicts(local: local, remote: remote)
        }
    }
}

@MainActor
public final class AppDependencies {
    public let modelContainer: ModelContainer
    public let productionRepository: ProductionRepository
    public let logEntryRepository: LogEntryRepository
    public let templateRepository: ProductionTemplateRepository
    public let logTakeUseCase: LogTakeUseCase
    public let syncEngine: SyncEngine
    public let presenceService: PresenceService
    public let auditService: AuditService
    public let smartSuggestor: CoreMLSmartSuggestor
    public let session: ProductionSession

    public init(
        swiftDataCloudKit: Bool = false,
        syncCloudKit: Bool = true,
        inMemory: Bool = false
    ) throws {
        modelContainer = try inMemory
            ? ModelContainerFactory.makeInMemory()
            : ModelContainerFactory.makePersistent(cloudKitEnabled: swiftDataCloudKit)

        let context = modelContainer.mainContext
        auditService = AuditService()
        productionRepository = ProductionRepository(context: context)
        logEntryRepository = LogEntryRepository(context: context, auditService: auditService)
        templateRepository = ProductionTemplateRepository(context: context)
        syncEngine = SyncEngine(cloudKitAvailable: syncCloudKit)
        logTakeUseCase = LogTakeUseCase(
            entryRepository: logEntryRepository,
            syncEngine: syncEngine,
            metadataProvider: {
                MetadataCaptureService.captureContext(
                    location: nil,
                    motion: DeviceMotionSnapshot(pitch: 0, roll: 0, yaw: 0)
                )
            }
        )
        presenceService = PresenceService()
        smartSuggestor = CoreMLSmartSuggestor()

        let onboarded = UserDefaults.standard.bool(forKey: "hasCompletedOnboarding")
        session = ProductionSession(isOnboarded: onboarded)
    }

    public func bootstrapIfNeeded() async throws {
        if try productionRepository.fetchActive() == nil {
            let production = try productionRepository.create(name: "Untitled Production")
            session.activeProduction = production
        } else {
            session.activeProduction = try productionRepository.fetchActive()
        }
        session.selectedCamera = session.activeProduction?.cameras.sorted(by: { $0.sortOrder < $1.sortOrder }).first
        session.selectedDay = session.activeProduction?.days.sorted(by: { $0.dayNumber < $1.dayNumber }).first

        if let production = session.activeProduction {
            let zones = try? await syncEngine.prepareZones(for: production.code)
            _ = try? await syncEngine.createShare(for: production.code, productionName: production.name)
            let invite = syncEngine.makeInvite(for: production.code)
            production.shareURL = zones?.shareURL ?? invite.shareURL.absoluteString
            try? productionRepository.setActive(production)
        }

        syncLatestEntryToSlate()
        session.markReady(productionName: session.activeProduction?.name)
        AppIntentLogService.register(self)
    }

    public func syncLatestEntryToSlate() {
        guard let production = session.activeProduction,
              let camera = session.selectedCamera else { return }
        let entries = (try? logEntryRepository.fetchEntries(
            production: production, camera: camera, day: session.selectedDay, limit: 1, offset: 0
        )) ?? []
        if let latest = entries.first {
            session.slateScene = latest.scene
            session.slateTake = latest.take
        } else {
            session.slateScene = ""
            session.slateTake = 1
        }
    }
}