import SwiftUI
import WidgetKit

@main
struct FinanzasWidgetsBundle: WidgetBundle {
    var body: some Widget {
        AddExpenseControl()
        AddIncomeControl()
    }
}
