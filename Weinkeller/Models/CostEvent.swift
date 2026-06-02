import Foundation
import SwiftData

/// Einzelne (geschätzte) Kostenbuchung für eine KI-Anfrage.
/// Wird für beide Anbieter (Gemini & Anthropic) erzeugt, sofern der Anbieter
/// einen Tokenverbrauch zurückmeldet.
@Model
final class CostEvent {
    var datum: Date
    /// Anbieter als Rohwert (siehe `AIProvider`).
    var anbieter: String
    var inputTokens: Int
    var outputTokens: Int
    /// Geschätzte Kosten in US-Dollar.
    var kostenUSD: Double

    init(datum: Date = .now, anbieter: String = "", inputTokens: Int, outputTokens: Int, kostenUSD: Double) {
        self.datum = datum
        self.anbieter = anbieter
        self.inputTokens = inputTokens
        self.outputTokens = outputTokens
        self.kostenUSD = kostenUSD
    }
}
