import SwiftUI
import WidgetKit

struct StatTile: View {
    let kind: StatKind
    let snapshot: WidgetSnapshot
    var compact: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 4) {
                Image(systemName: kind.systemImage)
                    .font(.system(size: compact ? 9 : 11, weight: .semibold))
                    .foregroundStyle(.secondary)
                Text(kind.title)
                    .font(.system(size: compact ? 9 : 10, weight: .medium))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Text(kind.value(from: snapshot))
                .font(.system(size: compact ? 13 : 16, weight: .semibold, design: .rounded))
                .lineLimit(1)
                .minimumScaleFactor(0.6)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .padding(compact ? 6 : 8)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(.quaternary.opacity(0.5))
        )
    }
}

struct SingleStatView: View {
    let kind: StatKind
    let snapshot: WidgetSnapshot

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Image(systemName: kind.systemImage)
                    .foregroundStyle(.secondary)
                Text(kind.title)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
            Text(kind.value(from: snapshot))
                .font(.system(size: 34, weight: .bold, design: .rounded))
                .minimumScaleFactor(0.5)
                .lineLimit(1)
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .padding(12)
    }
}

struct StatsGridView: View {
    let kinds: [StatKind]
    let snapshot: WidgetSnapshot
    let columns: Int

    var body: some View {
        let cols = Array(repeating: GridItem(.flexible(), spacing: 6), count: columns)
        LazyVGrid(columns: cols, spacing: 6) {
            ForEach(kinds) { kind in
                StatTile(kind: kind, snapshot: snapshot, compact: kinds.count > 6)
            }
        }
        .padding(8)
    }
}
