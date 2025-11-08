import Foundation

final class ScoreService {
    private let baseWeights: [String: Double] = [
        "passport": 85,
        "id_card": 70
    ]

    func computeRiskResult(for detections: [Detection]) -> RiskResult {
        var entityRisks: [EntityRisk] = []

        for detection in detections {
            let baseWeight = baseWeights[detection.type, default: 0]
            let rawScore = baseWeight * detection.confidence
            let clampedScore = max(0, min(100, Int(rawScore.rounded())))
            entityRisks.append(EntityRisk(type: detection.type, score: clampedScore))
        }

        let maxScore = entityRisks.map { $0.score }.max() ?? 0
        let sensitiveCount = entityRisks.filter { baseWeights.keys.contains($0.type) && $0.score > 0 }.count
        let bump = sensitiveCount > 1 ? 5 : 0
        let globalScore = max(0, min(100, maxScore + bump))

        return RiskResult(globalScore: globalScore, entities: entityRisks)
    }
}
