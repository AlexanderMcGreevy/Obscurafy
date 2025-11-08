import Foundation

final class SensitiveContentFlagger {
    private let sensitiveTypes: Set<String> = [
        "ssn",
        "social_security",
        "credit_card",
        "card_number",
        "bank",
        "bank_account",
        "drivers_license",
        "passport",
        "id_card",
        "address",
        "phone",
        "email"
    ]

    /// Flags content when any sensitive type crosses the confidence threshold.
    func flagSensitiveDetections(in detections: [Detection], threshold: Double = 0.6) -> SensitiveFlagResult {
        let matched = detections.filter { detection in
            let normalized = Self.normalize(type: detection.type)
            return sensitiveTypes.contains(normalized) && detection.confidence >= threshold
        }

        return SensitiveFlagResult(isSensitive: !matched.isEmpty, detections: matched)
    }

    private static func normalize(type: String) -> String {
        return type
            .lowercased()
            .replacingOccurrences(of: " ", with: "_")
            .replacingOccurrences(of: "-", with: "_")
    }
}
