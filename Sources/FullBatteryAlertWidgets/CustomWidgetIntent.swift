import AppIntents
import WidgetKit

enum StatKindEntity: String, AppEnum {
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

    static var typeDisplayRepresentation: TypeDisplayRepresentation { "Battery Stat" }
    static var caseDisplayRepresentations: [StatKindEntity: DisplayRepresentation] = [
        .percentage: "Charge %",
        .temperature: "Temperature",
        .healthPercent: "Health %",
        .cycleCount: "Cycle Count",
        .timeToFull: "Time To Full",
        .timeToEmpty: "Time To Empty",
        .mahRemaining: "mAh Remaining",
        .age: "Age",
        .manufacturedDate: "Manufactured Date",
        .macOSHealthStatus: "macOS Health Status",
    ]

    var kind: StatKind { StatKind(rawValue: rawValue) ?? .percentage }
}

struct CustomWidgetIntent: WidgetConfigurationIntent {
    static var title: LocalizedStringResource = "Customize Stats"
    static var description = IntentDescription("Pick which battery stats to display.")

    @Parameter(title: "Stat 1", default: .percentage)
    var stat1: StatKindEntity
    @Parameter(title: "Stat 2", default: .healthPercent)
    var stat2: StatKindEntity
    @Parameter(title: "Stat 3", default: .cycleCount)
    var stat3: StatKindEntity
    @Parameter(title: "Stat 4", default: .temperature)
    var stat4: StatKindEntity
    @Parameter(title: "Stat 5", default: .timeToFull)
    var stat5: StatKindEntity
    @Parameter(title: "Stat 6", default: .timeToEmpty)
    var stat6: StatKindEntity
    @Parameter(title: "Stat 7", default: .mahRemaining)
    var stat7: StatKindEntity
    @Parameter(title: "Stat 8", default: .age)
    var stat8: StatKindEntity
    @Parameter(title: "Stat 9", default: .macOSHealthStatus)
    var stat9: StatKindEntity

    var allStats: [StatKind] {
        [stat1, stat2, stat3, stat4, stat5, stat6, stat7, stat8, stat9].map { $0.kind }
    }
}
