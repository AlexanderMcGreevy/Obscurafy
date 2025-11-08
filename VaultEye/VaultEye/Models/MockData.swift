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
        return DetectionResult(
            asset: nil,  // No real asset for previews
            isFlagged: true,
            detectedRegions: [
                DetectedRegion(
                    normalizedRect: CGRect(x: 0.2, y: 0.3, width: 0.4, height: 0.3),
                    confidence: 0.92,
                    label: "Credit Card"
                ),
                DetectedRegion(
                    normalizedRect: CGRect(x: 0.5, y: 0.6, width: 0.3, height: 0.2),
                    confidence: 0.87,
                    label: "Social Security Number"
                )
            ],
            reason: "Contains sensitive information: Credit Card, SSN",
            geminiExplanation: "This image contains financial information that could be used for identity theft. The detected credit card shows card numbers and expiration date, while the SSN could be used to access personal accounts.",
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
            geminiExplanation: nil,
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
