//
//  VaultEyeApp.swift
//  VaultEye
//
//  Created by Alexander McGreevy on 11/7/25.
//

import SwiftUI
import UserNotifications

@main
struct VaultEyeApp: App {
    @StateObject private var scanManager = BackgroundScanManager()
    @StateObject private var statsManager = StatisticsManager()
    @Environment(\.scenePhase) private var scenePhase

    init() {
        // Set notification delegate
        UNUserNotificationCenter.current().delegate = NotificationHelper.shared
    }

    var body: some Scene {
        WindowGroup {
            TabView {
                ContentView()
                    .environmentObject(scanManager)
                    .environmentObject(statsManager)
                    .tabItem {
                        Label("Review", systemImage: "rectangle.stack.badge.play")
                    }

                ScanScreen()
                    .environmentObject(scanManager)
                    .tabItem {
                        Label("Scan", systemImage: "magnifyingglass")
                    }

                StatisticsView()
                    .environmentObject(statsManager)
                    .tabItem {
                        Label("Statistics", systemImage: "chart.bar.fill")
                    }
            }
            .onAppear {
                // Configure scan manager with stats
                scanManager.configure(statsManager: statsManager)

                // Register background tasks with the actual scanManager instance
                BGTasks.register(scanManager: scanManager)
            }
            .onChange(of: scenePhase) { oldPhase, newPhase in
                switch newPhase {
                case .background:
                    print("📱 App entered background - scan will continue")
                    // Schedule background processing task as backup
                    if scanManager.isRunning {
                        BGTasks.scheduleProcessing()
                    }
                case .active:
                    print("📱 App became active")
                default:
                    break
                }
            }
        }
    }
}

// MARK: - Xcode Configuration Required
/*
 To enable background scanning, configure these in Xcode:

 1. Target → Info tab → Add:
    - Permitted background task scheduler identifiers
      └─ com.vaulteye.scan

 2. Target → Signing & Capabilities → Add "Background Modes":
    ✅ Background fetch
    ✅ Background processing

 3. Verify privacy descriptions exist:
    - Privacy - Photo Library Usage Description
    - Privacy - Photo Library Additions Usage Description
    - Privacy - User Notifications Usage Description

 See BACKGROUND_SETUP_INSTRUCTIONS_UPDATED.md for detailed setup guide.
 */
