import Foundation
import SwiftData

/// Bündelt die Buchungslogik für Bestände, damit Views einfach bleiben.
/// Bestand wird ausschließlich in einzelnen Flaschen geführt.
enum StockService {

    /// Sucht den vorhandenen `StockEntry` eines Produkts an einem Lagerort.
    static func entry(for product: Product, at location: Location) -> StockEntry? {
        product.stockEntries.first { $0.location?.persistentModelID == location.persistentModelID }
    }

    /// Bucht eine Anzahl Flaschen auf einen Lagerort.
    @discardableResult
    static func book(
        product: Product,
        location: Location,
        anzahl: Int,
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
        target.anzahl += max(0, anzahl)
        return target
    }

    /// Verschiebt eine Anzahl Flaschen von einem Lagerort zu einem anderen.
    static func move(
        product: Product,
        from quelle: Location,
        to ziel: Location,
        anzahl: Int,
        context: ModelContext
    ) {
        guard quelle.persistentModelID != ziel.persistentModelID, anzahl > 0 else { return }
        guard let quellEintrag = entry(for: product, at: quelle) else { return }

        let bewegt = min(anzahl, quellEintrag.anzahl)
        guard bewegt > 0 else { return }
        quellEintrag.anzahl -= bewegt

        book(product: product, location: ziel, anzahl: bewegt, context: context)
        cleanupIfEmpty(quellEintrag, context: context)
    }

    /// Entnimmt (verbraucht) eine Anzahl Flaschen aus einem Lagerort.
    /// Der Bestand sinkt entsprechend; leere Einträge werden entfernt.
    static func consume(
        product: Product,
        at location: Location,
        anzahl: Int,
        context: ModelContext
    ) {
        guard anzahl > 0, let eintrag = entry(for: product, at: location) else { return }
        let entnommen = min(anzahl, eintrag.anzahl)
        guard entnommen > 0 else { return }
        eintrag.anzahl -= entnommen
        cleanupIfEmpty(eintrag, context: context)
    }

    /// Entfernt einen StockEntry, wenn er keinen Bestand mehr enthält.
    /// SwiftData entfernt ihn dabei automatisch aus den inversen Beziehungen.
    static func cleanupIfEmpty(_ entry: StockEntry, context: ModelContext) {
        guard entry.istLeer else { return }
        context.delete(entry)
    }
}
