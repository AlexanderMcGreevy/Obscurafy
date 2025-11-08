import Testing
import UIKit
@testable import VaultEye

struct AnalysisPipelineTests {
    private final class MockOCRService: OCRServiceProtocol {
        let segments: [OCRTextSegment]
        let error: Error?

        init(segments: [OCRTextSegment], error: Error? = nil) {
            self.segments = segments
            self.error = error
        }

        func extractSegments(from image: UIImage, regions: [DetectedRegion]) async throws -> [OCRTextSegment] {
            if let error {
                throw error
            }
            return segments
        }
    }

    private final class MockGeminiService: GeminiAnalyzing {
        let result: SensitiveAnalysisResult

        init(result: SensitiveAnalysisResult) {
            self.result = result
        }

        func generateAnalysis(ocrText: String, detections: [Detection]) async throws -> SensitiveAnalysisResult {
            return result
        }
    }

    private final class MockConsentManager: PrivacyConsentManaging {
        var storedConsent: Bool

        init(hasConsented: Bool) {
            storedConsent = hasConsented
        }

        var hasConsented: Bool { storedConsent }

        func recordConsent(_ consented: Bool) {
            storedConsent = consented
        }
    }

    @Test func sanitizerMasksDigitsAndEmails() {
        let raw = "4111 1111 1111 1111 john.doe@example.com"
        let sanitized = TextSanitizer.sanitize(raw)
        #expect(sanitized.contains("•••• •••• •••• 1111"))
        #expect(sanitized.contains("••••@example.com"))
    }

    @Test func pipelineRequiresConsent() async throws {
        let region = DetectedRegion(
            normalizedRect: CGRect(x: 0.1, y: 0.1, width: 0.4, height: 0.2),
            confidence: 0.9,
            label: "Credit Card"
        )
        let detection = Detection(type: "credit_card", confidence: 0.9)
        let mockSegments = [
            OCRTextSegment(regionID: region.id, rawText: "4111111111111111", sanitizedText: "•••• •••• •••• 1111")
        ]

        let mockOCR = MockOCRService(segments: mockSegments)
        let mockGemini = MockGeminiService(result: SensitiveAnalysisResult(
            explanation: "Test",
            riskLevel: .high,
            keyPhrases: [],
            recommendedActions: [],
            categories: [SensitiveCategoryPrediction(category: .creditCard, confidence: 0.9)]
        ))
        let consent = MockConsentManager(hasConsented: false)

        let service = ScannerService(
            photoLibraryManager: nil,
            ocrService: mockOCR,
            geminiService: mockGemini,
            flagger: SensitiveContentFlagger(),
            consentManager: consent
        )

        let result = await service.analyze(
            image: UIImage(),
            asset: nil,
            regions: [region],
            detections: [detection],
            thumbnail: nil
        )

        #expect(result.analysisStatus == .consentRequired)
        #expect(result.analysis == nil)
    }

    @Test func pipelineProducesAnalysis() async throws {
        let region = DetectedRegion(
            normalizedRect: CGRect(x: 0.1, y: 0.1, width: 0.4, height: 0.2),
            confidence: 0.9,
            label: "Credit Card"
        )
        let detection = Detection(type: "credit_card", confidence: 0.9)
        let mockSegments = [
            OCRTextSegment(regionID: region.id, rawText: "4111111111111111", sanitizedText: "•••• •••• •••• 1111")
        ]

        let mockOCR = MockOCRService(segments: mockSegments)
        let analysis = SensitiveAnalysisResult(
            explanation: "Credit card detected",
            riskLevel: .high,
            keyPhrases: ["•••• •••• •••• 1111"],
            recommendedActions: ["Delete"],
            categories: [SensitiveCategoryPrediction(category: .creditCard, confidence: 0.95)]
        )
        let mockGemini = MockGeminiService(result: analysis)
        let consent = MockConsentManager(hasConsented: true)

        let service = ScannerService(
            photoLibraryManager: nil,
            ocrService: mockOCR,
            geminiService: mockGemini,
            flagger: SensitiveContentFlagger(),
            consentManager: consent
        )

        let result = await service.analyze(
            image: UIImage(),
            asset: nil,
            regions: [region],
            detections: [detection],
            thumbnail: nil
        )

        #expect(result.analysisStatus == .completed)
        #expect(result.analysis == analysis)
        #expect(result.privacyScore == 0.9)
        #expect(result.ocrSegments.count == 1)
        #expect(result.ocrSegments.first?.sanitizedText == "•••• •••• •••• 1111")
    }
}
