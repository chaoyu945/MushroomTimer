import SwiftData
import SwiftUI

/// `@Query` 的 filter 是屬性初始化式，不能引用型別自己的 static 成員，所以放在檔案層級。
private let activeStatusRaw = TimerStatus.active.rawValue

/// 主畫面上半部：進行中的計時，依 fireAt 由近到遠。
struct ActiveTimersSection: View {
    @Environment(\.modelContext) private var context

    @Query(
        filter: #Predicate<TimerEntry> { $0.statusRaw == activeStatusRaw },
        sort: \TimerEntry.fireAt,
        order: .forward
    )
    private var timers: [TimerEntry]

    var body: some View {
        Group {
            if timers.isEmpty {
                ContentUnavailableView(
                    "沒有進行中的提醒",
                    systemImage: "timer",
                    description: Text("在下方選一顆菇，輸入眼睛看到的剩餘時間就好。")
                )
                .frame(maxHeight: .infinity)
            } else {
                List {
                    ForEach(timers) { timer in
                        row(for: timer)
                            .swipeActions(edge: .leading) {
                                Button("取消", role: .destructive) {
                                    try? MushroomLogger.cancel(timer, context: context)
                                }
                            }
                    }
                }
                .listStyle(.plain)
            }
        }
    }

    private func row(for timer: TimerEntry) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(timer.mushroom?.name ?? "（已刪除的菇）")
                    .font(.headline)
                Text(timer.mushroom?.group?.name ?? "")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            // 給定結束時間後元件自己逐秒跑動，不需要任何背景作業。
            // 範圍必須夾住：到期後這個 row 仍會被重新求值，
            // 而 lowerBound > upperBound 的 ClosedRange 會直接 trap。
            countdown(to: timer.fireAt)
                .font(.system(.title, design: .rounded).monospacedDigit().bold())
                .foregroundStyle(.orange)
        }
        .padding(.vertical, 4)
    }

    private func countdown(to date: Date) -> some View {
        let now = Date.now
        return Text(timerInterval: min(now, date)...max(now, date), countsDown: true)
    }
}
