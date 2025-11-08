import Foundation

protocol GeminiAnalyzing {
    func generateAnalysis(ocrText: String, detections: [Detection]) async throws -> SensitiveAnalysisResult
}

final class GeminiService: GeminiAnalyzing {
    private let apiKey: String
    private let session: URLSession
    private let endpoint = "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent"

    init(apiKey: String, session: URLSession = .shared) {
        self.apiKey = apiKey
        self.session = session
    }

    func generateAnalysis(ocrText: String, detections: [Detection]) async throws -> SensitiveAnalysisResult {
        guard var components = URLComponents(string: endpoint) else {
            throw GeminiServiceError.invalidURL
        }
        components.queryItems = [URLQueryItem(name: "key", value: apiKey)]

        guard let url = components.url else {
            throw GeminiServiceError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")

        let prompt = buildPrompt(ocrText: ocrText, detections: detections)
        let body = GenerateContentRequest(
            contents: [
                GenerateContentRequest.Content(parts: [
                    GenerateContentRequest.Content.Part(text: prompt)
                ])
            ],
            generationConfig: .init(responseMimeType: "application/json")
        )

        request.httpBody = try JSONEncoder().encode(body)

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) else {
            throw GeminiServiceError.invalidResponse
        }

        let decoded = try JSONDecoder().decode(GenerateContentResponse.self, from: data)
        guard let rawJSON = decoded.primaryText else {
            throw GeminiServiceError.missingContent
        }

        let analysisData = Data(rawJSON.utf8)
        let analysisPayload = try JSONDecoder().decode(GeminiAnalysisPayload.self, from: analysisData)
        return analysisPayload.toDomain()
    }

    private func buildPrompt(ocrText: String, detections: [Detection]) -> String {
        let formattedDetections = detections
            .map { "\($0.type) (confidence: \(String(format: "%.2f", $0.confidence)))" }
            .joined(separator: ", ")

        let allowedCategories = SensitiveCategory.allCases
            .filter { $0 != .unknown }
            .map { $0.rawValue }
            .joined(separator: ", ")

        return """
        You are a privacy assistant running on-device. You receive sanitized OCR text and detection metadata that indicate potential exposure of personal identity information. Detect any privacy risks present in the text without fabricating data. Detection metadata is a hint only.

        Detections: [\(formattedDetections)]
        OCR Text (already sanitized):
        \(ocrText)

        Respond STRICTLY as minified JSON using these keys:
        - "explanation": concise description of the identified risk.
        - "risk_level": one of "low", "medium", "high".
        - "categories": array of objects {"label": string, "confidence": number between 0 and 1}. Labels must be chosen from [\(allowedCategories)].
        - "key_phrases": array of verbatim fragments from the provided OCR text that demonstrate the risk.
        - "recommended_actions": array of short mitigation steps.

        Do not add extra keys. Only quote verbatim content from OCR text when referencing sensitive fragments.
        """
    }
}

private enum GeminiServiceError: Error {
    case invalidURL
    case invalidResponse
    case emptyResponse
    case missingContent
    case encodingFailure
    case invalidJSON
}

private struct GenerateContentRequest: Codable {
    let contents: [Content]
    let generationConfig: GenerationConfig?

    struct Content: Codable {
        let parts: [Part]

        struct Part: Codable {
            let text: String
        }
    }

    struct GenerationConfig: Codable {
        let responseMimeType: String?

        init(responseMimeType: String?) {
            self.responseMimeType = responseMimeType
        }
    }
}

private struct GenerateContentResponse: Codable {
    let candidates: [Candidate]?

    struct Candidate: Codable {
        let content: Content?

        struct Content: Codable {
            let parts: [Part]?

            struct Part: Codable {
                let text: String?
            }
        }
    }

    var primaryText: String? {
        candidates?.compactMap { candidate in
            candidate.content?.parts?.compactMap { $0.text }.joined(separator: " ")
        }.first { !$0.isEmpty }
    }
}

private struct GeminiAnalysisPayload: Codable {
    struct Category: Codable {
        let label: String
        let confidence: Double
    }

    let explanation: String
    let riskLevel: String
    let keyPhrases: [String]
    let recommendedActions: [String]
    let categories: [Category]

    enum CodingKeys: String, CodingKey {
        case explanation
        case riskLevel = "risk_level"
        case keyPhrases = "key_phrases"
        case recommendedActions = "recommended_actions"
        case categories
    }

    func toDomain() -> SensitiveAnalysisResult {
        let predictions = categories.map { category in
            SensitiveCategoryPrediction(
                category: SensitiveCategory.from(label: category.label),
                confidence: category.confidence
            )
        }

        let risk = SensitiveAnalysisResult.RiskLevel(rawValue: riskLevel.lowercased()) ?? .unknown

        return SensitiveAnalysisResult(
            explanation: explanation,
            riskLevel: risk,
            keyPhrases: keyPhrases,
            recommendedActions: recommendedActions,
            categories: predictions
        )
    }
}
