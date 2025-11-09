//
//  PhotoScanService.swift
//  VaultEye
//
//  YOLO-powered photo scanning service
//

import Foundation
import Combine
internal import Photos
import OSLog

/// Result of scanning a single photo
struct PhotoScanResult {
    let assetLocalIdentifier: String
    let matched: Bool
    let detections: [YOLODetection]
    let timestamp: Date

    var hasSensitiveContent: Bool {
        detections.contains { YOLOService.isSensitive($0.label) }
    }
}

/// Observable service for scanning photos with YOLO model
@MainActor
final class PhotoScanService: ObservableObject {
    // MARK: - Published State

    @Published var confidenceThreshold: Int = 70  // 0...100
    @Published var isScanning: Bool = false
    @Published var scannedCount: Int = 0
    @Published var matchedCount: Int = 0
    @Published var results: [PhotoScanResult] = []

    // MARK: - Private State

    private let yoloService = YOLOService.shared
    private let logger = Logger(subsystem: "com.vaulteye.app", category: "PhotoScan")
    private var processedAssets: Set<String> = []  // For resume capability

    // MARK: - Computed Properties

    var threshold01: Float {
        Float(confidenceThreshold) / 100.0
    }

    // MARK: - Public API

    /// Scan all photos in the library
    func scanAllPhotos() async {
        guard !isScanning else {
            logger.warning("Scan already in progress")
            return
        }

        isScanning = true
        scannedCount = 0
        matchedCount = 0
        results = []

        logger.info("Starting photo scan with threshold=\(self.confidenceThreshold)%")

        let assets = PhotoAccess.fetchAllImageAssets()

        for (index, assetID) in assets.enumerated() {
            // Skip already processed assets
            if processedAssets.contains(assetID) {
                continue
            }

            guard let asset = PhotoAccess.fetchAsset(byLocalIdentifier: assetID) else {
                continue
            }

            let result = await scanPhoto(asset: asset)

            results.append(result)
            processedAssets.insert(assetID)
            scannedCount = index + 1

            if result.matched {
                matchedCount += 1
            }

            // Log progress every 10 photos
            if scannedCount % 10 == 0 {
                logger.info("Progress: \(self.scannedCount)/\(assets.count) scanned, \(self.matchedCount) matched")
            }
        }

        isScanning = false
        logger.info("Scan complete: \(self.scannedCount) scanned, \(self.matchedCount) matched")
    }

    /// Scan a single photo
    func scanPhoto(asset: PHAsset) async -> PhotoScanResult {
        let detections = await yoloService.detect(asset: asset, threshold01: threshold01)

        // Check if any detection is a sensitive document
        let matched = detections.contains { detection in
            YOLOService.isSensitive(detection.label) && detection.confidence >= threshold01
        }

        return PhotoScanResult(
            assetLocalIdentifier: asset.localIdentifier,
            matched: matched,
            detections: detections,
            timestamp: Date()
        )
    }

    /// Cancel ongoing scan
    func cancelScan() {
        isScanning = false
        logger.info("Scan cancelled at \(self.scannedCount) photos")
    }

    /// Reset scan state (clears processed assets for fresh scan)
    func resetScanState() {
        processedAssets.removeAll()
        results.removeAll()
        scannedCount = 0
        matchedCount = 0
        logger.info("Scan state reset")
    }

    /// Get matched photos (for review screen)
    func getMatchedAssetIDs() -> [String] {
        return results
            .filter { $0.matched }
            .map { $0.assetLocalIdentifier }
    }
}
