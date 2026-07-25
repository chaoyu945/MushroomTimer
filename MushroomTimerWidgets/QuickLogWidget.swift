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
        .description("按一下常用的菇，直接以「剛爆」建立提醒。")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

struct QuickLogEntry: TimelineEntry {
    let date: Date
    let payload: WidgetPayload
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
        let entry = QuickLogEntry(date: .now, payload: SharedKeychain.load() ?? .empty)
        // 內容只有在主 App 呼叫 reloadAllTimelines() 時才會變，不需要定時刷新。
        completion(Timeline(entries: [entry], policy: .never))
    }
}

struct QuickLogWidgetView: View {
    let payload: WidgetPayload

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(payload.groupName.isEmpty ? "打菇茜" : payload.groupName)
                .font(.caption.bold())
                .foregroundStyle(.secondary)

            if payload.mushrooms.isEmpty {
                Text("開啟打菇茜建立群組與菇")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(payload.mushrooms) { item in
                    Button(
                        intent: QuickLogIntent(
                            mushroomID: item.id.uuidString,
                            mushroomName: item.name
                        )
                    ) {
                        Text(item.name)
                            .font(.footnote.bold())
                            .lineLimit(1)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
            Spacer(minLength: 0)
        }
    }
}
