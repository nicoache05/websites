import Foundation

/// Configuración guardada de la conexión con Notion.
struct NotionConfig: Sendable {
    let token: String
    let databaseID: String
    let titleProperty: String

    private static let tokenAccount = "notion.token"
    private static let databaseKey = "notion.databaseID"
    private static let titleKey = "notion.titleProperty"
    private static let databaseNameKey = "notion.databaseName"

    static func load() -> NotionConfig? {
        guard
            let token = Keychain.get(tokenAccount), !token.isEmpty,
            let databaseID = UserDefaults.standard.string(forKey: databaseKey), !databaseID.isEmpty,
            let title = UserDefaults.standard.string(forKey: titleKey), !title.isEmpty
        else { return nil }
        return NotionConfig(token: token, databaseID: databaseID, titleProperty: title)
    }

    static var savedToken: String { Keychain.get(tokenAccount) ?? "" }
    static var savedDatabaseID: String { UserDefaults.standard.string(forKey: databaseKey) ?? "" }
    static var savedDatabaseName: String? { UserDefaults.standard.string(forKey: databaseNameKey) }

    func save(databaseName: String) {
        Keychain.set(token, for: Self.tokenAccount)
        UserDefaults.standard.set(databaseID, forKey: Self.databaseKey)
        UserDefaults.standard.set(titleProperty, forKey: Self.titleKey)
        UserDefaults.standard.set(databaseName, forKey: Self.databaseNameKey)
    }

    static func clear() {
        Keychain.delete(tokenAccount)
        for key in [databaseKey, titleKey, databaseNameKey] {
            UserDefaults.standard.removeObject(forKey: key)
        }
    }

    /// Acepta un ID (con o sin guiones) o la URL completa de la base de datos.
    static func extractDatabaseID(from input: String) -> String? {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        let path = trimmed.split(separator: "?", maxSplits: 1).first.map(String.init) ?? trimmed
        let compact = path.replacingOccurrences(of: "-", with: "")
        guard compact.count >= 32 else { return nil }
        let candidate = String(compact.suffix(32))
        guard candidate.allSatisfy(\.isHexDigit) else { return nil }
        return candidate.lowercased()
    }
}

enum NotionError: LocalizedError {
    case http(status: Int, message: String)
    case invalidResponse
    case missingTitleProperty
    case propertyTypeMismatch(name: String, expected: String, found: String)

    var errorDescription: String? {
        switch self {
        case let .http(status, message):
            switch status {
            case 401: return "Token de Notion inválido. Revisa el secreto de tu integración."
            case 404: return "No se encontró la base de datos. ¿La compartiste con tu integración (··· › Conexiones)?"
            default: return "Notion respondió \(status): \(message)"
            }
        case .invalidResponse:
            return "Respuesta inesperada de Notion."
        case .missingTitleProperty:
            return "La base de datos no tiene una propiedad de título."
        case let .propertyTypeMismatch(name, expected, found):
            return "La propiedad «\(name)» es de tipo \(found), pero debe ser \(expected). Renómbrala o cambia su tipo en Notion."
        }
    }
}

/// Cliente REST de la API de Notion.
struct NotionService {
    /// Columnas que la app usa en la base de datos de Notion.
    enum Property {
        static let amount = "Monto"
        static let net = "Neto"
        static let kind = "Tipo"
        static let date = "Fecha"
        static let category = "Categoría"
        static let paymentMethod = "Método de pago"
        static let note = "Nota"
    }

    private static let baseURL = URL(string: "https://api.notion.com/v1/")!
    private static let apiVersion = "2022-06-28"

    let token: String
    let databaseID: String

    init(token: String, databaseID: String) {
        self.token = token
        self.databaseID = databaseID
    }

    init(config: NotionConfig) {
        self.init(token: config.token, databaseID: config.databaseID)
    }

    // MARK: - Configuración de la base de datos

    /// Verifica el acceso y crea las columnas que falten.
    /// Devuelve el nombre de la base de datos y el nombre de su propiedad de título.
    func prepareDatabase() async throws -> (name: String, titleProperty: String) {
        let database = try await send("databases/\(databaseID)", method: "GET")
        let properties = database["properties"] as? [String: [String: Any]] ?? [:]

        guard let titleProperty = properties.first(where: { $0.value["type"] as? String == "title" })?.key else {
            throw NotionError.missingTitleProperty
        }

        let required: [(name: String, type: String, schema: [String: Any])] = [
            (Property.amount, "number", ["number": ["format": "number_with_commas"]]),
            (Property.net, "number", ["number": ["format": "number_with_commas"]]),
            (Property.kind, "select", ["select": ["options": TransactionKind.allCases.map { Self.option(for: $0) }]]),
            (Property.date, "date", ["date": [String: Any]()]),
            (Property.category, "select", ["select": ["options": TransactionCategory.allCases.map { ["name": $0.title] }]]),
            (Property.paymentMethod, "select", ["select": ["options": PaymentMethod.allCases.map { ["name": $0.title] }]]),
            (Property.note, "rich_text", ["rich_text": [String: Any]()]),
        ]

        var missing: [String: Any] = [:]
        for property in required {
            if let existing = properties[property.name] {
                let found = existing["type"] as? String ?? "?"
                if found != property.type {
                    throw NotionError.propertyTypeMismatch(name: property.name, expected: property.type, found: found)
                }
            } else {
                missing[property.name] = property.schema
            }
        }

        if !missing.isEmpty {
            _ = try await send("databases/\(databaseID)", method: "PATCH", body: ["properties": missing])
        }

        let titleParts = database["title"] as? [[String: Any]] ?? []
        let name = titleParts.compactMap { $0["plain_text"] as? String }.joined()
        return (name.isEmpty ? "Sin título" : name, titleProperty)
    }

    private static func option(for kind: TransactionKind) -> [String: Any] {
        ["name": kind.title, "color": kind == .income ? "green" : "red"]
    }

    // MARK: - Páginas (movimientos)

    /// Crea o actualiza la página de un movimiento. Devuelve el ID de la página.
    func upsert(_ entry: EntrySnapshot, titleProperty: String) async throws -> String {
        let properties = Self.properties(for: entry, titleProperty: titleProperty)
        if let pageID = entry.notionPageID {
            do {
                _ = try await send("pages/\(pageID)", method: "PATCH", body: ["properties": properties, "archived": false])
                return pageID
            } catch NotionError.http(404, _) {
                // La página se borró en Notion: se vuelve a crear.
            }
        }
        let page = try await send("pages", method: "POST", body: [
            "parent": ["database_id": databaseID],
            "properties": properties,
        ])
        guard let id = page["id"] as? String else { throw NotionError.invalidResponse }
        return id
    }

    /// Envía la página a la papelera de Notion.
    func archive(pageID: String) async throws {
        _ = try await send("pages/\(pageID)", method: "PATCH", body: ["archived": true])
    }

    private static func properties(for entry: EntrySnapshot, titleProperty: String) -> [String: Any] {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = .current
        formatter.dateFormat = "yyyy-MM-dd"

        let noteText: [[String: Any]] = entry.note.isEmpty ? [] : [["text": ["content": entry.note]]]

        return [
            titleProperty: ["title": [["text": ["content": entry.displayTitle]]]],
            Property.amount: ["number": entry.amount],
            Property.net: ["number": entry.signedAmount],
            Property.kind: ["select": ["name": entry.kind.title]],
            Property.date: ["date": ["start": formatter.string(from: entry.date)]],
            Property.category: ["select": ["name": entry.category.title]],
            Property.paymentMethod: ["select": ["name": entry.paymentMethod.title]],
            Property.note: ["rich_text": noteText],
        ]
    }

    // MARK: - HTTP

    private func send(_ path: String, method: String, body: [String: Any]? = nil) async throws -> [String: Any] {
        var request = URLRequest(url: Self.baseURL.appendingPathComponent(path))
        request.httpMethod = method
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue(Self.apiVersion, forHTTPHeaderField: "Notion-Version")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let body {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
        }

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw NotionError.invalidResponse }
        let json = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] ?? [:]
        guard (200..<300).contains(http.statusCode) else {
            throw NotionError.http(status: http.statusCode, message: json["message"] as? String ?? "")
        }
        return json
    }
}
