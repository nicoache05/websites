import Foundation
import UserNotifications

/// Programa la notificación de fin de semana con la ganancia o pérdida de cada semana.
///
/// iOS no permite ejecutar código justo antes de mostrar una notificación local,
/// así que se programan las próximas semanas con los totales ya calculados y se
/// vuelven a programar cada vez que cambia un movimiento o la configuración.
enum WeeklySummaryScheduler {
    enum Keys {
        static let enabled = "reminder.enabled"
        static let weekday = "reminder.weekday" // 1 = domingo … 7 = sábado
        static let hour = "reminder.hour"
        static let minute = "reminder.minute"
    }

    enum Defaults {
        static let enabled = true
        static let weekday = 1
        static let hour = 20
        static let minute = 0
    }

    private static let idPrefix = "weekly-summary-"
    private static let weeksAhead = 8

    @discardableResult
    static func requestAuthorization() async -> Bool {
        (try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge])) ?? false
    }

    static func reschedule(records: [AmountRecord]) async {
        let center = UNUserNotificationCenter.current()
        let pending = await center.pendingNotificationRequests()
        center.removePendingNotificationRequests(withIdentifiers: pending.map(\.identifier).filter { $0.hasPrefix(idPrefix) })

        let defaults = UserDefaults.standard
        let enabled = defaults.object(forKey: Keys.enabled) as? Bool ?? Defaults.enabled
        guard enabled else { return }

        let weekday = defaults.object(forKey: Keys.weekday) as? Int ?? Defaults.weekday
        let hour = defaults.object(forKey: Keys.hour) as? Int ?? Defaults.hour
        let minute = defaults.object(forKey: Keys.minute) as? Int ?? Defaults.minute

        let calendar = Calendar.finance
        guard let first = calendar.nextDate(
            after: Date(),
            matching: DateComponents(hour: hour, minute: minute, weekday: weekday),
            matchingPolicy: .nextTime
        ) else { return }

        for week in 0..<weeksAhead {
            guard let fireDate = calendar.date(byAdding: .weekOfYear, value: week, to: first) else { continue }
            let summary = WeekSummary(interval: calendar.weekInterval(containing: fireDate), records: records)
            let components = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: fireDate)
            let request = UNNotificationRequest(
                identifier: idPrefix + "\(Int(fireDate.timeIntervalSince1970))",
                content: content(for: summary),
                trigger: UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
            )
            try? await center.add(request)
        }
    }

    /// Envía en 5 segundos el resumen de la semana actual.
    static func sendTest(records: [AmountRecord]) async {
        let summary = WeekSummary(interval: Calendar.finance.weekInterval(containing: Date()), records: records)
        let request = UNNotificationRequest(
            identifier: "weekly-summary-test",
            content: content(for: summary),
            trigger: UNTimeIntervalNotificationTrigger(timeInterval: 5, repeats: false)
        )
        try? await UNUserNotificationCenter.current().add(request)
    }

    static func content(for summary: WeekSummary) -> UNMutableNotificationContent {
        let content = UNMutableNotificationContent()
        content.title = "Resumen semanal · \(summary.interval.weekLabel)"
        content.sound = .default

        if summary.isEmpty {
            content.body = "No registraste movimientos esta semana. Abre Finanzas para ponerte al día."
        } else {
            let headline = summary.net >= 0
                ? "✅ Ganancia de \(summary.net.currencyText)"
                : "⚠️ Pérdida de \(abs(summary.net).currencyText)"
            content.body = "\(headline)\nIngresos: \(summary.income.currencyText) · Egresos: \(summary.expense.currencyText)"
        }
        return content
    }
}
