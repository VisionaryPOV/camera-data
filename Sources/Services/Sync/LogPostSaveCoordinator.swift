import Foundation

public struct LogPostSaveCoordinator: Sendable {
    private let syncEngine: SyncEngine
    private let flushWhenCloudKitEnabled: Bool

    public init(syncEngine: SyncEngine, flushWhenCloudKitEnabled: Bool) {
        self.syncEngine = syncEngine
        self.flushWhenCloudKitEnabled = flushWhenCloudKitEnabled
    }

    public func handle(
        entryId: UUID,
        syncVersion: Int,
        scene: String,
        take: Int,
        lens: String,
        iso: Int,
        productionCode: String
    ) async {
        await syncEngine.enqueueLogEntry(
            entryId: entryId,
            syncVersion: syncVersion,
            scene: scene,
            take: take,
            lens: lens,
            iso: iso,
            productionCode: productionCode
        )

        if flushWhenCloudKitEnabled {
            _ = await syncEngine.flushOfflineQueue()
        }
    }
}