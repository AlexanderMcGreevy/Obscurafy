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
    let redactionService: RedactionServiceProtocol

    @State private var fullSizeImage: UIImage?
    @State private var showDeleteConfirmation = false
    @State private var isDeleting = false
    @State private var dragOffset: CGFloat = 0
    @State private var isRedacting = false
    @State private var redactionError: String?
    @State private var showError = false
    @Environment(\.dismiss) private var dismiss

    private let swipeThreshold: CGFloat = 120

    init(
        result: DetectionResult,
        photoLibraryManager: PhotoLibraryManager,
        onDelete: @escaping () -> Void,
        redactionService: RedactionServiceProtocol = RedactionService()
    ) {
        self.result = result
        self.photoLibraryManager = photoLibraryManager
        self.onDelete = onDelete
        self.redactionService = redactionService
    }

    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                // Image at the top (outside scroll)
                if let image = fullSizeImage {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                        .frame(maxHeight: 400)
                        .clipped()
                } else {
                    Rectangle()
                        .fill(Color.gray.opacity(0.3))
                        .frame(height: 300)
                        .overlay {
                            ProgressView()
                        }
                }

                // Scrollable details below
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        detectionInfoSection
                        placeholderSections
                        deleteButton
                    }
                    .padding()
                }
            }
            .offset(y: max(0, dragOffset)) // Only allow downward drag
            .gesture(
                DragGesture()
                    .onChanged { value in
                        if value.translation.height > 0 {
                            dragOffset = value.translation.height
                        }
                    }
                    .onEnded { _ in
                        if dragOffset > swipeThreshold {
                            // Trigger redaction
                            performRedaction()
                        } else {
                            // Snap back
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                dragOffset = 0
                            }
                        }
                    }
            )

            // Blue indicator at bottom
            if dragOffset > 0 {
                VStack {
                    Spacer()
                    Rectangle()
                        .fill(Color.blue)
                        .frame(height: 4)
                        .opacity(min(1.0, dragOffset / swipeThreshold))
                }
                .ignoresSafeArea()
            }

            // Progress overlay
            if isRedacting {
                Color.black.opacity(0.4)
                    .ignoresSafeArea()

                VStack(spacing: 16) {
                    ProgressView()
                        .scaleEffect(1.5)
                        .progressViewStyle(.circular)
                        .tint(.white)

                    Text("Redacting text…")
                        .font(.headline)
                        .foregroundColor(.white)
                }
                .padding(32)
                .background(Color(.systemGray6))
                .cornerRadius(16)
            }
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
        .alert("Redaction Error", isPresented: $showError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(redactionError ?? "An error occurred during redaction")
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

    private func performRedaction() {
        guard let asset = result.asset else {
            redactionError = "Cannot redact preview images"
            showError = true
            withAnimation {
                dragOffset = 0
            }
            return
        }

        isRedacting = true
        dragOffset = 0

        Task {
            do {
                let newAsset = try await redactionService.redactAndReplace(asset: asset)

                await MainActor.run {
                    isRedacting = false

                    // Update the view with the new redacted asset
                    Task {
                        let targetSize = CGSize(width: 1024, height: 1024)
                        fullSizeImage = await photoLibraryManager.loadThumbnail(
                            for: newAsset,
                            targetSize: targetSize
                        )
                    }

                    // Haptic success feedback
                    UINotificationFeedbackGenerator().notificationOccurred(.success)
                }
            } catch RedactionError.noTextFound {
                await MainActor.run {
                    isRedacting = false
                    redactionError = "No text found in this image"
                    showError = true
                }
            } catch RedactionError.deleteFailed {
                await MainActor.run {
                    isRedacting = false
                    redactionError = "Redacted copy saved, but original could not be deleted. Both copies remain in your library."
                    showError = true
                }
            } catch {
                await MainActor.run {
                    isRedacting = false
                    redactionError = "Failed to redact: \(error.localizedDescription)"
                    showError = true
                }
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
            onDelete: {},
            redactionService: RedactionService()
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
