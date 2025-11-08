import Foundation

enum PrivacyRiskExample {
    static func run() {
        let detections = [
            Detection(type: "passport", confidence: 0.88),
            Detection(type: "id_card", confidence: 0.91)
        ]

        let scoreService = ScoreService()
        let riskResult = scoreService.computeRiskResult(for: detections)

        let geminiService = GeminiService(apiKey: "YOUR_GEMINI_API_KEY")
        geminiService.generateExplanation(for: riskResult) { result in
            switch result {
            case .success(let explanation):
                print("Gemini JSON response:\n\(explanation)")
            case .failure(let error):
                print("Failed to fetch explanation: \(error)")
            }
        }
    }
}
