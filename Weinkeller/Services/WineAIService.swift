import UIKit

/// Vorschlag der KI für die Etikett-Erkennung.
struct WineAISuggestion: Decodable {
    var winzer: String?
    var sorte: String?
    var jahrgang: String?
    var typ: String?
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

/// Optionale KI-Erkennung über die Anthropic-API (Claude).
/// Benötigt einen eigenen API-Schlüssel, der in den Einstellungen hinterlegt wird.
enum WineAIService {

    static func identify(image: UIImage) async throws -> WineAISuggestion {
        let key = UserDefaults.standard.string(forKey: "anthropicAPIKey") ?? ""
        guard !key.isEmpty else { throw WineAIError.noAPIKey }

        guard let jpeg = resized(image).jpegData(compressionQuality: 0.6) else {
            throw WineAIError.requestFailed("Bild konnte nicht verarbeitet werden.")
        }
        let base64 = jpeg.base64EncodedString()

        let prompt = """
        Analysiere das Wein- oder Sekt-Etikett auf dem Foto. Antworte AUSSCHLIESSLICH mit einem \
        JSON-Objekt, ohne weiteren Text, genau in diesem Format:
        {"winzer": "", "sorte": "", "jahrgang": "", "typ": "Wein oder Sekt"}
        Lass einzelne Felder leer, wenn du sie nicht sicher erkennen kannst.
        """

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

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let http = response as? HTTPURLResponse else {
            throw WineAIError.requestFailed("Keine Antwort vom Server.")
        }
        guard http.statusCode == 200 else {
            let body = String(data: data, encoding: .utf8) ?? "Status \(http.statusCode)"
            throw WineAIError.requestFailed("Serverfehler (\(http.statusCode)): \(body)")
        }

        // Antwortstruktur: { "content": [ { "type": "text", "text": "..." } ] }
        guard
            let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
            let content = json["content"] as? [[String: Any]],
            let text = content.first(where: { ($0["type"] as? String) == "text" })?["text"] as? String
        else {
            throw WineAIError.requestFailed("Antwort konnte nicht gelesen werden.")
        }

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
              let end = text.lastIndex(of: "}") else { return nil }
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
