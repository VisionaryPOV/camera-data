import Foundation
import CameraDataDomain

public enum LogEntryMapper {
    public static func toDraft(_ model: LogEntryModel) -> LogEntryDraft {
        var custom: [String: String] = [:]
        for value in model.customValues {
            if let key = value.definition?.key, let str = value.stringValue {
                custom[key] = str
            }
        }

        return LogEntryDraft(
            scene: model.scene,
            take: model.take,
            setup: model.setup,
            lens: model.lens,
            filter: model.filter,
            iso: model.iso,
            shutterAngle: model.shutterAngle,
            shutterSpeed: model.shutterSpeed,
            whiteBalance: model.whiteBalance,
            fps: model.fps,
            resolution: model.resolution,
            codec: model.codec,
            rollNumber: model.rollNumber,
            timecodeIn: model.timecodeIn,
            timecodeOut: model.timecodeOut,
            duration: model.duration,
            notes: model.notes,
            scriptNotes: model.scriptNotes,
            vfxNotes: model.vfxNotes,
            isCircled: model.isCircled,
            isMOS: model.isMOS,
            isPickup: model.isPickup,
            isTail: model.isTail,
            isHold: model.isHold,
            isBad: model.isBad,
            isSeries: model.isSeries,
            customValues: custom
        )
    }

    public static func apply(_ draft: LogEntryDraft, to model: LogEntryModel, modifiedBy: String) {
        model.scene = draft.scene
        model.take = draft.take
        model.setup = draft.setup
        model.sortKey = SortKeyGenerator.make(scene: draft.scene, take: draft.take)
        model.lens = draft.lens
        model.filter = draft.filter
        model.iso = draft.iso
        model.shutterAngle = draft.shutterAngle
        model.shutterSpeed = draft.shutterSpeed
        model.whiteBalance = draft.whiteBalance
        model.fps = draft.fps
        model.resolution = draft.resolution
        model.codec = draft.codec
        model.rollNumber = draft.rollNumber
        model.timecodeIn = draft.timecodeIn
        model.timecodeOut = draft.timecodeOut
        model.duration = draft.duration
        model.notes = draft.notes
        model.scriptNotes = draft.scriptNotes
        model.vfxNotes = draft.vfxNotes
        model.isCircled = draft.isCircled
        model.isMOS = draft.isMOS
        model.isPickup = draft.isPickup
        model.isTail = draft.isTail
        model.isHold = draft.isHold
        model.isBad = draft.isBad
        model.isSeries = draft.isSeries
        model.modifiedAt = .now
        model.modifiedBy = modifiedBy
        model.syncVersion += 1
    }

    public static func captureContext(from model: LogEntryModel) -> CaptureContext {
        CaptureContext(
            latitude: model.latitude,
            longitude: model.longitude,
            altitude: model.altitude,
            pitch: model.pitch,
            roll: model.roll,
            yaw: model.yaw
        )
    }

    public static func applyCaptureContext(_ context: CaptureContext, to model: LogEntryModel) {
        model.latitude = context.latitude
        model.longitude = context.longitude
        model.altitude = context.altitude
        model.pitch = context.pitch
        model.roll = context.roll
        model.yaw = context.yaw
    }
}