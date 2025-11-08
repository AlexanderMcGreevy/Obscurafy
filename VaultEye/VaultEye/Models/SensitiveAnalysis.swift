import Foundation

enum SensitiveCategory: String, Codable, CaseIterable, Hashable {
    case ssn
    case creditCard = "credit_card"
    case bank
    case driversLicense = "drivers_license"
    case passport
    case address
    case phone
    case email
    case unknown

    static func from(label: String) -> SensitiveCategory {
        let normalized = label
            .lowercased()
            .replacingOccurrences(of: " ", with: "_")
            .replacingOccurrences(of: "-", with: "_")
        return SensitiveCategory(rawValue: normalized) ?? .unknown
    }
}

struct SensitiveCategoryPrediction: Codable, Hashable {
    let category: SensitiveCategory
    let confidence: Double

    init(category: SensitiveCategory, confidence: Double) {
        self.category = category
        self.confidence = confidence
    }
}

struct SensitiveAnalysisResult: Codable, Hashable {
    enum RiskLevel: String, Codable {
        case low
        case medium
        case high
        case unknown
    }

    let explanation: String
    let riskLevel: RiskLevel
    let keyPhrases: [String]
    let recommendedActions: [String]
    let categories: [SensitiveCategoryPrediction]
}

enum AnalysisStatus: String, Codable {
    case pending
    case consentRequired
    case unreadable
    case unclassified
    case completed
}
