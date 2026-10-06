import Combine
import SwiftData
import SwiftUI

enum AppTab: Hashable {
    case summary, entries, settings
}

struct RootView: View {
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.modelContext) private var context
    @Query private var entries: [MoneyEntry]

    @AppStorage(WeeklySummaryScheduler.Keys.enabled) private var reminderEnabled = WeeklySummaryScheduler.Defaults.enabled
    @AppStorage(WeeklySummaryScheduler.Keys.weekday) private var reminderWeekday = WeeklySummaryScheduler.Defaults.weekday
    @AppStorage(WeeklySummaryScheduler.Keys.hour) private var reminderHour = WeeklySummaryScheduler.Defaults.hour
    @AppStorage(WeeklySummaryScheduler.Keys.minute) private var reminderMinute = WeeklySummaryScheduler.Defaults.minute
    @AppStorage(CurrencyFormat.storageKey) private var currencyCode = ""

    @State private var tab = AppTab.summary
    @State private var newEntryKind: TransactionKind?

    var body: some View {
        TabView(selection: $tab) {
            SummaryView(onAdd: { newEntryKind = $0 })
                .tabItem { Label("Resumen", systemImage: "chart.pie.fill") }
                .tag(AppTab.summary)

            EntriesListView(onAdd: { newEntryKind = $0 })
                .tabItem { Label("Movimientos", systemImage: "list.bullet.rectangle.fill") }
                .tag(AppTab.entries)

            SettingsView()
                .tabItem { Label("Ajustes", systemImage: "gearshape.fill") }
                .tag(AppTab.settings)
        }
        .id(currencyCode)
        .sheet(item: $newEntryKind) { kind in
            EntryFormView(kind: kind)
        }
        // Reprograma el recordatorio cada vez que cambian los datos o la configuración.
        .task(id: reminderFingerprint) {
            await WeeklySummaryScheduler.reschedule(records: entries.map(\.record))
        }
        .task {
            if reminderEnabled {
                await WeeklySummaryScheduler.requestAuthorization()
            }
            consumeQuickAction()
            await NotionSyncCoordinator.shared.syncPending(in: context)
        }
        .onChange(of: scenePhase) { _, phase in
            guard phase == .active else { return }
            consumeQuickAction()
            Task { await NotionSyncCoordinator.shared.syncPending(in: context) }
        }
        .onReceive(NotificationCenter.default.publisher(for: .quickActionRequested).receive(on: RunLoop.main)) { _ in
            consumeQuickAction()
        }
        .onOpenURL(perform: handle)
    }

    private var reminderFingerprint: Int {
        var hasher = Hasher()
        hasher.combine(reminderEnabled)
        hasher.combine(reminderWeekday)
        hasher.combine(reminderHour)
        hasher.combine(reminderMinute)
        hasher.combine(currencyCode)
        for entry in entries {
            hasher.combine(entry.id)
            hasher.combine(entry.amount)
            hasher.combine(entry.date)
            hasher.combine(entry.kindRaw)
        }
        return hasher.finalize()
    }

    private func consumeQuickAction() {
        guard let action = PendingQuickAction.consume() else { return }
        newEntryKind = TransactionKind(action)
    }

    /// finanzas://nuevo?tipo=egreso | finanzas://nuevo?tipo=ingreso
    private func handle(_ url: URL) {
        guard url.scheme == "finanzas", url.host == "nuevo" else { return }
        let type = URLComponents(url: url, resolvingAgainstBaseURL: false)?
            .queryItems?.first { $0.name == "tipo" }?.value
        newEntryKind = type == "ingreso" ? .income : .expense
    }
}
