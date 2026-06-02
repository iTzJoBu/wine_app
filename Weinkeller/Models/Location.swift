import Foundation
import SwiftData

/// Ein Lagerort (z. B. "Keller", "Garage", "Weinkühlschrank") mit Kapazität.
@Model
final class Location {
    /// Name des Lagerorts.
    var name: String
    /// Wie viele Flaschen hier hineinpassen. Optional – ohne Angabe gilt der
    /// Lagerort als unbegrenzt (keine Überbelegung).
    var kapazitaet: Int?
    /// Optionale Notiz.
    var notiz: String?
    /// Anlegedatum (für stabile Sortierung).
    var dateAdded: Date

    /// Welche Bestände aktuell hier liegen.
    @Relationship(deleteRule: .cascade, inverse: \StockEntry.location)
    var stockEntries: [StockEntry] = []

    init(name: String = "", kapazitaet: Int? = nil, notiz: String? = nil, dateAdded: Date = .now) {
        self.name = name
        self.kapazitaet = kapazitaet
        self.notiz = notiz
        self.dateAdded = dateAdded
    }

    /// Aktuell hier eingelagerte Flaschen.
    var belegteFlaschen: Int {
        stockEntries.reduce(0) { $0 + $1.gesamtflaschen }
    }

    /// Noch freie Plätze (nil = unbegrenzt), nie negativ.
    var freieKapazitaet: Int? {
        guard let kapazitaet else { return nil }
        return max(0, kapazitaet - belegteFlaschen)
    }

    /// Ob mehr eingelagert ist, als hineinpasst (nur bei gesetzter Kapazität).
    var istUeberbelegt: Bool {
        guard let kapazitaet else { return false }
        return belegteFlaschen > kapazitaet
    }

    /// Kurzanzeige der Belegung, z. B. "12 / 24" oder "12" (ohne Limit).
    var belegungsText: String {
        if let kapazitaet {
            return "\(belegteFlaschen) / \(kapazitaet)"
        }
        return "\(belegteFlaschen)"
    }
}
