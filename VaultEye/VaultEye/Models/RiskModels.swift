import Foundation

struct Detection: Hashable, Codable {
    let type: String
    let confidence: Double
}

struct SensitiveFlagResult: Hashable, Codable {
    let isSensitive: Bool
    let detections: [Detection]
}
