import Foundation

final class SensitiveContentFlagger {
    private let sensitiveTypes: Set<String> = [
        "passport",
        "id_card"
    ]

    /// Flags content when any sensitive type crosses the confidence threshold.
    func flagSensitiveDetections(in detections: [Detection], threshold: Double = 0.6) -> SensitiveFlagResult {
        let matched = detections.filter { detection in
            sensitiveTypes.contains(detection.type) && detection.confidence >= threshold
        }

        return SensitiveFlagResult(isSensitive: !matched.isEmpty, detections: matched)
    }
}
