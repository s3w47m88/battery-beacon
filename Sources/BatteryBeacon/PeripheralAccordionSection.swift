import SwiftUI

struct PeripheralAccordionSection: View {
    @ObservedObject var monitor: PeripheralBatteryMonitor

    var body: some View {
        AccordionSection(id: "peripherals", title: "Other Devices") {
            if monitor.devices.isEmpty {
                Text("No connected devices reporting battery.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            } else {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(monitor.devices) { device in
                        PeripheralRow(device: device)
                    }
                }
            }
        }
    }
}

private struct PeripheralRow: View {
    let device: PeripheralDevice

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: device.kind.sfSymbol)
                .frame(width: 18)
                .foregroundStyle(.secondary)
            Text(device.name)
                .lineLimit(1)
                .truncationMode(.tail)
            Spacer()
            if device.isCharging {
                Image(systemName: "bolt.fill")
                    .font(.caption)
                    .foregroundStyle(.yellow)
            }
            Text("\(device.percent)%")
                .monospacedDigit()
                .foregroundStyle(color(for: device.percent))
        }
        .font(.callout)
    }

    private func color(for pct: Int) -> Color {
        if pct <= 10 { return .red }
        if pct <= 20 { return .yellow }
        return .secondary
    }
}
