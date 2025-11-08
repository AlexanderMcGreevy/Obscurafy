//
//  VaultEyeApp.swift
//  VaultEye
//
//  Created by Alexander McGreevy on 11/7/25.
//

import SwiftUI

@main
struct VaultEyeApp: App {
    @StateObject private var activityTracker = ActivityTracker()

    var body: some Scene {
        WindowGroup {
            TabView {
                ContentView()
                    .environmentObject(activityTracker)
                    .tabItem {
                        Label("Scan", systemImage: "magnifyingglass")
                    }

                NavigationStack {
                    DashboardView(activityTracker: activityTracker)
                }
                .tabItem {
                    Label("Dashboard", systemImage: "chart.bar.fill")
                }
            }
        }
    }
}
