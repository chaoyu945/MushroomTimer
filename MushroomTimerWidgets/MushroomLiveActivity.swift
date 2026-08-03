import ActivityKit
import SwiftUI
import WidgetKit

/// 鎖定畫面與動態島的 Live Activity 版面。
/// 倒數一律用 `Text(timerInterval:)`：給定結束時間後元件自己逐秒跑動，
/// 不需要任何背景作業，也因此完全不需要讀取主 App 的資料庫。
struct MushroomLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: MushroomActivityAttributes.self) { context in
            lockScreenView(context.state, isStale: context.isStale)
                .padding()
                .activityBackgroundTint(.black.opacity(0.6))
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    // emoji 自帶顏色，所以不要加 foregroundStyle——那會是個沒有作用的修飾詞。
                    Text("🍄")
                        .font(.title2)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    if context.isStale {
                        Text("已到期")
                            .font(.headline)
                            .foregroundStyle(.orange)
                    } else {
                        countdown(to: context.state.respawnAt)
                            .font(.title2.monospacedDigit().bold())
                    }
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
                Text("🍄")
            } compactTrailing: {
                if context.isStale {
                    Image(systemName: "exclamationmark.circle.fill")
                        .foregroundStyle(.orange)
                } else {
                    countdown(to: context.state.respawnAt)
                        .font(.caption.monospacedDigit())
                        .frame(width: 44)
                }
            } minimal: {
                if context.isStale {
                    Image(systemName: "exclamationmark.circle.fill")
                        .foregroundStyle(.orange)
                } else {
                    countdown(to: context.state.respawnAt)
                        .font(.caption2.monospacedDigit())
                        .frame(width: 36)
                }
            }
        }
    }

    private func lockScreenView(
        _ state: MushroomActivityAttributes.ContentState,
        isStale: Bool
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
                if isStale {
                    // 免費帳號沒有遠端推播，App 沒在執行時這張卡片沒辦法自己
                    // 換成下一筆。與其停在 0:00 裝作還在倒數，不如講實話。
                    Text("已到期")
                        .font(.title2.bold())
                        .foregroundStyle(.orange)
                    Text(state.nextMushroomName == nil ? "開啟打菇茜" : "開啟看下一個")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    countdown(to: state.respawnAt)
                        .font(.largeTitle.monospacedDigit().bold())
                    if let label = state.queueLabel {
                        Text("還有 \(label)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }

    private func countdown(to date: Date) -> some View {
        // `Text(timerInterval:)` 吃的是 ClosedRange，lowerBound > upperBound 會直接 trap。
        // 提醒時間過了之後這個 view 仍可能被重新求值（extension 重啟、狀態切換），
        // 所以一定要夾住範圍，不能直接寫 Date.now...date。
        let now = Date.now
        return Text(timerInterval: min(now, date)...max(now, date), countsDown: true)
            .multilineTextAlignment(.trailing)
    }
}
