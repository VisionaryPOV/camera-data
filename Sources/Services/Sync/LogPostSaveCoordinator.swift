import Foundation

public struct LogPostSaveCoordinator: Sendable {
    private let syncEngine: SyncEngine
    private let flushAfterEnqueue: Bool

    public init(syncEngine: SyncEngine, flushAfterEnqueue: Bool = true) {
        self.syncEngine = syncEngine
        self.flushAfterEnqueue = flushAfterEnqueue
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

        if flushAfterEnqueue {
            _ = await syncEngine.flushOfflineQueue()
        }
    }
}