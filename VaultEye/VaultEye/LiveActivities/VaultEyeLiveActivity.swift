import SwiftUI
import ActivityKit
import WidgetKit

@available(iOS 17.0, *)
struct VaultEyeLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: VaultEyeAttributes.self) { context in
            // Lock Screen / Expanded UI
            ZStack {
                // subtle gradient background (replace Color("...") with asset or system colors)
                LinearGradient(
                    colors: [Color("VaultBlue"), Color("VaultMint"), Color("VaultViolet")],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()

                VStack(spacing: 12) {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(context.attributes.startedAt, style: .time)
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text(context.state.status == .scanning ? "Scanning your gallery…" : "Scan complete")
                                .font(.headline).bold()
                        }
                        Spacer()
                        statusIcon(for: context.state)
                    }
                    .padding(.horizontal)

                    // Main ring + counts
                    HStack {
                        ScanningRing(progress: context.state.progress, isActive: context.state.status == .scanning)
                            .frame(width: 88, height: 88)
                        VStack(alignment: .leading, spacing: 6) {
                            Text("\(context.state.scannedCount) scanned")
                                .font(.title3.bold())
                            if context.state.status == .scanning {
                                Text("\(context.state.flaggedCount) flagged so far")
                                    .font(.subheadline)
                                    .foregroundColor(.red)
                            } else {
                                HStack(spacing: 6) {
                                    Text("\(context.state.flaggedCount) flagged")
                                        .font(.subheadline)
                                        .foregroundColor(.red)
                                    Text("•")
                                        .foregroundColor(.secondary)
                                    Text(context.state.topCategory)
                                        .font(.subheadline)
                                        .foregroundColor(.primary)
                                }
                            }
                        }
                        Spacer()
                    }
                    .padding(.horizontal)

                    if context.state.status == .complete {
                        // result card
                        HStack {
                            VStack(alignment: .leading, spacing: 6) {
                                Text("\(context.state.scannedCount) photos scanned")
                                    .font(.subheadline)
                                Text("\(context.state.flaggedCount) flagged")
                                    .font(.headline).bold()
                                    .foregroundColor(.red)
                                Text("Most common: \(context.state.topCategory)")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                            VStack {
                                Image(systemName: "checkmark.shield.fill")
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 36, height: 36)
                                    .foregroundStyle(.green)
                                Text("VaultEye secured your data 🔒")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .padding()
                        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12))
                        .padding(.horizontal)
                        .transition(.opacity.combined(with: .scale))
                        .animation(.easeInOut, value: context.state.status)
                    }

                    Spacer(minLength: 6)
                }
                .padding(.vertical)
                .foregroundColor(.white)
                .shadow(radius: 6)
            }
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.center) {
                    HStack(spacing: 12) {
                        ScanningRing(progress: context.state.progress, isActive: context.state.status == .scanning)
                            .frame(width: 48, height: 48)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(context.state.status == .scanning ? "Scanning…" : "Scan complete")
                                .font(.subheadline).bold()
                            Text("\(context.state.scannedCount) scanned")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(.horizontal, 6)
                }
                DynamicIslandExpandedRegion(.leading) {
                    Image(systemName: "photo.on.rectangle.angled")
                        .foregroundStyle(.white)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    if context.state.flaggedCount > 0 {
                        Text("\(context.state.flaggedCount)")
                            .font(.headline)
                            .foregroundColor(.red)
                    } else {
                        Image(systemName: "checkmark")
                            .foregroundStyle(.green)
                    }
                }
            } compactLeading: {
                Image(systemName: "photo.on.rectangle.angled")
                    .foregroundStyle(.white)
            } compactTrailing: {
                Text("\(context.state.scannedCount)")
                    .font(.headline)
            } minimal: {
                Image(systemName: context.state.status == .scanning ? "arrow.triangle.2.circlepath" : "checkmark.seal.fill")
            }
        }
    }

    @ViewBuilder
    private func statusIcon(for state: VaultEyeAttributes.ContentState) -> some View {
        if state.status == .scanning {
            Image(systemName: "wave.3.right.circle.fill")
                .font(.title2)
                .foregroundStyle(LinearGradient(colors: [.mint, .blue], startPoint: .top, endPoint: .bottom))
        } else {
            Image(systemName: "checkmark.shield.fill")
                .font(.title2)
                .foregroundStyle(.green)
        }
    }
}

// MARK: - ScanningRing
@available(iOS 17.0, *)
private struct ScanningRing: View {
    var progress: Double
    var isActive: Bool

    @State private var animateGlow = false

    var body: some View {
        ZStack {
            Circle()
                .stroke(lineWidth: 10)
                .foregroundStyle(Color.white.opacity(0.12))

            Circle()
                .trim(from: 0, to: CGFloat(progress))
                .stroke(
                    AngularGradient(gradient: Gradient(colors: [Color.blue, Color.mint, Color.purple]), center: .center),
                    style: StrokeStyle(lineWidth: 10, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .shadow(color: Color.purple.opacity(0.25), radius: 6, x: 0, y: 4)

            if isActive {
                Circle()
                    .stroke(Color.mint.opacity(0.25), lineWidth: 6)
                    .scaleEffect(animateGlow ? 1.2 : 1.0)
                    .opacity(animateGlow ? 0.0 : 0.6)
                    .animation(Animation.easeOut(duration: 1.0).repeatForever(autoreverses: false), value: animateGlow)
                    .onAppear { animateGlow.toggle() }
            }

            Text("\(Int(progress * 100))%")
                .font(.caption).bold()
                .foregroundColor(.white)
        }
    }
}

// Preview for quick design checks (not used in extension runtime)
@available(iOS 17.0, *)
struct VaultEyeLiveActivity_Previews: PreviewProvider {
    static var previews: some View {
        // simple preview of scanning and complete states in Xcode canvas
        Group {
            ZStack {
                Color.black.ignoresSafeArea()
                VaultEyePreviewWrapper(progress: 0.42, scanned: 324, flagged: 2, category: "Credit Cards", status: .scanning)
                    .frame(width: 320, height: 200)
            }
            ZStack {
                Color.black.ignoresSafeArea()
                VaultEyePreviewWrapper(progress: 1.0, scanned: 482, flagged: 5, category: "Credit Cards", status: .complete)
                    .frame(width: 320, height: 200)
            }
        }
    }

    private struct VaultEyePreviewWrapper: View {
        let progress: Double
        let scanned: Int
        let flagged: Int
        let category: String
        let status: VaultEyeAttributes.ContentState.Status

        var body: some View {
            let attributes = VaultEyeAttributes(startedAt: Date())
            let content = VaultEyeAttributes.ContentState(progress: progress, scannedCount: scanned, flaggedCount: flagged, topCategory: category, status: status)
            ActivityPreview(attributes: attributes, contentState: content) {
                // reuse the ActivityConfiguration content by constructing it in-place is complicated;
                // Use a simplified view for preview here (design only).
                HStack {
                    ScanningRing(progress: progress, isActive: status == .scanning).frame(width: 60, height: 60)
                    VStack(alignment: .leading) {
                        Text(status == .scanning ? "Scanning…" : "Scan complete").bold()
                        Text("\(scanned) scanned • \(flagged) flagged")
                    }
                }
                .padding()
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
            }
        }
    }
}