import AppIntents
import SwiftData
import SwiftUI
import UserNotifications

@main
struct FinanzasApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        WindowGroup {
            RootView()
        }
        .modelContainer(for: MoneyEntry.self)
    }
}

final class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        return true
    }

    /// Muestra el resumen semanal aunque la app esté abierta.
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.banner, .list, .sound]
    }
}

/// Atajos de Siri y de la app Atajos.
struct FinanzasShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: AddExpenseIntent(),
            phrases: ["Registrar egreso en \(.applicationName)", "Nuevo gasto en \(.applicationName)"],
            shortTitle: "Nuevo egreso",
            systemImageName: "minus.circle.fill"
        )
        AppShortcut(
            intent: AddIncomeIntent(),
            phrases: ["Registrar ingreso en \(.applicationName)", "Nuevo ingreso en \(.applicationName)"],
            shortTitle: "Nuevo ingreso",
            systemImageName: "plus.circle.fill"
        )
    }
}
