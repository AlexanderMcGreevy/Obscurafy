//
//  MockData.swift
//  VaultEye
//
//  Created by Alexander McGreevy on 11/7/25.
//

import Photos
import UIKit

extension DetectionResult {
    static var mockFlagged: DetectionResult {
        let cardRegion = DetectedRegion(
            normalizedRect: CGRect(x: 0.2, y: 0.3, width: 0.4, height: 0.3),
            confidence: 0.92,
            label: "Credit Card"
        )
        let ssnRegion = DetectedRegion(
            normalizedRect: CGRect(x: 0.5, y: 0.6, width: 0.3, height: 0.2),
            confidence: 0.87,
            label: "Social Security Number"
        )

        return DetectionResult(
            asset: nil,  // No real asset for previews
            isFlagged: true,
            detectedRegions: [cardRegion, ssnRegion],
            reason: "Contains sensitive information: Credit Card, SSN",
            ocrSegments: [
                OCRTextSegment(
                    regionID: cardRegion.id,
                    rawText: "4111 1111 1111 1111\nEXP 04/27",
                    sanitizedText: "•••• •••• •••• 1111\nEXP 04/27"
                ),
                OCRTextSegment(
                    regionID: ssnRegion.id,
                    rawText: "SSN: 123-45-6789",
                    sanitizedText: "SSN: •••-••-6789"
                )
            ],
            analysisStatus: .completed,
            analysis: SensitiveAnalysisResult(
                explanation: "Credit card and SSN are visible; both expose identity details.",
                riskLevel: .high,
                keyPhrases: ["•••• •••• •••• 1111", "SSN: •••-••-6789"],
                recommendedActions: ["Delete image from shared locations", "Redact card number before sharing"],
                categories: [
                    SensitiveCategoryPrediction(category: .creditCard, confidence: 0.97),
                    SensitiveCategoryPrediction(category: .ssn, confidence: 0.93)
                ]
            ),
            analysisMessage: nil,
            privacyScore: 0.89,
            thumbnail: createMockImage(color: .systemBlue)
        )
    }

    static var mockClean: DetectionResult {
        return DetectionResult(
            asset: nil,  // No real asset for previews
            isFlagged: false,
            detectedRegions: [],
            reason: "No sensitive content detected",
            ocrSegments: [],
            analysisStatus: .pending,
            analysis: nil,
            analysisMessage: nil,
            privacyScore: nil,
            thumbnail: createMockImage(color: .systemGreen)
        )
    }

    private static func createMockImage(color: UIColor) -> UIImage {
        let size = CGSize(width: 200, height: 200)
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { context in
            color.setFill()
            context.fill(CGRect(origin: .zero, size: size))

            // Add a simple icon
            let iconSize: CGFloat = 80
            let iconRect = CGRect(
                x: (size.width - iconSize) / 2,
                y: (size.height - iconSize) / 2,
                width: iconSize,
                height: iconSize
            )

            UIColor.white.setFill()
            context.cgContext.fillEllipse(in: iconRect)
        }
    }
}
