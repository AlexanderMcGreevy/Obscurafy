import Foundation

final class GeminiService {
    private let apiKey: String
    private let session: URLSession
    private let endpoint = "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent"

    init(apiKey: String, session: URLSession = .shared) {
        self.apiKey = apiKey
        self.session = session
    }

    func generateExplanation(for riskResult: RiskResult, completion: @escaping (Result<String, Error>) -> Void) {
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

        let prompt = buildPrompt(for: riskResult)
        let body = GenerateContentRequest(contents: [
            GenerateContentRequest.Content(parts: [
                GenerateContentRequest.Content.Part(text: prompt)
            ])
        ])

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
                guard let explanation = decoded.primaryText else {
                    completion(.failure(GeminiServiceError.missingContent))
                    return
                }

                let payload = GeminiExplanationPayload(globalScore: riskResult.globalScore,
                                                       entities: riskResult.entities,
                                                       explanation: explanation)

                let encoder = JSONEncoder()
                encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
                let jsonData = try encoder.encode(payload)

                guard let jsonString = String(data: jsonData, encoding: .utf8) else {
                    completion(.failure(GeminiServiceError.encodingFailure))
                    return
                }

                completion(.success(jsonString))
            } catch {
                completion(.failure(error))
            }
        }.resume()
    }

    private func buildPrompt(for riskResult: RiskResult) -> String {
        let entityStrings = riskResult.entities
            .map { "\($0.type) (risk score: \($0.score))" }
            .joined(separator: ", ")

        return "You are a privacy assistant on a mobile device. You receive only metadata about an image: a global risk score and a list of entities with risk scores. You never see the image or raw text. Based on the metadata, explain in 1–2 sentences why this image might expose personal identity information. Do not invent card numbers or personal details. Global risk score: \(riskResult.globalScore). Entities: \(entityStrings)."
    }
}

private enum GeminiServiceError: Error {
    case invalidURL
    case invalidResponse
    case emptyResponse
    case missingContent
    case encodingFailure
}

private struct GeminiExplanationPayload: Codable {
    let entities: [EntityRisk]
    let explanation: String
    let globalScore: Int

    init(globalScore: Int, entities: [EntityRisk], explanation: String) {
        self.globalScore = globalScore
        self.entities = entities
        self.explanation = explanation
    }
}

private struct GenerateContentRequest: Codable {
    let contents: [Content]

    struct Content: Codable {
        let parts: [Part]

        struct Part: Codable {
            let text: String
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
