//
//  DeleteBatchManager.swift
//  VaultEye
//
//  Created by Alexander McGreevy on 11/8/25.
//

import Photos
import SwiftUI
import Combine

@MainActor
final class DeleteBatchManager: ObservableObject {
    @Published var stagedAssetIds: Set<String> = []

    func stage(_ assetId: String) {
        stagedAssetIds.insert(assetId)
    }

    func unstage(_ assetId: String) {
        stagedAssetIds.remove(assetId)
    }

    func isStaged(_ assetId: String) -> Bool {
        stagedAssetIds.contains(assetId)
    }

    /// Commit all staged deletions in a single batch operation
    func commit(using resolver: (String) -> PHAsset?) async throws {
        let assets = stagedAssetIds.compactMap { resolver($0) }

        guard !assets.isEmpty else { return }

        try await PHPhotoLibrary.shared().performChanges {
            PHAssetChangeRequest.deleteAssets(NSArray(array: assets))
        }

        // Success - clear staged items
        stagedAssetIds.removeAll()

        // Success haptic
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }
}
