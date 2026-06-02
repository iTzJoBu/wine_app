import Foundation
import SwiftData

/// Art der Flasche – Wein oder Sekt.
enum BottleType: String, Codable, CaseIterable, Identifiable {
    case wein = "Wein"
    case sekt = "Sekt"

    var id: String { rawValue }
}

/// Eine einzelne Position im Weinkeller. Jede Flasche (bzw. jeder Posten mit
/// einer bestimmten Anzahl) wird als eigenes Objekt in der Datenbank gespeichert.
@Model
final class Bottle {
    /// Winzer / Weingut, z. B. "Weingut Müller".
    var winzer: String
    /// Sorte oder Produktname, z. B. "Riesling trocken".
    var sorte: String
    /// Jahrgang als Text (Text, damit z. B. "o. J." bei Sekt möglich ist).
    var jahrgang: String
    /// Intern gespeicherte Art (siehe `typ`).
    var typRaw: String
    /// EAN-/Barcode-Nummer vom Etikett.
    var ean: String
    /// Anzahl der Flaschen dieses Postens.
    var quantity: Int
    /// Lagerort im Keller, z. B. "Regal 3, Fach B". Kann auch später ergänzt werden.
    var lagerort: String
    /// Freie Notiz.
    var notiz: String
    /// Das aufgenommene Etiketten-Foto (als JPEG). Wird ausgelagert gespeichert.
    @Attribute(.externalStorage) var bildData: Data?
    /// Zeitpunkt des Hinzufügens (für die Sortierung).
    var dateAdded: Date

    /// Komfort-Zugriff auf die Art als Aufzählung.
    var typ: BottleType {
        get { BottleType(rawValue: typRaw) ?? .wein }
        set { typRaw = newValue.rawValue }
    }

    init(
        winzer: String = "",
        sorte: String = "",
        jahrgang: String = "",
        typ: BottleType = .wein,
        ean: String = "",
        quantity: Int = 1,
        lagerort: String = "",
        notiz: String = "",
        bildData: Data? = nil,
        dateAdded: Date = .now
    ) {
        self.winzer = winzer
        self.sorte = sorte
        self.jahrgang = jahrgang
        self.typRaw = typ.rawValue
        self.ean = ean
        self.quantity = quantity
        self.lagerort = lagerort
        self.notiz = notiz
        self.bildData = bildData
        self.dateAdded = dateAdded
    }
}
