import Foundation

final class GeminiService {
    private let apiKey: String
    private let session: URLSession
    private let endpoint = "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent"

    init(apiKey: String, session: URLSession = .shared) {
        self.apiKey = apiKey
        self.session = session
    }

    func generateExplanation(ocrText: String, detections: [Detection], completion: @escaping (Result<String, Error>) -> Void) {
        guard var components = URLComponents(string: endpoint) else {
            completion(.failure(GeminiServiceError.invalidURL))
            return
        }
        components.queryItems = [URLQueryItem(name: "key", value: apiKey)]

        guard let url = components.url else {
            completion(.failure(GeminiServiceError.invalidURL))
            return
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

        do {
            request.httpBody = try JSONEncoder().encode(body)
        } catch {
            completion(.failure(error))
            return
        }

        session.dataTask(with: request) { data, response, error in
            if let error = error {
                completion(.failure(error))
                return
            }

            guard let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) else {
                completion(.failure(GeminiServiceError.invalidResponse))
                return
            }

            guard let data = data else {
                completion(.failure(GeminiServiceError.emptyResponse))
                return
            }

            do {
                let decoded = try JSONDecoder().decode(GenerateContentResponse.self, from: data)
                guard let rawJSON = decoded.primaryText else {
                    completion(.failure(GeminiServiceError.missingContent))
                    return
                }

                let analysisData = Data(rawJSON.utf8)
                let analysis = try JSONDecoder().decode(GeminiAnalysisPayload.self, from: analysisData)

                let payload = GeminiFrontendPayload(
                    detections: detections,
                    ocrTextSnippet: Self.snippet(from: ocrText),
                    analysis: analysis
                )

                let encoder = JSONEncoder()
                encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
                let jsonData = try encoder.encode(payload)

                guard let jsonString = String(data: jsonData, encoding: .utf8) else {
                    completion(.failure(GeminiServiceError.encodingFailure))
                    return
                }

                completion(.success(jsonString))
            } catch let decodingError as DecodingError {
                completion(.failure(GeminiServiceError.invalidJSON))
            } catch {
                completion(.failure(error))
            }
        }.resume()
    }

    private func buildPrompt(ocrText: String, detections: [Detection]) -> String {
        let formattedDetections = detections
            .map { "\($0.type) (confidence: \(String(format: "%.2f", $0.confidence)))" }
            .joined(separator: ", ")

        return """
        You are a privacy assistant running entirely on device. You receive sanitized OCR text and detection metadata that indicate potential exposure of personal identity information. Detect any privacy risks present in the text, without inventing numbers or details that are not present. Use the detection metadata as hints only.

        Detections: [\(formattedDetections)]
        OCR Text: """
        \(ocrText)
        """

        Respond strictly as minified JSON with the following keys:
        - "explanation": short string describing the risk.
        - "risk_level": one of "low", "medium", or "high".
        - "key_phrases": array of strings highlighting risky fragments taken verbatim from the provided text.
        - "recommended_actions": array of short action items to mitigate exposure.

        Do not include personal identifiers that are not already in the OCR text. Do not add any additional fields.
        """
    }

    private static func snippet(from text: String, limit: Int = 200) -> String {
        guard text.count > limit else { return text }
        let index = text.index(text.startIndex, offsetBy: limit)
        return "\(text[..<index])…"
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
    let explanation: String
    let riskLevel: String
    let keyPhrases: [String]
    let recommendedActions: [String]

    enum CodingKeys: String, CodingKey {
        case explanation
        case riskLevel = "risk_level"
        case keyPhrases = "key_phrases"
        case recommendedActions = "recommended_actions"
    }
}

private struct GeminiFrontendPayload: Codable {
    let analysis: GeminiAnalysisPayload
    let detections: [Detection]
    let ocrTextSnippet: String

    enum CodingKeys: String, CodingKey {
        case analysis
        case detections
        case ocrTextSnippet = "ocr_text_snippet"
    }
}
