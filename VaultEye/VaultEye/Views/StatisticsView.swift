//
//  StatisticsView.swift
//  VaultEye
//
//  Display app statistics for photos scanned, deleted, kept, and redacted
//

import SwiftUI

struct StatisticsView: View {
    @EnvironmentObject var statsManager: StatisticsManager

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Scan Coverage Section
                    scanCoverageSection

                    // Overview Section
                    overviewSection

                    // Actions Section
                    actionsSection

                    // Detailed Stats
                    detailedStatsSection

                    // Last Scan Info
                    if let lastScan = statsManager.lastScanDate {
                        lastScanSection(date: lastScan)
                    }

                    Spacer()
                }
                .padding()
            }
            .navigationTitle("Statistics")
            .background(Color(.systemGroupedBackground))
            .task {
                await updateLibraryPhotoCount()
            }
        }
    }

    // MARK: - Scan Coverage Section

    private var scanCoverageSection: some View {
        VStack(spacing: 16) {
            Text("Library Scan Coverage")
                .font(.headline)
                .foregroundColor(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)

            VStack(spacing: 12) {
                // Circular progress indicator
                ZStack {
                    Circle()
                        .stroke(Color(.systemGray5), lineWidth: 12)
                        .frame(width: 120, height: 120)

                    Circle()
                        .trim(from: 0, to: statsManager.scanCoverage)
                        .stroke(
                            AppColor.primary,
                            style: StrokeStyle(lineWidth: 12, lineCap: .round)
                        )
                        .frame(width: 120, height: 120)
                        .rotationEffect(.degrees(-90))
                        .animation(.easeInOut, value: statsManager.scanCoverage)

                    VStack(spacing: 4) {
                        Text("\(Int(statsManager.scanCoverage * 100))%")
                            .font(.system(size: 28, weight: .bold))
                            .foregroundColor(statsManager.scanCoverage >= 1.0 ? .green : .primary)

                        Text("Scanned")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.vertical, 8)

                // Stats breakdown
                VStack(spacing: 8) {
                    HStack {
                        Image(systemName: "photo.on.rectangle")
                            .foregroundColor(.blue)
                        Text("Total photos in library:")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        Spacer()
                        Text("\(statsManager.totalPhotosInLibrary)")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                    }

                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                        Text("Photos scanned:")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        Spacer()
                        Text("\(statsManager.lastPhotosScannedCount)")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                    }

                    if statsManager.unscannedPhotos > 0 {
                        HStack {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(.orange)
                            Text("Not yet scanned:")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            Spacer()
                            Text("\(statsManager.unscannedPhotos)")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .foregroundColor(.orange)
                        }
                        .padding(.vertical, 4)
                        .padding(.horizontal, 12)
                        .background(AppColor.primaryBg)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                }
            }
            .padding()
            .background(Color(.systemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }

    // MARK: - Overview Section

    private var overviewSection: some View {
        VStack(spacing: 16) {
            Text("Total Activity")
                .font(.headline)
                .foregroundColor(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)

            HStack(spacing: 16) {
                StatCard(
                    title: "Scanned",
                    value: "\(statsManager.photosScanned)",
                    icon: "magnifyingglass",
                    color: .blue
                )

                StatCard(
                    title: "Processed",
                    value: "\(statsManager.totalProcessed)",
                    icon: "checkmark.circle",
                    color: .green
                )
            }
        }
    }

    // MARK: - Actions Section

    private var actionsSection: some View {
        VStack(spacing: 16) {
            Text("Actions Taken")
                .font(.headline)
                .foregroundColor(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)

            VStack(spacing: 12) {
                ActionRow(
                    icon: "trash.fill",
                    title: "Deleted",
                    count: statsManager.photosDeleted,
                    color: .red
                )

                ActionRow(
                    icon: "hand.thumbsup.fill",
                    title: "Kept",
                    count: statsManager.photosKept,
                    color: .green
                )

                ActionRow(
                    icon: "eye.slash.fill",
                    title: "Redacted",
                    count: statsManager.photosRedacted,
                    color: .orange
                )
            }
            .padding()
            .background(Color(.systemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }

    // MARK: - Detailed Stats Section

    private var detailedStatsSection: some View {
        VStack(spacing: 16) {
            Text("Insights")
                .font(.headline)
                .foregroundColor(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)

            VStack(spacing: 12) {
                InsightRow(
                    title: "Total Scans Run",
                    value: "\(statsManager.totalScans)"
                )

                if statsManager.totalProcessed > 0 {
                    InsightRow(
                        title: "Deletion Rate",
                        value: "\(Int(statsManager.deletionRate * 100))%"
                    )

                    InsightRow(
                        title: "Keep Rate",
                        value: "\(Int(statsManager.keepRate * 100))%"
                    )
                }
            }
            .padding()
            .background(Color(.systemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }

    // MARK: - Last Scan Section

    private func lastScanSection(date: Date) -> some View {
        VStack(spacing: 8) {
            Text("Last Scan")
                .font(.headline)
                .foregroundColor(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)

            HStack {
                Image(systemName: "clock.fill")
                    .foregroundColor(.blue)

                Text(date, style: .relative)
                    .font(.subheadline)
                    .foregroundColor(.secondary)

                Spacer()
            }
            .padding()
            .background(Color(.systemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }

    // MARK: - Helper Methods

    private func updateLibraryPhotoCount() async {
        // Get current photo library count
        let assetIDs = PhotoAccess.fetchAllImageAssets()
        await MainActor.run {
            statsManager.updateLibraryPhotoCount(assetIDs.count)
        }
    }
}

// MARK: - Stat Card Component

private struct StatCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 30))
                .foregroundColor(color)

            Text(value)
                .font(.title)
                .fontWeight(.bold)

            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

// MARK: - Action Row Component

private struct ActionRow: View {
    let icon: String
    let title: String
    let count: Int
    let color: Color

    var body: some View {
        HStack {
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundColor(color)
                .frame(width: 32)

            Text(title)
                .font(.body)
                .fontWeight(.medium)

            Spacer()

            Text("\(count)")
                .font(.title3)
                .fontWeight(.bold)
                .foregroundColor(color)
        }
    }
}

// MARK: - Insight Row Component

private struct InsightRow: View {
    let title: String
    let value: String

    var body: some View {
        HStack {
            Text(title)
                .font(.body)
                .foregroundColor(.secondary)

            Spacer()

            Text(value)
                .font(.body)
                .fontWeight(.semibold)
        }
    }
}

// MARK: - Preview

#Preview {
    let statsManager = StatisticsManager()
    statsManager.photosScanned = 150
    statsManager.photosDeleted = 25
    statsManager.photosKept = 100
    statsManager.photosRedacted = 15
    statsManager.totalScans = 3
    statsManager.lastScanDate = Date().addingTimeInterval(-3600) // 1 hour ago
    statsManager.totalPhotosInLibrary = 200
    statsManager.lastPhotosScannedCount = 150

    return StatisticsView()
        .environmentObject(statsManager)
}
