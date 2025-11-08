import Foundation

struct Detection: Hashable, Codable {
    let type: String
    let confidence: Double
}

struct EntityRisk: Hashable, Codable {
    let type: String
    let score: Int
}

struct RiskResult: Hashable, Codable {
    let globalScore: Int
    let entities: [EntityRisk]
}
