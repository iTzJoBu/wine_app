import Foundation
import SwiftData

/// Verknüpft ein `Product` mit einem `Location` und führt den dortigen Bestand
/// getrennt nach ganzen Kartons und losen Einzelflaschen.
@Model
final class StockEntry {
    /// Zugehöriges Produkt.
    var product: Product?
    /// Zugehöriger Lagerort.
    var location: Location?
    /// Anzahl ganzer Kartons an diesem Ort.
    var kartons: Int
    /// Anzahl loser Einzelflaschen an diesem Ort.
    var einzelflaschen: Int

    init(product: Product? = nil, location: Location? = nil, kartons: Int = 0, einzelflaschen: Int = 0) {
        self.product = product
        self.location = location
        self.kartons = kartons
        self.einzelflaschen = einzelflaschen
    }

    /// Flaschen pro Karton dieses Produkts (Fallback 6, falls Produkt fehlt).
    var flaschenProKarton: Int {
        product?.flaschenProKarton ?? 6
    }

    /// Gesamtflaschen an diesem Ort = Kartons × Flaschen/Karton + Einzelflaschen.
    var gesamtflaschen: Int {
        kartons * flaschenProKarton + einzelflaschen
    }

    /// Ob dieser Eintrag leer ist (kann dann entfernt werden).
    var istLeer: Bool {
        kartons <= 0 && einzelflaschen <= 0
    }

    /// Beschreibung wie "1 Karton (6) + 2 Flaschen = 8".
    var beschreibung: String {
        var teile: [String] = []
        if kartons > 0 {
            let kartonWort = kartons == 1 ? "Karton" : "Kartons"
            teile.append("\(kartons) \(kartonWort) (\(kartons * flaschenProKarton))")
        }
        if einzelflaschen > 0 {
            let flaschenWort = einzelflaschen == 1 ? "Flasche" : "Flaschen"
            teile.append("\(einzelflaschen) \(flaschenWort)")
        }
        if teile.isEmpty {
            return "leer"
        }
        let zusammen = teile.joined(separator: " + ")
        return teile.count > 1 ? "\(zusammen) = \(gesamtflaschen)" : zusammen
    }
}
