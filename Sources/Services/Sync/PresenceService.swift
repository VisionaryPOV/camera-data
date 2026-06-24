import Foundation
import CameraDataDomain

public actor PresenceService {
    private var presences: [String: PresenceInfo] = [:]
    private let staleInterval: TimeInterval = 30

    public init() {}

    public func heartbeat(userId: String, displayName: String, editingEntryLabel: String?) {
        presences[userId] = PresenceInfo(
            userId: userId,
            displayName: displayName,
            editingEntryLabel: editingEntryLabel,
            lastHeartbeat: .now
        )
    }

    public func activePresences(now: Date = .now) -> [PresenceInfo] {
        presences.values.filter { now.timeIntervalSince($0.lastHeartbeat) < staleInterval }
            .sorted { $0.displayName < $1.displayName }
    }

    public func presenceLabel(for userId: String) -> String? {
        guard let info = presences[userId] else { return nil }
        if let editing = info.editingEntryLabel {
            return "\(info.displayName) is editing \(editing)"
        }
        return info.displayName
    }
}