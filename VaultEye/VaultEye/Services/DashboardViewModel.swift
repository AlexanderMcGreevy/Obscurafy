import Foundation
import SwiftUI
import Combine

// Simple model for chart points
struct DayPoint: Identifiable, Equatable {
    let id = UUID()
    let date: Date
    let count: Int

    static func == (lhs: DayPoint, rhs: DayPoint) -> Bool {
        lhs.id == rhs.id && lhs.date == rhs.date && lhs.count == rhs.count
    }
}

// Summary stats
struct ScanStats {
    var totalScanned: Int
    var flagged: Int
    var protectedPercentage: Double // 0..100
}

// Sensitive category model
struct SensitiveCategory: Identifiable {
    let id = UUID()
    let title: String
    let count: Int
    let systemIcon: String
    let color: Color
}

// Impact model
struct ImpactSummary {
    let protectedItems: Int
    let estimatedRiskReduction: Int // percent
}

@MainActor
final class DashboardViewModel: ObservableObject {
    enum Timeframe { case last15Days, last30Days }

    // public outputs
    @Published var stats: ScanStats
    @Published var categories: [SensitiveCategory] = []
    @Published var series: [DayPoint] = []
    @Published var monthlyImpact: ImpactSummary

    // internal data source
    private let activityTracker: ActivityTracker
    private var allDays: [DayPoint] = []

    init(activityTracker: ActivityTracker) {
        self.activityTracker = activityTracker

        // Initialize with real data from tracker
        let totalScanned = activityTracker.getTotalScanned()
        let totalFlagged = activityTracker.getTotalFlagged()
        let protectedPercentage = activityTracker.getProtectedPercentage()

        self.stats = ScanStats(
            totalScanned: totalScanned > 0 ? totalScanned : 0,
            flagged: totalFlagged > 0 ? totalFlagged : 0,
            protectedPercentage: protectedPercentage
        )

        // Monthly impact
        let monthlyProtected = activityTracker.getMonthlyProtectedItems()
        let riskReduction = monthlyProtected > 0 ? min(Int(Double(monthlyProtected) / Double(max(1, totalScanned)) * 100), 100) : 0
        self.monthlyImpact = ImpactSummary(
            protectedItems: monthlyProtected,
            estimatedRiskReduction: riskReduction
        )

        // Initialize empty arrays - will be filled after init
        self.categories = []
        self.allDays = []
        self.series = []

        // Now build the data (after all properties are initialized)
        let categoryCounts = activityTracker.getCategoryCounts()
        self.categories = Self.buildCategories(from: categoryCounts)
        self.allDays = Self.buildDailySeries(from: activityTracker, days: 30)
        self.series = Array(allDays.suffix(15))
    }

    // called when timeframe changes
    func updateSeries(for timeframe: Timeframe) {
        switch timeframe {
        case .last15Days:
            series = Array(allDays.suffix(15))
        case .last30Days:
            series = allDays
        }
    }

    func refresh() {
        // Refresh stats from tracker
        let totalScanned = activityTracker.getTotalScanned()
        let totalFlagged = activityTracker.getTotalFlagged()
        let protectedPercentage = activityTracker.getProtectedPercentage()

        self.stats = ScanStats(
            totalScanned: totalScanned,
            flagged: totalFlagged,
            protectedPercentage: protectedPercentage
        )

        // Refresh categories
        let categoryCounts = activityTracker.getCategoryCounts()
        self.categories = Self.buildCategories(from: categoryCounts)

        // Refresh monthly impact
        let monthlyProtected = activityTracker.getMonthlyProtectedItems()
        let riskReduction = monthlyProtected > 0 ? min(Int(Double(monthlyProtected) / Double(max(1, totalScanned)) * 100), 100) : 0
        self.monthlyImpact = ImpactSummary(
            protectedItems: monthlyProtected,
            estimatedRiskReduction: riskReduction
        )

        // Refresh daily series
        allDays = Self.buildDailySeries(from: activityTracker, days: 30)
        series = Array(allDays.suffix(15))
    }

    private static func buildDailySeries(from tracker: ActivityTracker, days: Int) -> [DayPoint] {
        let dailyCounts = tracker.getDailyFlaggedCounts(days: days)
        return dailyCounts.map { DayPoint(date: $0.0, count: $0.1) }
    }

    private static func buildCategories(from counts: [String: Int]) -> [SensitiveCategory] {
        // Map detection types to categories with icons
        var categories: [SensitiveCategory] = []

        // Credit Card is hardcoded as primary for now
        if let creditCardCount = counts["Credit Card"] {
            categories.append(
                SensitiveCategory(
                    title: "Credit Cards",
                    count: creditCardCount,
                    systemIcon: "creditcard",
                    color: .indigo
                )
            )
        }

        // Add other types that exist in data
        for (type, count) in counts where type != "Credit Card" {
            let icon: String
            let color: Color

            switch type {
            case "ID Card":
                icon = "idcard"
                color = .blue
            case "Personal Document":
                icon = "doc.text"
                color = .teal
            default:
                icon = "exclamationmark.shield"
                color = .orange
            }

            categories.append(
                SensitiveCategory(
                    title: type + "s",
                    count: count,
                    systemIcon: icon,
                    color: color
                )
            )
        }

        // If no data yet, show placeholder
        if categories.isEmpty {
            categories.append(
                SensitiveCategory(
                    title: "Credit Cards",
                    count: 0,
                    systemIcon: "creditcard",
                    color: .indigo
                )
            )
        }

        return categories.sorted { $0.count > $1.count }
    }

    func stride(for timeframe: Timeframe) -> Int {
        switch timeframe {
        case .last15Days: return 3
        case .last30Days: return 6
        }
    }

    // create mock points with small randomness
    private static func mockSeries(days: Int) -> [DayPoint] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        var points: [DayPoint] = []
        for i in (0..<days).reversed() {
            let date = calendar.date(byAdding: .day, value: -i, to: today)!
            // create a base pattern + random
            let base = Int(5 + 10 * sin(Double(i) / 3.0))
            let noise = Int.random(in: 0...8)
            let count = max(0, base + noise)
            points.append(DayPoint(date: date, count: count))
        }
        return points
    }
}
