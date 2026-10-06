import SwiftUI

extension TransactionKind {
    var color: Color {
        switch self {
        case .income: .green
        case .expense: .red
        }
    }
}

struct EntryRow: View {
    let entry: MoneyEntry
    var showsDate = false
    var showsSyncState = false

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: entry.category.symbol)
                .font(.body.weight(.semibold))
                .foregroundStyle(entry.kind.color)
                .frame(width: 36, height: 36)
                .background(entry.kind.color.opacity(0.15), in: Circle())

            VStack(alignment: .leading, spacing: 2) {
                Text(entry.note.isEmpty ? entry.category.title : entry.note)
                    .font(.body)
                    .lineLimit(1)
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 8)

            VStack(alignment: .trailing, spacing: 2) {
                Text((entry.kind == .income ? "+" : "−") + entry.amount.currencyText)
                    .font(.body.monospacedDigit().weight(.semibold))
                    .foregroundStyle(entry.kind.color)
                if showsSyncState && entry.needsNotionSync {
                    Label("Pendiente", systemImage: "arrow.triangle.2.circlepath")
                        .font(.caption2)
                        .foregroundStyle(.orange)
                }
            }
        }
        .accessibilityElement(children: .combine)
    }

    private var subtitle: String {
        var parts: [String] = []
        if !entry.note.isEmpty { parts.append(entry.category.title) }
        parts.append(entry.paymentMethod.title)
        if showsDate { parts.append(entry.date.formatted(.dateTime.day().month(.abbreviated))) }
        return parts.joined(separator: " · ")
    }
}

struct AddEntryMenu: View {
    let onAdd: (TransactionKind) -> Void

    var body: some View {
        Menu {
            Button { onAdd(.expense) } label: {
                Label("Nuevo egreso", systemImage: "minus.circle")
            }
            Button { onAdd(.income) } label: {
                Label("Nuevo ingreso", systemImage: "plus.circle")
            }
        } label: {
            Image(systemName: "plus.circle.fill")
                .font(.title2)
        } primaryAction: {
            onAdd(.expense)
        }
        .accessibilityLabel("Agregar movimiento")
    }
}
