import SwiftUI
import Charts

struct DashboardView: View {
    @StateObject private var vm = DashboardViewModel() // swap with injected VM later
    @State private var timeframe: DashboardViewModel.Timeframe = .last15Days

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                // Top summary cards
                HStack(spacing: 12) {
                    summaryCard(title: "Scanned", value: "\(vm.stats.totalScanned)", color: .blue, systemIcon: "photo.on.rectangle")
                    summaryCard(title: "Flagged", value: "\(vm.stats.flagged)", color: .red, systemIcon: "exclamationmark.triangle")
                    protectedCard()
                }
                .padding(.horizontal)

                // Chart with toggle
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Flagged Photos")
                            .font(.headline)
                        Spacer()
                        Picker("", selection: $timeframe) {
                            Text("15d").tag(DashboardViewModel.Timeframe.last15Days)
                            Text("30d").tag(DashboardViewModel.Timeframe.last30Days)
                        }
                        .pickerStyle(.segmented)
                        .frame(width: 140)
                        .onChange(of: timeframe) { _ in vm.updateSeries(for: timeframe) }
                    }

                    Chart {
                        ForEach(vm.series) { point in
                            BarMark(
                                x: .value("Day", point.date, unit: .day),
                                y: .value("Count", point.count)
                            )
                            .foregroundStyle(LinearGradient(colors: [.red.opacity(0.9), .red.opacity(0.5)], startPoint: .top, endPoint: .bottom))
                            LineMark(
                                x: .value("Day", point.date, unit: .day),
                                y: .value("Count", point.count)
                            )
                            .foregroundStyle(.purple)
                            .lineStyle(.init(lineWidth: 2))
                        }
                    }
                    .chartXAxis {
                        AxisMarks(values: .stride(by: .day, count: vm.stride(for: timeframe))) { _ in
                            AxisGridLine()
                            AxisTick()
                            AxisValueLabel(format: .dateTime.month().day())
                        }
                    }
                    .frame(height: 220)
                    .padding(.horizontal)
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
                    .animation(.easeInOut, value: vm.series)
                }
                .padding(.horizontal)

                // Protected Info list & impact summary
                VStack(spacing: 12) {
                    HStack {
                        Text("Protected Info")
                            .font(.headline)
                        Spacer()
                        Text("This month")
                            .foregroundColor(.secondary)
                            .font(.subheadline)
                    }
                    .padding(.horizontal)

                    // Categories
                    VStack(spacing: 8) {
                        ForEach(vm.categories) { cat in
                            HStack {
                                Label {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(cat.title)
                                            .font(.subheadline)
                                        Text("\(cat.count) items")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                } icon: {
                                    Image(systemName: cat.systemIcon)
                                        .resizable()
                                        .scaledToFit()
                                        .frame(width: 28, height: 28)
                                        .foregroundStyle(cat.color)
                                        .padding(8)
                                        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 8))
                                }
                                Spacer()
                                // small progress indicator
                                ProgressView(value: min(Double(cat.count) / max(1, Double(vm.stats.flagged)), 1.0))
                                    .progressViewStyle(LinearProgressViewStyle(tint: cat.color))
                                    .frame(width: 120)
                            }
                            .padding(.horizontal)
                            .padding(.vertical, 6)
                        }
                    }
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
                    .padding(.horizontal)

                    // Impact summary
                    HStack {
                        VStack(alignment: .leading) {
                            Text("Impact")
                                .font(.headline)
                            Text("Protected personal data this month")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                        VStack(alignment: .trailing) {
                            Text("\(vm.monthlyImpact.protectedItems) items")
                                .font(.title3.bold())
                            Text("~\(vm.monthlyImpact.estimatedRiskReduction)% risk reduced")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding()
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
                    .padding(.horizontal)
                }
            }
            .padding(.vertical)
        }
        .navigationTitle("VaultEye")
        .onAppear { vm.updateSeries(for: timeframe) }
    }

    // MARK: - Subviews
    @ViewBuilder
    private func summaryCard(title: String, value: String, color: Color, systemIcon: String) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: systemIcon)
                    .foregroundStyle(color)
                    .font(.title2)
                Spacer()
                Text(value)
                    .font(.title2.bold())
            }
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
        .shadow(color: Color.black.opacity(0.03), radius: 4, x: 0, y: 2)
    }

    @ViewBuilder
    private func protectedCard() -> some View {
        VStack {
            ZStack {
                Circle()
                    .stroke(Color.gray.opacity(0.2), lineWidth: 10)
                    .frame(width: 68, height: 68)
                Circle()
                    .trim(from: 0, to: CGFloat(vm.stats.protectedPercentage / 100))
                    .stroke(AngularGradient(gradient: Gradient(colors: [.green, .mint]), center: .center), style: StrokeStyle(lineWidth: 10, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .frame(width: 68, height: 68)
                    .animation(.easeOut, value: vm.stats.protectedPercentage)
                Text("\(Int(vm.stats.protectedPercentage))%")
                    .font(.caption2.bold())
            }
            Text("Protected")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
    }
}

// MARK: - Preview
struct DashboardView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            DashboardView()
        }
    }
}