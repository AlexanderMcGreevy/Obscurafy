//
//  RedactionService.swift
//  VaultEye
//
//  Created by Alexander McGreevy on 11/8/25.
//

internal import Photos
import UIKit
import Vision
import CoreImage

enum RedactionError: Error {
    case loadImageFailed
    case ocrFailed
    case renderFailed
    case saveFailed
    case noTextFound
}

protocol RedactionServiceProtocol {
    func redactAndReplace(asset: PHAsset, onOriginalAsset: ((PHAsset) -> Void)?) async throws -> PHAsset
}

class RedactionService: RedactionServiceProtocol {
    private let padding: CGFloat = 6.0
    private let blurRadius: CGFloat = 10.0

    init() {}

    /// Main entry point: detect text, blur it, save new asset, queue original for deletion
    @MainActor
    func redactAndReplace(asset: PHAsset, onOriginalAsset: ((PHAsset) -> Void)? = nil) async throws -> PHAsset {
        print("🔒 Starting redaction process for asset: \(asset.localIdentifier)")

        // Save original creation date
        let originalCreationDate = asset.creationDate

        // Step 1: Load the full-resolution image
        print("  Step 1: Loading full-resolution image...")
        guard let image = await loadImage(from: asset) else {
            print("  ❌ Failed to load image")
            throw RedactionError.loadImageFailed
        }
        print("  ✅ Image loaded: \(Int(image.size.width))×\(Int(image.size.height))px")

        // Step 2: Detect text boxes using Vision OCR
        print("  Step 2: Detecting text with Vision OCR...")
        let textBoxes = try await detectText(in: image)

        guard !textBoxes.isEmpty else {
            print("  ❌ No text found in image")
            throw RedactionError.noTextFound
        }

        // Step 3: Blur text regions
        print("  Step 3: Blurring \(textBoxes.count) text region(s)...")
        guard let redactedImage = blurText(in: image, boxes: textBoxes) else {
            print("  ❌ Failed to render blurred image")
            throw RedactionError.renderFailed
        }
        print("  ✅ Text regions blurred successfully")

        // Step 4: Save as new asset with original creation date
        print("  Step 4: Saving redacted image to photo library...")
        let newAsset = try await saveAsNewAsset(image: redactedImage, creationDate: originalCreationDate)
        print("  ✅ New asset saved: \(newAsset.localIdentifier)")

        // Step 5: Queue ORIGINAL uncensored photo for deletion via callback
        print("  Step 5: Queuing original uncensored photo for deletion...")
        onOriginalAsset?(asset)
        print("  ✅ Original photo queued for batch deletion")

        print("🎉 Redaction complete! New redacted photo added, original queued for deletion")
        return newAsset
    }

    // MARK: - Private Methods

    private func loadImage(from asset: PHAsset) async -> UIImage? {
        return await withCheckedContinuation { continuation in
            let options = PHImageRequestOptions()
            options.deliveryMode = .highQualityFormat
            options.isNetworkAccessAllowed = false // On-device only
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

    private func detectText(in image: UIImage) async throws -> [CGRect] {
        guard let cgImage = image.cgImage else {
            throw RedactionError.ocrFailed
        }

        return try await withCheckedThrowingContinuation { continuation in
            let request = VNRecognizeTextRequest { request, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }

                guard let observations = request.results as? [VNRecognizedTextObservation] else {
                    print("⚠️ OCR: No text observations found")
                    continuation.resume(returning: [])
                    return
                }

                print("📝 OCR: Found \(observations.count) text observation(s)")

                // Convert normalized coordinates to image coordinates with padding
                let imageSize = CGSize(width: cgImage.width, height: cgImage.height)
                var boxes: [CGRect] = []

                for (index, observation) in observations.enumerated() {
                    // Extract the recognized text
                    let topCandidate = observation.topCandidates(1).first
                    let recognizedText = topCandidate?.string ?? ""
                    let confidence = topCandidate?.confidence ?? 0.0

                    print("  [\(index + 1)] Text: \"\(recognizedText)\" (confidence: \(String(format: "%.2f", confidence)))")

                    let box = observation.boundingBox

                    // Convert from normalized (0-1, origin bottom-left) to image coordinates
                    let rect = VNImageRectForNormalizedRect(
                        box,
                        Int(imageSize.width),
                        Int(imageSize.height)
                    )

                    // Add padding
                    let paddedRect = rect.insetBy(dx: -self.padding, dy: -self.padding)
                    boxes.append(paddedRect)
                }

                // Merge overlapping boxes
                let merged = self.mergeOverlappingBoxes(boxes)
                print("✅ OCR: Merged into \(merged.count) redaction region(s)")
                continuation.resume(returning: merged)
            }

            // Use accurate recognition for best results
            request.recognitionLevel = .accurate
            request.usesLanguageCorrection = false // Faster, we only need regions

            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])

            do {
                try handler.perform([request])
            } catch {
                continuation.resume(throwing: RedactionError.ocrFailed)
            }
        }
    }

    private func mergeOverlappingBoxes(_ boxes: [CGRect]) -> [CGRect] {
        guard !boxes.isEmpty else { return [] }

        var merged: [CGRect] = []
        var remaining = boxes.sorted { $0.origin.y < $1.origin.y }

        while !remaining.isEmpty {
            var current = remaining.removeFirst()
            var didMerge = true

            while didMerge {
                didMerge = false
                for (index, box) in remaining.enumerated() {
                    if current.intersects(box) || current.insetBy(dx: -padding, dy: -padding).intersects(box) {
                        current = current.union(box)
                        remaining.remove(at: index)
                        didMerge = true
                        break
                    }
                }
            }

            merged.append(current)
        }

        return merged
    }

    private func blurText(in image: UIImage, boxes: [CGRect]) -> UIImage? {
        guard let ciImage = CIImage(image: image) else { return nil }

        let context = CIContext(options: nil)

        // Create a mask where text regions are white
        let maskImage = createMask(for: boxes, imageSize: image.size)
        guard let ciMask = CIImage(image: maskImage) else { return nil }

        // Apply Gaussian blur to entire image
        guard let blurFilter = CIFilter(name: "CIGaussianBlur") else { return nil }
        blurFilter.setValue(ciImage, forKey: kCIInputImageKey)
        blurFilter.setValue(blurRadius, forKey: kCIInputRadiusKey)
        guard let blurred = blurFilter.outputImage else { return nil }

        // Blend original with blurred using mask
        guard let blendFilter = CIFilter(name: "CIBlendWithMask") else { return nil }
        blendFilter.setValue(blurred, forKey: kCIInputImageKey)
        blendFilter.setValue(ciImage, forKey: kCIInputBackgroundImageKey)
        blendFilter.setValue(ciMask, forKey: kCIInputMaskImageKey)

        guard let output = blendFilter.outputImage else { return nil }

        // Render to UIImage
        guard let cgImage = context.createCGImage(output, from: output.extent) else { return nil }

        return UIImage(cgImage: cgImage, scale: image.scale, orientation: image.imageOrientation)
    }

    private func createMask(for boxes: [CGRect], imageSize: CGSize) -> UIImage {
        let renderer = UIGraphicsImageRenderer(size: imageSize)

        return renderer.image { context in
            // Black background
            UIColor.black.setFill()
            context.fill(CGRect(origin: .zero, size: imageSize))

            // White rectangles for text regions
            UIColor.white.setFill()
            for box in boxes {
                context.fill(box)
            }
        }
    }

    private func saveAsNewAsset(image: UIImage, creationDate: Date?) async throws -> PHAsset {
        var assetId: String?

        try await PHPhotoLibrary.shared().performChanges {
            let request = PHAssetChangeRequest.creationRequestForAsset(from: image)

            // Preserve the original creation date if available
            if let originalDate = creationDate {
                request.creationDate = originalDate
            }

            assetId = request.placeholderForCreatedAsset?.localIdentifier
        }

        guard let id = assetId else {
            throw RedactionError.saveFailed
        }

        let fetchResult = PHAsset.fetchAssets(withLocalIdentifiers: [id], options: nil)
        guard let asset = fetchResult.firstObject else {
            throw RedactionError.saveFailed
        }

        return asset
    }
}
