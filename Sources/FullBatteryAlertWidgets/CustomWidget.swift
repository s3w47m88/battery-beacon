import WidgetKit
import SwiftUI
import AppIntents

struct CustomEntry: TimelineEntry {
    let date: Date
    let snapshot: WidgetSnapshot
    let configuration: CustomWidgetIntent
}

struct CustomProvider: AppIntentTimelineProvider {
    private var fallback: WidgetSnapshot {
        WidgetSnapshot(percentage: 75, temperatureCelsius: 32.5, currentCapacityMah: 4200, maxCapacityMah: 5200, designCapacityMah: 5800, ageYears: 1.4, manufacturedDate: Date(timeIntervalSinceNow: -60*60*24*500), timeToFullMinutes: 42, timeToEmptyMinutes: 320, macOSHealthStatus: "Normal", cycleCount: 120, healthPercent: 92)
    }

    func placeholder(in context: Context) -> CustomEntry {
        CustomEntry(date: Date(), snapshot: fallback, configuration: CustomWidgetIntent())
    }

    func snapshot(for configuration: CustomWidgetIntent, in context: Context) async -> CustomEntry {
        CustomEntry(date: Date(), snapshot: WidgetSnapshotStore.read() ?? fallback, configuration: configuration)
    }

    func timeline(for configuration: CustomWidgetIntent, in context: Context) async -> Timeline<CustomEntry> {
        let entry = CustomEntry(date: Date(), snapshot: WidgetSnapshotStore.read() ?? fallback, configuration: configuration)
        return Timeline(entries: [entry], policy: .after(Date().addingTimeInterval(5 * 60)))
    }
}

struct CustomWidgetEntryView: View {
    @Environment(\.widgetFamily) var family
    let entry: CustomEntry

    var slotCount: Int {
        switch family {
        case .systemSmall: return 4
        case .systemMedium: return 6
        case .systemLarge: return 9
        default: return 4
        }
    }

    var columns: Int {
        switch family {
        case .systemSmall: return 2
        case .systemMedium: return 3
        case .systemLarge: return 3
        default: return 2
        }
    }

    var body: some View {
        let kinds = Array(entry.configuration.allStats.prefix(slotCount))
        StatsGridView(kinds: kinds, snapshot: entry.snapshot, columns: columns)
            .containerBackground(.fill.tertiary, for: .widget)
    }
}

struct CustomWidget: Widget {
    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: "FBA.custom", intent: CustomWidgetIntent.self, provider: CustomProvider()) { entry in
            CustomWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("Custom Battery Stats")
        .description("Choose which stats to show.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}
