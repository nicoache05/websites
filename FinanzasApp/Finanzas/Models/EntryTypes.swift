import Foundation

enum TransactionKind: String, Codable, CaseIterable, Identifiable {
    case income
    case expense

    var id: String { rawValue }

    var title: String {
        switch self {
        case .income: "Ingreso"
        case .expense: "Egreso"
        }
    }

    var pluralTitle: String {
        switch self {
        case .income: "Ingresos"
        case .expense: "Egresos"
        }
    }

    var symbol: String {
        switch self {
        case .income: "arrow.down.left.circle.fill"
        case .expense: "arrow.up.right.circle.fill"
        }
    }

    init(_ action: QuickAction) {
        switch action {
        case .income: self = .income
        case .expense: self = .expense
        }
    }
}

/// Tipo de consumo (categoría). Cada categoría pertenece a ingresos o a egresos.
enum TransactionCategory: String, Codable, CaseIterable, Identifiable {
    // Ingresos
    case salary, sales, freelance, investments, gift, otherIncome
    // Egresos
    case food, transport, housing, utilities, health, entertainment
    case education, shopping, subscriptions, debt, otherExpense

    var id: String { rawValue }

    var kind: TransactionKind {
        switch self {
        case .salary, .sales, .freelance, .investments, .gift, .otherIncome: .income
        default: .expense
        }
    }

    var title: String {
        switch self {
        case .salary: "Salario"
        case .sales: "Ventas"
        case .freelance: "Trabajo independiente"
        case .investments: "Inversiones"
        case .gift: "Regalo"
        case .otherIncome: "Otro ingreso"
        case .food: "Alimentación"
        case .transport: "Transporte"
        case .housing: "Vivienda"
        case .utilities: "Servicios"
        case .health: "Salud"
        case .entertainment: "Entretenimiento"
        case .education: "Educación"
        case .shopping: "Compras"
        case .subscriptions: "Suscripciones"
        case .debt: "Deudas y préstamos"
        case .otherExpense: "Otro egreso"
        }
    }

    var symbol: String {
        switch self {
        case .salary: "briefcase.fill"
        case .sales: "storefront.fill"
        case .freelance: "laptopcomputer"
        case .investments: "chart.line.uptrend.xyaxis"
        case .gift: "gift.fill"
        case .otherIncome: "plus.circle"
        case .food: "fork.knife"
        case .transport: "car.fill"
        case .housing: "house.fill"
        case .utilities: "bolt.fill"
        case .health: "cross.case.fill"
        case .entertainment: "gamecontroller.fill"
        case .education: "book.fill"
        case .shopping: "bag.fill"
        case .subscriptions: "play.rectangle.fill"
        case .debt: "creditcard.trianglebadge.exclamationmark"
        case .otherExpense: "ellipsis.circle"
        }
    }

    static func options(for kind: TransactionKind) -> [TransactionCategory] {
        allCases.filter { $0.kind == kind }
    }
}

enum PaymentMethod: String, Codable, CaseIterable, Identifiable {
    case cash, debitCard, creditCard, transfer, digitalWallet, other

    var id: String { rawValue }

    var title: String {
        switch self {
        case .cash: "Efectivo"
        case .debitCard: "Tarjeta de débito"
        case .creditCard: "Tarjeta de crédito"
        case .transfer: "Transferencia"
        case .digitalWallet: "Billetera digital"
        case .other: "Otro"
        }
    }

    var symbol: String {
        switch self {
        case .cash: "banknote.fill"
        case .debitCard: "creditcard.fill"
        case .creditCard: "creditcard.circle.fill"
        case .transfer: "arrow.left.arrow.right"
        case .digitalWallet: "iphone.gen3"
        case .other: "questionmark.circle"
        }
    }
}
