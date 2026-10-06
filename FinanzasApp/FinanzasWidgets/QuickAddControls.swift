import SwiftUI
import WidgetKit

/// Botón para el Centro de control: abre la app para registrar un egreso.
struct AddExpenseControl: ControlWidget {
    static let kind = "com.tuempresa.finanzas.control.add-expense"

    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(kind: Self.kind) {
            ControlWidgetButton(action: AddExpenseIntent()) {
                Label("Nuevo egreso", systemImage: "minus.circle.fill")
            }
        }
        .displayName("Registrar egreso")
        .description("Abre Finanzas para registrar un gasto.")
    }
}

/// Botón para el Centro de control: abre la app para registrar un ingreso.
struct AddIncomeControl: ControlWidget {
    static let kind = "com.tuempresa.finanzas.control.add-income"

    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(kind: Self.kind) {
            ControlWidgetButton(action: AddIncomeIntent()) {
                Label("Nuevo ingreso", systemImage: "plus.circle.fill")
            }
        }
        .displayName("Registrar ingreso")
        .description("Abre Finanzas para registrar un ingreso.")
    }
}
