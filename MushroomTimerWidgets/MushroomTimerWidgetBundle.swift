import SwiftUI
import WidgetKit

@main
struct MushroomTimerWidgetBundle: WidgetBundle {
    var body: some Widget {
        EmptyWidget()
        MushroomLiveActivity()
    }
}

/// 第 0 階段驗證用：把從共享 keychain 讀到的內容直接畫出來。
/// Task 15 會換成真正的互動式小工具。
struct EmptyWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "Placeholder", provider: PlaceholderProvider()) { entry in
            VStack(alignment: .leading, spacing: 4) {
                Text(entry.payload.groupName.isEmpty ? "（無群組）" : entry.payload.groupName)
                    .font(.caption.bold())
                ForEach(entry.payload.mushrooms) { item in
                    Button(
                        intent: QuickLogIntent(
                            mushroomID: item.id.uuidString,
                            mushroomName: item.name
                        )
                    ) {
                        Text(item.name).font(.caption2)
                    }
                    .buttonStyle(.bordered)
                }
                if entry.payload.mushrooms.isEmpty {
                    Text("讀不到 payload").font(.caption2).foregroundStyle(.secondary)
                }
            }
            .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("打菇茜")
        .description("快速登記一顆菇。")
        .supportedFamilies([.systemSmall])
    }
}

struct PlaceholderEntry: TimelineEntry {
    let date: Date
    let payload: WidgetPayload
}

struct PlaceholderProvider: TimelineProvider {
    private func currentEntry() -> PlaceholderEntry {
        PlaceholderEntry(date: .now, payload: SharedKeychain.load() ?? .empty)
    }

    func placeholder(in context: Context) -> PlaceholderEntry {
        PlaceholderEntry(date: .now, payload: .empty)
    }

    func getSnapshot(in context: Context, completion: @escaping (PlaceholderEntry) -> Void) {
        completion(currentEntry())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<PlaceholderEntry>) -> Void) {
        completion(Timeline(entries: [currentEntry()], policy: .never))
    }
}
