//
//  DetailView.swift
//  VaultEye
//
//  Created by Alexander McGreevy on 11/7/25.
//

import SwiftUI
import Photos

struct DetailView: View {
    let result: DetectionResult
    let photoLibraryManager: PhotoLibraryManager
    let onDelete: () -> Void

    @State private var fullSizeImage: UIImage?
    @State private var showDeleteConfirmation = false
    @State private var isDeleting = false
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                imageSection
                detectionInfoSection
                placeholderSections
                deleteButton
            }
            .padding()
        }
        .navigationTitle("Detection Details")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await loadFullSizeImage()
        }
        .alert("Delete Photo?", isPresented: $showDeleteConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                deletePhoto()
            }
        } message: {
            Text("This photo will be permanently deleted from your library.")
        }
    }

    private var imageSection: some View {
        VStack(spacing: 12) {
            if let image = fullSizeImage {
                GeometryReader { geometry in
                    ZStack {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFit()
                            .frame(width: geometry.size.width, height: geometry.size.height)

                        // Overlay detected regions
                        ForEach(result.detectedRegions) { region in
                            DetectionOverlay(region: region, imageSize: image.size, frameSize: geometry.size)
                        }
                    }
                }
                .aspectRatio(fullSizeImage?.size.width ?? 1 / (fullSizeImage?.size.height ?? 1), contentMode: .fit)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            } else {
                ProgressView()
                    .frame(height: 300)
            }
        }
    }

    private var detectionInfoSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Detection Results")
                .font(.headline)

            VStack(alignment: .leading, spacing: 8) {
                Label(result.reason, systemImage: "exclamationmark.triangle.fill")
                    .foregroundColor(.red)

                if let score = result.privacyScore {
                    HStack {
                        Text("Privacy Risk Score:")
                            .foregroundColor(.secondary)
                        Spacer()
                        Text("\(String(format: "%.0f%%", score * 100))")
                            .fontWeight(.semibold)
                            .foregroundColor(.orange)
                    }
                }
            }
            .padding()
            .background(Color(.systemGray6))
            .clipShape(RoundedRectangle(cornerRadius: 12))

            if !result.detectedRegions.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Detected Regions")
                        .font(.subheadline)
                        .fontWeight(.semibold)

                    ForEach(result.detectedRegions) { region in
                        HStack {
                            Circle()
                                .fill(Color.red)
                                .frame(width: 8, height: 8)

                            Text(region.label)
                                .font(.subheadline)

                            Spacer()

                            Text("\(String(format: "%.0f%%", region.confidence * 100))")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .padding()
                .background(Color(.systemGray6))
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
        }
    }

    private var placeholderSections: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Gemini Explanation Placeholder
            VStack(alignment: .leading, spacing: 8) {
                Label("AI Explanation", systemImage: "sparkles")
                    .font(.headline)

                if let explanation = result.geminiExplanation {
                    Text(explanation)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                } else {
                    Text("No explanation available")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .italic()
                }
            }
            .padding()
            .background(Color(.systemGray6))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }

    private var deleteButton: some View {
        Button(action: {
            showDeleteConfirmation = true
        }) {
            if isDeleting {
                ProgressView()
                    .frame(maxWidth: .infinity)
            } else {
                Label("Delete Photo", systemImage: "trash.fill")
                    .frame(maxWidth: .infinity)
            }
        }
        .buttonStyle(.borderedProminent)
        .tint(.red)
        .disabled(isDeleting)
    }

    private func loadFullSizeImage() async {
        // Use cached thumbnail if no asset (preview mode)
        if let thumbnail = result.thumbnail {
            fullSizeImage = thumbnail
            return
        }

        guard let asset = result.asset else { return }
        let targetSize = CGSize(width: 1024, height: 1024)
        fullSizeImage = await photoLibraryManager.loadThumbnail(for: asset, targetSize: targetSize)
    }

    private func deletePhoto() {
        guard let asset = result.asset else {
            // Preview mode - just dismiss
            onDelete()
            dismiss()
            return
        }

        isDeleting = true
        Task {
            do {
                try await photoLibraryManager.deleteAsset(asset)
                await MainActor.run {
                    onDelete()
                    dismiss()
                }
            } catch {
                print("Failed to delete photo: \(error)")
                isDeleting = false
            }
        }
    }
}

struct DetectionOverlay: View {
    let region: DetectedRegion
    let imageSize: CGSize
    let frameSize: CGSize

    var body: some View {
        let rect = convertedRect

        Rectangle()
            .stroke(Color.red, lineWidth: 3)
            .background(Color.red.opacity(0.2))
            .frame(width: rect.width, height: rect.height)
            .position(x: rect.midX, y: rect.midY)
            .overlay(alignment: .topLeading) {
                Text(region.label)
                    .font(.caption)
                    .fontWeight(.semibold)
                    .padding(4)
                    .background(Color.red)
                    .foregroundColor(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 4))
                    .position(x: rect.minX + 40, y: rect.minY + 12)
            }
    }

    private var convertedRect: CGRect {
        // Calculate scale to fit image in frame
        let scale = min(frameSize.width / imageSize.width, frameSize.height / imageSize.height)
        let scaledImageSize = CGSize(width: imageSize.width * scale, height: imageSize.height * scale)

        // Calculate offset to center image in frame
        let offsetX = (frameSize.width - scaledImageSize.width) / 2
        let offsetY = (frameSize.height - scaledImageSize.height) / 2

        // Convert normalized coordinates to actual frame coordinates
        let x = region.normalizedRect.origin.x * scaledImageSize.width + offsetX
        let y = region.normalizedRect.origin.y * scaledImageSize.height + offsetY
        let width = region.normalizedRect.width * scaledImageSize.width
        let height = region.normalizedRect.height * scaledImageSize.height

        return CGRect(x: x, y: y, width: width, height: height)
    }
}

#Preview("Detail View") {
    NavigationStack {
        DetailView(
            result: DetectionResult.mockFlagged,
            photoLibraryManager: PhotoLibraryManager(),
            onDelete: {}
        )
    }
}

#Preview("Detection Overlay") {
    GeometryReader { geometry in
        ZStack {
            Color.gray.opacity(0.3)

            DetectionOverlay(
                region: DetectedRegion(
                    normalizedRect: CGRect(x: 0.2, y: 0.3, width: 0.4, height: 0.3),
                    confidence: 0.92,
                    label: "Credit Card"
                ),
                imageSize: CGSize(width: 800, height: 600),
                frameSize: geometry.size
            )
        }
    }
    .frame(height: 400)
}
