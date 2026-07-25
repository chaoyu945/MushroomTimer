import SwiftUI
import WidgetKit

@main
struct MushroomTimerWidgetBundle: WidgetBundle {
    var body: some Widget {
        EmptyWidget()
    }
}

/// 佔位用，Task 15 會換成真正的互動式小工具。
struct EmptyWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "Placeholder", provider: PlaceholderProvider()) { _ in
            Text("打菇茜")
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("打菇茜")
        .description("快速登記一顆菇。")
        .supportedFamilies([.systemSmall])
    }
}

struct PlaceholderEntry: TimelineEntry {
    let date: Date
}

struct PlaceholderProvider: TimelineProvider {
    func placeholder(in context: Context) -> PlaceholderEntry {
        PlaceholderEntry(date: .now)
    }

    func getSnapshot(in context: Context, completion: @escaping (PlaceholderEntry) -> Void) {
        completion(PlaceholderEntry(date: .now))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<PlaceholderEntry>) -> Void) {
        completion(Timeline(entries: [PlaceholderEntry(date: .now)], policy: .never))
    }
}
