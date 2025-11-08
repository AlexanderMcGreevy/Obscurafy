//
//  DetectedRegion.swift
//  VaultEye
//
//  Created by Alexander McGreevy on 11/7/25.
//

import Foundation

struct DetectedRegion: Identifiable {
    let id: UUID
    let normalizedRect: CGRect  // Normalized coordinates (0-1)
    let confidence: Float
    let label: String

    init(id: UUID = UUID(), normalizedRect: CGRect, confidence: Float, label: String) {
        self.id = id
        self.normalizedRect = normalizedRect
        self.confidence = confidence
        self.label = label
    }
}
