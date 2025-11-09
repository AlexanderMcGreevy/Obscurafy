//
//  PhotoLibraryManager.swift
//  VaultEye
//
//  Created by Alexander McGreevy on 11/7/25.
//

internal import Photos
import SwiftUI
import Combine

@MainActor
class PhotoLibraryManager: ObservableObject {
    @Published var authorizationStatus: PHAuthorizationStatus = .notDetermined

    init() {
        authorizationStatus = PHPhotoLibrary.authorizationStatus(for: .readWrite)
    }

    func requestPermission() async {
        let status = await PHPhotoLibrary.requestAuthorization(for: .readWrite)
        authorizationStatus = status
    }

    var isAuthorized: Bool {
        authorizationStatus == .authorized || authorizationStatus == .limited
    }

    func fetchAllPhotos() -> PHFetchResult<PHAsset> {
        let options = PHFetchOptions()
        options.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
        return PHAsset.fetchAssets(with: .image, options: options)
    }

    func deleteAsset(_ asset: PHAsset) async throws {
        try await PHPhotoLibrary.shared().performChanges {
            PHAssetChangeRequest.deleteAssets([asset] as NSArray)
        }
    }

    func loadThumbnail(for asset: PHAsset, targetSize: CGSize) async -> UIImage? {
        return await withCheckedContinuation { continuation in
            let options = PHImageRequestOptions()
            // Use highQualityFormat instead of opportunistic to ensure completion is called only once
            options.deliveryMode = .highQualityFormat
            options.isNetworkAccessAllowed = true
            options.isSynchronous = false

            var hasResumed = false
            let lock = NSLock()

            PHImageManager.default().requestImage(
                for: asset,
                targetSize: targetSize,
                contentMode: .aspectFill,
                options: options
            ) { image, info in
                lock.lock()
                defer { lock.unlock() }

                // Only resume once, even if completion is called multiple times
                guard !hasResumed else { return }

                // Check if this is the final/degraded image
                let isDegraded = (info?[PHImageResultIsDegradedKey] as? Bool) ?? false

                // For opportunistic mode, we want the final (non-degraded) image
                // But if we're using highQualityFormat, we always get the final image
                if !isDegraded || options.deliveryMode == .highQualityFormat {
                    hasResumed = true
                    continuation.resume(returning: image)
                }
            }
        }
    }
}
