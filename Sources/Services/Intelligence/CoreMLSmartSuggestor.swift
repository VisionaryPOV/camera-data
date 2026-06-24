import Foundation
import CoreML
import CameraDataDomain

public final class CoreMLSmartSuggestor: @unchecked Sendable {
    private let model: MLModel?

    public var isModelLoaded: Bool { model != nil }

    public init(bundle: Bundle = .main) {
        if let url = bundle.url(forResource: "LensPredictor", withExtension: "mlmodelc")
            ?? bundle.url(forResource: "LensPredictor", withExtension: "mlmodel") {
            model = try? MLModel(contentsOf: url)
        } else {
            model = nil
        }
    }

    public func suggest(from history: [LogEntryDraft], for draft: LogEntryDraft) -> [SmartSuggestion] {
        let baseline = SmartSuggestEngine.suggest(from: history, for: draft)
        guard let model else { return baseline }

        return baseline.compactMap { suggestion in
            guard let confidence = predictConfidence(
                history: history,
                draft: draft,
                suggestion: suggestion,
                model: model
            ) else { return suggestion }
            let blended = (suggestion.confidence + confidence) / 2.0
            return SmartSuggestion(field: suggestion.field, value: suggestion.value, confidence: blended)
        }.filter { $0.confidence >= 0.3 }
    }

    public static func historicalFrequency(
        history: [LogEntryDraft],
        scene: String,
        field: String,
        value: String
    ) -> Double {
        let sameScene = history.filter { $0.scene == scene }
        guard !sameScene.isEmpty else { return 0.0 }

        let matches: Int
        switch field {
        case "lens":
            matches = sameScene.filter { $0.lens == value }.count
        case "iso":
            matches = sameScene.filter { String($0.iso) == value }.count
        default:
            return 0.0
        }
        return Double(matches) / Double(sameScene.count)
    }

    public static func sceneNumericFeature(_ scene: String) -> Double {
        let digits = scene.filter(\.isNumber)
        guard let number = Int(digits), number > 0 else { return 0.0 }
        return min(1.0, Double(number) / 100.0)
    }

    private func predictConfidence(
        history: [LogEntryDraft],
        draft: LogEntryDraft,
        suggestion: SmartSuggestion,
        model: MLModel
    ) -> Double? {
        let sceneFeature = Self.sceneNumericFeature(draft.scene)
        let fieldCode: Double = suggestion.field == "lens" ? 1.0 : 2.0
        let frequency = Self.historicalFrequency(
            history: history,
            scene: draft.scene,
            field: suggestion.field,
            value: suggestion.value
        )

        guard let array = try? MLMultiArray(shape: [3], dataType: .double) else { return nil }
        array[0] = NSNumber(value: sceneFeature)
        array[1] = NSNumber(value: fieldCode)
        array[2] = NSNumber(value: frequency)

        guard let input = try? MLDictionaryFeatureProvider(dictionary: ["features": MLFeatureValue(multiArray: array)]),
              let output = try? model.prediction(from: input),
              let confidence = output.featureValue(for: "confidence")?.multiArrayValue?[0].doubleValue else {
            return nil
        }
        return min(1.0, max(0.0, confidence))
    }
}