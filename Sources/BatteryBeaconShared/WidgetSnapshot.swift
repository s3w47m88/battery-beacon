import Foundation

public struct WidgetSnapshot: Codable, Equatable {
    public var percentage: Int
    public var temperatureCelsius: Double?
    public var currentCapacityMah: Int?
    public var maxCapacityMah: Int?
    public var designCapacityMah: Int?
    public var ageYears: Double?
    public var manufacturedDate: Date?
    public var timeToFullMinutes: Int?
    public var timeToEmptyMinutes: Int?
    public var macOSHealthStatus: String?
    public var cycleCount: Int?
    public var healthPercent: Double?
    public var updatedAt: Date

    public init(
        percentage: Int = 0,
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
        healthPercent: Double? = nil,
        updatedAt: Date = Date()
    ) {
        self.percentage = percentage
        self.temperatureCelsius = temperatureCelsius
        self.currentCapacityMah = currentCapacityMah
        self.maxCapacityMah = maxCapacityMah
        self.designCapacityMah = designCapacityMah
        self.ageYears = ageYears
        self.manufacturedDate = manufacturedDate
        self.timeToFullMinutes = timeToFullMinutes
        self.timeToEmptyMinutes = timeToEmptyMinutes
        self.macOSHealthStatus = macOSHealthStatus
        self.cycleCount = cycleCount
        self.healthPercent = healthPercent
        self.updatedAt = updatedAt
    }
}

public enum WidgetSnapshotStore {
    public static let appGroupID = "group.com.spencerhill.batterybeacon"
    public static let key = "WidgetSnapshot.v1"

    public static var defaults: UserDefaults? {
        UserDefaults(suiteName: appGroupID)
    }

    public static func read() -> WidgetSnapshot? {
        guard let data = defaults?.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(WidgetSnapshot.self, from: data)
    }

    public static func write(_ snapshot: WidgetSnapshot) {
        guard let data = try? JSONEncoder().encode(snapshot) else { return }
        defaults?.set(data, forKey: key)
    }
}
