import Foundation

extension Calendar {
    /// Calendario usado para las semanas financieras: de lunes a domingo.
    static var finance: Calendar {
        var calendar = Calendar.current
        calendar.firstWeekday = 2
        return calendar
    }

    func weekInterval(containing date: Date) -> DateInterval {
        dateInterval(of: .weekOfYear, for: date) ?? DateInterval(start: startOfDay(for: date), duration: 7 * 86_400)
    }
}

extension DateInterval {
    /// Igual que `contains`, pero excluye el instante final (que ya es la semana siguiente).
    func containsExcludingEnd(_ date: Date) -> Bool {
        date >= start && date < end
    }

    /// Texto tipo "30 sep – 6 oct".
    var weekLabel: String {
        let last = end.addingTimeInterval(-1)
        let format = Date.FormatStyle.dateTime.day().month(.abbreviated)
        return "\(start.formatted(format)) – \(last.formatted(format))"
    }
}

struct WeekSummary {
    let interval: DateInterval
    let income: Double
    let expense: Double

    var net: Double { income - expense }
    var isEmpty: Bool { income == 0 && expense == 0 }

    init(interval: DateInterval, records: [AmountRecord]) {
        self.interval = interval
        var income = 0.0
        var expense = 0.0
        for record in records where interval.containsExcludingEnd(record.date) {
            switch record.kind {
            case .income: income += record.amount
            case .expense: expense += record.amount
            }
        }
        self.income = income
        self.expense = expense
    }
}

enum CurrencyFormat {
    static let storageKey = "currencyCode"

    /// Moneda elegida en Ajustes o, si no hay, la de la región del dispositivo.
    static var code: String {
        if let stored = UserDefaults.standard.string(forKey: storageKey), !stored.isEmpty {
            return stored
        }
        return Locale.current.currency?.identifier ?? "USD"
    }

    static let common = ["MXN", "COP", "ARS", "CLP", "PEN", "USD", "EUR", "BOB", "UYU", "PYG", "GTQ", "DOP", "CRC", "VES", "BRL"]
}

extension Double {
    var currencyText: String {
        formatted(.currency(code: CurrencyFormat.code))
    }
}
