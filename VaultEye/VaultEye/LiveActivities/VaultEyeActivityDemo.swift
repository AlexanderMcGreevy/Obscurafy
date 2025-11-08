import Foundation
import ActivityKit
import UIKit
import SwiftUI

@available(iOS 17.0, *)
final class VaultEyeActivityDemo {
    private var activity: Activity<VaultEyeAttributes>?

    // Start a demo live activity and simulate updates
    func startDemo() async {
        let attributes = VaultEyeAttributes(startedAt: Date())
        let initial = VaultEyeAttributes.ContentState(progress: 0.02, scannedCount: 2, flaggedCount: 0, topCategory: "—", status: .scanning)
        do {
            let activity = try Activity<VaultEyeAttributes>.request(attributes: attributes, content: initial, pushType: nil)
            self.activity = activity
            await simulateUpdates()
        } catch {
            print("Failed to request activity:", error)
        }
    }

    func stopDemo() {
        Task {
            await activity?.end(dismissalPolicy: .immediate)
            activity = nil
        }
    }

    private func simulateUpdates() async {
        guard let activity = activity else { return }
        var scanned = 2
        var flagged = 0
        for step in 1...20 {
            try? await Task.sleep(nanoseconds: 1_200_000_000)
            scanned += Int.random(in: 8...20)
            if Bool.random() && Int.random(in: 0...10) > 7 { flagged += 1 }
            let progress = min(1.0, Double(step) / 20.0)
            let state = VaultEyeAttributes.ContentState(progress: progress, scannedCount: scanned, flaggedCount: flagged, topCategory: "Credit Cards", status: progress < 1.0 ? .scanning : .complete)
            await activity.update(using: state)
            if progress >= 1.0 {
                try? await Task.sleep(nanoseconds: 2_000_000_000)
                await activity.end(using: state, dismissalPolicy: .afterExpiry)
                break
            }
        }
    }
}