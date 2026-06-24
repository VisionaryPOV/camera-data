import WidgetKit
import SwiftUI

struct TakeCountEntry: TimelineEntry {
    let date: Date
    let takeCount: Int
    let productionName: String
}

struct TakeCountProvider: TimelineProvider {
    func placeholder(in context: Context) -> TakeCountEntry {
        TakeCountEntry(date: .now, takeCount: 12, productionName: "Production")
    }

    func getSnapshot(in context: Context, completion: @escaping (TakeCountEntry) -> Void) {
        completion(TakeCountEntry(date: .now, takeCount: 12, productionName: "Production"))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<TakeCountEntry>) -> Void) {
        let entry = TakeCountEntry(date: .now, takeCount: 0, productionName: "Camera Data")
        completion(Timeline(entries: [entry], policy: .after(.now.addingTimeInterval(900))))
    }
}

struct TakeCountWidgetView: View {
    let entry: TakeCountEntry

    var body: some View {
        VStack(alignment: .leading) {
            Text(entry.productionName)
                .font(.caption)
            Text("\(entry.takeCount)")
                .font(.largeTitle.bold())
            Text("Takes Today")
                .font(.caption2)
        }
        .containerBackground(.fill.tertiary, for: .widget)
    }
}

@main
struct CameraDataWidget: Widget {
    let kind = "CameraDataWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: TakeCountProvider()) { entry in
            TakeCountWidgetView(entry: entry)
        }
        .configurationDisplayName("Take Count")
        .description("Shows today's logged take count.")
        .supportedFamilies([.systemSmall, .accessoryRectangular])
    }
}