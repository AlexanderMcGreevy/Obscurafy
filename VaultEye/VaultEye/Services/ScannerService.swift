//
//  ScannerService.swift
//  VaultEye
//
//  Created by Alexander McGreevy on 11/7/25.
//

import OSLog
import Photos
import UIKit

class ScannerService {
    private let photoLibraryManager: PhotoLibraryManager?
    private let ocrService: OCRServiceProtocol
    private let geminiService: GeminiAnalyzing?
    private let flagger: SensitiveContentFlagger
    private let consentManager: PrivacyConsentManaging
    private let logger = Logger(subsystem: "com.vaulteye.app", category: "ScannerService")

    init(
        photoLibraryManager: PhotoLibraryManager?,
        ocrService: OCRServiceProtocol = VisionOCRService(),
        geminiService: GeminiAnalyzing?,
        flagger: SensitiveContentFlagger = SensitiveContentFlagger(),
        consentManager: PrivacyConsentManaging = PrivacyConsentManager()
    ) {
        self.photoLibraryManager = photoLibraryManager
        self.ocrService = ocrService
        self.geminiService = geminiService
        self.flagger = flagger
        self.consentManager = consentManager
    }

    func scanPhotos() async -> [DetectionResult] {
        guard let photoLibraryManager else { return [] }

        let fetchResult = photoLibraryManager.fetchAllPhotos()
        var results: [DetectionResult] = []

        for index in 0..<fetchResult.count {
            let asset = fetchResult.object(at: index)
            let result = await analyze(asset: asset)
            results.append(result)
        }

        return results
    }

    private func analyze(asset: PHAsset) async -> DetectionResult {
        guard let photoLibraryManager else {
            return await analyze(
                image: nil,
                asset: asset,
                regions: [],
                detections: [],
                thumbnail: nil
            )
        }

        let thumbnail = await photoLibraryManager.loadThumbnail(
            for: asset,
            targetSize: CGSize(width: 200, height: 200)
        )

        let (regions, detections) = await mockDetections()
        let fullImage = await loadFullResolutionImage(for: asset)
        return await analyze(
            image: fullImage,
            asset: asset,
            regions: regions,
            detections: detections,
            thumbnail: thumbnail
        )
    }

    func analyze(
        image: UIImage?,
        asset: PHAsset?,
        regions: [DetectedRegion],
        detections: [Detection],
        thumbnail: UIImage?
    ) async -> DetectionResult {
        let flagResult = flagger.flagSensitiveDetections(in: detections)

        var detectionResult = DetectionResult(
            asset: asset,
            isFlagged: flagResult.isSensitive,
            detectedRegions: regions,
            reason: summaryReason(for: regions),
            ocrSegments: [],
            analysisStatus: flagResult.isSensitive ? .pending : .completed,
            analysis: nil,
            analysisMessage: nil,
            privacyScore: nil,
            thumbnail: thumbnail
        )

        guard flagResult.isSensitive else {
            return detectionResult
        }

        do {
            guard let image else {
                detectionResult.analysisStatus = .unreadable
                detectionResult.analysisMessage = "Unable to load full image for OCR."
                return detectionResult
            }

            let segments = try await ocrService.extractSegments(from: image, regions: regions)
            detectionResult.ocrSegments = segments

            guard consentManager.hasConsented else {
                detectionResult.analysisStatus = .consentRequired
                detectionResult.analysisMessage = "Enable AI analysis to classify sensitive content."
                return detectionResult
            }

            guard let geminiService else {
                detectionResult.analysisStatus = .unclassified
                detectionResult.analysisMessage = "Gemini service not configured."
                return detectionResult
            }

            let sanitizedText = segments
                .map { $0.sanitizedText }
                .joined(separator: "\n---\n")

            let trimmedSanitized = sanitizedText.trimmingCharacters(in: .whitespacesAndNewlines)

            guard !trimmedSanitized.isEmpty else {
                detectionResult.analysisStatus = .unreadable
                detectionResult.analysisMessage = "Sanitized text was empty; nothing to classify."
                return detectionResult
            }

            let analysis = try await geminiService.generateAnalysis(
                ocrText: trimmedSanitized,
                detections: detections
            )

            detectionResult.analysis = analysis
            detectionResult.analysisStatus = .completed
            detectionResult.privacyScore = Self.privacyScore(for: analysis.riskLevel)
            detectionResult.analysisMessage = nil

            if analysis.riskLevel == .high, let asset {
                logger.notice("High risk content detected for asset \(asset.localIdentifier, privacy: .public)")
            }
        } catch OCRServiceError.noTextDetected {
            detectionResult.analysisStatus = .unreadable
            detectionResult.analysisMessage = "Text could not be read in the flagged regions."
        } catch {
            detectionResult.analysisStatus = .unclassified
            detectionResult.analysisMessage = "AI analysis failed: \(error.localizedDescription)"
        }

        return detectionResult
    }

    private func summaryReason(for regions: [DetectedRegion]) -> String {
        guard !regions.isEmpty else {
            return "Awaiting sensitive content detection"
        }

        let labels = regions.map { $0.label }.joined(separator: ", ")
        return "Contains sensitive information: \(labels)"
    }

    private func mockDetections() async -> ([DetectedRegion], [Detection]) {
        // Placeholder detection until CV model integration
        let region = DetectedRegion(
            normalizedRect: CGRect(x: 0.2, y: 0.3, width: 0.45, height: 0.3),
            confidence: 0.9,
            label: "Credit Card"
        )

        let detection = Detection(type: "credit_card", confidence: 0.9)
        return ([region], [detection])
    }

    private func loadFullResolutionImage(for asset: PHAsset) async -> UIImage? {
        await withCheckedContinuation { continuation in
            let options = PHImageRequestOptions()
            options.deliveryMode = .highQualityFormat
            options.isNetworkAccessAllowed = true
            options.isSynchronous = false

            PHImageManager.default().requestImage(
                for: asset,
                targetSize: PHImageManagerMaximumSize,
                contentMode: .default,
                options: options
            ) { image, _ in
                continuation.resume(returning: image)
            }
        }
    }

    private static func privacyScore(for riskLevel: SensitiveAnalysisResult.RiskLevel) -> Double {
        switch riskLevel {
        case .high:
            return 0.9
        case .medium:
            return 0.6
        case .low:
            return 0.3
        case .unknown:
            return 0.2
        }
    }
}
