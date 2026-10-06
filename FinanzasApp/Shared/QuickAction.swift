import Foundation

/// Identificador del App Group compartido entre la app y la extensión de widgets.
/// Debe coincidir con el valor en los archivos .entitlements y en project.yml.
enum AppGroup {
    static let identifier = "group.com.tuempresa.finanzas"

    static var defaults: UserDefaults {
        UserDefaults(suiteName: identifier) ?? .standard
    }
}

/// Acción rápida solicitada desde el Centro de control, Siri o Atajos.
enum QuickAction: String {
    case income
    case expense
}

/// Guarda la acción pendiente para que la app la abra en cuanto pase a primer plano.
enum PendingQuickAction {
    private static let actionKey = "pendingQuickAction"
    private static let dateKey = "pendingQuickActionDate"

    static func set(_ action: QuickAction) {
        let defaults = AppGroup.defaults
        defaults.set(action.rawValue, forKey: actionKey)
        defaults.set(Date(), forKey: dateKey)
        NotificationCenter.default.post(name: .quickActionRequested, object: nil)
    }

    /// Devuelve y borra la acción pendiente (se ignora si tiene más de 2 minutos).
    static func consume() -> QuickAction? {
        let defaults = AppGroup.defaults
        defer {
            defaults.removeObject(forKey: actionKey)
            defaults.removeObject(forKey: dateKey)
        }
        guard
            let raw = defaults.string(forKey: actionKey),
            let action = QuickAction(rawValue: raw),
            let date = defaults.object(forKey: dateKey) as? Date,
            Date().timeIntervalSince(date) < 120
        else { return nil }
        return action
    }
}

extension Notification.Name {
    static let quickActionRequested = Notification.Name("quickActionRequested")
}
