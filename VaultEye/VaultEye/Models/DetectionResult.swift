//
//  DetectionResult.swift
//  VaultEye
//
//  Created by Alexander McGreevy on 11/7/25.
//

import Photos
import UIKit

struct DetectionResult: Identifiable {
    let id = UUID()
    let asset: PHAsset?
    let isFlagged: Bool
    let detectedRegions: [DetectedRegion]
    let reason: String

    // Placeholder fields for future integration
    var geminiExplanation: String?
    var privacyScore: Double?

    // Cached thumbnail
    var thumbnail: UIImage?

    // For preview support - store asset identifier
    var assetIdentifier: String {
        asset?.localIdentifier ?? id.uuidString
    }
}
