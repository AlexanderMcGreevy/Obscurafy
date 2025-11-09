//
//  DeleteBatchManager.swift
//  VaultEye
//
//  Created by Alexander McGreevy on 11/8/25.
//

internal import Photos
import SwiftUI
import Combine

@MainActor
final class DeleteBatchManager: ObservableObject {
    @Published var stagedAssetIds: Set<String> = []

    private weak var statsManager: StatisticsManager?

    func configure(statsManager: StatisticsManager) {
        self.statsManager = statsManager
    }

    func stage(_ assetId: String) {
        stagedAssetIds.insert(assetId)
    }

    func unstage(_ assetId: String) {
        stagedAssetIds.remove(assetId)
    }

    func isStaged(_ assetId: String) -> Bool {
        stagedAssetIds.contains(assetId)
    }

    /// Clear all staged assets without deleting
    func clearStagedAssets() {
        stagedAssetIds.removeAll()
    }

    /// Commit all staged deletions in a single batch operation
    func commit(using resolver: (String) -> PHAsset?) async throws {
        let assets = stagedAssetIds.compactMap { resolver($0) }

        guard !assets.isEmpty else { return }

        let deleteCount = assets.count

        try await PHPhotoLibrary.shared().performChanges {
            PHAssetChangeRequest.deleteAssets(NSArray(array: assets))
        }

        // Record stats
        statsManager?.recordPhotosDeleted(deleteCount)

        // Success - clear staged items
        stagedAssetIds.removeAll()

        // Success haptic
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }
}
