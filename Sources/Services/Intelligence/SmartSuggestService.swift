import Foundation
import CameraDataDomain

public enum SmartSuggestService {
    public static func suggestions(from history: [LogEntryDraft], for draft: LogEntryDraft) -> [SmartSuggestion] {
        SmartSuggestEngine.suggest(from: history, for: draft)
    }
}