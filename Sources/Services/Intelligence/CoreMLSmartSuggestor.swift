import Foundation
import CoreML
import CameraDataDomain

public final class CoreMLSmartSuggestor: @unchecked Sendable {
    private let model: MLModel?

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
                scene: draft.scene,
                field: suggestion.field,
                value: suggestion.value,
                model: model
            ) else { return suggestion }
            let blended = (suggestion.confidence + confidence) / 2.0
            return SmartSuggestion(field: suggestion.field, value: suggestion.value, confidence: blended)
        }.filter { $0.confidence >= 0.3 }
    }

    private func predictConfidence(scene: String, field: String, value: String, model: MLModel) -> Double? {
        let sceneHash = Double(abs(scene.hashValue % 1000)) / 1000.0
        let fieldCode: Double = field == "lens" ? 1.0 : 2.0
        let valueHash = Double(abs(value.hashValue % 1000)) / 1000.0

        guard let array = try? MLMultiArray(shape: [3], dataType: .double) else { return nil }
        array[0] = NSNumber(value: sceneHash)
        array[1] = NSNumber(value: fieldCode)
        array[2] = NSNumber(value: valueHash)

        guard let input = try? MLDictionaryFeatureProvider(dictionary: ["features": MLFeatureValue(multiArray: array)]),
              let output = try? model.prediction(from: input),
              let confidence = output.featureValue(for: "confidence")?.multiArrayValue?[0].doubleValue else {
            return nil
        }
        return min(1.0, max(0.0, confidence))
    }
}