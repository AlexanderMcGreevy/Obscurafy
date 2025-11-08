import Foundation
import SwiftUI

// Simple model for chart points
struct DayPoint: Identifiable {
    let id = UUID()
    let date: Date
    let count: Int
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

    // internal mock source
    private var allDays: [DayPoint] = []

    init() {
        // Generate mock stats and categories
        self.stats = ScanStats(totalScanned: 4820, flagged: 142, protectedPercentage: 78.0)
        self.categories = [
            SensitiveCategory(title: "ID Cards", count: 48, systemIcon: "idcard", color: .blue),
            SensitiveCategory(title: "Credit Cards", count: 32, systemIcon: "creditcard", color: .indigo),
            SensitiveCategory(title: "Personal Docs", count: 36, systemIcon: "doc.text", color: .teal),
            SensitiveCategory(title: "Photos of People", count: 26, systemIcon: "person.crop.rectangle", color: .pink)
        ]
        self.monthlyImpact = ImpactSummary(protectedItems: 97, estimatedRiskReduction: 42)

        // Build mock daily series for last 30 days
        allDays = Self.mockSeries(days: 30)
        self.series = Array(allDays.suffix(15)) // default last 15
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