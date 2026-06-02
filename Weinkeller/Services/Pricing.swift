import Foundation

/// Geschätzte Token-Preise je Anbieter/Modell.
/// Bewusst als anpassbare Konstanten gehalten – falls sich die Preise ändern,
/// hier einfach aktualisieren. Alle Angaben in USD pro 1 Million Token.
enum AIPricing {
    // Google Gemini (gemini-3.1-flash-lite – Richtwerte).
    static let geminiInputUSDPerMillion: Double = 0.10
    static let geminiOutputUSDPerMillion: Double = 0.40

    // Anthropic Claude (claude-opus-4-8).
    static let claudeInputUSDPerMillion: Double = 15.0
    static let claudeOutputUSDPerMillion: Double = 75.0

    /// Preise (Input, Output) je 1 Mio. Token für einen Anbieter.
    static func preise(for provider: AIProvider) -> (input: Double, output: Double) {
        switch provider {
        case .gemini: return (geminiInputUSDPerMillion, geminiOutputUSDPerMillion)
        case .anthropic: return (claudeInputUSDPerMillion, claudeOutputUSDPerMillion)
        }
    }

    /// Schätzt die Kosten einer Anfrage aus den verbrauchten Token.
    static func estimate(provider: AIProvider, inputTokens: Int, outputTokens: Int) -> Double {
        let p = preise(for: provider)
        let input = Double(inputTokens) / 1_000_000.0 * p.input
        let output = Double(outputTokens) / 1_000_000.0 * p.output
        return input + output
    }
}
