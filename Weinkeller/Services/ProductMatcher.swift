import Foundation

/// Findet mögliche Duplikate beim Hinzufügen eines Getränks – komplett offline.
///
/// Reihenfolge der Prüfung:
/// 1. Exakter EAN-Treffer (Einzelflasche oder Karton-Code).
/// 2. Normalisierter Vergleich von Winzer + Sorte + Jahrgang.
/// 3. Ähnlichkeit zum gespeicherten OCR-Text – aber NUR bei gleichem Jahrgang,
///    denn verschiedene Jahrgänge gelten als verschiedene Produkte.
enum ProductMatcher {

    /// Normalisiert Text für robusten Vergleich: Kleinbuchstaben, ohne Akzente,
    /// nur Buchstaben/Ziffern, Mehrfach-Leerzeichen zusammengefasst.
    static func normalize(_ text: String) -> String {
        let folded = text.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
        let allowed = folded.unicodeScalars.map { scalar -> Character in
            if CharacterSet.alphanumerics.contains(scalar) {
                return Character(scalar)
            } else {
                return " "
            }
        }
        let collapsed = String(allowed)
            .split(separator: " ")
            .joined(separator: " ")
        return collapsed.trimmingCharacters(in: .whitespaces)
    }

    /// Zerlegt einen Text in eine Menge von Wort-Tokens (mind. 3 Zeichen).
    private static func tokens(_ text: String) -> Set<String> {
        Set(normalize(text).split(separator: " ").map(String.init).filter { $0.count >= 3 })
    }

    /// Jaccard-Ähnlichkeit zweier Texte (0…1).
    static func similarity(_ a: String, _ b: String) -> Double {
        let ta = tokens(a)
        let tb = tokens(b)
        guard !ta.isEmpty, !tb.isEmpty else { return 0 }
        let intersection = ta.intersection(tb).count
        let union = ta.union(tb).count
        return union == 0 ? 0 : Double(intersection) / Double(union)
    }

    /// Sucht ein passendes vorhandenes Produkt.
    /// - Parameters:
    ///   - products: alle gespeicherten Produkte
    ///   - ean: erkannte/eingegebene EAN (ggf. leer)
    ///   - barcodes: alle offline erkannten Barcodes
    ///   - winzer/sorte/jahrgang: eingegebene/erkannte Felder
    ///   - text: offline erkannter OCR-Text
    static func findMatch(
        in products: [Product],
        ean: String,
        barcodes: [String] = [],
        winzer: String,
        sorte: String,
        jahrgang: String,
        text: String
    ) -> Product? {
        let alleCodes = Set(([ean] + barcodes).map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty })

        // 1. Exakter EAN-/Karton-Code-Treffer.
        if !alleCodes.isEmpty {
            for product in products {
                if alleCodes.contains(product.ean.trimmingCharacters(in: .whitespaces)) && !product.ean.isEmpty {
                    return product
                }
                if let karton = product.kartonEAN?.trimmingCharacters(in: .whitespaces),
                   !karton.isEmpty, alleCodes.contains(karton) {
                    return product
                }
                // Auch früher gemerkte Barcodes berücksichtigen.
                if !product.erkannteBarcodes.isEmpty,
                   !alleCodes.isDisjoint(with: Set(product.erkannteBarcodes)) {
                    return product
                }
            }
        }

        let normJahrgang = normalize(jahrgang)
        let normWinzer = normalize(winzer)
        let normSorte = normalize(sorte)

        // 2. Normalisierter Vergleich Winzer + Sorte + Jahrgang.
        if !normWinzer.isEmpty || !normSorte.isEmpty {
            for product in products {
                let gleicheNamen = normalize(product.winzer) == normWinzer
                    && normalize(product.sorte) == normSorte
                let gleicherJahrgang = normalize(product.jahrgang) == normJahrgang
                if gleicheNamen && gleicherJahrgang {
                    return product
                }
            }
        }

        // 3. Ähnlichkeit zum gespeicherten OCR-Text – nur bei gleichem Jahrgang.
        if !text.isEmpty {
            for product in products where normalize(product.jahrgang) == normJahrgang {
                if similarity(product.erkannterText, text) >= 0.6 {
                    return product
                }
            }
        }

        return nil
    }
}
