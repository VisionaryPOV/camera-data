import Foundation
import SwiftData
import CameraDataDomain

@MainActor
public final class ProductionRepository: ProductionRepositoryProtocol {
    private let context: ModelContext
    private let defaultsKey = "activeProductionId"

    public init(context: ModelContext) {
        self.context = context
    }

    public func fetchAll() throws -> [ProductionModel] {
        let descriptor = FetchDescriptor<ProductionModel>(sortBy: [SortDescriptor(\.createdAt, order: .reverse)])
        return try context.fetch(descriptor)
    }

    public func fetchActive() throws -> ProductionModel? {
        if let idString = UserDefaults.standard.string(forKey: defaultsKey),
           let id = UUID(uuidString: idString) {
            let descriptor = FetchDescriptor<ProductionModel>(predicate: #Predicate { $0.id == id })
            return try context.fetch(descriptor).first
        }
        return try fetchAll().first
    }

    public func create(name: String) throws -> ProductionModel {
        let production = ProductionModel(name: name)
        let cameraA = CameraUnitModel(label: "A", sortOrder: 0)
        let cameraB = CameraUnitModel(label: "B", sortOrder: 1)
        cameraA.production = production
        cameraB.production = production
        production.cameras = [cameraA, cameraB]

        let day = ShootDayModel(dayNumber: 1)
        day.production = production
        production.days = [day]

        context.insert(production)
        try context.save()
        try setActive(production)
        return production
    }

    public func setActive(_ production: ProductionModel) throws {
        UserDefaults.standard.set(production.id.uuidString, forKey: defaultsKey)
    }
}

@MainActor
public final class LogEntryRepository: LogEntryRepositoryProtocol {
    private let context: ModelContext
    private let auditService: AuditTracking?

    public init(context: ModelContext, auditService: AuditTracking? = nil) {
        self.context = context
        self.auditService = auditService
    }

    public func fetchEntries(
        production: ProductionModel,
        camera: CameraUnitModel?,
        day: ShootDayModel?,
        limit: Int,
        offset: Int
    ) throws -> [LogEntryModel] {
        let productionId = production.id
        let cameraId = camera?.id
        let dayId = day?.id

        let descriptor: FetchDescriptor<LogEntryModel>
        if let cameraId, let dayId {
            descriptor = FetchDescriptor<LogEntryModel>(
                predicate: #Predicate<LogEntryModel> { entry in
                    entry.isDeleted == false
                        && entry.productionId == productionId
                        && entry.cameraId == cameraId
                        && entry.dayId == dayId
                },
                sortBy: [SortDescriptor(\.sortKey, order: .reverse)]
            )
        } else if let cameraId {
            descriptor = FetchDescriptor<LogEntryModel>(
                predicate: #Predicate<LogEntryModel> { entry in
                    entry.isDeleted == false
                        && entry.productionId == productionId
                        && entry.cameraId == cameraId
                },
                sortBy: [SortDescriptor(\.sortKey, order: .reverse)]
            )
        } else {
            descriptor = FetchDescriptor<LogEntryModel>(
                predicate: #Predicate<LogEntryModel> { entry in
                    entry.isDeleted == false && entry.productionId == productionId
                },
                sortBy: [SortDescriptor(\.sortKey, order: .reverse)]
            )
        }

        var mutable = descriptor
        mutable.fetchLimit = limit
        mutable.fetchOffset = offset
        mutable.relationshipKeyPathsForPrefetching = [\.auditTrail]

        return try context.fetch(mutable)
    }

    public func fetchSceneTakes(production: ProductionModel, camera: CameraUnitModel?) throws -> [(scene: String, take: Int)] {
        let entries = try fetchEntries(production: production, camera: camera, day: nil, limit: 10_000, offset: 0)
        return entries.map { ($0.scene, $0.take) }
    }

    public func fetchEntry(id: UUID) throws -> LogEntryModel? {
        let descriptor = FetchDescriptor<LogEntryModel>(predicate: #Predicate { $0.id == id })
        return try context.fetch(descriptor).first
    }

    public func save(
        draft: LogEntryDraft,
        production: ProductionModel,
        camera: CameraUnitModel,
        day: ShootDayModel,
        existing: LogEntryModel?,
        modifiedBy: String,
        captureContext: CaptureContext?,
        preferredId: UUID? = nil
    ) throws -> LogEntryModel {
        let sceneTakes = try fetchSceneTakes(production: production, camera: camera)
        try LogEntryValidator.validate(draft, existingSceneTakes: sceneTakes, excludingTake: existing?.take)

        let model: LogEntryModel
        if let existing {
            model = existing
            let before = LogEntryMapper.toDraft(existing)
            LogEntryMapper.apply(draft, to: model, modifiedBy: modifiedBy)
            auditService?.recordChanges(entry: model, before: before, after: draft, userId: modifiedBy, context: context)
        } else {
            model = LogEntryModel(scene: draft.scene, take: draft.take, modifiedBy: modifiedBy)
            if let preferredId {
                model.id = preferredId
            }
            LogEntryMapper.apply(draft, to: model, modifiedBy: modifiedBy)
            model.production = production
            model.camera = camera
            model.day = day
            context.insert(model)
        }

        model.productionId = production.id
        model.cameraId = camera.id
        model.dayId = day.id

        if let captureContext {
            LogEntryMapper.applyCaptureContext(captureContext, to: model)
        }

        day.cachedTakeCount += existing == nil ? 1 : 0
        try context.save()
        return model
    }

    public func softDelete(_ entry: LogEntryModel) throws {
        entry.isDeleted = true
        entry.modifiedAt = .now
        entry.syncVersion += 1
        try context.save()
    }
}

@MainActor
public final class ProductionTemplateRepository: ProductionTemplateRepositoryProtocol {
    private let context: ModelContext

    public init(context: ModelContext) {
        self.context = context
    }

    public func cloneProduction(from source: ProductionModel, newName: String) throws -> ProductionModel {
        let clone = ProductionModel(name: newName)
        clone.settingsJSON = source.settingsJSON
        clone.brandingJSON = source.brandingJSON

        for cam in source.cameras.sorted(by: { $0.sortOrder < $1.sortOrder }) {
            let newCam = CameraUnitModel(label: cam.label, sortOrder: cam.sortOrder)
            newCam.defaultLens = cam.defaultLens
            newCam.defaultISO = cam.defaultISO
            newCam.defaultFPS = cam.defaultFPS
            newCam.defaultWhiteBalance = cam.defaultWhiteBalance
            newCam.defaultCodec = cam.defaultCodec
            newCam.defaultResolution = cam.defaultResolution
            newCam.production = clone
            clone.cameras.append(newCam)
        }

        for field in source.customFields.sorted(by: { $0.sortOrder < $1.sortOrder }) {
            let newField = CustomFieldDefinitionModel(
                key: field.key,
                label: field.label,
                fieldType: CustomFieldType(rawValue: field.fieldTypeRaw) ?? .text,
                sortOrder: field.sortOrder
            )
            newField.defaultValue = field.defaultValue
            newField.production = clone
            clone.customFields.append(newField)
        }

        let day = ShootDayModel(dayNumber: 1)
        day.production = clone
        clone.days = [day]

        context.insert(clone)
        try context.save()
        return clone
    }
}

/// Audit tracking protocol to avoid circular dependency with Services.
public protocol AuditTracking: Sendable {
    func recordChanges(
        entry: LogEntryModel,
        before: LogEntryDraft,
        after: LogEntryDraft,
        userId: String,
        context: ModelContext
    )
}