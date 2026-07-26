import SwiftUI
import WidgetKit

/// 互動式桌面小工具：按一下就以「剛爆」建立計時，不需要開啟 App。
///
/// 小工具本身不做任何資料查詢——它讀的是主 App 寫進共享 keychain 的 payload。
struct QuickLogWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "QuickLogWidget", provider: QuickLogProvider()) { entry in
            QuickLogWidgetView(payload: entry.payload)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("快速登記")
        .description("按一下常用的菇，直接以「剛爆」建立提醒。要指定剩餘時間請用「登記一顆菇」捷徑。")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}

struct QuickLogEntry: TimelineEntry {
    let date: Date
    /// nil 代表「讀不到共享 keychain」，跟「讀得到但還沒建立任何菇」是兩回事。
    /// 兩者顯示同一句話的話，通道壞掉時使用者只會以為自己還沒設定。
    let payload: WidgetPayload?
}

struct QuickLogProvider: TimelineProvider {
    private static let sample = WidgetPayload(
        groupName: "中山路口",
        mushrooms: [
            .init(id: UUID(), name: "7-11 門口"),
            .init(id: UUID(), name: "天橋下")
        ]
    )

    func placeholder(in context: Context) -> QuickLogEntry {
        QuickLogEntry(date: .now, payload: Self.sample)
    }

    func getSnapshot(in context: Context, completion: @escaping (QuickLogEntry) -> Void) {
        completion(QuickLogEntry(date: .now, payload: SharedKeychain.load() ?? Self.sample))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<QuickLogEntry>) -> Void) {
        let entry = QuickLogEntry(date: .now, payload: SharedKeychain.load())
        // 內容只有在主 App 呼叫 reloadAllTimelines() 時才會變，不需要定時刷新。
        completion(Timeline(entries: [entry], policy: .never))
    }
}

struct QuickLogWidgetView: View {
    @Environment(\.widgetFamily) private var family

    let payload: WidgetPayload?

    /// 一列放幾顆、總共放幾顆，由尺寸決定。
    /// 一個地點常有二十顆以上的菇，只露出三顆會讓人乾脆不用小工具。
    private var columns: Int {
        switch family {
        case .systemLarge: return 3
        case .systemMedium: return 3
        default: return 1
        }
    }

    private var visibleCount: Int {
        switch family {
        case .systemLarge: return 12
        case .systemMedium: return 6
        default: return 3
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(payload?.groupName.isEmpty == false ? payload!.groupName : "打菇茜")
                .font(.caption.bold())
                .foregroundStyle(.secondary)

            if let payload {
                content(for: payload)
            } else {
                Text("讀不到資料，請開啟一次打菇茜")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
    }

    @ViewBuilder
    private func content(for payload: WidgetPayload) -> some View {
        Group {
            if payload.mushrooms.isEmpty {
                Text("開啟打菇茜建立群組與菇")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            } else {
                LazyVGrid(
                    columns: Array(
                        repeating: GridItem(.flexible(), spacing: 4), count: columns
                    ),
                    spacing: 4
                ) {
                    ForEach(payload.mushrooms.prefix(visibleCount)) { item in
                        Button(
                            intent: QuickLogIntent(
                                mushroomID: item.id.uuidString,
                                mushroomName: item.name
                            )
                        ) {
                            Text(item.name)
                                .font(.caption2.bold())
                                .lineLimit(2)
                                .minimumScaleFactor(0.6)
                                .frame(maxWidth: .infinity, minHeight: 28)
                        }
                        .buttonStyle(.borderedProminent)
                    }
                }
            }
            Spacer(minLength: 0)
        }
    }
}
