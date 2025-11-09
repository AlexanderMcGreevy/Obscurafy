//
//  ImageClassifier.swift
//  VaultEye
//
//  Core ML image classification wrapper
//

import Foundation
@preconcurrency import Vision
import CoreML
import UIKit

struct ImageClassifier {
    private let model: VNCoreMLModel

    // MARK: - Initialization

    /// Initialize with a Core ML model
    init(mlModel: MLModel) throws {
        self.model = try VNCoreMLModel(for: mlModel)
    }

    // MARK: - Classification

    /// Returns confidence score 0-100 for the given image
    func confidence(for cgImage: CGImage) async throws -> Int {
        return try await withCheckedThrowingContinuation { continuation in
            let request = VNCoreMLRequest(model: model) { request, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }

                guard let results = request.results as? [VNClassificationObservation],
                      let topResult = results.first else {
                    continuation.resume(returning: 0)
                    return
                }

                // Convert 0.0-1.0 confidence to 0-100
                let confidenceInt = Int(topResult.confidence * 100)
                continuation.resume(returning: confidenceInt)
            }

            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])

            DispatchQueue.global(qos: .userInitiated).async {
                do {
                    try handler.perform([request])
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
}
