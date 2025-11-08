//
//  ContentView.swift
//  VaultEye
//
//  Created by Alexander McGreevy on 11/7/25.
//

import SwiftUI
import Photos

struct ContentView: View {
    private let geminiService: GeminiAnalyzing?

    @StateObject private var photoLibraryManager: PhotoLibraryManager
    @StateObject private var deleteBatchManager: DeleteBatchManager
    @StateObject private var consentManager: PrivacyConsentManager
    @State private var detectionResults: [DetectionResult] = []
    @State private var isScanning = false
    @State private var showPermissionAlert = false
    @State private var showConsentPrompt = false
    @State private var highRiskAlert: DetectionResult?

    init(geminiService: GeminiAnalyzing? = ContentView.makeGeminiService()) {
        self.geminiService = geminiService
        _photoLibraryManager = StateObject(wrappedValue: PhotoLibraryManager())
        _deleteBatchManager = StateObject(wrappedValue: DeleteBatchManager())
        _consentManager = StateObject(wrappedValue: PrivacyConsentManager())
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Delete batch button (only shows when items staged)
                if deleteBatchManager.stagedAssetIds.count > 0 {
                    deleteBatchButton
                }

                if !photoLibraryManager.isAuthorized {
                    permissionView
                } else if detectionResults.isEmpty && deleteBatchManager.stagedAssetIds.isEmpty {
                    emptyStateView
                } else if detectionResults.isEmpty && deleteBatchManager.stagedAssetIds.count > 0 {
                    finalCommitView
                } else {
                    resultsList
                }
            }
            .navigationTitle("VaultEye")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    scanButton
                }
            }
            .alert("Allow AI Analysis?", isPresented: $showConsentPrompt) {
                Button("Allow") {
                    consentManager.recordConsent(true)
                    performScan()
                }
                Button("Not Now", role: .cancel) {
                    consentManager.recordConsent(false)
                    performScan()
                }
            } message: {
                Text("VaultEye can send sanitized text snippets to Gemini to classify sensitive content. No images are shared. Allow this to enable full analysis?")
            }
            .alert("High Risk Content", isPresented: Binding(
                get: { highRiskAlert != nil },
                set: { if !$0 { highRiskAlert = nil } }
            ), presenting: highRiskAlert) { _ in
                Button("OK", role: .cancel) {
                    highRiskAlert = nil
                }
            } message: { result in
                Text(result.analysis?.explanation ?? "Sensitive content detected")
            }
        }
    }

    private var deleteBatchButton: some View {
        Button(action: commitDeletions) {
            HStack {
                Image(systemName: "trash.fill")
                Text("Delete (\(deleteBatchManager.stagedAssetIds.count))")
                    .fontWeight(.semibold)
            }
            .foregroundColor(.white)
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(Color.red)
            .cornerRadius(20)
        }
        .padding(.top, 8)
        .transition(.move(edge: .top).combined(with: .opacity))
        .animation(.spring(), value: deleteBatchManager.stagedAssetIds.count)
    }

    private var permissionView: some View {
        VStack(spacing: 16) {
            Image(systemName: "photo.on.rectangle.angled")
                .font(.system(size: 60))
                .foregroundColor(.blue)

            Text("Photo Library Access Required")
                .font(.title2)
                .fontWeight(.semibold)

            Text("VaultEye needs access to your photos to scan for sensitive information.")
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
                .padding(.horizontal)

            Button("Grant Access") {
                Task {
                    await photoLibraryManager.requestPermission()
                }
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
    }

    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "shield.checkered")
                .font(.system(size: 60))
                .foregroundColor(.green)

            Text("Ready to Scan")
                .font(.title2)
                .fontWeight(.semibold)

            Text("Tap the scan button to check your photos for sensitive information.")
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
                .padding(.horizontal)
        }
        .padding()
    }

    private var resultsList: some View {
        VStack(spacing: 16) {
            // Progress indicator
            HStack {
                Text("\(detectionResults.count) photo(s) remaining")
                    .font(.headline)
                    .foregroundColor(.secondary)
                Spacer()
                Text("← Keep | Delete →")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal)
            .padding(.top, 8)

            // Show only the first (current) photo as swipeable card
            if let currentResult = detectionResults.first {
                SwipeCardView(
                    content: {
                        DetectionResultCard(result: currentResult)
                    },
                    onDelete: {
                        handleDelete(currentResult)
                    },
                    onKeep: {
                        handleKeep(currentResult)
                    }
                )
                .padding(.horizontal, 16)
                .id(currentResult.id) // Force view recreation for smooth transitions
            }

            Spacer()
        }
    }

    private var finalCommitView: some View {
        VStack(spacing: 24) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 60))
                .foregroundColor(.green)

            Text("All Photos Reviewed!")
                .font(.title2)
                .fontWeight(.semibold)

            if deleteBatchManager.stagedAssetIds.count > 0 {
                Text("\(deleteBatchManager.stagedAssetIds.count) photo(s) queued for deletion")
                    .foregroundColor(.secondary)

                Button(action: commitDeletions) {
                    HStack {
                        Image(systemName: "trash.fill")
                        Text("Commit Deletions")
                    }
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                    .padding(.horizontal, 32)
                    .padding(.vertical, 16)
                    .background(Color.red)
                    .cornerRadius(12)
                }
            } else {
                Text("No deletions queued")
                    .foregroundColor(.secondary)
            }
        }
        .padding()
    }

    private var scanButton: some View {
        Button(action: startScan) {
            if isScanning {
                ProgressView()
                    .progressViewStyle(.circular)
            } else {
                Label("Scan", systemImage: "magnifyingglass")
            }
        }
        .disabled(isScanning || !photoLibraryManager.isAuthorized)
    }

    private func startScan() {
        guard photoLibraryManager.isAuthorized else {
            showPermissionAlert = true
            return
        }

        if !consentManager.hasConsented {
            showConsentPrompt = true
        } else {
            performScan()
        }
    }

    private func performScan() {
        isScanning = true
        Task {
            let scanner = ScannerService(
                photoLibraryManager: photoLibraryManager,
                geminiService: geminiService,
                consentManager: consentManager
            )
            let results = await scanner.scanPhotos()
            await MainActor.run {
                detectionResults = results
                isScanning = false
                highRiskAlert = results.first { $0.analysis?.riskLevel == .high }
            }
        }
    }

    private func removeResult(_ result: DetectionResult) {
        withAnimation {
            detectionResults.removeAll { $0.id == result.id }
        }
    }

    private func handleDelete(_ result: DetectionResult) {
        // Stage for batch deletion
        deleteBatchManager.stage(result.assetIdentifier)

        // Remove from current list
        removeResult(result)
    }

    private func handleKeep(_ result: DetectionResult) {
        // Just remove from list (mark as reviewed/kept)
        removeResult(result)
    }

    private func commitDeletions() {
        Task {
            do {
                try await deleteBatchManager.commit { assetId in
                    // Resolver: convert assetId to PHAsset
                    let fetchResult = PHAsset.fetchAssets(
                        withLocalIdentifiers: [assetId],
                        options: nil
                    )
                    return fetchResult.firstObject
                }
            } catch {
                print("Failed to delete photos: \(error)")
            }
        }
    }
}

private extension ContentView {
    static func makeGeminiService() -> GeminiAnalyzing? {
        if let envKey = ProcessInfo.processInfo.environment["GEMINI_API_KEY"], !envKey.isEmpty {
            return GeminiService(apiKey: envKey)
        }

        if let infoKey = Bundle.main.object(forInfoDictionaryKey: "GeminiAPIKey") as? String, !infoKey.isEmpty {
            return GeminiService(apiKey: infoKey)
        }

        return nil
    }
}

#Preview("Content View - Empty") {
    ContentView()
}

#Preview("Swipe Card") {
    SwipeCardView(
        content: {
            DetectionResultCard(result: DetectionResult.mockFlagged)
        },
        onDelete: { print("Delete") },
        onKeep: { print("Keep") }
    )
    .padding()
}
