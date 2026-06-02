import Foundation
import SwiftData

/// Bündelt die Buchungslogik für Bestände, damit Views einfach bleiben.
enum StockService {

    /// Sucht den vorhandenen `StockEntry` eines Produkts an einem Lagerort.
    static func entry(for product: Product, at location: Location) -> StockEntry? {
        product.stockEntries.first { $0.location?.persistentModelID == location.persistentModelID }
    }

    /// Bucht Menge in einer Einheit (Flasche/Karton) auf einen Lagerort.
    @discardableResult
    static func book(
        product: Product,
        location: Location,
        unit: StockUnit,
        menge: Int,
        context: ModelContext
    ) -> StockEntry {
        let target: StockEntry
        if let vorhanden = entry(for: product, at: location) {
            target = vorhanden
        } else {
            // product/location werden gesetzt – SwiftData pflegt die inversen
            // Beziehungs-Arrays automatisch, daher kein manuelles append.
            let neu = StockEntry(product: product, location: location)
            context.insert(neu)
            target = neu
        }
        switch unit {
        case .flasche: target.einzelflaschen += max(0, menge)
        case .karton: target.kartons += max(0, menge)
        }
        return target
    }

    /// Verschiebt Menge in einer Einheit von einem Lagerort zu einem anderen.
    /// Bestände werden angepasst, leere Einträge danach entfernt.
    static func move(
        product: Product,
        from quelle: Location,
        to ziel: Location,
        unit: StockUnit,
        menge: Int,
        context: ModelContext
    ) {
        guard quelle.persistentModelID != ziel.persistentModelID, menge > 0 else { return }
        guard let quellEintrag = entry(for: product, at: quelle) else { return }

        let bewegt: Int
        switch unit {
        case .flasche:
            bewegt = min(menge, quellEintrag.einzelflaschen)
            quellEintrag.einzelflaschen -= bewegt
        case .karton:
            bewegt = min(menge, quellEintrag.kartons)
            quellEintrag.kartons -= bewegt
        }
        guard bewegt > 0 else { return }

        book(product: product, location: ziel, unit: unit, menge: bewegt, context: context)
        cleanupIfEmpty(quellEintrag, context: context)
    }

    /// Entfernt einen StockEntry, wenn er keinen Bestand mehr enthält.
    /// SwiftData entfernt ihn dabei automatisch aus den inversen Beziehungen.
    static func cleanupIfEmpty(_ entry: StockEntry, context: ModelContext) {
        guard entry.istLeer else { return }
        context.delete(entry)
    }
}
