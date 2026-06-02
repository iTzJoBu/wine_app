import Foundation
import SwiftUI
import SwiftData
import UniformTypeIdentifiers

// MARK: - Übertragungsobjekte (DTOs) für das JSON-Backup

struct BackupData: Codable {
    var version: Int = 1
    var exportiertAm: Date = .now
    var locations: [LocationDTO] = []
    var products: [ProductDTO] = []
}

struct LocationDTO: Codable {
    var name: String
    var kapazitaet: Int?
    var notiz: String?
}

struct ProductDTO: Codable {
    var sorte: String
    var winzer: String
    var jahrgang: String
    var farbe: String
    var art: String
    var alkoholfrei: Bool
    var ean: String
    var flaschenProKarton: Int
    var anzeigebildBase64: String?
    var erkannterText: String
    var erkannteBarcodes: [String]
    var bestaende: [StockDTO]
}

struct StockDTO: Codable {
    var lagerort: String
    var kartons: Int
    var einzelflaschen: Int
}

// MARK: - Export / Import

/// Sichert und importiert den kompletten Bestand als JSON (inkl. Anzeigebilder).
enum BackupService {

    /// Baut aus dem aktuellen Datenbestand das Backup-Objekt.
    static func makeBackup(products: [Product], locations: [Location]) -> BackupData {
        let locDTOs = locations.map {
            LocationDTO(name: $0.name, kapazitaet: $0.kapazitaet, notiz: $0.notiz)
        }
        let prodDTOs = products.map { p in
            ProductDTO(
                sorte: p.sorte,
                winzer: p.winzer,
                jahrgang: p.jahrgang,
                farbe: p.farbeRaw,
                art: p.art,
                alkoholfrei: p.alkoholfrei,
                ean: p.ean,
                flaschenProKarton: p.flaschenProKarton,
                anzeigebildBase64: p.anzeigebildData?.base64EncodedString(),
                erkannterText: p.erkannterText,
                erkannteBarcodes: p.erkannteBarcodes,
                bestaende: p.stockEntries.filter { !$0.istLeer }.map { e in
                    StockDTO(lagerort: e.location?.name ?? "", kartons: e.kartons, einzelflaschen: e.einzelflaschen)
                }
            )
        }
        return BackupData(locations: locDTOs, products: prodDTOs)
    }

    static func encode(_ backup: BackupData) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return try encoder.encode(backup)
    }

    static func decode(_ data: Data) throws -> BackupData {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(BackupData.self, from: data)
    }

    /// Importiert ein Backup im Modus „Zusammenführen". Damit kein Bestand
    /// doppelt gezählt wird, gilt:
    /// - Ein Produkt gilt nur dann als bereits vorhanden, wenn die EAN exakt
    ///   übereinstimmt ODER Sorte + Winzer + Jahrgang (normalisiert) gleich sind.
    /// - Ein Bestandseintrag wird nur gebucht, wenn nicht bereits ein identischer
    ///   Eintrag existiert (gleicher Lagerort, gleiche Kartons + Einzelflaschen).
    ///   So bleibt ein erneuter Import desselben Backups wirkungslos.
    static func merge(
        _ backup: BackupData,
        into context: ModelContext,
        existingProducts: [Product],
        existingLocations: [Location]
    ) {
        var locByName: [String: Location] = [:]
        for l in existingLocations { locByName[l.name] = l }

        func location(named name: String, kapazitaet: Int?, notiz: String?) -> Location {
            if let vorhanden = locByName[name] { return vorhanden }
            let neu = Location(name: name, kapazitaet: kapazitaet, notiz: notiz)
            context.insert(neu)
            locByName[name] = neu
            return neu
        }

        // Zuerst alle Lagerorte aus dem Backup sicherstellen.
        for l in backup.locations {
            _ = location(named: l.name, kapazitaet: l.kapazitaet, notiz: l.notiz)
        }

        var aktuelleProdukte = existingProducts
        for pdto in backup.products {
            let product: Product
            if let match = strictMatch(in: aktuelleProdukte, dto: pdto) {
                product = match
            } else {
                let neu = Product(
                    sorte: pdto.sorte,
                    winzer: pdto.winzer,
                    jahrgang: pdto.jahrgang,
                    farbe: WineColor(rawValue: pdto.farbe) ?? .keine,
                    art: pdto.art,
                    alkoholfrei: pdto.alkoholfrei,
                    ean: pdto.ean,
                    flaschenProKarton: pdto.flaschenProKarton,
                    anzeigebildData: pdto.anzeigebildBase64.flatMap { Data(base64Encoded: $0) },
                    erkannterText: pdto.erkannterText,
                    erkannteBarcodes: pdto.erkannteBarcodes
                )
                context.insert(neu)
                aktuelleProdukte.append(neu)
                product = neu
            }

            for s in pdto.bestaende where !s.lagerort.isEmpty {
                let loc = location(named: s.lagerort, kapazitaet: nil, notiz: nil)
                // Identischer Eintrag schon vorhanden? Dann nicht erneut buchen.
                if let vorhanden = StockService.entry(for: product, at: loc),
                   vorhanden.kartons == s.kartons,
                   vorhanden.einzelflaschen == s.einzelflaschen {
                    continue
                }
                if s.kartons > 0 {
                    StockService.book(product: product, location: loc, unit: .karton, menge: s.kartons, context: context)
                }
                if s.einzelflaschen > 0 {
                    StockService.book(product: product, location: loc, unit: .flasche, menge: s.einzelflaschen, context: context)
                }
            }
        }
    }

    /// Strenger Produktabgleich für den Import: exakte EAN ODER gleiche
    /// (normalisierte) Sorte + Winzer + Jahrgang. Bewusst ohne Textähnlichkeit,
    /// damit nur wirklich identische Produkte zusammengeführt werden.
    private static func strictMatch(in products: [Product], dto: ProductDTO) -> Product? {
        let ean = dto.ean.trimmingCharacters(in: .whitespaces)
        let nWinzer = ProductMatcher.normalize(dto.winzer)
        let nSorte = ProductMatcher.normalize(dto.sorte)
        let nJahrgang = ProductMatcher.normalize(dto.jahrgang)

        return products.first { p in
            if !ean.isEmpty, p.ean.trimmingCharacters(in: .whitespaces) == ean {
                return true
            }
            return ProductMatcher.normalize(p.winzer) == nWinzer
                && ProductMatcher.normalize(p.sorte) == nSorte
                && ProductMatcher.normalize(p.jahrgang) == nJahrgang
        }
    }
}

/// Dokument zum Speichern/Öffnen des JSON-Backups über die Systemdialoge.
struct BackupDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.json] }

    var data: Data

    init(data: Data) { self.data = data }

    init(configuration: ReadConfiguration) throws {
        guard let inhalt = configuration.file.regularFileContents else {
            throw CocoaError(.fileReadCorruptFile)
        }
        data = inhalt
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: data)
    }
}
