import SwiftData
import SwiftUI

/// Formulario para crear o editar un ingreso/egreso.
struct EntryFormView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    private let entry: MoneyEntry?

    @State private var kind: TransactionKind
    @State private var amountText: String
    @State private var date: Date
    @State private var category: TransactionCategory
    @State private var paymentMethod: PaymentMethod
    @State private var note: String
    @State private var confirmDelete = false
    @FocusState private var amountFocused: Bool

    init(entry: MoneyEntry) {
        self.entry = entry
        _kind = State(initialValue: entry.kind)
        _amountText = State(initialValue: Self.format(entry.amount))
        _date = State(initialValue: entry.date)
        _category = State(initialValue: entry.category)
        _paymentMethod = State(initialValue: entry.paymentMethod)
        _note = State(initialValue: entry.note)
    }

    init(kind: TransactionKind) {
        self.entry = nil
        _kind = State(initialValue: kind)
        _amountText = State(initialValue: "")
        _date = State(initialValue: Date())
        _category = State(initialValue: TransactionCategory.options(for: kind)[0])
        _paymentMethod = State(initialValue: .debitCard)
        _note = State(initialValue: "")
    }

    private var amount: Double? {
        let separator = Locale.current.decimalSeparator ?? "."
        let normalized = amountText
            .replacingOccurrences(of: " ", with: "")
            .replacingOccurrences(of: separator, with: ".")
            .replacingOccurrences(of: ",", with: ".")
        guard let value = Double(normalized), value > 0 else { return nil }
        return value
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("Tipo", selection: $kind) {
                        ForEach(TransactionKind.allCases) { kind in
                            Text(kind.title).tag(kind)
                        }
                    }
                    .pickerStyle(.segmented)
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets())
                }

                Section("Monto") {
                    HStack {
                        Text(currencySymbol)
                            .font(.title)
                            .foregroundStyle(.secondary)
                        TextField("0", text: $amountText)
                            .keyboardType(.decimalPad)
                            .font(.system(size: 34, weight: .semibold, design: .rounded))
                            .foregroundStyle(kind.color)
                            .focused($amountFocused)
                    }
                }

                Section("Detalles") {
                    DatePicker("Fecha", selection: $date, displayedComponents: [.date, .hourAndMinute])

                    Picker("Tipo de \(kind == .income ? "ingreso" : "consumo")", selection: $category) {
                        ForEach(TransactionCategory.options(for: kind)) { option in
                            Label(option.title, systemImage: option.symbol).tag(option)
                        }
                    }

                    Picker(kind == .income ? "Medio de cobro" : "Método de pago", selection: $paymentMethod) {
                        ForEach(PaymentMethod.allCases) { method in
                            Label(method.title, systemImage: method.symbol).tag(method)
                        }
                    }
                }

                Section("Nota") {
                    TextField("Ej. Súper de la semana", text: $note, axis: .vertical)
                        .lineLimit(1...4)
                }

                if entry != nil {
                    Section {
                        Button("Eliminar movimiento", role: .destructive) {
                            confirmDelete = true
                        }
                    }
                }
            }
            .navigationTitle(entry == nil ? "Nuevo \(kind.title.lowercased())" : "Editar \(kind.title.lowercased())")
            .navigationBarTitleDisplayMode(.inline)
            .onChange(of: kind) { _, newKind in
                if category.kind != newKind {
                    category = TransactionCategory.options(for: newKind)[0]
                }
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Guardar", action: save)
                        .disabled(amount == nil)
                }
            }
            .confirmationDialog("¿Eliminar este movimiento?", isPresented: $confirmDelete, titleVisibility: .visible) {
                Button("Eliminar", role: .destructive, action: delete)
            }
            .onAppear {
                if entry == nil { amountFocused = true }
            }
        }
    }

    private var currencySymbol: String {
        var locale = Locale.current
        locale = Locale(identifier: locale.identifier + "@currency=\(CurrencyFormat.code)")
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.locale = locale
        return formatter.currencySymbol ?? "$"
    }

    private static func format(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.usesGroupingSeparator = false
        formatter.maximumFractionDigits = 2
        return formatter.string(from: NSNumber(value: value)) ?? "\(value)"
    }

    private func save() {
        guard let amount else { return }
        let trimmedNote = note.trimmingCharacters(in: .whitespacesAndNewlines)

        let target: MoneyEntry
        if let entry {
            entry.amount = amount
            entry.kind = kind
            entry.category = category
            entry.paymentMethod = paymentMethod
            entry.date = date
            entry.note = trimmedNote
            entry.needsNotionSync = true
            target = entry
        } else {
            target = MoneyEntry(
                amount: amount,
                kind: kind,
                category: category,
                paymentMethod: paymentMethod,
                date: date,
                note: trimmedNote
            )
            context.insert(target)
        }
        try? context.save()

        let modelContext = self.context
        Task { await NotionSyncCoordinator.shared.sync(target, in: modelContext) }
        dismiss()
    }

    private func delete() {
        guard let entry else { return }
        let pageID = entry.notionPageID
        context.delete(entry)
        try? context.save()
        Task { await NotionSyncCoordinator.shared.archive(pageID: pageID) }
        dismiss()
    }
}
