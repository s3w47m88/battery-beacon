import WidgetKit
import Foundation

struct SnapshotEntry: TimelineEntry {
    let date: Date
    let snapshot: WidgetSnapshot
}

struct SnapshotProvider: TimelineProvider {
    func placeholder(in context: Context) -> SnapshotEntry {
        SnapshotEntry(date: Date(), snapshot: WidgetSnapshot(percentage: 75, temperatureCelsius: 32.5, currentCapacityMah: 4200, maxCapacityMah: 5200, designCapacityMah: 5800, ageYears: 1.4, manufacturedDate: Date(timeIntervalSinceNow: -60*60*24*500), timeToFullMinutes: 42, timeToEmptyMinutes: 320, macOSHealthStatus: "Normal", cycleCount: 120, healthPercent: 92))
    }

    func getSnapshot(in context: Context, completion: @escaping (SnapshotEntry) -> Void) {
        completion(SnapshotEntry(date: Date(), snapshot: WidgetSnapshotStore.read() ?? placeholder(in: context).snapshot))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<SnapshotEntry>) -> Void) {
        let entry = SnapshotEntry(date: Date(), snapshot: WidgetSnapshotStore.read() ?? placeholder(in: context).snapshot)
        let timeline = Timeline(entries: [entry], policy: .after(Date().addingTimeInterval(5 * 60)))
        completion(timeline)
    }
}
