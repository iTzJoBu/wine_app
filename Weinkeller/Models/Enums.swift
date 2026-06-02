import Foundation
import SwiftUI

/// Farbe eines Getränks. Bewusst getrennt von der "Art" (siehe unten),
/// damit z. B. ein "rosé Sekt" beide Eigenschaften haben kann.
enum WineColor: String, Codable, CaseIterable, Identifiable {
    case rot = "rot"
    case weiss = "weiß"
    case rose = "rosé"
    case keine = "–"

    var id: String { rawValue }

    /// Anzeigefarbe für kleine Punkte/Markierungen in der Liste.
    var swatch: Color {
        switch self {
        case .rot: return .red
        case .weiss: return Color(red: 0.85, green: 0.8, blue: 0.4)
        case .rose: return .pink
        case .keine: return .secondary
        }
    }
}

/// Einheit beim Buchen/Verschieben von Beständen.
enum StockUnit: String, CaseIterable, Identifiable {
    case flasche = "Flasche"
    case karton = "Karton"

    var id: String { rawValue }
}

/// Wählbarer KI-Anbieter.
enum AIProvider: String, CaseIterable, Identifiable {
    case gemini = "gemini"
    case anthropic = "anthropic"

    var id: String { rawValue }

    var anzeigeName: String {
        switch self {
        case .gemini: return "Google Gemini (kostenlos)"
        case .anthropic: return "Anthropic Claude"
        }
    }
}

/// Verwaltet die Liste der verfügbaren "Arten" (Wein, Sekt, …).
/// Die fest eingebauten Arten sind immer vorhanden; eigene Arten
/// (z. B. Crémant, Cava) werden in den Einstellungen ergänzt und als
/// zeilenweise Liste in den App-Einstellungen (@AppStorage) gespeichert.
enum ArtStore {
    static let builtIn = ["Wein", "Sekt", "Champagner", "Prosecco"]

    /// Liefert eingebaute + eigene Arten ohne Dubletten.
    static func all(custom raw: String) -> [String] {
        let customList = parse(raw)
        var result = builtIn
        for art in customList where !result.contains(art) {
            result.append(art)
        }
        return result
    }

    /// Zerlegt den gespeicherten Roh-String (eine Art pro Zeile) in eine Liste.
    static func parse(_ raw: String) -> [String] {
        raw.split(separator: "\n")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
    }

    /// Setzt eine Liste eigener Arten wieder zu einem Roh-String zusammen.
    static func join(_ list: [String]) -> String {
        list.map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
            .joined(separator: "\n")
    }
}

/// Zentrale Schlüssel für @AppStorage, damit es keine Tippfehler gibt.
enum SettingsKey {
    static let aiProvider = "aiProvider"
    static let geminiAPIKey = "geminiAPIKey"
    static let anthropicAPIKey = "anthropicAPIKey"
    static let customArten = "customArten"
}
