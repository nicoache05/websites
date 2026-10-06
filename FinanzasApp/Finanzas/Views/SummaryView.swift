import Charts
import SwiftData
import SwiftUI

struct SummaryView: View {
    let onAdd: (TransactionKind) -> Void

    @Query(sort: \MoneyEntry.date, order: .reverse) private var entries: [MoneyEntry]
    @State private var weekOffset = 0
    @State private var editingEntry: MoneyEntry?

    private var calendar: Calendar { .finance }

    private var interval: DateInterval {
        let reference = calendar.date(byAdding: .weekOfYear, value: weekOffset, to: Date()) ?? Date()
        return calendar.weekInterval(containing: reference)
    }

    private var weekEntries: [MoneyEntry] {
        entries.filter { interval.containsExcludingEnd($0.date) }
    }

    private var summary: WeekSummary {
        WeekSummary(interval: interval, records: weekEntries.map(\.record))
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    weekSelector
                    BalanceCard(summary: summary)
                }
                .listRowSeparator(.hidden)

                if weekEntries.isEmpty {
                    ContentUnavailableView {
                        Label("Sin movimientos", systemImage: "tray")
                    } description: {
                        Text("Registra tus ingresos y egresos de esta semana.")
                    } actions: {
                        Button("Agregar egreso") { onAdd(.expense) }
                            .buttonStyle(.borderedProminent)
                    }
                } else {
                    breakdownSection(for: .expense)
                    breakdownSection(for: .income)
                    paymentMethodSection

                    Section("Movimientos de la semana") {
                        ForEach(weekEntries) { entry in
                            Button { editingEntry = entry } label: {
                                EntryRow(entry: entry, showsDate: true)
                            }
                            .tint(.primary)
                        }
                    }
                }
            }
            .navigationTitle("Resumen")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    AddEntryMenu(onAdd: onAdd)
                }
            }
            .sheet(item: $editingEntry) { entry in
                EntryFormView(entry: entry)
            }
        }
    }

    private var weekSelector: some View {
        HStack {
            Button { weekOffset -= 1 } label: {
                Image(systemName: "chevron.left")
            }
            .accessibilityLabel("Semana anterior")

            Spacer()

            VStack(spacing: 2) {
                Text(weekOffset == 0 ? "Esta semana" : weekOffset == -1 ? "Semana pasada" : "Semana")
                    .font(.headline)
                Text(interval.weekLabel)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button { weekOffset += 1 } label: {
                Image(systemName: "chevron.right")
            }
            .disabled(weekOffset >= 0)
            .accessibilityLabel("Semana siguiente")
        }
        .buttonStyle(.borderless)
        .font(.title3)
    }

    @ViewBuilder
    private func breakdownSection(for kind: TransactionKind) -> some View {
        let totals = Dictionary(grouping: weekEntries.filter { $0.kind == kind }, by: \.category)
            .map { CategoryTotal(category: $0.key, total: $0.value.reduce(0) { $0 + $1.amount }) }
            .sorted { $0.total > $1.total }

        if !totals.isEmpty {
            Section("\(kind.pluralTitle) por tipo") {
                Chart(totals) { item in
                    BarMark(
                        x: .value("Monto", item.total),
                        y: .value("Tipo", item.category.title)
                    )
                    .foregroundStyle(kind.color.gradient)
                    .cornerRadius(4)
                }
                .chartXAxis(.hidden)
                .frame(height: CGFloat(totals.count) * 34 + 10)

                ForEach(totals) { item in
                    LabeledContent {
                        Text(item.total.currencyText).monospacedDigit()
                    } label: {
                        Label(item.category.title, systemImage: item.category.symbol)
                    }
                }
            }
        }
    }

    private var paymentMethodSection: some View {
        let totals = Dictionary(grouping: weekEntries, by: \.paymentMethod)
            .map { group in
                PaymentTotal(
                    method: group.key,
                    income: group.value.filter { $0.kind == .income }.reduce(0) { $0 + $1.amount },
                    expense: group.value.filter { $0.kind == .expense }.reduce(0) { $0 + $1.amount }
                )
            }
            .sorted { $0.expense + $0.income > $1.expense + $1.income }

        return Section("Por método de pago") {
            ForEach(totals) { item in
                HStack {
                    Label(item.method.title, systemImage: item.method.symbol)
                    Spacer()
                    VStack(alignment: .trailing) {
                        if item.income > 0 {
                            Text("+" + item.income.currencyText).foregroundStyle(.green)
                        }
                        if item.expense > 0 {
                            Text("−" + item.expense.currencyText).foregroundStyle(.red)
                        }
                    }
                    .font(.callout.monospacedDigit())
                }
            }
        }
    }
}

private struct CategoryTotal: Identifiable {
    let category: TransactionCategory
    let total: Double
    var id: TransactionCategory { category }
}

private struct PaymentTotal: Identifiable {
    let method: PaymentMethod
    let income: Double
    let expense: Double
    var id: PaymentMethod { method }
}

struct BalanceCard: View {
    let summary: WeekSummary

    var body: some View {
        VStack(spacing: 16) {
            VStack(spacing: 4) {
                Text(summary.net >= 0 ? "Ganancia" : "Pérdida")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.secondary)
                Text(abs(summary.net).currencyText)
                    .font(.system(size: 40, weight: .bold, design: .rounded).monospacedDigit())
                    .foregroundStyle(summary.isEmpty ? Color.primary : (summary.net >= 0 ? Color.green : Color.red))
                    .minimumScaleFactor(0.5)
                    .lineLimit(1)
            }

            HStack(spacing: 12) {
                tile(.income, value: summary.income)
                tile(.expense, value: summary.expense)
            }
        }
        .padding(.vertical, 8)
    }

    private func tile(_ kind: TransactionKind, value: Double) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Label(kind.pluralTitle, systemImage: kind.symbol)
                .font(.caption.weight(.semibold))
                .foregroundStyle(kind.color)
            Text(value.currencyText)
                .font(.headline.monospacedDigit())
                .minimumScaleFactor(0.6)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(kind.color.opacity(0.1), in: RoundedRectangle(cornerRadius: 12))
    }
}
