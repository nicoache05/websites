import SwiftData
import SwiftUI

struct SettingsView: View {
    @Environment(\.modelContext) private var context
    @ObservedObject private var sync = NotionSyncCoordinator.shared
    @Query private var entries: [MoneyEntry]
    @Query(filter: #Predicate<MoneyEntry> { $0.needsNotionSync }) private var pendingEntries: [MoneyEntry]

    @AppStorage(WeeklySummaryScheduler.Keys.enabled) private var reminderEnabled = WeeklySummaryScheduler.Defaults.enabled
    @AppStorage(WeeklySummaryScheduler.Keys.weekday) private var reminderWeekday = WeeklySummaryScheduler.Defaults.weekday
    @AppStorage(WeeklySummaryScheduler.Keys.hour) private var reminderHour = WeeklySummaryScheduler.Defaults.hour
    @AppStorage(WeeklySummaryScheduler.Keys.minute) private var reminderMinute = WeeklySummaryScheduler.Defaults.minute
    @AppStorage(CurrencyFormat.storageKey) private var currencyCode = ""

    @State private var token = NotionConfig.savedToken
    @State private var databaseInput = NotionConfig.savedDatabaseID
    @State private var connectedName = NotionConfig.savedDatabaseName
    @State private var isConnecting = false
    @State private var notionMessage: String?
    @State private var testSent = false

    var body: some View {
        NavigationStack {
            Form {
                notionSection
                reminderSection
                currencySection
                controlCenterSection
            }
            .navigationTitle("Ajustes")
        }
    }

    // MARK: Notion

    private var notionSection: some View {
        Section {
            if let connectedName {
                LabeledContent("Conectado a", value: connectedName)
                Button {
                    Task {
                        let count = await sync.syncPending(in: context)
                        notionMessage = count > 0 ? "Se sincronizaron \(count) movimientos." : sync.lastError
                    }
                } label: {
                    HStack {
                        Label("Sincronizar pendientes", systemImage: "arrow.triangle.2.circlepath")
                        Spacer()
                        if sync.isSyncing {
                            ProgressView()
                        } else {
                            Text("\(pendingEntries.count)").foregroundStyle(.secondary)
                        }
                    }
                }
                .disabled(pendingEntries.isEmpty || sync.isSyncing)

                Button("Desconectar Notion", role: .destructive, action: disconnect)
            } else {
                SecureField("Token de la integración (ntn_… )", text: $token)
                    .textContentType(.password)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                TextField("Enlace o ID de la base de datos", text: $databaseInput)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                    .keyboardType(.URL)
                Button {
                    Task { await connect() }
                } label: {
                    HStack {
                        Text("Conectar")
                        if isConnecting {
                            Spacer()
                            ProgressView()
                        }
                    }
                }
                .disabled(token.isEmpty || databaseInput.isEmpty || isConnecting)
            }

            if let message = notionMessage ?? sync.lastError {
                Text(message)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        } header: {
            Text("Notion")
        } footer: {
            if connectedName == nil {
                Text("""
                1. Crea una integración interna en notion.so/my-integrations y copia su token.
                2. Crea una base de datos (tabla) vacía en Notion.
                3. En la base de datos: ··· › Conexiones › agrega tu integración.
                4. Copia el enlace de la base de datos y pégalo aquí.
                La app crea automáticamente las columnas Monto, Neto, Tipo, Fecha, Categoría, Método de pago y Nota.
                """)
            } else {
                Text("Cada movimiento que registres, edites o borres se refleja en tu base de datos de Notion.")
            }
        }
    }

    private func connect() async {
        guard let databaseID = NotionConfig.extractDatabaseID(from: databaseInput) else {
            notionMessage = "No reconozco ese enlace o ID de base de datos."
            return
        }
        isConnecting = true
        defer { isConnecting = false }

        let cleanToken = token.trimmingCharacters(in: .whitespacesAndNewlines)
        do {
            let result = try await NotionService(token: cleanToken, databaseID: databaseID).prepareDatabase()
            NotionConfig(token: cleanToken, databaseID: databaseID, titleProperty: result.titleProperty)
                .save(databaseName: result.name)
            connectedName = result.name
            // Todo lo registrado antes de conectar se sube ahora.
            for entry in entries { entry.needsNotionSync = true }
            try? context.save()
            let count = await sync.syncPending(in: context)
            notionMessage = "¡Listo! Se subieron \(count) movimientos a Notion."
        } catch {
            notionMessage = error.localizedDescription
        }
    }

    private func disconnect() {
        NotionConfig.clear()
        for entry in entries {
            entry.notionPageID = nil
            entry.needsNotionSync = true
        }
        try? context.save()
        connectedName = nil
        token = ""
        databaseInput = ""
        notionMessage = nil
    }

    // MARK: Recordatorio

    private var reminderSection: some View {
        Section {
            Toggle("Resumen semanal", isOn: $reminderEnabled)
                .onChange(of: reminderEnabled) { _, enabled in
                    if enabled { Task { await WeeklySummaryScheduler.requestAuthorization() } }
                }

            if reminderEnabled {
                Picker("Día", selection: $reminderWeekday) {
                    ForEach(weekdayOrder, id: \.self) { day in
                        Text(Calendar.current.weekdaySymbols[day - 1].capitalized).tag(day)
                    }
                }
                DatePicker("Hora", selection: reminderTime, displayedComponents: .hourAndMinute)
                Button(testSent ? "Enviada: llegará en 5 segundos" : "Enviar notificación de prueba") {
                    Task {
                        await WeeklySummaryScheduler.requestAuthorization()
                        await WeeklySummaryScheduler.sendTest(records: entries.map(\.record))
                        testSent = true
                    }
                }
            }
        } header: {
            Text("Recordatorio")
        } footer: {
            Text("Al final de cada semana (lunes a domingo) recibirás una notificación con tus ingresos, egresos y la ganancia o pérdida obtenida.")
        }
    }

    /// Lunes primero.
    private var weekdayOrder: [Int] { [2, 3, 4, 5, 6, 7, 1] }

    private var reminderTime: Binding<Date> {
        Binding {
            Calendar.current.date(from: DateComponents(hour: reminderHour, minute: reminderMinute)) ?? Date()
        } set: { newValue in
            let components = Calendar.current.dateComponents([.hour, .minute], from: newValue)
            reminderHour = components.hour ?? WeeklySummaryScheduler.Defaults.hour
            reminderMinute = components.minute ?? WeeklySummaryScheduler.Defaults.minute
        }
    }

    // MARK: Moneda

    private var currencySection: some View {
        Section("Moneda") {
            Picker("Moneda", selection: $currencyCode) {
                Text("Automática (\(Locale.current.currency?.identifier ?? "USD"))").tag("")
                ForEach(CurrencyFormat.common, id: \.self) { code in
                    Text("\(code) · \(Locale.current.localizedString(forCurrencyCode: code) ?? code)").tag(code)
                }
            }
        }
    }

    // MARK: Centro de control

    private var controlCenterSection: some View {
        Section {
            Label("Desliza hacia abajo desde la esquina superior derecha para abrir el Centro de control.", systemImage: "1.circle")
            Label("Mantén presionado un espacio vacío o toca + arriba a la izquierda.", systemImage: "2.circle")
            Label("Toca «Agregar un control», busca «Finanzas» y elige «Registrar egreso» o «Registrar ingreso».", systemImage: "3.circle")
        } header: {
            Text("Centro de control")
        } footer: {
            Text("También puedes decir «Oye Siri, registrar egreso en Finanzas», usar la app Atajos o asignarlo al botón de Acción.")
        }
        .font(.callout)
    }
}
