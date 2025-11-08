//
//  ActivityTracker.swift
//  VaultEye
//
//  Tracks user actions for dashboard analytics
//

import Foundation
import Combine

enum UserAction {
    case scanned
    case deleted(type: String)  // "Credit Card", "ID", etc.
    case kept
    case redacted(type: String)
}

struct DailyActivity: Codable {
    let date: Date
    var scannedCount: Int
    var deletedCount: Int
    var keptCount: Int
    var redactedCount: Int
    var detectionsByType: [String: Int]  // "Credit Card": 5, etc.

    init(date: Date) {
        self.date = date
        self.scannedCount = 0
        self.deletedCount = 0
        self.keptCount = 0
        self.redactedCount = 0
        self.detectionsByType = [:]
    }
}

@MainActor
final class ActivityTracker: ObservableObject {
    @Published var activities: [DailyActivity] = []

    private let saveKey = "VaultEyeActivities"
    private let calendar = Calendar.current

    init() {
        loadActivities()
    }

    // MARK: - Track Actions

    func trackScan() {
        var today = getTodayActivity()
        today.scannedCount += 1
        updateActivity(today)
        objectWillChange.send()
    }

    func trackDelete(type: String = "Credit Card") {
        var today = getTodayActivity()
        today.deletedCount += 1
        today.detectionsByType[type, default: 0] += 1
        updateActivity(today)
        objectWillChange.send()
    }

    func trackKeep() {
        var today = getTodayActivity()
        today.keptCount += 1
        updateActivity(today)
        objectWillChange.send()
    }

    func trackRedaction(type: String = "Credit Card") {
        var today = getTodayActivity()
        today.redactedCount += 1
        today.detectionsByType[type, default: 0] += 1
        updateActivity(today)
        objectWillChange.send()
    }

    // MARK: - Dashboard Data

    func getTotalScanned() -> Int {
        activities.reduce(0) { $0 + $1.scannedCount }
    }

    func getTotalFlagged() -> Int {
        activities.reduce(0) { $0 + $1.deletedCount + $1.redactedCount }
    }

    func getProtectedPercentage() -> Double {
        let total = getTotalScanned()
        guard total > 0 else { return 0 }
        let protected = activities.reduce(0) { $0 + $1.deletedCount + $1.redactedCount }
        return Double(protected) / Double(total) * 100
    }

    func getDailyFlaggedCounts(days: Int) -> [(Date, Int)] {
        let today = calendar.startOfDay(for: Date())
        var results: [(Date, Int)] = []

        for i in (0..<days).reversed() {
            let date = calendar.date(byAdding: .day, value: -i, to: today)!
            let activity = activities.first { calendar.isDate($0.date, inSameDayAs: date) }
            let count = (activity?.deletedCount ?? 0) + (activity?.redactedCount ?? 0)
            results.append((date, count))
        }

        return results
    }

    func getCategoryCounts() -> [String: Int] {
        var totals: [String: Int] = [:]

        for activity in activities {
            for (type, count) in activity.detectionsByType {
                totals[type, default: 0] += count
            }
        }

        return totals
    }

    func getMonthlyProtectedItems() -> Int {
        let thirtyDaysAgo = calendar.date(byAdding: .day, value: -30, to: Date())!

        return activities
            .filter { $0.date >= thirtyDaysAgo }
            .reduce(0) { $0 + $1.deletedCount + $1.redactedCount }
    }

    // MARK: - Persistence

    private func getTodayActivity() -> DailyActivity {
        let today = calendar.startOfDay(for: Date())

        if let existing = activities.first(where: { calendar.isDate($0.date, inSameDayAs: today) }) {
            return existing
        }

        let newActivity = DailyActivity(date: today)
        activities.append(newActivity)
        return newActivity
    }

    private func updateActivity(_ activity: DailyActivity) {
        if let index = activities.firstIndex(where: { calendar.isDate($0.date, inSameDayAs: activity.date) }) {
            activities[index] = activity
        }
        saveActivities()
    }

    private func saveActivities() {
        if let encoded = try? JSONEncoder().encode(activities) {
            UserDefaults.standard.set(encoded, forKey: saveKey)
        }
    }

    private func loadActivities() {
        guard let data = UserDefaults.standard.data(forKey: saveKey),
              let decoded = try? JSONDecoder().decode([DailyActivity].self, from: data) else {
            return
        }
        self.activities = decoded
    }

    // MARK: - Testing

    func addMockData() {
        // Add some mock historical data for testing
        for i in 0..<30 {
            let date = calendar.date(byAdding: .day, value: -i, to: Date())!
            var activity = DailyActivity(date: date)
            activity.scannedCount = Int.random(in: 10...50)
            activity.deletedCount = Int.random(in: 2...10)
            activity.redactedCount = Int.random(in: 1...5)
            activity.keptCount = Int.random(in: 5...20)
            activity.detectionsByType = [
                "Credit Card": Int.random(in: 1...5),
                "ID Card": Int.random(in: 1...3),
                "Personal Document": Int.random(in: 1...4)
            ]
            activities.append(activity)
        }
        saveActivities()
        objectWillChange.send()
    }
}
