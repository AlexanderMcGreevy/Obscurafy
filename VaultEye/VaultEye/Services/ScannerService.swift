//
//  ScannerService.swift
//  VaultEye
//
//  Created by Alexander McGreevy on 11/7/25.
//

import Photos
import UIKit

class ScannerService {
    private let photoLibraryManager: PhotoLibraryManager

    init(photoLibraryManager: PhotoLibraryManager) {
        self.photoLibraryManager = photoLibraryManager
    }

    /// Temporary: Display ALL photos until real detection is implemented
    func scanPhotos() async -> [DetectionResult] {
        let fetchResult = photoLibraryManager.fetchAllPhotos()
        var results: [DetectionResult] = []

        for index in 0..<fetchResult.count {
            let asset = fetchResult.object(at: index)

            // Temporary: Mark all as flagged for testing UI
            let isFlagged = true

            // Mock detected regions for demo
            let detectedRegions: [DetectedRegion] = [
                DetectedRegion(
                    normalizedRect: CGRect(x: 0.2, y: 0.3, width: 0.4, height: 0.3),
                    confidence: 0.92,
                    label: "Pending Analysis"
                )
            ]
            let reason = "Awaiting sensitive content detection"

            // Load thumbnail
            let thumbnail = await photoLibraryManager.loadThumbnail(
                for: asset,
                targetSize: CGSize(width: 200, height: 200)
            )

            let result = DetectionResult(
                asset: asset,
                isFlagged: isFlagged,
                detectedRegions: detectedRegions,
                reason: reason,
                geminiExplanation: "Real-time detection will be implemented soon",
                privacyScore: 0.5,
                thumbnail: thumbnail
            )

            results.append(result)
        }

        // Return ALL photos (removed filter)
        return results
    }
}
