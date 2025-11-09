//
//  ContentView.swift
//  VaultEye
//
//  Created by Alexander McGreevy on 11/7/25.
//

import SwiftUI
internal import Photos

struct ContentView: View {
    @EnvironmentObject var scanManager: BackgroundScanManager
    @EnvironmentObject var statsManager: StatisticsManager
    @StateObject private var photoLibraryManager: PhotoLibraryManager
    @StateObject private var deleteBatchManager: DeleteBatchManager
    private let geminiService: GeminiAnalyzing?
    private let consentManager: PrivacyConsentManaging

    @State private var detectionResults: [DetectionResult] = []
    @State private var showPermissionAlert = false

    init(
        geminiService: GeminiAnalyzing? = ContentView.makeGeminiService(),
        consentManager: PrivacyConsentManaging = PrivacyConsentManager()
    ) {
        self.geminiService = geminiService
        self.consentManager = consentManager
        _photoLibraryManager = StateObject(wrappedValue: PhotoLibraryManager())
        _deleteBatchManager = StateObject(wrappedValue: DeleteBatchManager())
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
            .navigationTitle("Review Photos")
            .task {
                // Load photos from background scan results on appear
                await loadPhotosFromBackgroundScan()
            }
            .onAppear {
                // Configure delete batch manager with stats
                deleteBatchManager.configure(statsManager: statsManager)
            }
            .onChange(of: scanManager.isRunning) { oldValue, newValue in
                // Reload when scan completes
                if oldValue && !newValue {
                    Task {
                        await loadPhotosFromBackgroundScan()
                    }
                }
            }
            .onChange(of: scanManager.scanDataVersion) { oldValue, newValue in
                // Clear results when scan data is reset
                print("🗑️ Scan data reset detected - clearing review results")
                detectionResults = []
                deleteBatchManager.clearStagedAssets()
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
        VStack(spacing: 20) {
            Image(systemName: "photo.stack")
                .font(.system(size: 60))
                .foregroundColor(.blue)

            Text("No Photos to Review")
                .font(.title2)
                .fontWeight(.semibold)

            Text("Matched photos from your background scan will appear here for review.")
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
                .padding(.horizontal)

            VStack(spacing: 12) {
                HStack(spacing: 8) {
                    Image(systemName: "1.circle.fill")
                        .foregroundColor(.blue)
                    Text("Go to the Background Scan tab")
                        .font(.subheadline)
                    Spacer()
                }

                HStack(spacing: 8) {
                    Image(systemName: "2.circle.fill")
                        .foregroundColor(.blue)
                    Text("Start a scan to find flagged photos")
                        .font(.subheadline)
                    Spacer()
                }

                HStack(spacing: 8) {
                    Image(systemName: "3.circle.fill")
                        .foregroundColor(.blue)
                    Text("Return here to review and sort them")
                        .font(.subheadline)
                    Spacer()
                }
            }
            .padding()
            .background(Color(.systemGray6))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .padding(.horizontal)
        }
        .padding()
    }

    private var resultsList: some View {
        VStack(spacing: 16) {
            // Progress indicator with action instructions
            VStack(spacing: 8) {
                HStack {
                    Text("\(detectionResults.count) matched photo(s) to review")
                        .font(.headline)
                        .foregroundColor(.secondary)
                    Spacer()
                }

                HStack(spacing: 16) {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.left")
                            .font(.caption)
                            .foregroundColor(.green)
                        Text("Keep")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    Text("|")
                        .foregroundColor(.secondary)

                    HStack(spacing: 4) {
                        Text("Delete")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Image(systemName: "arrow.right")
                            .font(.caption)
                            .foregroundColor(.red)
                    }

                    Spacer()

                    HStack(spacing: 4) {
                        Image(systemName: "arrow.down")
                            .font(.caption)
                            .foregroundColor(.blue)
                        Text("Redact")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .padding(.horizontal)
            .padding(.top, 8)

            // Show only the first (current) photo as swipeable card
            if let currentResult = detectionResults.first {
                SwipeCardView(
                    content: {
                        DetectionResultCard(
                            result: currentResult,
                            photoLibraryManager: photoLibraryManager,
                            deleteBatchManager: deleteBatchManager,
                            geminiService: geminiService,
                            consentManager: consentManager
                        )
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

            Text("You've reviewed all matched photos")
                .font(.subheadline)
                .foregroundColor(.secondary)

            if deleteBatchManager.stagedAssetIds.count > 0 {
                VStack(spacing: 16) {
                    HStack {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.orange)
                        Text("\(deleteBatchManager.stagedAssetIds.count) photo(s) queued for deletion")
                            .foregroundColor(.secondary)
                    }
                    .padding()
                    .background(Color.orange.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 8))

                    Button(action: commitDeletions) {
                        HStack {
                            Image(systemName: "trash.fill")
                            Text("Permanently Delete Selected Photos")
                        }
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                        .padding(.horizontal, 32)
                        .padding(.vertical, 16)
                        .background(Color.red)
                        .cornerRadius(12)
                    }

                    Text("This action cannot be undone")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            } else {
                Text("No photos selected for deletion")
                    .foregroundColor(.secondary)
                    .padding()
                    .background(Color(.systemGray6))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            }
        }
        .padding()
    }


    /// Load photos from background scan results
    private func loadPhotosFromBackgroundScan() async {
        guard photoLibraryManager.isAuthorized else { return }

        // Get selected asset IDs from background scan
        let assetIDs = scanManager.getSelectedAssetIDs()

        guard !assetIDs.isEmpty else { return }

        // Convert to DetectionResults with YOLO detections
        var results: [DetectionResult] = []

        for assetID in assetIDs {
            guard let asset = PhotoAccess.fetchAsset(byLocalIdentifier: assetID) else {
                continue
            }

            // Run YOLO detection to get regions
            let detections = await YOLOService.shared.detect(asset: asset, threshold01: 0.5)

            // Convert YOLO detections to DetectedRegions
            let regions = detections.map { detection in
                DetectedRegion(
                    normalizedRect: detection.boundingBox,
                    confidence: detection.confidence,
                    label: detection.label
                )
            }

            // Create detection result with actual YOLO detections
            let result = DetectionResult(
                asset: asset,
                isFlagged: true,
                detectedRegions: regions,
                reason: regions.isEmpty ? "Flagged by background scan" : "Contains \(regions.first?.label ?? "sensitive content")"
            )

            results.append(result)
        }

        // Update UI on main actor
        await MainActor.run {
            // Only load if we don't already have results
            if detectionResults.isEmpty {
                detectionResults = results
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
        // Record stat
        statsManager.recordPhotoKept()

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
        // Try environment variable first
        if let envKey = ProcessInfo.processInfo.environment["GEMINI_API_KEY"], !envKey.isEmpty {
            print("✅ Gemini API key loaded from environment variable")
            return GeminiService(apiKey: envKey)
        }

        // Try Info.plist
        if let infoKey = Bundle.main.object(forInfoDictionaryKey: "GeminiAPIKey") as? String, !infoKey.isEmpty {
            print("✅ Gemini API key loaded from Info.plist")
            return GeminiService(apiKey: infoKey)
        }

        // Try reading from Secrets.xcconfig file (development fallback)
        if let configKey = readAPIKeyFromSecretsFile(), !configKey.isEmpty {
            print("✅ Gemini API key loaded from Secrets.xcconfig")
            return GeminiService(apiKey: configKey)
        }

        print("❌ Gemini API key not found - AI analysis disabled")
        print("   Add GEMINI_API_KEY environment variable or configure Secrets.xcconfig")
        return nil
    }

    /// Reads API key from Secrets.xcconfig file (development only)
    private static func readAPIKeyFromSecretsFile() -> String? {
        // Get path to Secrets.xcconfig in project root
        guard let projectPath = Bundle.main.resourcePath?
            .replacingOccurrences(of: "/Build/Products", with: "")
            .replacingOccurrences(of: "/Debug-iphonesimulator/VaultEye.app", with: "")
            .replacingOccurrences(of: "/Release-iphonesimulator/VaultEye.app", with: "")
            .replacingOccurrences(of: "/Debug-iphoneos/VaultEye.app", with: "")
            .replacingOccurrences(of: "/Release-iphoneos/VaultEye.app", with: "")
        else {
            // Try alternative: look in parent directories from source location
            let fileManager = FileManager.default
            var currentPath = fileManager.currentDirectoryPath

            for _ in 0..<5 {
                let secretsPath = (currentPath as NSString).appendingPathComponent("Secrets.xcconfig")
                if fileManager.fileExists(atPath: secretsPath) {
                    return parseAPIKeyFromFile(secretsPath)
                }
                currentPath = (currentPath as NSString).deletingLastPathComponent
            }
            return nil
        }

        let secretsPath = (projectPath as NSString).appendingPathComponent("Secrets.xcconfig")
        return parseAPIKeyFromFile(secretsPath)
    }

    private static func parseAPIKeyFromFile(_ path: String) -> String? {
        guard let contents = try? String(contentsOfFile: path, encoding: .utf8) else {
            return nil
        }

        // Parse: GEMINI_API_KEY = AIzaSy...
        for line in contents.components(separatedBy: .newlines) {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix("GEMINI_API_KEY") {
                let parts = trimmed.components(separatedBy: "=")
                if parts.count >= 2 {
                    let key = parts[1...].joined(separator: "=")
                        .trimmingCharacters(in: .whitespaces)
                    if key != "YOUR_GEMINI_API_KEY_HERE" && !key.isEmpty {
                        return key
                    }
                }
            }
        }
        return nil
    }
}

#Preview("Content View - Empty") {
    ContentView()
        .environmentObject(BackgroundScanManager())
        .environmentObject(StatisticsManager())
}

#Preview("Swipe Card") {
    SwipeCardView(
        content: {
            DetectionResultCard(
                result: DetectionResult.mockFlagged,
                photoLibraryManager: PhotoLibraryManager(),
                deleteBatchManager: DeleteBatchManager()
            )
        },
        onDelete: { print("Delete") },
        onKeep: { print("Keep") }
    )
    .padding()
}
