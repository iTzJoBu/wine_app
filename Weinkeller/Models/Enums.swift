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
        // Dunkles Bordeaux statt knalligem Rot.
        case .rot: return Color(red: 0.40, green: 0.07, blue: 0.13)
        case .weiss: return Color(red: 0.85, green: 0.8, blue: 0.4)
        // Helleres, kräftigeres Rosa.
        case .rose: return Color(red: 0.97, green: 0.72, blue: 0.80)
        case .keine: return .secondary
        }
    }

    /// Ordnet einen KI-/Freitextwert einer Farbe zu (nil = unbekannt/leer).
    static func fromAI(_ raw: String) -> WineColor? {
        let n = raw.lowercased()
        if n.isEmpty { return nil }
        if n.contains("rot") || n.contains("red") { return .rot }
        if n.contains("weiß") || n.contains("weiss") || n.contains("white") { return .weiss }
        if n.contains("rosé") || n.contains("rose") || n.contains("pink") { return .rose }
        return nil
    }
}

/// Verschlussart einer Flasche. Wird – falls möglich – von der KI miterkannt.
enum ClosureType: String, Codable, CaseIterable, Identifiable {
    case korken = "Korken"
    case schraubverschluss = "Schraubverschluss"
    case kronkorken = "Kronkorken"
    case keine = "keine Angabe"

    var id: String { rawValue }

    /// Ordnet einen KI-/Freitextwert einer Verschlussart zu (nil = unbekannt/leer).
    static func fromAI(_ raw: String) -> ClosureType? {
        let n = raw.lowercased()
        if n.isEmpty { return nil }
        if n.contains("schraub") || n.contains("screw") { return .schraubverschluss }
        if n.contains("kron") || n.contains("crown") { return .kronkorken }
        if n.contains("kork") || n.contains("cork") { return .korken }
        return nil
    }
}

/// Wählbarer KI-Anbieter (bestimmt die bevorzugte Reihenfolge; bei Fehlern wird
/// automatisch auf den jeweils anderen Anbieter mit hinterlegtem Schlüssel zurückgefallen).
enum AIProvider: String, CaseIterable, Identifiable {
    case gemini = "gemini"
    case anthropic = "anthropic"

    var id: String { rawValue }

    var anzeigeName: String {
        switch self {
        case .gemini: return "Google Gemini"
        case .anthropic: return "Anthropic Claude"
        }
    }
}

/// Verwaltet die Liste der verfügbaren "Arten" (Wein, Sekt, …).
/// Es gibt fest eingebaute Arten (einzeln deaktivierbar) und eigene Arten
/// (z. B. Crémant, Cava). Beide Listen werden als zeilenweise Strings in den
/// App-Einstellungen (@AppStorage) gespeichert.
enum ArtStore {
    static let builtIn = ["Wein", "Sekt", "Champagner", "Prosecco"]

    /// Liefert die tatsächlich auswählbaren Arten: eingebaute (ohne die
    /// deaktivierten) gefolgt von den eigenen, ohne Dubletten. Ist die Liste
    /// leer, wird als Sicherheitsnetz ["Wein"] zurückgegeben, damit Picker nie
    /// ohne Auswahl dastehen.
    static func effective(custom rawCustom: String, deaktiviert rawDeaktiviert: String) -> [String] {
        let deaktiviert = Set(parse(rawDeaktiviert))
        var result = builtIn.filter { !deaktiviert.contains($0) }
        for art in parse(rawCustom) where !result.contains(art) {
            result.append(art)
        }
        return result.isEmpty ? ["Wein"] : result
    }

    /// Zerlegt den gespeicherten Roh-String (ein Eintrag pro Zeile) in eine Liste.
    static func parse(_ raw: String) -> [String] {
        raw.split(separator: "\n")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
    }

    /// Setzt eine Liste wieder zu einem Roh-String zusammen.
    static func join(_ list: [String]) -> String {
        list.map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
            .joined(separator: "\n")
    }

    /// Ordnet einen KI-/Freitextwert einer BEREITS VORHANDENEN Art zu.
    /// Liefert nil, wenn keine passende Art existiert – es werden NIEMALS
    /// selbstständig neue Arten/Klassen angelegt.
    static func match(_ raw: String, in arten: [String]) -> String? {
        let n = raw.trimmingCharacters(in: .whitespaces)
        guard !n.isEmpty else { return nil }
        return arten.first { $0.caseInsensitiveCompare(n) == .orderedSame }
    }
}

/// Zentrale Schlüssel für @AppStorage, damit es keine Tippfehler gibt.
enum SettingsKey {
    static let aiProvider = "aiProvider"
    static let geminiAPIKey = "geminiAPIKey"
    static let anthropicAPIKey = "anthropicAPIKey"
    static let customArten = "customArten"
    static let deaktivierteArten = "deaktivierteArten"
}
