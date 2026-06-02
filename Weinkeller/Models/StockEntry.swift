import Foundation
import SwiftData

/// Verknüpft ein `Product` mit einem `Location` und führt den dortigen Bestand
/// ausschließlich in einzelnen Flaschen (keine Kartons mehr).
@Model
final class StockEntry {
    /// Zugehöriges Produkt.
    var product: Product?
    /// Zugehöriger Lagerort.
    var location: Location?
    /// Anzahl Flaschen an diesem Ort.
    var anzahl: Int

    init(product: Product? = nil, location: Location? = nil, anzahl: Int = 0) {
        self.product = product
        self.location = location
        self.anzahl = anzahl
    }

    /// Ob dieser Eintrag leer ist (kann dann entfernt werden).
    var istLeer: Bool {
        anzahl <= 0
    }

    /// Beschreibung wie "8 Flaschen".
    var beschreibung: String {
        if anzahl <= 0 { return "leer" }
        return "\(anzahl) \(anzahl == 1 ? "Flasche" : "Flaschen")"
    }
}
