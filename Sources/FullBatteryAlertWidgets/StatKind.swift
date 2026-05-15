import Foundation
import SwiftUI

enum StatKind: String, CaseIterable, Identifiable, Codable {
    case percentage
    case temperature
    case healthPercent
    case cycleCount
    case timeToFull
    case timeToEmpty
    case mahRemaining
    case age
    case manufacturedDate
    case macOSHealthStatus

    var id: String { rawValue }

    var title: String {
        switch self {
        case .percentage: return "Charge"
        case .temperature: return "Temperature"
        case .healthPercent: return "Health"
        case .cycleCount: return "Cycles"
        case .timeToFull: return "To Full"
        case .timeToEmpty: return "To Empty"
        case .mahRemaining: return "mAh Left"
        case .age: return "Age"
        case .manufacturedDate: return "Made"
        case .macOSHealthStatus: return "Status"
        }
    }

    var systemImage: String {
        switch self {
        case .percentage: return "battery.100"
        case .temperature: return "thermometer.medium"
        case .healthPercent: return "heart.fill"
        case .cycleCount: return "arrow.triangle.2.circlepath"
        case .timeToFull: return "bolt.fill"
        case .timeToEmpty: return "hourglass"
        case .mahRemaining: return "bolt.batteryblock"
        case .age: return "calendar"
        case .manufacturedDate: return "calendar.badge.clock"
        case .macOSHealthStatus: return "checkmark.seal"
        }
    }

    func value(from s: WidgetSnapshot) -> String {
        switch self {
        case .percentage:
            return "\(s.percentage)%"
        case .temperature:
            if let t = s.temperatureCelsius { return String(format: "%.1f°C", t) }
            return "—"
        case .healthPercent:
            if let h = s.healthPercent { return String(format: "%.0f%%", h) }
            return "—"
        case .cycleCount:
            if let c = s.cycleCount { return "\(c)" }
            return "—"
        case .timeToFull:
            return Self.formatMinutes(s.timeToFullMinutes)
        case .timeToEmpty:
            return Self.formatMinutes(s.timeToEmptyMinutes)
        case .mahRemaining:
            if let m = s.currentCapacityMah { return "\(m)" }
            return "—"
        case .age:
            if let a = s.ageYears { return String(format: "%.1fy", a) }
            return "—"
        case .manufacturedDate:
            if let d = s.manufacturedDate {
                let f = DateFormatter()
                f.dateFormat = "MMM yyyy"
                return f.string(from: d)
            }
            return "—"
        case .macOSHealthStatus:
            return s.macOSHealthStatus ?? "—"
        }
    }

    static func formatMinutes(_ minutes: Int?) -> String {
        guard let m = minutes, m > 0 else { return "—" }
        let h = m / 60
        let mm = m % 60
        if h > 0 { return "\(h)h \(mm)m" }
        return "\(mm)m"
    }

    var widgetKind: String { "FBA.stat.\(rawValue)" }
    var displayName: String { title }
    var description: String { "Shows \(title.lowercased()) from your Mac's battery." }
}
