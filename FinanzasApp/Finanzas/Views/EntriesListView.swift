import SwiftData
import SwiftUI

struct EntriesListView: View {
    let onAdd: (TransactionKind) -> Void

    @Environment(\.modelContext) private var context
    @Query(sort: \MoneyEntry.date, order: .reverse) private var entries: [MoneyEntry]
    @State private var filter: TransactionKind?
    @State private var paymentFilter: PaymentMethod?
    @State private var search = ""
    @State private var editingEntry: MoneyEntry?

    private var filtered: [MoneyEntry] {
        entries.filter { entry in
            (filter == nil || entry.kind == filter)
                && (paymentFilter == nil || entry.paymentMethod == paymentFilter)
                && (search.isEmpty
                    || entry.note.localizedCaseInsensitiveContains(search)
                    || entry.category.title.localizedCaseInsensitiveContains(search))
        }
    }

    private struct DayGroup: Identifiable {
        let day: Date
        let entries: [MoneyEntry]
        var id: Date { day }
    }

    private var days: [DayGroup] {
        let calendar = Calendar.finance
        return Dictionary(grouping: filtered) { calendar.startOfDay(for: $0.date) }
            .map { DayGroup(day: $0.key, entries: $0.value) }
            .sorted { $0.day > $1.day }
    }

    var body: some View {
        NavigationStack {
            List {
                Picker("Tipo", selection: $filter) {
                    Text("Todos").tag(TransactionKind?.none)
                    ForEach(TransactionKind.allCases) { kind in
                        Text(kind.pluralTitle).tag(Optional(kind))
                    }
                }
                .pickerStyle(.segmented)
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets())

                ForEach(days) { group in
                    Section {
                        ForEach(group.entries) { entry in
                            Button { editingEntry = entry } label: {
                                EntryRow(entry: entry, showsSyncState: NotionSyncCoordinator.shared.isConfigured)
                            }
                            .tint(.primary)
                        }
                        .onDelete { offsets in
                            delete(offsets.map { group.entries[$0] })
                        }
                    } header: {
                        HStack {
                            Text(group.day.formatted(.dateTime.weekday(.wide).day().month(.wide)))
                            Spacer()
                            let net = group.entries.reduce(0) { $0 + $1.signedAmount }
                            Text(net.currencyText)
                                .foregroundStyle(net >= 0 ? .green : .red)
                                .monospacedDigit()
                        }
                    }
                }
            }
            .overlay {
                if filtered.isEmpty {
                    ContentUnavailableView(
                        entries.isEmpty ? "Aún no hay movimientos" : "Sin resultados",
                        systemImage: "tray",
                        description: Text(entries.isEmpty ? "Toca + para registrar tu primer ingreso o egreso." : "Prueba con otros filtros.")
                    )
                }
            }
            .searchable(text: $search, prompt: "Buscar por nota o tipo")
            .navigationTitle("Movimientos")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Menu {
                        Picker("Método de pago", selection: $paymentFilter) {
                            Text("Todos los métodos").tag(PaymentMethod?.none)
                            ForEach(PaymentMethod.allCases) { method in
                                Label(method.title, systemImage: method.symbol).tag(Optional(method))
                            }
                        }
                    } label: {
                        Image(systemName: paymentFilter == nil
                              ? "line.3.horizontal.decrease.circle"
                              : "line.3.horizontal.decrease.circle.fill")
                    }
                    .accessibilityLabel("Filtrar por método de pago")
                }
                ToolbarItem(placement: .primaryAction) {
                    AddEntryMenu(onAdd: onAdd)
                }
            }
            .sheet(item: $editingEntry) { entry in
                EntryFormView(entry: entry)
            }
        }
    }

    private func delete(_ toDelete: [MoneyEntry]) {
        for entry in toDelete {
            let pageID = entry.notionPageID
            context.delete(entry)
            Task { await NotionSyncCoordinator.shared.archive(pageID: pageID) }
        }
        try? context.save()
    }
}
