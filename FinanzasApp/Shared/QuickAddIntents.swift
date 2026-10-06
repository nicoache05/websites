import AppIntents

/// Abre la app con el formulario de egreso. Se usa en el Centro de control, Siri y Atajos.
struct AddExpenseIntent: AppIntent {
    static var title: LocalizedStringResource { "Registrar egreso" }
    static var description: IntentDescription? {
        IntentDescription("Abre Finanzas con el formulario de egreso listo.")
    }
    static var openAppWhenRun: Bool { true }

    @MainActor
    func perform() async throws -> some IntentResult {
        PendingQuickAction.set(.expense)
        return .result()
    }
}

/// Abre la app con el formulario de ingreso.
struct AddIncomeIntent: AppIntent {
    static var title: LocalizedStringResource { "Registrar ingreso" }
    static var description: IntentDescription? {
        IntentDescription("Abre Finanzas con el formulario de ingreso listo.")
    }
    static var openAppWhenRun: Bool { true }

    @MainActor
    func perform() async throws -> some IntentResult {
        PendingQuickAction.set(.income)
        return .result()
    }
}
