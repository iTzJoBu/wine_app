import UIKit

/// Vorschlag der KI für die Etikett-Erkennung.
struct WineAISuggestion: Decodable {
    var winzer: String?
    var sorte: String?
    var jahrgang: String?
    var farbe: String?
    var art: String?
    var verschluss: String?
}

/// Ergebnis eines KI-Aufrufs inkl. (optionalem) Tokenverbrauch für die Kostenschätzung.
struct WineAIResult {
    var suggestion: WineAISuggestion
    var provider: AIProvider
    var inputTokens: Int?
    var outputTokens: Int?
}

enum WineAIError: LocalizedError {
    case noAPIKey
    case requestFailed(String)

    var errorDescription: String? {
        switch self {
        case .noAPIKey:
            return "Kein API-Schlüssel hinterlegt. Bitte unter Einstellungen eintragen."
        case .requestFailed(let message):
            return message
        }
    }
}

/// Optionale KI-Erkennung. Primär wird Google Gemini (gemini-3.1-flash-lite)
/// verwendet; bei Fehlern/Kontingenten wird automatisch auf den jeweils anderen
/// Anbieter mit hinterlegtem Schlüssel zurückgefallen.
enum WineAIService {

    /// Gemini-Modelle in Reihenfolge: erst 3.1-flash-lite, dann dessen Preview.
    private static let geminiModelle = ["gemini-3.1-flash-lite", "gemini-3.1-flash-lite-preview"]

    /// Gemeinsamer Prompt für beide Anbieter.
    private static let prompt = """
    Analysiere das Wein- oder Sekt-Etikett auf dem Foto. Antworte AUSSCHLIESSLICH mit einem \
    JSON-Objekt, ohne weiteren Text, genau in diesem Format:
    {"sorte": "", "winzer": "", "jahrgang": "", "farbe": "rot|weiß|rosé|", "art": "Wein|Sekt|Champagner|Prosecco|…", "verschluss": "korken|schraubverschluss|kronkorken|"}
    Regeln: "farbe" nur aus {rot, weiß, rosé} oder leer. "verschluss" nur aus \
    {korken, schraubverschluss, kronkorken} oder leer. Lass einzelne Felder leer, wenn du sie \
    nicht sicher erkennen kannst.
    """

    /// Versucht die Erkennung. Reihenfolge: bevorzugter Anbieter zuerst, dann der
    /// andere als Fallback. Übersprungen wird, wofür kein Schlüssel hinterlegt ist.
    static func identify(image: UIImage) async throws -> WineAIResult {
        guard let jpeg = resized(image).jpegData(compressionQuality: 0.6) else {
            throw WineAIError.requestFailed("Bild konnte nicht verarbeitet werden.")
        }
        let base64 = jpeg.base64EncodedString()

        let providerRaw = UserDefaults.standard.string(forKey: SettingsKey.aiProvider) ?? AIProvider.gemini.rawValue
        let bevorzugt = AIProvider(rawValue: providerRaw) ?? .gemini
        // Bevorzugten Anbieter zuerst, danach den jeweils anderen als Fallback.
        let reihenfolge: [AIProvider] = bevorzugt == .gemini ? [.gemini, .anthropic] : [.anthropic, .gemini]

        var letzterFehler: Error?
        var hatteSchluessel = false
        for provider in reihenfolge {
            guard hatSchluessel(provider) else { continue }
            hatteSchluessel = true
            do {
                switch provider {
                case .gemini: return try await identifyWithGemini(base64: base64)
                case .anthropic: return try await identifyWithAnthropic(base64: base64)
                }
            } catch {
                // Anbieter nicht verfügbar / Kontingent erschöpft → nächsten versuchen.
                letzterFehler = error
                continue
            }
        }

        if !hatteSchluessel { throw WineAIError.noAPIKey }
        throw letzterFehler ?? WineAIError.requestFailed("Kein KI-Anbieter verfügbar.")
    }

    private static func hatSchluessel(_ provider: AIProvider) -> Bool {
        let key: String
        switch provider {
        case .gemini: key = UserDefaults.standard.string(forKey: SettingsKey.geminiAPIKey) ?? ""
        case .anthropic: key = UserDefaults.standard.string(forKey: SettingsKey.anthropicAPIKey) ?? ""
        }
        return !key.trimmingCharacters(in: .whitespaces).isEmpty
    }

    // MARK: - Google Gemini

    private static func identifyWithGemini(base64: String) async throws -> WineAIResult {
        let key = UserDefaults.standard.string(forKey: SettingsKey.geminiAPIKey) ?? ""
        guard !key.isEmpty else { throw WineAIError.noAPIKey }

        let payload: [String: Any] = [
            "contents": [[
                "parts": [
                    ["text": prompt],
                    ["inline_data": ["mime_type": "image/jpeg", "data": base64]]
                ]
            ]]
        ]
        let body = try JSONSerialization.data(withJSONObject: payload)

        var letzterFehler: Error?
        // Modell-Fallback: erst 3.1-flash-lite, dann dessen Preview.
        for modell in geminiModelle {
            let urlString = "https://generativelanguage.googleapis.com/v1beta/models/\(modell):generateContent"
            guard let url = URL(string: urlString) else { continue }

            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.setValue(key, forHTTPHeaderField: "x-goog-api-key")
            request.httpBody = body

            do {
                let data = try await send(request)
                guard
                    let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                    let candidates = json["candidates"] as? [[String: Any]],
                    let content = candidates.first?["content"] as? [String: Any],
                    let parts = content["parts"] as? [[String: Any]],
                    let text = parts.compactMap({ $0["text"] as? String }).first
                else {
                    throw WineAIError.requestFailed("Antwort von Gemini konnte nicht gelesen werden.")
                }

                let suggestion = try parseSuggestion(from: text)

                // Tokenverbrauch aus usageMetadata (promptTokenCount/candidatesTokenCount).
                var inputTokens: Int?
                var outputTokens: Int?
                if let usage = json["usageMetadata"] as? [String: Any] {
                    inputTokens = usage["promptTokenCount"] as? Int
                    outputTokens = usage["candidatesTokenCount"] as? Int
                }

                return WineAIResult(suggestion: suggestion, provider: .gemini, inputTokens: inputTokens, outputTokens: outputTokens)
            } catch {
                letzterFehler = error
                continue
            }
        }
        throw letzterFehler ?? WineAIError.requestFailed("Gemini nicht verfügbar.")
    }

    // MARK: - Anthropic Claude

    private static func identifyWithAnthropic(base64: String) async throws -> WineAIResult {
        let key = UserDefaults.standard.string(forKey: SettingsKey.anthropicAPIKey) ?? ""
        guard !key.isEmpty else { throw WineAIError.noAPIKey }

        let payload: [String: Any] = [
            "model": "claude-opus-4-8",
            "max_tokens": 400,
            "messages": [[
                "role": "user",
                "content": [
                    [
                        "type": "image",
                        "source": [
                            "type": "base64",
                            "media_type": "image/jpeg",
                            "data": base64
                        ]
                    ],
                    ["type": "text", "text": prompt]
                ]
            ]]
        ]

        var request = URLRequest(url: URL(string: "https://api.anthropic.com/v1/messages")!)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(key, forHTTPHeaderField: "x-api-key")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        request.httpBody = try JSONSerialization.data(withJSONObject: payload)

        let data = try await send(request)

        guard
            let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
            let content = json["content"] as? [[String: Any]],
            let text = content.first(where: { ($0["type"] as? String) == "text" })?["text"] as? String
        else {
            throw WineAIError.requestFailed("Antwort von Claude konnte nicht gelesen werden.")
        }

        let suggestion = try parseSuggestion(from: text)

        var inputTokens: Int?
        var outputTokens: Int?
        if let usage = json["usage"] as? [String: Any] {
            inputTokens = usage["input_tokens"] as? Int
            outputTokens = usage["output_tokens"] as? Int
        }

        return WineAIResult(suggestion: suggestion, provider: .anthropic, inputTokens: inputTokens, outputTokens: outputTokens)
    }

    // MARK: - Hilfsfunktionen

    /// Schickt eine Anfrage los und prüft den HTTP-Status.
    private static func send(_ request: URLRequest) async throws -> Data {
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw WineAIError.requestFailed("Keine Antwort vom Server.")
        }
        guard http.statusCode == 200 else {
            let body = String(data: data, encoding: .utf8) ?? "Status \(http.statusCode)"
            throw WineAIError.requestFailed("Serverfehler (\(http.statusCode)): \(body)")
        }
        return data
    }

    /// Liest aus dem Antworttext robust das JSON-Objekt heraus und decodiert es.
    private static func parseSuggestion(from text: String) throws -> WineAISuggestion {
        guard
            let jsonText = extractJSON(from: text),
            let suggestion = try? JSONDecoder().decode(WineAISuggestion.self, from: Data(jsonText.utf8))
        else {
            throw WineAIError.requestFailed("Die KI-Antwort war unerwartet: \(text)")
        }
        return suggestion
    }

    /// Schneidet aus dem Antworttext das JSON-Objekt heraus (falls Text drumherum steht).
    private static func extractJSON(from text: String) -> String? {
        guard let start = text.firstIndex(of: "{"),
              let end = text.lastIndex(of: "}"), start < end else { return nil }
        return String(text[start...end])
    }

    /// Verkleinert das Bild vor dem Upload, um Datenmenge und Kosten zu sparen.
    private static func resized(_ image: UIImage, maxDimension: CGFloat = 1024) -> UIImage {
        let size = image.size
        let scale = min(1, maxDimension / max(size.width, size.height))
        guard scale < 1 else { return image }
        let newSize = CGSize(width: size.width * scale, height: size.height * scale)
        let renderer = UIGraphicsImageRenderer(size: newSize)
        return renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: newSize))
        }
    }
}
