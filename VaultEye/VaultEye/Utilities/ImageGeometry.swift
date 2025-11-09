//
//  ImageGeometry.swift
//  VaultEye
//
//  Utilities for converting between coordinate spaces
//

import Foundation
import CoreGraphics
import UIKit

struct ImageGeometry {
    /// Convert normalized bounding box (0...1, bottom-left origin) to pixel rect (top-left origin)
    /// - Parameters:
    ///   - normalized: Normalized CGRect from Vision/YOLO (bottom-left origin, 0...1)
    ///   - imageSize: Size of the image in pixels
    /// - Returns: Pixel-based CGRect with top-left origin
    static func rectInPixels(from normalized: CGRect, imageSize: CGSize) -> CGRect {
        // Normalized coordinates from YOLO/Vision are:
        // - Origin: bottom-left
        // - Range: 0...1
        //
        // UIKit coordinates are:
        // - Origin: top-left
        // - Range: 0...imageSize

        let x = normalized.origin.x * imageSize.width
        let width = normalized.width * imageSize.width

        // Flip Y-axis: Vision's bottom-left to UIKit's top-left
        let visionY = normalized.origin.y
        let height = normalized.height * imageSize.height
        let y = imageSize.height - (visionY * imageSize.height) - height

        return CGRect(x: x, y: y, width: width, height: height)
    }

    /// Convert normalized bounding box for SwiftUI display
    /// - Parameters:
    ///   - normalized: Normalized CGRect from Vision/YOLO
    ///   - displaySize: Size of the image view in SwiftUI
    /// - Returns: CGRect for SwiftUI overlay
    static func rectForDisplay(from normalized: CGRect, displaySize: CGSize) -> CGRect {
        // For SwiftUI, we often need to maintain aspect ratio
        // This assumes the image is displayed at displaySize
        return rectInPixels(from: normalized, imageSize: displaySize)
    }

    /// Scale normalized rect to fit within a view while maintaining aspect ratio
    /// - Parameters:
    ///   - normalized: Normalized CGRect from Vision/YOLO
    ///   - imageSize: Original image size
    ///   - viewSize: View size for display
    /// - Returns: Scaled CGRect for the view
    static func scaledRect(
        from normalized: CGRect,
        imageSize: CGSize,
        viewSize: CGSize
    ) -> CGRect {
        // Calculate scale factor to fit image in view
        let scaleX = viewSize.width / imageSize.width
        let scaleY = viewSize.height / imageSize.height
        let scale = min(scaleX, scaleY)

        // Calculate actual displayed image size
        let displayedWidth = imageSize.width * scale
        let displayedHeight = imageSize.height * scale

        // Center offsets
        let offsetX = (viewSize.width - displayedWidth) / 2
        let offsetY = (viewSize.height - displayedHeight) / 2

        // Convert normalized to pixels, then scale
        let pixelRect = rectInPixels(from: normalized, imageSize: imageSize)

        return CGRect(
            x: (pixelRect.origin.x * scale) + offsetX,
            y: (pixelRect.origin.y * scale) + offsetY,
            width: pixelRect.width * scale,
            height: pixelRect.height * scale
        )
    }
}
