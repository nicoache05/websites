import Foundation
import SwiftData

/// Un movimiento de dinero (ingreso o egreso).
@Model
final class MoneyEntry {
    var id: UUID = UUID()
    var amount: Double = 0
    var kindRaw: String = TransactionKind.expense.rawValue
    var categoryRaw: String = TransactionCategory.otherExpense.rawValue
    var paymentMethodRaw: String = PaymentMethod.cash.rawValue
    var date: Date = Date()
    var note: String = ""
    var createdAt: Date = Date()
    /// ID de la página en Notion, si ya se sincronizó al menos una vez.
    var notionPageID: String?
    /// `true` cuando hay cambios locales que aún no llegan a Notion.
    var needsNotionSync: Bool = true

    init(
        amount: Double,
        kind: TransactionKind,
        category: TransactionCategory,
        paymentMethod: PaymentMethod,
        date: Date,
        note: String = ""
    ) {
        self.amount = amount
        self.kindRaw = kind.rawValue
        self.categoryRaw = category.rawValue
        self.paymentMethodRaw = paymentMethod.rawValue
        self.date = date
        self.note = note
    }

    var kind: TransactionKind {
        get { TransactionKind(rawValue: kindRaw) ?? .expense }
        set { kindRaw = newValue.rawValue }
    }

    var category: TransactionCategory {
        get { TransactionCategory(rawValue: categoryRaw) ?? (kind == .income ? .otherIncome : .otherExpense) }
        set { categoryRaw = newValue.rawValue }
    }

    var paymentMethod: PaymentMethod {
        get { PaymentMethod(rawValue: paymentMethodRaw) ?? .other }
        set { paymentMethodRaw = newValue.rawValue }
    }

    /// Positivo para ingresos, negativo para egresos.
    var signedAmount: Double { kind == .income ? amount : -amount }

    var record: AmountRecord {
        AmountRecord(date: date, kind: kind, amount: amount)
    }

    var snapshot: EntrySnapshot {
        EntrySnapshot(
            id: id,
            amount: amount,
            kind: kind,
            category: category,
            paymentMethod: paymentMethod,
            date: date,
            note: note,
            notionPageID: notionPageID
        )
    }
}

/// Copia inmutable de un movimiento, segura para enviar a tareas en segundo plano.
struct EntrySnapshot: Sendable {
    let id: UUID
    let amount: Double
    let kind: TransactionKind
    let category: TransactionCategory
    let paymentMethod: PaymentMethod
    let date: Date
    let note: String
    let notionPageID: String?

    var signedAmount: Double { kind == .income ? amount : -amount }

    var displayTitle: String {
        note.isEmpty ? category.title : note
    }
}

/// Lo mínimo para calcular totales.
struct AmountRecord: Sendable {
    let date: Date
    let kind: TransactionKind
    let amount: Double
}
