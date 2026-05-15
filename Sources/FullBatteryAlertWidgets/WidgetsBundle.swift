import WidgetKit
import SwiftUI

@main
struct FullBatteryAlertWidgetsBundle: WidgetBundle {
    var body: some Widget {
        PercentageWidget()
        TemperatureWidget()
        HealthPercentWidget()
        CycleCountWidget()
        TimeToFullWidget()
        TimeToEmptyWidget()
        MahRemainingWidget()
        AgeWidget()
        ManufacturedDateWidget()
        MacOSHealthStatusWidget()
        AllStatsWidget()
        CustomWidget()
    }
}
