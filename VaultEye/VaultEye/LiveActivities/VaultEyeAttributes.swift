import Foundation
import ActivityKit

// Shared Activity Attributes for VaultEye Live Activity
public struct VaultEyeAttributes: ActivityAttributes, Codable {
    public struct ContentState: Codable, Hashable {
        var progress: Double        // 0.0 ... 1.0
        var scannedCount: Int
        var flaggedCount: Int
        var topCategory: String
        var status: Status

        public enum Status: String, Codable, CaseIterable {
            case scanning
            case complete
        }
    }

    // metadata available at activity creation
    public var startedAt: Date
}