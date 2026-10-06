import Combine
import Foundation
import SwiftData

/// Sube a Notion los movimientos creados o editados en el iPhone.
@MainActor
final class NotionSyncCoordinator: ObservableObject {
    static let shared = NotionSyncCoordinator()

    @Published private(set) var isSyncing = false
    @Published private(set) var lastError: String?
    @Published private(set) var lastSync: Date?

    var isConfigured: Bool { NotionConfig.load() != nil }

    func sync(_ entry: MoneyEntry, in context: ModelContext) async {
        guard let config = NotionConfig.load() else { return }
        await push(entry, config: config, context: context)
    }

    /// Sincroniza todo lo pendiente. Devuelve cuántos movimientos se subieron.
    @discardableResult
    func syncPending(in context: ModelContext) async -> Int {
        guard let config = NotionConfig.load(), !isSyncing else { return 0 }
        isSyncing = true
        defer { isSyncing = false }

        let descriptor = FetchDescriptor<MoneyEntry>(
            predicate: #Predicate { $0.needsNotionSync },
            sortBy: [SortDescriptor(\.date)]
        )
        let pending = (try? context.fetch(descriptor)) ?? []
        var uploaded = 0
        for entry in pending {
            if await push(entry, config: config, context: context) {
                uploaded += 1
            } else {
                break // Probablemente sin conexión: se reintenta más tarde.
            }
        }
        return uploaded
    }

    /// Envía a la papelera de Notion la página de un movimiento eliminado.
    func archive(pageID: String?) async {
        guard let pageID, let config = NotionConfig.load() else { return }
        do {
            try await NotionService(config: config).archive(pageID: pageID)
        } catch {
            lastError = error.localizedDescription
        }
    }

    @discardableResult
    private func push(_ entry: MoneyEntry, config: NotionConfig, context: ModelContext) async -> Bool {
        let snapshot = entry.snapshot
        do {
            let pageID = try await NotionService(config: config).upsert(snapshot, titleProperty: config.titleProperty)
            entry.notionPageID = pageID
            entry.needsNotionSync = false
            try? context.save()
            lastError = nil
            lastSync = Date()
            return true
        } catch {
            lastError = error.localizedDescription
            return false
        }
    }
}
