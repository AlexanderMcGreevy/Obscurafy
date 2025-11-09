//
//  ScanScreen.swift
//  VaultEye
//
//  Background scan control screen with progress
//

import SwiftUI
internal import Photos

struct ScanScreen: View {
    @EnvironmentObject var scanManager: BackgroundScanManager
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var consentManager = PrivacyConsentManager()
    @StateObject private var photoScanService = PhotoScanService()

    @State private var threshold: Int = 85
    @State private var showResetConfirmation = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Status Section
                    statusSection

                    // Progress Section
                    if scanManager.isRunning {
                        progressSection
                    }

                    // Controls Section
                    controlsSection

                    // Last completion summary
                    if let summary = scanManager.lastCompletionSummary {
                        Text(summary)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .padding()
                    }

                    // Reset Button Section
                    resetSection
                }
                .padding()
            }
            .navigationTitle("Background Scan")
            .onChange(of: scenePhase) { oldPhase, newPhase in
                handleScenePhaseChange(from: oldPhase, to: newPhase)
            }
            .alert("Reset Scan Data?", isPresented: $showResetConfirmation) {
                Button("Cancel", role: .cancel) { }
                Button("Reset", role: .destructive) {
                    scanManager.resetScanData()
                }
            } message: {
                Text("This will clear all scan history and progress. You'll start from scratch on the next scan. This does not delete any photos.")
            }
        }
    }

    // MARK: - Status Section

    private var statusSection: some View {
        VStack(spacing: 12) {
            Image(systemName: scanManager.isRunning ? "hourglass" : "checkmark.circle.fill")
                .font(.system(size: 60))
                .foregroundColor(scanManager.isRunning ? .blue : .green)

            Text(scanManager.isRunning ? "Scanning..." : "Ready")
                .font(.title2)
                .fontWeight(.semibold)

            if scanManager.isRunning {
                Text("Processing photos in background")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            } else {
                Text("Tap Start to scan your photo library")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
        }
    }

    // MARK: - Progress Section

    private var progressSection: some View {
        VStack(spacing: 16) {
            ProgressView(
                value: Double(scanManager.processed),
                total: Double(scanManager.total)
            )
            .progressViewStyle(.linear)

            HStack {
                Text("\(scanManager.processed) / \(scanManager.total)")
                    .font(.headline)

                Spacer()

                Text("\(progressPercentage)%")
                    .font(.headline)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private var progressPercentage: Int {
        guard scanManager.total > 0 else { return 0 }
        return Int((Double(scanManager.processed) / Double(scanManager.total)) * 100)
    }

    // MARK: - Controls Section

    private var controlsSection: some View {
        VStack(spacing: 12) {
            // Detection Confidence Slider
            if !scanManager.isRunning {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Label("Detection Confidence", systemImage: "slider.horizontal.3")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                        Spacer()
                        Text("\(photoScanService.confidenceThreshold)%")
                            .font(.subheadline)
                            .fontWeight(.bold)
                            .foregroundColor(.blue)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 4)
                            .background(AppColor.primaryBg)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    }

                    Slider(
                        value: Binding(
                            get: { Double(photoScanService.confidenceThreshold) },
                            set: { photoScanService.confidenceThreshold = Int($0) }
                        ),
                        in: 0...100,
                        step: 1
                    )
                    .tint(.blue)

                    HStack {
                        Text("Lower = More photos flagged")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        Spacer()
                        Text("Higher = Only confident matches")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
                .padding()
                .background(Color(.systemGray6))
                .clipShape(RoundedRectangle(cornerRadius: 12))

                // Gemini AI Analysis Toggle
                geminiConsentSection
            }

            // Start/Cancel Button
            if scanManager.isRunning {
                Button(action: {
                    scanManager.cancel()
                }) {
                    HStack {
                        Image(systemName: "stop.fill")
                        Text("Cancel Scan")
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(AppColor.primary)
                    .foregroundColor(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
            } else {
                Button(action: {
                    Task {
                        await scanManager.startScan(threshold: threshold)
                    }
                }) {
                    HStack {
                        Image(systemName: "play.fill")
                        Text("Start Scan")
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(AppColor.primary)
                    .foregroundColor(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
            }

            // Test Model Button (Debug)
            #if DEBUG
            if !scanManager.isRunning {
                Button(action: testModel) {
                    HStack {
                        Image(systemName: "ant.circle")
                        Text("Test YOLO Model")
                    }
                    .font(.subheadline)
                    .foregroundColor(.green)
                }
            }
            #endif

            // Settings Link
            Link(destination: URL(string: UIApplication.openSettingsURLString)!) {
                HStack {
                    Image(systemName: "gear")
                    Text("Open Settings")
                }
                .font(.subheadline)
                .foregroundColor(.blue)
            }
        }
    }

    // MARK: - Test Model

    private func testModel() {
        print("[YOLO] Test button tapped - running model test...")

        Task {
            // Get first photo from library
            let assets = PhotoAccess.fetchAllImageAssets()
            guard let firstAssetID = assets.first,
                  let asset = PhotoAccess.fetchAsset(byLocalIdentifier: firstAssetID) else {
                print("[YOLO] No photos found in library")
                return
            }

            print("[YOLO] Testing with asset: \(asset.localIdentifier)")

            // Run YOLO detection
            let detections = await YOLOService.shared.detect(
                asset: asset,
                threshold01: photoScanService.threshold01
            )

            // Print results
            print("[YOLO] ✅ Test complete!")
            print("[YOLO] Found \(detections.count) detection(s)")

            for (index, detection) in detections.enumerated() {
                print("[YOLO]   \(index + 1). \(detection.label) - \(Int(detection.confidence * 100))%")
            }

            if let topDetection = detections.first {
                // Show toast notification
                await MainActor.run {
                    scanManager.lastCompletionSummary = "Test: \(topDetection.label) \(Int(topDetection.confidence * 100))%"
                }
            } else {
                await MainActor.run {
                    scanManager.lastCompletionSummary = "Test: No detections found"
                }
            }
        }
    }

    // MARK: - Gemini Consent Section

    private var geminiConsentSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("AI Analysis", systemImage: "sparkles")
                    .font(.subheadline)
                    .fontWeight(.semibold)

                Spacer()

                Toggle("", isOn: Binding(
                    get: { consentManager.hasConsented },
                    set: { newValue in
                        consentManager.recordConsent(newValue)
                        print(newValue ? "✅ Gemini AI analysis enabled" : "⚠️ Gemini AI analysis disabled")
                    }
                ))
                .labelsHidden()
            }

            VStack(alignment: .leading, spacing: 8) {
                if consentManager.hasConsented {
                    // Why it's enabled
                    VStack(alignment: .leading, spacing: 6) {
                        HStack(alignment: .top, spacing: 8) {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                                .font(.caption)
                            Text("Enhanced Protection")
                                .font(.caption)
                                .fontWeight(.semibold)
                        }
                        Text("AI analyzes detected text to identify credit cards, SSNs, and other sensitive information with detailed explanations and risk scores.")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                            .padding(.leading, 20)
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        HStack(alignment: .top, spacing: 8) {
                            Image(systemName: "lock.shield.fill")
                                .foregroundColor(.blue)
                                .font(.caption)
                            Text("Privacy First")
                                .font(.caption)
                                .fontWeight(.semibold)
                        }
                        Text("Only sanitized text is sent to Gemini API - no photos leave your device. Original images never transmitted.")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                            .padding(.leading, 20)
                    }
                } else {
                    // Why to enable
                    VStack(alignment: .leading, spacing: 6) {
                        HStack(alignment: .top, spacing: 8) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(.orange)
                                .font(.caption)
                            Text("Limited Detection")
                                .font(.caption)
                                .fontWeight(.semibold)
                        }
                        Text("Without AI analysis, only basic detection is available. You may miss sensitive information that requires context to identify.")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                            .padding(.leading, 20)
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        HStack(alignment: .top, spacing: 8) {
                            Image(systemName: "info.circle.fill")
                                .foregroundColor(.blue)
                                .font(.caption)
                            Text("How It Works")
                                .font(.caption)
                                .fontWeight(.semibold)
                        }
                        Text("When enabled, detected text is sanitized and analyzed by Google's Gemini AI to classify sensitivity levels and provide actionable recommendations.")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                            .padding(.leading, 20)
                    }
                }
            }
        }
        .padding()
        .background(AppColor.primaryBg)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(AppColor.border, lineWidth: 1)
        )
    }

    // MARK: - Reset Section

    private var resetSection: some View {
        VStack(spacing: 16) {
            Divider()
                .padding(.vertical, 8)

            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: "arrow.clockwise.circle.fill")
                        .foregroundColor(.orange)
                        .font(.title2)

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Reset Scan Data")
                            .font(.headline)
                            .foregroundColor(.primary)

                        Text("Clear all scan history and start fresh")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    Spacer()
                }

                Button(action: {
                    showResetConfirmation = true
                }) {
                    HStack {
                        Image(systemName: "trash.circle.fill")
                        Text("Reset")
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(AppColor.primaryBg)
                    .foregroundColor(AppColor.primary)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(AppColor.border, lineWidth: 1)
                    )
                }
                .disabled(scanManager.isRunning)
            }
            .padding()
            .background(Color(.systemGray6))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }

    // MARK: - Scene Phase Handling

    private func handleScenePhaseChange(from oldPhase: ScenePhase, to newPhase: ScenePhase) {
        switch newPhase {
        case .background:
            if scanManager.isRunning {
                print("📱 App entering background - scheduling BG task")
                BGTasks.scheduleProcessing()
            }
        case .active:
            print("📱 App became active")
        case .inactive:
            print("📱 App became inactive")
        @unknown default:
            break
        }
    }
}

// MARK: - Preview

#Preview {
    ScanScreen()
        .environmentObject(BackgroundScanManager())
}
