//
//  BGTasks.swift
//  VaultEye
//
//  Background task scheduling and registration
//

import BackgroundTasks
import Foundation

final class BGTasks {
    static let taskIdentifier = "com.vaulteye.scan"

    // MARK: - Registration

    static func register(scanManager: BackgroundScanManager) {
        BGTaskScheduler.shared.register(
            forTaskWithIdentifier: taskIdentifier,
            using: nil
        ) { task in
            guard let processingTask = task as? BGProcessingTask else {
                task.setTaskCompleted(success: false)
                return
            }

            handleBackgroundScan(task: processingTask, scanManager: scanManager)
        }

        print("✅ Registered background task: \(taskIdentifier)")
    }

    // MARK: - Scheduling

    static func scheduleProcessing() {
        let request = BGProcessingTaskRequest(identifier: taskIdentifier)
        request.requiresNetworkConnectivity = false
        request.requiresExternalPower = false
        request.earliestBeginDate = Date(timeIntervalSinceNow: 30) // Try in 30 seconds

        do {
            try BGTaskScheduler.shared.submit(request)
            print("✅ Scheduled background processing task")
        } catch let error as NSError {
            // Code 3 means identifier not registered in Info.plist - this is expected in simulator
            if error.code == 3 {
                print("⚠️ Background task identifier not registered (expected in simulator)")
            } else {
                print("❌ Failed to schedule background task: \(error)")
            }
        }
    }

    static func cancelAllTasks() {
        BGTaskScheduler.shared.cancel(taskRequestWithIdentifier: taskIdentifier)
        print("🚫 Cancelled background tasks")
    }

    // MARK: - Background Task Handler

    private static func handleBackgroundScan(
        task: BGProcessingTask,
        scanManager: BackgroundScanManager
    ) {
        print("🔄 Background task started")

        // Handle expiration
        var isExpired = false
        task.expirationHandler = {
            print("⏰ Background task expiring - checkpointing")
            isExpired = true

            Task { @MainActor in
                scanManager.checkpoint()
            }

            // Reschedule for later
            scheduleProcessing()
        }

        // Run the scan
        Task { @MainActor in
            let success = await scanManager.resumeOrStartIfNeeded(threshold: 85)

            if !isExpired {
                task.setTaskCompleted(success: success)
                print("✅ Background task completed: \(success)")
            }
        }
    }
}

// MARK: - Xcode Configuration Required
/*
 To enable background task scheduling, configure in Xcode:

 Target → Info tab:
   - Add "Permitted background task scheduler identifiers"
   - Set value: com.vaulteye.scan

 Target → Signing & Capabilities:
   - Add "Background Modes" capability
   - Enable: Background fetch + Background processing

 See BACKGROUND_SETUP_INSTRUCTIONS_UPDATED.md for detailed setup.
 */
