//
//  SwipeCardView.swift
//  VaultEye
//
//  Created by Alexander McGreevy on 11/8/25.
//

import SwiftUI

// Constants
private let swipeThreshold: CGFloat = 140
private let maxCardHeight: CGFloat = 480

struct SwipeCardView<Content: View>: View {
    let content: Content
    let onDelete: () -> Void
    let onKeep: () -> Void

    @State private var offset: CGFloat = 0
    @State private var isDragging = false
    @State private var hasTriggeredHaptic = false

    private var progress: CGFloat {
        min(1, abs(offset) / swipeThreshold)
    }

    private var isOverThreshold: Bool {
        abs(offset) > swipeThreshold
    }

    init(
        @ViewBuilder content: () -> Content,
        onDelete: @escaping () -> Void,
        onKeep: @escaping () -> Void
    ) {
        self.content = content()
        self.onDelete = onDelete
        self.onKeep = onKeep
    }

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .top) {
                // Background glows - tall half capsules extending to bottom
                // Left edge - green (keep)
                if offset < 0 {
                    LinearGradient(
                        colors: [
                            Color.green.opacity(progress * 0.7),
                            Color.green.opacity(0)
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                    .frame(width: 150)
                    .mask(
                        Capsule()
                            .frame(width: 300, height: geometry.size.height)
                            .offset(x: -150) // Shift left so only right half is visible
                    )
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .allowsHitTesting(false)
                }

                // Right edge - red (delete)
                if offset > 0 {
                    LinearGradient(
                        colors: [
                            Color.red.opacity(0),
                            Color.red.opacity(progress * 0.7)
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                    .frame(width: 150)
                    .mask(
                        Capsule()
                            .frame(width: 300, height: geometry.size.height)
                            .offset(x: 150) // Shift right so only left half is visible
                    )
                    .frame(maxWidth: .infinity, alignment: .trailing)
                    .allowsHitTesting(false)
                }

                // Card content - follows drag continuously with NO animation on offset
                content
                    .frame(maxHeight: maxCardHeight)
                    .background(Color(.systemBackground))
                    .cornerRadius(24)
                    .shadow(
                        color: Color.black.opacity(isDragging ? 0.2 : 0.1),
                        radius: isDragging ? 20 : 10,
                        x: 0,
                        y: isDragging ? 10 : 5
                    )
                    .offset(x: offset)  // Direct offset - no animation
                    .rotationEffect(.degrees(Double(offset) / 20))
                    .scaleEffect(isDragging ? 1.02 : 1.0)
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { value in
                                isDragging = true
                                // Card follows finger exactly - no animation
                                offset = value.translation.width

                                // Haptic feedback when crossing threshold
                                if isOverThreshold && !hasTriggeredHaptic {
                                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                                    hasTriggeredHaptic = true
                                } else if !isOverThreshold && hasTriggeredHaptic {
                                    hasTriggeredHaptic = false
                                }
                            }
                            .onEnded { _ in
                                isDragging = false

                                if offset > swipeThreshold {
                                    // Swipe right → Delete (only on release)
                                    dismissCard(direction: 1) {
                                        onDelete()
                                    }
                                } else if offset < -swipeThreshold {
                                    // Swipe left → Keep (only on release)
                                    dismissCard(direction: -1) {
                                        onKeep()
                                    }
                                } else {
                                    // Snap back to center
                                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                        offset = 0
                                        hasTriggeredHaptic = false
                                    }
                                }
                            }
                    )
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
        }
    }

    private func dismissCard(direction: CGFloat, completion: @escaping () -> Void) {
        // Use a large enough offset to dismiss off-screen
        let dismissOffset: CGFloat = direction * 500

        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
            offset = dismissOffset
        }

        // Small haptic on dismiss
        UIImpactFeedbackGenerator(style: .light).impactOccurred()

        // Call completion after animation
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            completion()
        }
    }
}

// Specialized version for DetectionResult
struct DetectionResultCard: View {
    let result: DetectionResult

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // Image with bounding boxes
                if let thumbnail = result.thumbnail {
                    GeometryReader { geometry in
                        ZStack {
                            Image(uiImage: thumbnail)
                                .resizable()
                                .scaledToFit()
                                .frame(width: geometry.size.width)

                            // Overlay bounding boxes
                            ForEach(result.detectedRegions) { region in
                                BoundingBoxOverlay(
                                    region: region,
                                    imageSize: thumbnail.size,
                                    frameWidth: geometry.size.width
                                )
                            }
                        }
                    }
                    .aspectRatio(result.thumbnail?.size.width ?? 1 / (result.thumbnail?.size.height ?? 1), contentMode: .fit)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                } else {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.gray.opacity(0.3))
                        .frame(height: 200)
                        .overlay {
                            Image(systemName: "photo")
                                .font(.largeTitle)
                                .foregroundColor(.gray)
                        }
                }

                // Detection details
                VStack(alignment: .leading, spacing: 12) {
                    // Risk score
                    if let score = result.privacyScore {
                        HStack {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(.red)
                            Text("Risk: \(String(format: "%.0f%%", score * 100))")
                                .font(.headline)
                                .foregroundColor(.red)
                        }
                    }

                    if let analysis = result.analysis {
                        HStack {
                            Text("Risk Level:")
                                .foregroundColor(.secondary)
                            Spacer()
                            Text(analysis.riskLevel.rawValue.capitalized)
                                .fontWeight(.semibold)
                        }
                    }

                    if let message = result.analysisMessage, result.analysisStatus != .completed {
                        HStack(alignment: .top, spacing: 8) {
                            Image(systemName: "info.circle")
                                .foregroundColor(.orange)
                            Text(message)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .padding(8)
                        .background(Color(.systemGray6))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                    }

                    // Detection types
                    if !result.detectedRegions.isEmpty {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Detected:")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                            ForEach(result.detectedRegions) { region in
                                HStack {
                                    Circle()
                                        .fill(Color.red)
                                        .frame(width: 6, height: 6)
                                    Text(region.label)
                                        .font(.subheadline)
                                    Spacer()
                                    Text("\(String(format: "%.0f%%", region.confidence * 100))")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                    }

                    // Reason
                    Text(result.reason)
                        .font(.subheadline)
                        .foregroundColor(.secondary)

                    // OCR Segments
                    if !result.ocrSegments.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Label("Sanitized Text", systemImage: "doc.text")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                            ForEach(result.ocrSegments) { segment in
                                Text(segment.sanitizedText)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .padding(8)
                                    .background(Color(.systemGray5))
                                    .clipShape(RoundedRectangle(cornerRadius: 6))
                            }
                        }
                        .padding(.vertical, 4)
                    }

                    // Gemini explanation
                    if let analysis = result.analysis {
                        VStack(alignment: .leading, spacing: 8) {
                            Label("AI Analysis", systemImage: "sparkles")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                            Text(analysis.explanation)
                                .font(.caption)
                                .foregroundColor(.secondary)

                            if !analysis.categories.isEmpty {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Categories")
                                        .font(.caption)
                                        .fontWeight(.semibold)
                                    ForEach(analysis.categories, id: \.self) { prediction in
                                        HStack {
                                            Text(prediction.category.rawValue.replacingOccurrences(of: "_", with: " ").capitalized)
                                            Spacer()
                                            Text(String(format: "%.0f%%", prediction.confidence * 100))
                                                .foregroundColor(.secondary)
                                        }
                                        .font(.caption)
                                    }
                                }
                            }

                            if !analysis.keyPhrases.isEmpty {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Key Phrases")
                                        .font(.caption)
                                        .fontWeight(.semibold)
                                    ForEach(analysis.keyPhrases, id: \.self) { phrase in
                                        Text("• \(phrase)")
                                            .font(.caption)
                                    }
                                }
                            }

                            if !analysis.recommendedActions.isEmpty {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Recommended Actions")
                                        .font(.caption)
                                        .fontWeight(.semibold)
                                    ForEach(analysis.recommendedActions, id: \.self) { action in
                                        Text("• \(action)")
                                            .font(.caption)
                                    }
                                }
                            }
                        }
                        .padding()
                        .background(Color(.systemGray6))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                }
                .padding(.horizontal)
            }
            .padding(.vertical)
        }
    }
}

// Helper for bounding box overlay
private struct BoundingBoxOverlay: View {
    let region: DetectedRegion
    let imageSize: CGSize
    let frameWidth: CGFloat

    var body: some View {
        let scale = frameWidth / imageSize.width
        let rect = CGRect(
            x: region.normalizedRect.origin.x * imageSize.width * scale,
            y: region.normalizedRect.origin.y * imageSize.height * scale,
            width: region.normalizedRect.width * imageSize.width * scale,
            height: region.normalizedRect.height * imageSize.height * scale
        )

        Rectangle()
            .stroke(Color.red, lineWidth: 2)
            .frame(width: rect.width, height: rect.height)
            .position(x: rect.midX, y: rect.midY)
    }
}


#Preview("Swipe Card - Flagged") {
    SwipeCardView(
        content: { DetectionResultCard(result: .mockFlagged) },
        onDelete: { print("Deleted") },
        onKeep: { print("Kept") }
    )
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .ignoresSafeArea()        // apply at the top level
}


#Preview("Detection Result Card Only") {
    DetectionResultCard(result: DetectionResult.mockFlagged)
        .padding()
}
