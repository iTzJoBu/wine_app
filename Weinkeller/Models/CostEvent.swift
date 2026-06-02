import Foundation
import SwiftData

/// Einzelne (geschätzte) Kostenbuchung für eine Claude-Anfrage.
/// Wird nur erzeugt, wenn als KI-Anbieter Anthropic gewählt ist.
@Model
final class CostEvent {
    var datum: Date
    var inputTokens: Int
    var outputTokens: Int
    /// Geschätzte Kosten in US-Dollar.
    var kostenUSD: Double

    init(datum: Date = .now, inputTokens: Int, outputTokens: Int, kostenUSD: Double) {
        self.datum = datum
        self.inputTokens = inputTokens
        self.outputTokens = outputTokens
        self.kostenUSD = kostenUSD
    }
}
