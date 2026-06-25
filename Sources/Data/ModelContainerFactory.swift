import Foundation
import SwiftData

public enum ModelContainerFactory {
    public static let schema = Schema([
        ProductionModel.self,
        CameraUnitModel.self,
        ShootDayModel.self,
        LogEntryModel.self,
        CustomFieldDefinitionModel.self,
        CustomFieldValueModel.self,
        RollModel.self,
        AttachmentModel.self,
        ProductionMemberModel.self,
        AuditEventModel.self,
        PresenceRecordModel.self
    ])

    public static let cloudKitContainerIdentifier = "iCloud.com.visionarypov.cameradata"

    public static func makeInMemory() throws -> ModelContainer {
        let config = ModelConfiguration(isStoredInMemoryOnly: true, cloudKitDatabase: .none)
        return try ModelContainer(for: schema, configurations: [config])
    }

    public static func makePersistent(cloudKitEnabled: Bool = false, storeURL: URL? = nil) throws -> ModelContainer {
        if cloudKitEnabled {
            let privateConfig = ModelConfiguration(
                "CameraData-Private",
                cloudKitDatabase: .private(cloudKitContainerIdentifier)
            )
            return try ModelContainer(for: schema, configurations: [privateConfig])
        }
        let config: ModelConfiguration
        if let storeURL {
            config = ModelConfiguration("CameraData", url: storeURL, cloudKitDatabase: .none)
        } else {
            config = ModelConfiguration("CameraData", cloudKitDatabase: .none)
        }
        return try openPersistentContainer(configuration: config)
    }

    public static func openPersistentContainer(configuration: ModelConfiguration) throws -> ModelContainer {
        do {
            return try ModelContainer(for: schema, configurations: [configuration])
        } catch {
            try removePersistentStoreFiles(for: configuration)
            return try ModelContainer(for: schema, configurations: [configuration])
        }
    }

    public static func removePersistentStoreFiles(for configuration: ModelConfiguration) throws {
        let storeURL = configuration.url
        let fileManager = FileManager.default
        let related = [
            storeURL,
            storeURL.appendingPathExtension("wal"),
            storeURL.appendingPathExtension("shm")
        ]
        for url in related where fileManager.fileExists(atPath: url.path) {
            try fileManager.removeItem(at: url)
        }
    }
}