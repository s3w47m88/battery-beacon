import WidgetKit
import SwiftUI

struct StatWidgetEntryView: View {
    let kind: StatKind
    let entry: SnapshotEntry

    var body: some View {
        SingleStatView(kind: kind, snapshot: entry.snapshot)
            .containerBackground(.fill.tertiary, for: .widget)
    }
}

struct PercentageWidget: Widget {
    let kind: StatKind = .percentage
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind.widgetKind, provider: SnapshotProvider()) { entry in
            StatWidgetEntryView(kind: kind, entry: entry)
        }
        .configurationDisplayName(kind.displayName)
        .description(kind.description)
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

struct TemperatureWidget: Widget {
    let kind: StatKind = .temperature
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind.widgetKind, provider: SnapshotProvider()) { entry in
            StatWidgetEntryView(kind: kind, entry: entry)
        }
        .configurationDisplayName(kind.displayName)
        .description(kind.description)
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

struct HealthPercentWidget: Widget {
    let kind: StatKind = .healthPercent
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind.widgetKind, provider: SnapshotProvider()) { entry in
            StatWidgetEntryView(kind: kind, entry: entry)
        }
        .configurationDisplayName(kind.displayName)
        .description(kind.description)
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

struct CycleCountWidget: Widget {
    let kind: StatKind = .cycleCount
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind.widgetKind, provider: SnapshotProvider()) { entry in
            StatWidgetEntryView(kind: kind, entry: entry)
        }
        .configurationDisplayName(kind.displayName)
        .description(kind.description)
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

struct TimeToFullWidget: Widget {
    let kind: StatKind = .timeToFull
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind.widgetKind, provider: SnapshotProvider()) { entry in
            StatWidgetEntryView(kind: kind, entry: entry)
        }
        .configurationDisplayName(kind.displayName)
        .description(kind.description)
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

struct TimeToEmptyWidget: Widget {
    let kind: StatKind = .timeToEmpty
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind.widgetKind, provider: SnapshotProvider()) { entry in
            StatWidgetEntryView(kind: kind, entry: entry)
        }
        .configurationDisplayName(kind.displayName)
        .description(kind.description)
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

struct MahRemainingWidget: Widget {
    let kind: StatKind = .mahRemaining
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind.widgetKind, provider: SnapshotProvider()) { entry in
            StatWidgetEntryView(kind: kind, entry: entry)
        }
        .configurationDisplayName(kind.displayName)
        .description(kind.description)
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

struct AgeWidget: Widget {
    let kind: StatKind = .age
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind.widgetKind, provider: SnapshotProvider()) { entry in
            StatWidgetEntryView(kind: kind, entry: entry)
        }
        .configurationDisplayName(kind.displayName)
        .description(kind.description)
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

struct ManufacturedDateWidget: Widget {
    let kind: StatKind = .manufacturedDate
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind.widgetKind, provider: SnapshotProvider()) { entry in
            StatWidgetEntryView(kind: kind, entry: entry)
        }
        .configurationDisplayName(kind.displayName)
        .description(kind.description)
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

struct MacOSHealthStatusWidget: Widget {
    let kind: StatKind = .macOSHealthStatus
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind.widgetKind, provider: SnapshotProvider()) { entry in
            StatWidgetEntryView(kind: kind, entry: entry)
        }
        .configurationDisplayName(kind.displayName)
        .description(kind.description)
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}
