//
//  DocumentPatternDetector.swift
//  VaultEye
//
//  Detects document types based on text patterns
//

import Foundation
import UIKit
import Vision
import OSLog

/// Detects document types by analyzing text patterns
class DocumentPatternDetector {
    private let logger = Logger(subsystem: "com.vaulteye.app", category: "PatternDetector")

    /// Detected document type based on text patterns
    enum DocumentType: String {
        case creditCard = "credit_card"
        case passport = "passport"
        case idCard = "id_card"
        case unknown = "unknown"

        var displayName: String {
            switch self {
            case .creditCard: return "Credit Card"
            case .passport: return "Passport"
            case .idCard: return "ID Card"
            case .unknown: return "Unknown"
            }
        }
    }

    /// Analyze text from an image to detect document type
    func detectDocumentType(from image: UIImage) async throws -> DocumentType {
        guard let cgImage = image.cgImage else {
            throw NSError(domain: "DocumentPatternDetector", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to get CGImage"])
        }

        // Extract all text from image
        let text = try await extractText(from: cgImage)

        logger.info("[Pattern] Extracted text length: \(text.count) characters")

        // Analyze text patterns
        let documentType = analyzeTextPatterns(text)

        logger.info("[Pattern] Detected document type: \(documentType.rawValue)")

        return documentType
    }

    // MARK: - Private Helpers

    private func extractText(from cgImage: CGImage) async throws -> String {
        return try await withCheckedThrowingContinuation { continuation in
            let request = VNRecognizeTextRequest { request, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }

                guard let observations = request.results as? [VNRecognizedTextObservation] else {
                    continuation.resume(returning: "")
                    return
                }

                let text = observations.compactMap { observation in
                    observation.topCandidates(1).first?.string
                }.joined(separator: "\n")

                continuation.resume(returning: text)
            }

            request.recognitionLevel = .accurate
            request.usesLanguageCorrection = false

            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])

            do {
                try handler.perform([request])
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }

    private func analyzeTextPatterns(_ text: String) -> DocumentType {
        let uppercaseText = text.uppercased()
        let normalizedText = text.replacingOccurrences(of: " ", with: "")

        // Credit Card Patterns (highest priority)
        if hasCreditCardPattern(normalizedText, uppercaseText) {
            logger.info("[Pattern] ✅ Credit card patterns found")
            return .creditCard
        }

        // Passport Patterns
        if hasPassportPattern(uppercaseText) {
            logger.info("[Pattern] ✅ Passport patterns found")
            return .passport
        }

        // ID Card patterns (fallback)
        if hasIDCardPattern(uppercaseText) {
            logger.info("[Pattern] ✅ ID card patterns found")
            return .idCard
        }

        return .unknown
    }

    private func hasCreditCardPattern(_ normalizedText: String, _ uppercaseText: String) -> Bool {
        // Check for 16-digit card numbers (with or without spaces/dashes)
        let cardNumberPattern = "\\d{4}[\\s-]?\\d{4}[\\s-]?\\d{4}[\\s-]?\\d{4}"
        if normalizedText.range(of: cardNumberPattern, options: .regularExpression) != nil {
            return true
        }

        // Check for credit card keywords
        let creditCardKeywords = [
            "VISA", "MASTERCARD", "AMEX", "DISCOVER",
            "VALID THRU", "EXPIRES", "EXP DATE",
            "CARDHOLDER", "CARD HOLDER",
            "CVV", "CVC", "SECURITY CODE"
        ]

        let keywordMatches = creditCardKeywords.filter { uppercaseText.contains($0) }.count
        if keywordMatches >= 2 {
            return true
        }

        // Check for expiration date pattern (MM/YY or MM/YYYY)
        let expirationPattern = "\\d{2}/\\d{2,4}"
        if uppercaseText.contains("VALID") || uppercaseText.contains("EXP") {
            if normalizedText.range(of: expirationPattern, options: .regularExpression) != nil {
                return true
            }
        }

        return false
    }

    private func hasPassportPattern(_ uppercaseText: String) -> Bool {
        // Check for passport keywords (need multiple matches to be confident)
        let passportKeywords = [
            "PASSPORT", "PASSEPORT", "PASAPORTE",
            "P<", // Machine readable zone prefix
            "SURNAME", "GIVEN NAME", "GIVEN NAMES",
            "NATIONALITY", "DATE OF BIRTH",
            "PLACE OF BIRTH",
            "SEX", "M/F",
            "PASSPORT NO", "PASSPORT NUMBER",
            "AUTHORITY", "ISSUING"
        ]

        let keywordMatches = passportKeywords.filter { uppercaseText.contains($0) }.count

        // Need at least 3 passport-specific keywords
        if keywordMatches >= 3 {
            return true
        }

        // Check for machine-readable zone pattern (starts with P<)
        if uppercaseText.contains("P<") {
            return true
        }

        return false
    }

    private func hasIDCardPattern(_ uppercaseText: String) -> Bool {
        // Check for ID card keywords
        let idKeywords = [
            "DRIVER LICENSE", "DRIVER'S LICENSE", "DRIVING LICENCE",
            "DL", "LICENSE NO", "LICENSE NUMBER",
            "STATE ID", "IDENTIFICATION CARD",
            "DOB", "DATE OF BIRTH",
            "HEIGHT", "WEIGHT", "EYES", "HAIR",
            "CLASS", "RESTRICTIONS", "ENDORSEMENTS",
            "ISSUED", "EXPIRES"
        ]

        let keywordMatches = idKeywords.filter { uppercaseText.contains($0) }.count

        // Need at least 2 ID-specific keywords
        if keywordMatches >= 2 {
            return true
        }

        return false
    }
}
