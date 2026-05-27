import WidgetKit
import SwiftUI

@main
struct BatteryBeaconWidgetsBundle: WidgetBundle {
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
