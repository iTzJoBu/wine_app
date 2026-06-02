import Vision
import UIKit

/// Ergebnis der Etikett-Erkennung direkt auf dem Gerät.
struct LabelResult {
    var fullText: String = ""
    var lines: [String] = []
    var jahrgang: String = ""
    /// Erster erkannter Barcode (für die schnelle EAN-Vorbelegung).
    var ean: String = ""
    /// Alle erkannten Barcodes (für die Wiedererkennung / Karton-Codes).
    var barcodes: [String] = []
}

/// Liest – komplett offline und kostenlos – mit Apples Vision-Technik den Text
/// und eventuelle Barcodes (EAN) vom Etiketten-Foto.
enum LabelRecognizer {

    static func recognize(_ image: UIImage) async -> LabelResult {
        guard let cgImage = image.cgImage else { return LabelResult() }
        var result = LabelResult()

        // Texterkennung (OCR)
        let textRequest = VNRecognizeTextRequest()
        textRequest.recognitionLevel = .accurate
        textRequest.usesLanguageCorrection = true
        textRequest.recognitionLanguages = ["de-DE", "fr-FR", "it-IT", "en-US"]

        // Barcode-Erkennung (EAN/UPC)
        let barcodeRequest = VNDetectBarcodesRequest()
        barcodeRequest.symbologies = [.ean13, .ean8, .upce]

        let handler = VNImageRequestHandler(
            cgImage: cgImage,
            orientation: cgOrientation(from: image.imageOrientation),
            options: [:]
        )

        do {
            try handler.perform([textRequest, barcodeRequest])
        } catch {
            return result
        }

        if let observations = textRequest.results {
            let lines = observations.compactMap { $0.topCandidates(1).first?.string }
            result.lines = lines
            result.fullText = lines.joined(separator: "\n")
            result.jahrgang = extractYear(from: lines) ?? ""
        }

        if let codes = barcodeRequest.results {
            let payloads = codes.compactMap { $0.payloadStringValue }
            result.barcodes = Array(Set(payloads)) // Dubletten entfernen
            result.ean = payloads.first ?? ""
        }

        return result
    }

    /// Sucht in den erkannten Zeilen nach einer plausiblen Jahreszahl (1950–2049).
    private static func extractYear(from lines: [String]) -> String? {
        let pattern = #"\b(19[5-9]\d|20[0-4]\d)\b"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return nil }
        for line in lines {
            let range = NSRange(line.startIndex..., in: line)
            if let match = regex.firstMatch(in: line, range: range),
               let matchRange = Range(match.range, in: line) {
                return String(line[matchRange])
            }
        }
        return nil
    }

    private static func cgOrientation(from orientation: UIImage.Orientation) -> CGImagePropertyOrientation {
        switch orientation {
        case .up: return .up
        case .down: return .down
        case .left: return .left
        case .right: return .right
        case .upMirrored: return .upMirrored
        case .downMirrored: return .downMirrored
        case .leftMirrored: return .leftMirrored
        case .rightMirrored: return .rightMirrored
        @unknown default: return .up
        }
    }
}
