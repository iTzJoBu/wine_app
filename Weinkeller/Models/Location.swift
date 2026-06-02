import Foundation
import SwiftData

/// Ein Lagerort (z. B. "Keller", "Garage", "Weinkühlschrank") mit Kapazität.
@Model
final class Location {
    /// Name des Lagerorts.
    var name: String
    /// Wie viele Flaschen hier hineinpassen.
    var kapazitaet: Int
    /// Optionale Notiz.
    var notiz: String?
    /// Anlegedatum (für stabile Sortierung).
    var dateAdded: Date

    /// Welche Bestände aktuell hier liegen.
    @Relationship(deleteRule: .cascade, inverse: \StockEntry.location)
    var stockEntries: [StockEntry] = []

    init(name: String = "", kapazitaet: Int = 24, notiz: String? = nil, dateAdded: Date = .now) {
        self.name = name
        self.kapazitaet = kapazitaet
        self.notiz = notiz
        self.dateAdded = dateAdded
    }

    /// Aktuell hier eingelagerte Flaschen.
    var belegteFlaschen: Int {
        stockEntries.reduce(0) { $0 + $1.gesamtflaschen }
    }

    /// Noch freie Plätze (nie negativ).
    var freieKapazitaet: Int {
        max(0, kapazitaet - belegteFlaschen)
    }

    /// Ob mehr eingelagert ist, als hineinpasst.
    var istUeberbelegt: Bool {
        belegteFlaschen > kapazitaet
    }

    /// Kurzanzeige der Belegung, z. B. "12 / 24".
    var belegungsText: String {
        "\(belegteFlaschen) / \(kapazitaet)"
    }
}
