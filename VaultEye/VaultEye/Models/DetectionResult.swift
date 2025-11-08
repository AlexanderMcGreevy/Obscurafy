//
//  DetectionResult.swift
//  VaultEye
//
//  Created by Alexander McGreevy on 11/7/25.
//

import Photos
import UIKit

struct DetectionResult: Identifiable {
    let id: UUID
    let asset: PHAsset?
    let isFlagged: Bool
    var detectedRegions: [DetectedRegion]
    var reason: String
    var ocrSegments: [OCRTextSegment]
    var analysisStatus: AnalysisStatus
    var analysis: SensitiveAnalysisResult?
    var analysisMessage: String?
    var privacyScore: Double?
    var thumbnail: UIImage?

    init(
        id: UUID = UUID(),
        asset: PHAsset?,
        isFlagged: Bool,
        detectedRegions: [DetectedRegion],
        reason: String,
        ocrSegments: [OCRTextSegment] = [],
        analysisStatus: AnalysisStatus = .pending,
        analysis: SensitiveAnalysisResult? = nil,
        analysisMessage: String? = nil,
        privacyScore: Double? = nil,
        thumbnail: UIImage? = nil
    ) {
        self.id = id
        self.asset = asset
        self.isFlagged = isFlagged
        self.detectedRegions = detectedRegions
        self.reason = reason
        self.ocrSegments = ocrSegments
        self.analysisStatus = analysisStatus
        self.analysis = analysis
        self.analysisMessage = analysisMessage
        self.privacyScore = privacyScore
        self.thumbnail = thumbnail
    }

    var geminiExplanation: String? {
        analysis?.explanation
    }

    // For preview support - store asset identifier
    var assetIdentifier: String {
        asset?.localIdentifier ?? id.uuidString
    }
}
