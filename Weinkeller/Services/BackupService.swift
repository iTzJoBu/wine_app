import Foundation
import SwiftUI
import SwiftData
import UniformTypeIdentifiers

// MARK: - Übertragungsobjekte (DTOs) für das JSON-Backup
//
// Grundsatz: ALLE Felder sind optional und werden beim Import defensiv mit
// sinnvollen Standardwerten ausgewertet. So führt weder ein fehlendes noch ein
// unbekanntes Feld zu einem Absturz, und neue Felder können künftig ohne Bruch
// ergänzt werden. Die Versionierung erfolgt über `schemaVersion`.

struct BackupData: Codable {
    /// Aktuelle Schema-Version (siehe `BackupService.currentSchemaVersion`).
    var schemaVersion: Int? = nil
    /// App-Version zum Zeitpunkt des Exports (rein informativ).
    var appVersion: String? = nil
    /// Legacy-Feld älterer Exporte (vor Einführung von `schemaVersion`).
    var version: Int? = nil
    var exportiertAm: Date? = nil
    var locations: [LocationDTO]? = nil
    var products: [ProductDTO]? = nil
    var einstellungen: SettingsDTO? = nil
}

struct SettingsDTO: Codable {
    var aiProvider: String? = nil
    var geminiAPIKey: String? = nil
    var anthropicAPIKey: String? = nil
    var customArten: String? = nil
    var deaktivierteArten: String? = nil
}

struct LocationDTO: Codable {
    var name: String? = nil
    var kapazitaet: Int? = nil
    var notiz: String? = nil
}

struct ProductDTO: Codable {
    var sorte: String? = nil
    var winzer: String? = nil
    var jahrgang: String? = nil
    var farbe: String? = nil
    var art: String? = nil
    var alkoholfrei: Bool? = nil
    var verschluss: String? = nil
    var ean: String? = nil
    var notiz: String? = nil
    var favorit: Bool? = nil
    var beliebtBei: String? = nil
    var anzeigebildBase64: String? = nil
    var erkannterText: String? = nil
    var erkannteBarcodes: [String]? = nil
    var bestaende: [StockDTO]? = nil

    // Legacy-Felder (vor dem Entfernen der Kartons):
    var flaschenProKarton: Int? = nil
    /// Sehr alte Exporte hatten evtl. einen einzelnen Lagerort als Text.
    var lagerort: String? = nil
}

struct StockDTO: Codable {
    var lagerort: String? = nil
    /// Neu: reine Flaschenanzahl.
    var anzahl: Int? = nil

    // Legacy-Felder (Karton-basiert):
    var kartons: Int? = nil
    var einzelflaschen: Int? = nil
}

/// Ergebnis eines Imports für die Rückmeldung an den Nutzer.
struct ImportSummary {
    var produkte: Int
    var lagerorte: Int
    var klassen: Int
    /// Gesetzt, falls die Datei eine neuere Schema-Version hat, als die App kennt.
    var neuereVersionHinweis: Bool
}

// MARK: - Export / Import

/// Sichert und importiert ALLE Daten als JSON (Produkte inkl. Bilder, Lagerorte,
/// manuell ergänzte Klassen/Arten und die hinterlegten API-Schlüssel).
enum BackupService {

    /// Aktuelle Schema-Version der Export-Datei. Bei künftigen Modelländerungen
    /// IMMER erhöhen UND eine passende Migration in `migrate` ergänzen.
    static let currentSchemaVersion = 1

    /// App-Version (rein informativ in der Datei).
    static let appVersion = "1.0"

    // MARK: Export

    /// Baut aus dem aktuellen Datenbestand das Backup-Objekt.
    static func makeBackup(
        products: [Product],
        locations: [Location],
        einstellungen: SettingsDTO
    ) -> BackupData {
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
                verschluss: p.verschlussRaw,
                ean: p.ean,
                notiz: p.notiz,
                favorit: p.favorit,
                beliebtBei: p.beliebtBei,
                anzeigebildBase64: p.anzeigebildData?.base64EncodedString(),
                erkannterText: p.erkannterText,
                erkannteBarcodes: p.erkannteBarcodes,
                bestaende: p.stockEntries.filter { !$0.istLeer }.map { e in
                    StockDTO(lagerort: e.location?.name, anzahl: e.anzahl)
                },
                flaschenProKarton: nil,
                lagerort: nil
            )
        }
        return BackupData(
            schemaVersion: currentSchemaVersion,
            appVersion: appVersion,
            version: nil,
            exportiertAm: .now,
            locations: locDTOs,
            products: prodDTOs,
            einstellungen: einstellungen
        )
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
        // Da alle Felder optional sind, wirft das Decodieren nur bei echtem
        // Format-Müll; unbekannte Felder werden ohnehin ignoriert.
        return try decoder.decode(BackupData.self, from: data)
    }

    // MARK: Versionierung / Migration

    /// Ermittelt die effektive Schema-Version einer Datei. Ältere Exporte ohne
    /// `schemaVersion` werden als Version 0 (Legacy) behandelt.
    private static func detectedVersion(_ backup: BackupData) -> Int {
        backup.schemaVersion ?? 0
    }

    /// Führt nötige Migrationen alter Strukturen durch und liefert ein Backup im
    /// AKTUELLEN Modell zurück. Für jede ältere Version eine eigene Stufe – beim
    /// Erhöhen von `currentSchemaVersion` hier eine weitere Stufe ergänzen.
    private static func migrate(_ backup: BackupData) -> BackupData {
        var version = detectedVersion(backup)
        var result = backup

        // Stufe 0 -> 1: Legacy-Exporte (Karton-basiert, evtl. einzelner Lagerort
        // als Text) auf das aktuelle Flaschen-Modell überführen.
        if version < 1 {
            result = migrateLegacyToV1(result)
            version = 1
        }

        // Künftige Stufen:
        // if version < 2 { result = migrateV1ToV2(result); version = 2 }

        return result
    }

    /// Überführt sehr alte/karton-basierte Produkte in das aktuelle Modell:
    /// - Karton-Bestände werden über `flaschenProKarton` in Flaschen umgerechnet.
    /// - Ein evtl. vorhandenes einzelnes `lagerort`-Textfeld wird zu einem
    ///   StockEntry mit Anzahl 0 (Bestand unbekannt) bzw. ignoriert, falls leer.
    private static func migrateLegacyToV1(_ backup: BackupData) -> BackupData {
        var result = backup
        result.products = (backup.products ?? []).map { p in
            var neu = p
            let fpk = max(1, p.flaschenProKarton ?? 6)
            var bestaende: [StockDTO] = (p.bestaende ?? []).map { s in
                let anzahl = s.anzahl ?? ((s.kartons ?? 0) * fpk + (s.einzelflaschen ?? 0))
                return StockDTO(lagerort: s.lagerort, anzahl: anzahl)
            }
            // Sehr alter Einzel-Lagerort als Text ohne explizite Bestände.
            if bestaende.isEmpty, let ort = p.lagerort?.trimmingCharacters(in: .whitespaces), !ort.isEmpty {
                bestaende = [StockDTO(lagerort: ort, anzahl: 0)]
            }
            neu.bestaende = bestaende
            neu.flaschenProKarton = nil
            neu.lagerort = nil
            return neu
        }
        return result
    }

    // MARK: Import

    /// Importiert ein Backup im Modus „Zusammenführen". Robust & abwärtskompatibel:
    /// - Migriert ältere Schema-Versionen vor dem Einlesen.
    /// - Ein Produkt gilt nur dann als vorhanden, wenn die EAN exakt übereinstimmt
    ///   ODER Sorte + Winzer + Jahrgang (normalisiert) gleich sind.
    /// - Ein Bestandseintrag wird nur gebucht, wenn nicht bereits ein identischer
    ///   Eintrag existiert (gleicher Lagerort, gleiche Anzahl) → erneuter Import
    ///   desselben Backups bleibt wirkungslos.
    /// - Stellt manuelle Arten/Klassen und API-Schlüssel wieder her.
    @discardableResult
    static func merge(
        _ rohBackup: BackupData,
        into context: ModelContext,
        existingProducts: [Product],
        existingLocations: [Location]
    ) -> ImportSummary {
        let neuereVersion = detectedVersion(rohBackup) > currentSchemaVersion
        let backup = migrate(rohBackup)

        // 1) Einstellungen / Klassen / Schlüssel wiederherstellen.
        let neueKlassen = restoreSettings(backup.einstellungen)

        // 2) Lagerorte.
        var locByName: [String: Location] = [:]
        for l in existingLocations where !l.name.isEmpty { locByName[l.name] = l }

        func location(named name: String, kapazitaet: Int?, notiz: String?) -> Location {
            if let vorhanden = locByName[name] { return vorhanden }
            let neu = Location(name: name, kapazitaet: kapazitaet, notiz: notiz)
            context.insert(neu)
            locByName[name] = neu
            return neu
        }

        for l in backup.locations ?? [] {
            let name = (l.name ?? "").trimmingCharacters(in: .whitespaces)
            guard !name.isEmpty else { continue }
            _ = location(named: name, kapazitaet: l.kapazitaet, notiz: l.notiz)
        }

        // 3) Produkte + Bestände.
        var aktuelleProdukte = existingProducts
        var importierteProdukte = 0
        for pdto in backup.products ?? [] {
            importierteProdukte += 1
            let product: Product
            if let match = strictMatch(in: aktuelleProdukte, dto: pdto) {
                product = match
            } else {
                let neu = Product(
                    sorte: (pdto.sorte ?? "").trimmingCharacters(in: .whitespacesAndNewlines),
                    winzer: (pdto.winzer ?? "").trimmingCharacters(in: .whitespacesAndNewlines),
                    jahrgang: (pdto.jahrgang ?? "").trimmingCharacters(in: .whitespacesAndNewlines),
                    farbe: WineColor(rawValue: pdto.farbe ?? "") ?? .keine,
                    art: pdto.art ?? "Wein",
                    alkoholfrei: pdto.alkoholfrei ?? false,
                    verschluss: ClosureType(rawValue: pdto.verschluss ?? "") ?? .keine,
                    ean: pdto.ean ?? "",
                    notiz: pdto.notiz ?? "",
                    favorit: pdto.favorit ?? false,
                    beliebtBei: pdto.beliebtBei ?? "",
                    anzeigebildData: (pdto.anzeigebildBase64).flatMap { Data(base64Encoded: $0) },
                    erkannterText: pdto.erkannterText ?? "",
                    erkannteBarcodes: pdto.erkannteBarcodes ?? []
                )
                context.insert(neu)
                aktuelleProdukte.append(neu)
                product = neu
            }

            for s in pdto.bestaende ?? [] {
                let ort = (s.lagerort ?? "").trimmingCharacters(in: .whitespaces)
                guard !ort.isEmpty else { continue }
                let anzahl = s.anzahl ?? ((s.kartons ?? 0) * max(1, pdto.flaschenProKarton ?? 6) + (s.einzelflaschen ?? 0))
                guard anzahl > 0 else { continue }
                let loc = location(named: ort, kapazitaet: nil, notiz: nil)
                // Identischer Eintrag schon vorhanden? Dann nicht erneut buchen.
                if let vorhanden = StockService.entry(for: product, at: loc), vorhanden.anzahl == anzahl {
                    continue
                }
                StockService.book(product: product, location: loc, anzahl: anzahl, context: context)
            }
        }

        return ImportSummary(
            produkte: importierteProdukte,
            lagerorte: locByName.count,
            klassen: neueKlassen,
            neuereVersionHinweis: neuereVersion
        )
    }

    /// Schreibt importierte Einstellungen (Anbieter, Schlüssel, Arten) zurück in
    /// die App-Einstellungen. Liefert die Anzahl neu hinzugefügter eigener Klassen.
    @discardableResult
    private static func restoreSettings(_ dto: SettingsDTO?) -> Int {
        guard let dto else { return 0 }
        let defaults = UserDefaults.standard

        if let p = dto.aiProvider, !p.isEmpty { defaults.set(p, forKey: SettingsKey.aiProvider) }
        if let k = dto.geminiAPIKey, !k.isEmpty { defaults.set(k, forKey: SettingsKey.geminiAPIKey) }
        if let k = dto.anthropicAPIKey, !k.isEmpty { defaults.set(k, forKey: SettingsKey.anthropicAPIKey) }
        if let d = dto.deaktivierteArten { defaults.set(d, forKey: SettingsKey.deaktivierteArten) }

        // Eigene Klassen zusammenführen (Dubletten vermeiden).
        var neueKlassen = 0
        if let importiert = dto.customArten {
            let bestehend = ArtStore.parse(defaults.string(forKey: SettingsKey.customArten) ?? "")
            var liste = bestehend
            for art in ArtStore.parse(importiert) where !liste.contains(art) && !ArtStore.builtIn.contains(art) {
                liste.append(art)
                neueKlassen += 1
            }
            defaults.set(ArtStore.join(liste), forKey: SettingsKey.customArten)
        }
        return neueKlassen
    }

    /// Strenger Produktabgleich für den Import: exakte EAN ODER gleiche
    /// (normalisierte) Sorte + Winzer + Jahrgang. Bewusst ohne Textähnlichkeit,
    /// damit nur wirklich identische Produkte zusammengeführt werden.
    private static func strictMatch(in products: [Product], dto: ProductDTO) -> Product? {
        let ean = (dto.ean ?? "").trimmingCharacters(in: .whitespaces)
        let nWinzer = ProductMatcher.normalize(dto.winzer ?? "")
        let nSorte = ProductMatcher.normalize(dto.sorte ?? "")
        let nJahrgang = ProductMatcher.normalize(dto.jahrgang ?? "")

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
