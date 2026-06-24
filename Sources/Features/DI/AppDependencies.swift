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

    public init(isOnboarded: Bool = false) {
        self.isOnboarded = isOnboarded
    }

    public func markReady(productionName: String?) {
        launchState = "dashboard_ready:\(productionName ?? "none")"
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
    public let session: ProductionSession

    public init(cloudKitEnabled: Bool = false, inMemory: Bool = false) throws {
        modelContainer = try inMemory
            ? ModelContainerFactory.makeInMemory()
            : ModelContainerFactory.makePersistent(cloudKitEnabled: cloudKitEnabled)

        let context = modelContainer.mainContext
        auditService = AuditService()
        productionRepository = ProductionRepository(context: context)
        logEntryRepository = LogEntryRepository(context: context, auditService: auditService)
        templateRepository = ProductionTemplateRepository(context: context)
        logTakeUseCase = LogTakeUseCase(entryRepository: logEntryRepository)
        syncEngine = SyncEngine(cloudKitAvailable: cloudKitEnabled)
        presenceService = PresenceService()

        let onboarded = UserDefaults.standard.bool(forKey: "hasCompletedOnboarding")
        session = ProductionSession(isOnboarded: onboarded)
    }

    public func bootstrapIfNeeded() throws {
        if try productionRepository.fetchActive() == nil {
            let production = try productionRepository.create(name: "Untitled Production")
            session.activeProduction = production
        } else {
            session.activeProduction = try productionRepository.fetchActive()
        }
        session.selectedCamera = session.activeProduction?.cameras.sorted(by: { $0.sortOrder < $1.sortOrder }).first
        session.selectedDay = session.activeProduction?.days.sorted(by: { $0.dayNumber < $1.dayNumber }).first
        session.markReady(productionName: session.activeProduction?.name)
    }
}