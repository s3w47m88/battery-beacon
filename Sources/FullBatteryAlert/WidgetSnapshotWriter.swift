import Foundation
#if canImport(WidgetKit)
import WidgetKit
#endif

enum WidgetSnapshotWriter {
    static func write(
        percentage: Int,
        temperatureCelsius: Double? = nil,
        currentCapacityMah: Int? = nil,
        maxCapacityMah: Int? = nil,
        designCapacityMah: Int? = nil,
        ageYears: Double? = nil,
        manufacturedDate: Date? = nil,
        timeToFullMinutes: Int? = nil,
        timeToEmptyMinutes: Int? = nil,
        macOSHealthStatus: String? = nil,
        cycleCount: Int? = nil,
        healthPercent: Double? = nil
    ) {
        let snapshot = WidgetSnapshot(
            percentage: percentage,
            temperatureCelsius: temperatureCelsius,
            currentCapacityMah: currentCapacityMah,
            maxCapacityMah: maxCapacityMah,
            designCapacityMah: designCapacityMah,
            ageYears: ageYears,
            manufacturedDate: manufacturedDate,
            timeToFullMinutes: timeToFullMinutes,
            timeToEmptyMinutes: timeToEmptyMinutes,
            macOSHealthStatus: macOSHealthStatus,
            cycleCount: cycleCount,
            healthPercent: healthPercent
        )
        WidgetSnapshotStore.write(snapshot)
        #if canImport(WidgetKit)
        if #available(macOS 14.0, *) {
            WidgetCenter.shared.reloadAllTimelines()
        }
        #endif
    }
}
