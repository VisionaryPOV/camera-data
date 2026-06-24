import WidgetKit
import SwiftUI
import CameraDataDomain

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
        let snapshot = readSnapshot()
        completion(TakeCountEntry(date: .now, takeCount: snapshot.takeCount, productionName: snapshot.productionName))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<TakeCountEntry>) -> Void) {
        let snapshot = readSnapshot()
        let entry = TakeCountEntry(date: .now, takeCount: snapshot.takeCount, productionName: snapshot.productionName)
        completion(Timeline(entries: [entry], policy: .after(.now.addingTimeInterval(900))))
    }

    private func readSnapshot() -> (takeCount: Int, productionName: String) {
        AppGroupStore.readWidgetSnapshot()
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