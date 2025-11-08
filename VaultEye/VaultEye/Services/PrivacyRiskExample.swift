import Foundation

enum PrivacyRiskExample {
    static func run() {
        let detections = [
            Detection(type: "passport", confidence: 0.88),
            Detection(type: "id_card", confidence: 0.91)
        ]

        let flagger = SensitiveContentFlagger()
        let flagResult = flagger.flagSensitiveDetections(in: detections, threshold: 0.6)

        guard flagResult.isSensitive else {
            print("No sensitive content detected. Skipping Gemini call.")
            return
        }

        let ocrText = """
        United States of America
        Passport
        Passport No. 123456789
        Doe, Jane Marie
        Date of Birth 04 Jan 1990
        """

        let geminiService = GeminiService(apiKey: "YOUR_GEMINI_API_KEY")

        Task {
            do {
                let analysis = try await geminiService.generateAnalysis(ocrText: ocrText, detections: flagResult.detections)
                print("Gemini analysis: \(analysis)")
            } catch {
                print("Failed to fetch explanation: \(error)")
            }
        }
    }
}
