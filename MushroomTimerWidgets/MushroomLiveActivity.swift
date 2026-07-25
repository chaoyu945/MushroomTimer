import ActivityKit
import SwiftUI
import WidgetKit

/// 鎖定畫面與動態島的 Live Activity 版面。
/// 倒數一律用 `Text(timerInterval:)`：給定結束時間後元件自己逐秒跑動，
/// 不需要任何背景作業，也因此完全不需要讀取主 App 的資料庫。
struct MushroomLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: MushroomActivityAttributes.self) { context in
            lockScreenView(context.state)
                .padding()
                .activityBackgroundTint(.black.opacity(0.6))
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Image(systemName: "circle.hexagongrid.fill")
                        .font(.title2)
                        .foregroundStyle(.orange)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    countdown(to: context.state.fireAt)
                        .font(.title2.monospacedDigit().bold())
                }
                DynamicIslandExpandedRegion(.bottom) {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(context.state.mushroomName)
                                .font(.headline)
                            Text(context.state.groupName)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        if let label = context.state.queueLabel {
                            Text(label)
                                .font(.caption.bold())
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(.quaternary, in: Capsule())
                        }
                    }
                }
            } compactLeading: {
                Image(systemName: "circle.hexagongrid.fill")
                    .foregroundStyle(.orange)
            } compactTrailing: {
                countdown(to: context.state.fireAt)
                    .font(.caption.monospacedDigit())
                    .frame(width: 44)
            } minimal: {
                countdown(to: context.state.fireAt)
                    .font(.caption2.monospacedDigit())
                    .frame(width: 36)
            }
        }
    }

    private func lockScreenView(
        _ state: MushroomActivityAttributes.ContentState
    ) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(state.mushroomName)
                    .font(.title3.bold())
                Text(state.groupName)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 4) {
                countdown(to: state.fireAt)
                    .font(.largeTitle.monospacedDigit().bold())
                if let label = state.queueLabel {
                    Text("還有 \(label)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private func countdown(to date: Date) -> some View {
        Text(timerInterval: Date.now...date, countsDown: true)
            .multilineTextAlignment(.trailing)
    }
}
