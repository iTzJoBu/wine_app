import SwiftUI
import SwiftData

// Einstiegspunkt der App. Hier wird die lokale Datenbank (SwiftData) eingerichtet,
// in der alle Produkte, Lagerorte, Bestände und (geschätzte) Kosten dauerhaft
// auf dem iPhone gespeichert werden.
@main
struct WeinkellerApp: App {
    /// Lokaler Datenspeicher für alle Modelle.
    let container: ModelContainer

    init() {
        container = Self.makeContainer()
    }

    var body: some Scene {
        WindowGroup {
            ProductListView()
        }
        .modelContainer(container)
    }

    /// Erstellt den SwiftData-Container. Lässt sich der vorhandene Store nicht
    /// öffnen (z. B. weil das Datenmodell sich geändert hat oder die Datei
    /// beschädigt ist – typischerweise ein „disk I/O error" im Simulator),
    /// werden die alten Store-Dateien einmalig entfernt und der Store frisch
    /// angelegt.
    ///
    /// Hinweis: Für eine spätere Produktivversion mit echten Daten sollte hier
    /// stattdessen eine richtige SwiftData-Migration (VersionedSchema) stehen –
    /// das automatische Löschen verwirft vorhandene Daten.
    private static func makeContainer() -> ModelContainer {
        let schema = Schema([Product.self, Location.self, StockEntry.self, CostEvent.self])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            return try ModelContainer(for: schema, configurations: [config])
        } catch {
            // Erster Versuch fehlgeschlagen: alten Store inkl. Begleitdateien löschen.
            removeStoreFiles(at: config.url)
            do {
                return try ModelContainer(for: schema, configurations: [config])
            } catch {
                // Letzter Ausweg: reiner In-Memory-Speicher, damit die App startet.
                let memoryConfig = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
                if let memoryContainer = try? ModelContainer(for: schema, configurations: [memoryConfig]) {
                    return memoryContainer
                }
                fatalError("SwiftData-Container konnte nicht erstellt werden: \(error)")
            }
        }
    }

    /// Entfernt die SQLite-Store-Datei samt -wal und -shm.
    private static func removeStoreFiles(at url: URL) {
        let fileManager = FileManager.default
        let pfade = [url.path, url.path + "-wal", url.path + "-shm"]
        for pfad in pfade where fileManager.fileExists(atPath: pfad) {
            try? fileManager.removeItem(atPath: pfad)
        }
    }
}
