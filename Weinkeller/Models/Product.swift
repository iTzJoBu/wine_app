import Foundation
import SwiftData

/// Ein Getränk (Wein, Sekt, …) als eindeutiger Eintrag im Keller.
/// Verschiedene Jahrgänge desselben Weins sind bewusst verschiedene Produkte.
/// Der konkrete Bestand wird nicht hier, sondern über `StockEntry` je Lagerort geführt.
@Model
final class Product {
    /// Sorte oder Produktname, z. B. "Riesling trocken".
    var sorte: String
    /// Winzer / Weingut, z. B. "Weingut Müller".
    var winzer: String
    /// Jahrgang als Text (Text, damit z. B. "o. J." möglich ist).
    var jahrgang: String

    /// Farbe (rot/weiß/rosé/–) – intern als Rohwert gespeichert.
    var farbeRaw: String
    /// Art (Sekt/Champagner/Prosecco/Wein/… – erweiterbar) als Text.
    var art: String
    /// Alkoholfrei ja/nein.
    var alkoholfrei: Bool

    /// EAN-/Barcode der Einzelflasche.
    var ean: String
    /// Anzahl Flaschen pro Karton (Standard 6).
    var flaschenProKarton: Int

    /// Genau EIN Anzeigebild pro Produkt (JPEG, ausgelagert gespeichert).
    @Attribute(.externalStorage) var anzeigebildData: Data?

    // MARK: Versteckte Felder für die Offline-Wiedererkennung
    /// Der beim Anlegen offline erkannte Text (OCR). Nicht in der UI sichtbar,
    /// dient nur dem Abgleich bei neuen Scans.
    var erkannterText: String
    /// Offline erkannte Barcodes. Ebenfalls nur für den Abgleich.
    var erkannteBarcodes: [String]

    /// Zeitpunkt des Anlegens (für die Sortierung).
    var dateAdded: Date

    /// Ein Produkt kann an mehreren Lagerorten liegen – je Ort ein `StockEntry`.
    @Relationship(deleteRule: .cascade, inverse: \StockEntry.product)
    var stockEntries: [StockEntry] = []

    /// Komfort-Zugriff auf die Farbe als Aufzählung.
    var farbe: WineColor {
        get { WineColor(rawValue: farbeRaw) ?? .keine }
        set { farbeRaw = newValue.rawValue }
    }

    /// Gesamtzahl aller Flaschen dieses Produkts über alle Lagerorte.
    var gesamtflaschen: Int {
        stockEntries.reduce(0) { $0 + $1.gesamtflaschen }
    }

    init(
        sorte: String = "",
        winzer: String = "",
        jahrgang: String = "",
        farbe: WineColor = .keine,
        art: String = "Wein",
        alkoholfrei: Bool = false,
        ean: String = "",
        flaschenProKarton: Int = 6,
        anzeigebildData: Data? = nil,
        erkannterText: String = "",
        erkannteBarcodes: [String] = [],
        dateAdded: Date = .now
    ) {
        self.sorte = sorte
        self.winzer = winzer
        self.jahrgang = jahrgang
        self.farbeRaw = farbe.rawValue
        self.art = art
        self.alkoholfrei = alkoholfrei
        self.ean = ean
        self.flaschenProKarton = flaschenProKarton
        self.anzeigebildData = anzeigebildData
        self.erkannterText = erkannterText
        self.erkannteBarcodes = erkannteBarcodes
        self.dateAdded = dateAdded
    }
}
