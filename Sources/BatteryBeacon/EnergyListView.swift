import SwiftUI
import AppKit

enum EnergyRowAction {
    case drillIn
    case help
    case forceQuit
}

struct EnergyListView: View {
    @ObservedObject var monitor: EnergyMonitor
    var onAction: (AppEnergy, EnergyRowAction) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            if monitor.topApps.isEmpty {
                Text("No Apps Using Significant Energy")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            } else {
                Text("Using Significant Energy")
                    .font(.subheadline.weight(.semibold))
                ForEach(monitor.topApps) { app in
                    EnergyRow(app: app, onAction: { onAction(app, $0) })
                }
            }
        }
    }
}

private struct EnergyRow: View {
    let app: AppEnergy
    let onAction: (EnergyRowAction) -> Void

    var body: some View {
        HStack(spacing: 6) {
            Button { onAction(.drillIn) } label: {
                HStack(spacing: 8) {
                    iconView
                        .frame(width: 18, height: 18)
                    Text(app.displayName)
                        .font(.callout)
                        .lineLimit(1)
                        .truncationMode(.tail)
                        .foregroundStyle(.primary)
                    Spacer(minLength: 4)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            Button { onAction(.help) } label: {
                Image(systemName: "questionmark.circle")
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.borderless)
            .help("What is \(app.displayName)?")

            Button { onAction(.forceQuit) } label: {
                Image(systemName: "xmark.circle")
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.borderless)
            .help("Force quit \(app.displayName)")

            Text(badgeText)
                .font(.caption)
                .foregroundStyle(.secondary)
                .monospacedDigit()
                .frame(minWidth: 36, alignment: .trailing)

            Button { onAction(.drillIn) } label: {
                Image(systemName: "chevron.right")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
            .buttonStyle(.plain)
            .help("Show details for \(app.displayName)")
        }
    }

    @ViewBuilder
    private var iconView: some View {
        if let icon = app.icon {
            Image(nsImage: icon)
                .resizable()
                .interpolation(.high)
        } else {
            Image(systemName: "app.dashed")
                .foregroundStyle(.secondary)
        }
    }

    private var badgeText: String {
        switch app.powerImpact {
        case 50...: return "High"
        case 10..<50: return "Medium"
        default: return String(format: "%.0f", app.powerImpact)
        }
    }
}
