import SwiftUI
import SwiftData

/// Bucht zusätzliche Flaschen eines Produkts auf einen Lagerort.
struct BookStockSheet: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    let product: Product

    @State private var location: Location?
    @State private var anzahl = 1

    var body: some View {
        NavigationStack {
            Form {
                Section("Lagerort") {
                    LocationPicker(selection: $location)
                }
                Section("Anzahl Flaschen") {
                    Stepper(value: $anzahl, in: 1...9999) {
                        Text("Menge: \(anzahl)")
                    }
                }
            }
            .navigationTitle("Bestand buchen")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Abbrechen") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Buchen") {
                        if let location {
                            StockService.book(product: product, location: location, anzahl: anzahl, context: context)
                        }
                        dismiss()
                    }
                    .disabled(location == nil)
                }
            }
        }
    }
}

/// Verschiebt Flaschen eines Produkts von einem Lagerort zu einem anderen.
struct MoveStockSheet: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    let product: Product

    @State private var quelle: Location?
    @State private var ziel: Location?
    @State private var anzahl = 1

    /// Lagerorte, an denen dieses Produkt tatsächlich liegt.
    private var quellOrte: [Location] {
        product.stockEntries.compactMap { $0.istLeer ? nil : $0.location }
    }

    private var maxMenge: Int {
        guard let quelle, let eintrag = StockService.entry(for: product, at: quelle) else { return 1 }
        return max(1, eintrag.anzahl)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Von Lagerort") {
                    Picker("Quelle", selection: $quelle) {
                        Text("wählen").tag(Location?.none)
                        ForEach(quellOrte) { loc in
                            Text("\(loc.name) – \(bestandText(loc))").tag(Location?.some(loc))
                        }
                    }
                }
                Section("Nach Lagerort") {
                    LocationPicker(selection: $ziel)
                }
                Section("Anzahl Flaschen") {
                    Stepper(value: $anzahl, in: 1...max(1, maxMenge)) {
                        Text("Menge: \(anzahl) (max. \(maxMenge))")
                    }
                }
            }
            .navigationTitle("Verschieben")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Abbrechen") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Verschieben") {
                        if let quelle, let ziel {
                            StockService.move(product: product, from: quelle, to: ziel, anzahl: anzahl, context: context)
                        }
                        dismiss()
                    }
                    .disabled(quelle == nil || ziel == nil || quelle?.persistentModelID == ziel?.persistentModelID)
                }
            }
        }
    }

    private func bestandText(_ loc: Location) -> String {
        StockService.entry(for: product, at: loc)?.beschreibung ?? "leer"
    }
}

/// Entnimmt (verbraucht) Flaschen eines Produkts aus einem Lagerort.
struct ConsumeStockSheet: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    let product: Product

    @State private var quelle: Location?
    @State private var anzahl = 1

    private var quellOrte: [Location] {
        product.stockEntries.compactMap { $0.istLeer ? nil : $0.location }
    }

    private var maxMenge: Int {
        guard let quelle, let eintrag = StockService.entry(for: product, at: quelle) else { return 1 }
        return max(1, eintrag.anzahl)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Aus Lagerort") {
                    Picker("Lagerort", selection: $quelle) {
                        Text("wählen").tag(Location?.none)
                        ForEach(quellOrte) { loc in
                            Text("\(loc.name) – \(bestandText(loc))").tag(Location?.some(loc))
                        }
                    }
                }
                Section("Anzahl Flaschen") {
                    Stepper(value: $anzahl, in: 1...max(1, maxMenge)) {
                        Text("Menge: \(anzahl) (max. \(maxMenge))")
                    }
                }
            }
            .navigationTitle("Entnehmen (Verbrauch)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Abbrechen") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Entnehmen") {
                        if let quelle {
                            StockService.consume(product: product, at: quelle, anzahl: anzahl, context: context)
                        }
                        dismiss()
                    }
                    .disabled(quelle == nil)
                }
            }
        }
    }

    private func bestandText(_ loc: Location) -> String {
        StockService.entry(for: product, at: loc)?.beschreibung ?? "leer"
    }
}
