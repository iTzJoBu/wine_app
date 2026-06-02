import Foundation

/// Geschätzte Token-Preise für das Modell claude-opus-4-8.
/// Bewusst als anpassbare Konstanten gehalten – falls Anthropic die Preise
/// ändert, hier einfach die Werte aktualisieren. Alle Angaben in USD pro 1
/// Million Token.
enum ClaudePricing {
    /// Preis für Eingabe-Token (USD je 1 Mio. Token).
    static let inputUSDPerMillion: Double = 15.0
    /// Preis für Ausgabe-Token (USD je 1 Mio. Token).
    static let outputUSDPerMillion: Double = 75.0

    /// Schätzt die Kosten einer Anfrage aus den verbrauchten Token.
    static func estimate(inputTokens: Int, outputTokens: Int) -> Double {
        let input = Double(inputTokens) / 1_000_000.0 * inputUSDPerMillion
        let output = Double(outputTokens) / 1_000_000.0 * outputUSDPerMillion
        return input + output
    }
}
