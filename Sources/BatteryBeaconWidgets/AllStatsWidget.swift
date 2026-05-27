import WidgetKit
import SwiftUI

struct AllStatsWidgetEntryView: View {
    @Environment(\.widgetFamily) var family
    let entry: SnapshotEntry

    var body: some View {
        let columns = family == .systemLarge ? 3 : 3
        StatsGridView(kinds: StatKind.allCases, snapshot: entry.snapshot, columns: columns)
            .containerBackground(.fill.tertiary, for: .widget)
    }
}

struct AllStatsWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "FBA.all", provider: SnapshotProvider()) { entry in
            AllStatsWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("All Battery Stats")
        .description("Every battery metric in one widget.")
        .supportedFamilies([.systemMedium, .systemLarge])
    }
}
