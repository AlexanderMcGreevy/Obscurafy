//
//  YOLOService.swift
//  VaultEye
//
//  Core ML YOLO object detection service
//

import Foundation
import UIKit
import CoreML
import Vision
import OSLog
internal import Photos

/// Detection result from YOLO model
struct YOLODetection: Identifiable, Hashable {
    let id: UUID
    let label: String
    let confidence: Float  // 0...1
    let boundingBox: CGRect  // Normalized coordinates (0...1)

    init(id: UUID = UUID(), label: String, confidence: Float, boundingBox: CGRect) {
        self.id = id
        self.label = label
        self.confidence = confidence
        self.boundingBox = boundingBox
    }
}

/// Dynamic label loader with multiple fallback sources
class ModelLabelLoader {
    private let logger = Logger(subsystem: "com.vaulteye.app", category: "Labels")
    private let labels: [String]

    /// Sensitive document classes we care about
    static let sensitiveLabels: Set<String> = [
        "credit_card",
        "id_card",
        "passport",
        "drivers_license",
        "bank_statement",
        "ssn"
    ]

    init(model: MLModel, numClasses: Int) {
        // Priority 1: Try model.modelDescription.classLabels
        if let classLabels = model.modelDescription.classLabels as? [String], !classLabels.isEmpty {
            logger.info("[Labels] Loaded \(classLabels.count) labels from model.modelDescription.classLabels")
            self.labels = Self.sanitizeLabels(classLabels)
            return
        }

        // Priority 2: Try model.modelDescription.metadata[creatorDefined]["classes" or "names"]
        if let metadata = model.modelDescription.metadata[MLModelMetadataKey.creatorDefinedKey] as? [String: Any] {
            if let classesCSV = metadata["classes"] as? String {
                let parsed = classesCSV.components(separatedBy: ",").map { $0.trimmingCharacters(in: .whitespaces) }
                if !parsed.isEmpty {
                    logger.info("[Labels] Loaded \(parsed.count) labels from metadata['classes'] (CSV)")
                    self.labels = Self.sanitizeLabels(parsed)
                    return
                }
            }

            if let namesCSV = metadata["names"] as? String {
                let parsed = namesCSV.components(separatedBy: ",").map { $0.trimmingCharacters(in: .whitespaces) }
                if !parsed.isEmpty {
                    logger.info("[Labels] Loaded \(parsed.count) labels from metadata['names'] (CSV)")
                    self.labels = Self.sanitizeLabels(parsed)
                    return
                }
            }
        }

        // Priority 3: Try bundled labels.json
        if let labelsFromJSON = Self.loadLabelsFromJSON() {
            logger.info("[Labels] Loaded \(labelsFromJSON.count) labels from bundled labels.json")
            self.labels = Self.sanitizeLabels(labelsFromJSON)
            return
        }

        // Priority 4: Fallback to generated class_0 ... class_n
        logger.warning("[Labels] No label source found, generating class_0 ... class_\(numClasses - 1)")
        self.labels = (0..<numClasses).map { "class_\($0)" }
    }

    func label(for index: Int) -> String {
        guard index >= 0 && index < labels.count else {
            return "class_\(index)"
        }
        return labels[index]
    }

    func displayName(for label: String) -> String {
        return Self.toDisplayName(label)
    }

    static func isSensitive(_ label: String) -> Bool {
        return sensitiveLabels.contains(label.lowercased())
    }

    // MARK: - Private Helpers

    private static func sanitizeLabels(_ labels: [String]) -> [String] {
        return labels.map { label in
            // If label is purely numeric (like "3"), convert to "class_3"
            if let _ = Int(label) {
                return "class_\(label)"
            }
            return label
        }
    }

    private static func loadLabelsFromJSON() -> [String]? {
        guard let url = Bundle.main.url(forResource: "labels", withExtension: "json") else {
            return nil
        }

        do {
            let data = try Data(contentsOf: url)
            let labels = try JSONDecoder().decode([String].self, from: data)
            return labels
        } catch {
            return nil
        }
    }

    private static func toDisplayName(_ label: String) -> String {
        // Handle common sensitive document labels
        let displayNameMap: [String: String] = [
            "credit_card": "Credit Card",
            "id_card": "ID Card",
            "passport": "Passport",
            "drivers_license": "Driver's License",
            "bank_statement": "Bank Statement",
            "ssn": "Social Security Number",
            "person": "Person",
            "cell phone": "Cell Phone",
            "traffic light": "Traffic Light",
            "fire hydrant": "Fire Hydrant",
            "stop sign": "Stop Sign",
            "parking meter": "Parking Meter",
            "sports ball": "Sports Ball",
            "baseball bat": "Baseball Bat",
            "baseball glove": "Baseball Glove",
            "tennis racket": "Tennis Racket",
            "wine glass": "Wine Glass",
            "hot dog": "Hot Dog",
            "potted plant": "Potted Plant",
            "dining table": "Dining Table",
            "teddy bear": "Teddy Bear",
            "hair drier": "Hair Dryer"
        ]

        // Check if we have a custom mapping
        if let mapped = displayNameMap[label.lowercased()] {
            return mapped
        }

        // For unknown labels: replace _ with space and capitalize each word
        return label
            .split(separator: "_")
            .map { $0.capitalized }
            .joined(separator: " ")
    }
}

/// Singleton service for YOLO object detection
final class YOLOService {
    static let shared = YOLOService()

    private let model: best
    private let labelLoader: ModelLabelLoader
    private let logger = Logger(subsystem: "com.vaulteye.app", category: "YOLO")

    private init() {
        do {
            let config = MLModelConfiguration()
            config.computeUnits = .all  // Use all available compute (CPU + GPU + ANE)
            let loadedModel = try best(configuration: config)
            self.model = loadedModel

            // Detect number of classes from model output shape
            let numClasses = Self.detectNumClasses(from: loadedModel.model, logger: logger)

            // Initialize label loader with model and detected number of classes
            self.labelLoader = ModelLabelLoader(model: loadedModel.model, numClasses: numClasses)

            logger.info("[YOLO] Model loaded successfully with computeUnits=.all")
        } catch {
            fatalError("[YOLO] Failed to load best.mlpackage: \(error.localizedDescription)")
        }
    }

    private static func detectNumClasses(from model: MLModel, logger: Logger) -> Int {
        // Try to get number of classes from model description
        let description = model.modelDescription

        // Check output descriptions for confidence array shape
        for output in description.outputDescriptionsByName.values {
            if output.name == "confidence" {
                if let multiArrayConstraint = output.multiArrayConstraint {
                    // Shape is typically [1, numClasses] or [numBoxes, numClasses]
                    let shape = multiArrayConstraint.shape
                    if shape.count >= 2 {
                        let numClasses = shape[1].intValue
                        logger.info("[YOLO] Detected \(numClasses) classes from confidence output shape")
                        return numClasses
                    }
                }
            }
        }

        // Fallback: try to get from class labels
        if let classLabels = description.classLabels as? [String] {
            logger.info("[YOLO] Detected \(classLabels.count) classes from classLabels")
            return classLabels.count
        }

        // Default fallback
        logger.warning("[YOLO] Could not detect number of classes, defaulting to 3")
        return 3
    }

    // MARK: - Public API

    /// Get display-friendly name for a label
    /// - Parameter label: Raw label from detection
    /// - Returns: Display-friendly name (e.g., "credit_card" → "Credit Card")
    func displayName(for label: String) -> String {
        return labelLoader.displayName(for: label)
    }

    /// Check if a label represents sensitive content
    /// - Parameter label: Raw label from detection
    /// - Returns: True if the label is considered sensitive
    static func isSensitive(_ label: String) -> Bool {
        return ModelLabelLoader.isSensitive(label)
    }

    /// Detect objects in a UIImage
    /// - Parameters:
    ///   - image: Input image
    ///   - threshold01: Confidence threshold (0...1)
    /// - Returns: Array of detections above threshold
    func detect(in image: UIImage, threshold01: Float) -> [YOLODetection] {
        guard let pixelBuffer = image.pixelBuffer(width: 640, height: 640) else {
            logger.error("[YOLO] Failed to convert image to pixel buffer")
            return []
        }

        do {
            // Use default iouThreshold of 0.45 (standard NMS threshold)
            let prediction = try model.prediction(
                image: pixelBuffer,
                iouThreshold: 0.45,
                confidenceThreshold: Double(threshold01)
            )

            let detections = parseDetections(
                confidence: prediction.confidence,
                coordinates: prediction.coordinates,
                threshold01: threshold01
            )

            if let topDetection = detections.first {
                logger.info("[YOLO] detections=\(detections.count) top=\(topDetection.label) \(Int(topDetection.confidence * 100))%")
            } else {
                logger.info("[YOLO] detections=0")
            }

            return detections

        } catch {
            logger.error("[YOLO] Prediction failed: \(error.localizedDescription)")
            return []
        }
    }

    /// Detect objects in a PHAsset
    /// - Parameters:
    ///   - asset: Photo asset
    ///   - threshold01: Confidence threshold (0...1)
    /// - Returns: Array of detections above threshold
    func detect(asset: PHAsset, threshold01: Float) async -> [YOLODetection] {
        let image = await loadImage(from: asset)
        guard let image = image else {
            logger.error("[YOLO] asset=\(asset.localIdentifier) Failed to load image")
            return []
        }

        logger.info("[YOLO] asset=\(asset.localIdentifier) Processing...")
        let detections = detect(in: image, threshold01: threshold01)

        if let topDetection = detections.first {
            logger.info("[YOLO] asset=\(asset.localIdentifier) detections=\(detections.count) top=\(topDetection.label) \(Int(topDetection.confidence * 100))%")
        } else {
            logger.info("[YOLO] asset=\(asset.localIdentifier) detections=0")
        }

        return detections
    }

    // MARK: - Private Helpers

    private func parseDetections(
        confidence: MLMultiArray,
        coordinates: MLMultiArray,
        threshold01: Float
    ) -> [YOLODetection] {
        var detections: [YOLODetection] = []
        var allClasses: [(classIdx: Int, confidence: Float)] = []

        // confidence shape: [boxes × N classes]
        // coordinates shape: [boxes × 4]

        guard confidence.shape.count >= 2,
              coordinates.shape.count >= 2 else {
            logger.error("[YOLO] Invalid output shapes")
            return []
        }

        let numBoxes = confidence.shape[0].intValue
        let numClasses = confidence.shape[1].intValue

        logger.info("[YOLO] Parsing \(numBoxes) boxes with threshold=\(String(format: "%.2f", threshold01))")

        for boxIdx in 0..<numBoxes {
            // Find argmax class and its confidence
            var maxConf: Float = 0
            var maxClassIdx: Int = 0

            for classIdx in 0..<numClasses {
                let confValue = confidence[[boxIdx as NSNumber, classIdx as NSNumber]].floatValue
                if confValue > maxConf {
                    maxConf = confValue
                    maxClassIdx = classIdx
                }
            }

            // Keep only detections above threshold
            guard maxConf >= threshold01 else { continue }

            // Track all class predictions for debugging
            allClasses.append((classIdx: maxClassIdx, confidence: maxConf))

            // Extract bounding box (normalized x, y, w, h)
            let x = coordinates[[boxIdx as NSNumber, 0 as NSNumber]].floatValue
            let y = coordinates[[boxIdx as NSNumber, 1 as NSNumber]].floatValue
            let w = coordinates[[boxIdx as NSNumber, 2 as NSNumber]].floatValue
            let h = coordinates[[boxIdx as NSNumber, 3 as NSNumber]].floatValue

            // Convert to CGRect (ensure normalized 0...1)
            let boundingBox = CGRect(
                x: CGFloat(max(0, min(1, x))),
                y: CGFloat(max(0, min(1, y))),
                width: CGFloat(max(0, min(1, w))),
                height: CGFloat(max(0, min(1, h)))
            )

            // Use label loader to get the label
            let label = labelLoader.label(for: maxClassIdx)

            let detection = YOLODetection(
                label: label,
                confidence: maxConf,
                boundingBox: boundingBox
            )

            detections.append(detection)
        }

        logger.info("[YOLO] Kept \(detections.count)/\(numBoxes) detections above threshold")

        // Sort by confidence (highest first)
        let sorted = detections.sorted { $0.confidence > $1.confidence }

        // Debug: Log top-3 class names to verify sensitive labels appear
        if !sorted.isEmpty {
            let top3 = sorted.prefix(3)
            logger.info("[YOLO] Top-3 detections:")
            for (index, detection) in top3.enumerated() {
                let displayName = labelLoader.displayName(for: detection.label)
                let isSensitive = ModelLabelLoader.isSensitive(detection.label) ? "⚠️ SENSITIVE" : ""
                logger.info("[YOLO]   \(index + 1). \(detection.label) (\(displayName)) - \(Int(detection.confidence * 100))% \(isSensitive)")
            }
        }

        return sorted
    }

    private func loadImage(from asset: PHAsset) async -> UIImage? {
        await withCheckedContinuation { continuation in
            let options = PHImageRequestOptions()
            options.deliveryMode = .highQualityFormat
            options.isNetworkAccessAllowed = true
            options.isSynchronous = false

            PHImageManager.default().requestImage(
                for: asset,
                targetSize: CGSize(width: 640, height: 640),
                contentMode: .aspectFill,
                options: options
            ) { image, _ in
                continuation.resume(returning: image)
            }
        }
    }
}

// MARK: - UIImage Extension

extension UIImage {
    /// Convert UIImage to CVPixelBuffer at specified size
    func pixelBuffer(width: Int, height: Int) -> CVPixelBuffer? {
        // Resize image
        let size = CGSize(width: width, height: height)
        UIGraphicsBeginImageContextWithOptions(size, false, 1.0)
        defer { UIGraphicsEndImageContext() }

        draw(in: CGRect(origin: .zero, size: size))
        guard let resizedImage = UIGraphicsGetImageFromCurrentImageContext(),
              let cgImage = resizedImage.cgImage else {
            return nil
        }

        // Create pixel buffer
        let attrs = [
            kCVPixelBufferCGImageCompatibilityKey: kCFBooleanTrue,
            kCVPixelBufferCGBitmapContextCompatibilityKey: kCFBooleanTrue
        ] as CFDictionary

        var pixelBuffer: CVPixelBuffer?
        let status = CVPixelBufferCreate(
            kCFAllocatorDefault,
            width,
            height,
            kCVPixelFormatType_32ARGB,
            attrs,
            &pixelBuffer
        )

        guard status == kCVReturnSuccess, let buffer = pixelBuffer else {
            return nil
        }

        CVPixelBufferLockBaseAddress(buffer, [])
        defer { CVPixelBufferUnlockBaseAddress(buffer, []) }

        guard let context = CGContext(
            data: CVPixelBufferGetBaseAddress(buffer),
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: CVPixelBufferGetBytesPerRow(buffer),
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.noneSkipFirst.rawValue
        ) else {
            return nil
        }

        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))

        return buffer
    }
}
