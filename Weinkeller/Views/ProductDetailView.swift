import SwiftUI
import SwiftData

/// Detailansicht eines Produkts – Felder bearbeitbar, Bestand je Lagerort sichtbar.
struct ProductDetailView: View {
    @Bindable var product: Product
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @AppStorage(SettingsKey.customArten) private var customArten = ""
    @AppStorage(SettingsKey.deaktivierteArten) private var deaktivierteArten = ""

    @State private var showCamera = false            // Anzeigebild ersetzen
    @State private var showCameraRueckseite = false  // Rückseite für KI
    @State private var zeigeRueckseiteHinweis = false
    @State private var showBook = false
    @State private var showMove = false
    @State private var aiRunning = false
    @State private var aiError: String?

    private var arten: [String] {
        var liste = ArtStore.effective(custom: customArten, deaktiviert: deaktivierteArten)
        // Falls das Produkt eine (z. B. deaktivierte) Art trägt, trotzdem zeigen.
        if !liste.contains(product.art), !product.art.isEmpty { liste.append(product.art) }
        return liste
    }

    /// Nur Einträge mit Bestand, stabil sortiert nach Lagerort-Name.
    private var bestandEintraege: [StockEntry] {
        product.stockEntries
            .filter { !$0.istLeer }
            .sorted { ($0.location?.name ?? "") < ($1.location?.name ?? "") }
    }

    var body: some View {
        Form {
            bildSection
            bestandSection
            getraenkSection
            kartonSection
            kiSection
            loeschenSection
        }
        .navigationTitle(product.sorte.isEmpty ? "Getränk" : product.sorte)
        .navigationBarTitleDisplayMode(.inline)
        .fullScreenCover(isPresented: $showCamera) {
            CameraPicker { captured in
                product.anzeigebildData = captured.jpegData(compressionQuality: 0.7)
                Task { await aktualisiereErkennung(captured) }
            }
            .ignoresSafeArea()
        }
        .fullScreenCover(isPresented: $showCameraRueckseite) {
            CameraPicker { captured in
                // Rückseite: nur für die KI, wird nicht gespeichert.
                Task { await runAI(on: captured) }
            }
            .ignoresSafeArea()
        }
        .alert("Rückseite fotografieren", isPresented: $zeigeRueckseiteHinweis) {
            Button("Kamera öffnen") { showCameraRueckseite = true }
            Button("Abbrechen", role: .cancel) {}
        } message: {
            Text("Bitte fotografiere jetzt die RÜCKSEITE des Etiketts. Dort stehen meist die Details, die die KI auswertet. Dieses Foto wird nur analysiert und danach wieder verworfen.")
        }
        .sheet(isPresented: $showBook) { BookStockSheet(product: product) }
        .sheet(isPresented: $showMove) { MoveStockSheet(product: product) }
    }

    // MARK: - Sections

    @ViewBuilder
    private var bildSection: some View {
        Section {
            if let data = product.anzeigebildData, let uiImage = UIImage(data: data) {
                Image(uiImage: uiImage)
                    .resizable().scaledToFit()
                    .frame(maxWidth: .infinity).frame(maxHeight: 260)
            }
            Button { showCamera = true } label: {
                Label(product.anzeigebildData == nil ? "Anzeigebild aufnehmen" : "Anzeigebild ersetzen", systemImage: "camera")
            }
        }
    }

    private var bestandSection: some View {
        Section {
            if bestandEintraege.isEmpty {
                Text("Kein Bestand eingelagert.").foregroundStyle(.secondary)
            } else {
                ForEach(bestandEintraege) { eintrag in
                    HStack {
                        Text(eintrag.location?.name ?? "—")
                            .fontWeight(.medium)
                        Spacer()
                        Text(eintrag.beschreibung)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.trailing)
                    }
                }
            }
            HStack {
                Button { showBook = true } label: { Label("Bestand buchen", systemImage: "plus.circle") }
                Spacer()
                Button { showMove = true } label: { Label("Verschieben", systemImage: "arrow.left.arrow.right") }
                    .disabled(bestandEintraege.isEmpty)
            }
        } header: {
            Text("Bestand je Lagerort")
        } footer: {
            Text("Gesamt: \(product.gesamtflaschen) Flaschen")
        }
    }

    private var getraenkSection: some View {
        Section("Getränk") {
            LabeledField("Sorte", text: $product.sorte)
            LabeledField("Winzer", text: $product.winzer)
            LabeledField("Jahrgang", text: $product.jahrgang)
            Picker("Farbe", selection: $product.farbe) {
                ForEach(WineColor.allCases) { Text($0.rawValue).tag($0) }
            }
            Picker("Art", selection: $product.art) {
                ForEach(arten, id: \.self) { Text($0).tag($0) }
            }
            Toggle("Alkoholfrei", isOn: $product.alkoholfrei)
        }
    }

    private var kartonSection: some View {
        Section("Barcode & Karton") {
            LabeledField("EAN", text: $product.ean)
            Stepper(value: $product.flaschenProKarton, in: 1...100) {
                Text("Flaschen pro Karton: \(product.flaschenProKarton)")
            }
        }
    }

    private var kiSection: some View {
        Section {
            Button {
                zeigeRueckseiteHinweis = true
            } label: {
                if aiRunning {
                    HStack { ProgressView(); Text("KI analysiert die Rückseite …") }
                } else {
                    Label("Mit KI nachschlagen (Rückseite)", systemImage: "sparkles")
                }
            }
            .disabled(aiRunning)
            if let aiError {
                Text(aiError).font(.footnote).foregroundStyle(.red)
            }
        } footer: {
            Text("Fotografiere die Rückseite des Etiketts; sie wird an den in den Einstellungen gewählten KI-Anbieter gesendet und danach verworfen.")
        }
    }

    private var loeschenSection: some View {
        Section {
            Button(role: .destructive) {
                context.delete(product)
                dismiss()
            } label: {
                Label("Produkt löschen", systemImage: "trash")
            }
        }
    }

    // MARK: - Logik

    /// Aktualisiert die versteckten Erkennungsdaten nach neuem Foto.
    private func aktualisiereErkennung(_ image: UIImage) async {
        let result = await LabelRecognizer.recognize(image)
        if !result.fullText.isEmpty { product.erkannterText = result.fullText }
        for code in result.barcodes where !product.erkannteBarcodes.contains(code) {
            product.erkannteBarcodes.append(code)
        }
    }

    private func runAI(on image: UIImage) async {
        // Erkennungsdaten aus der Rückseite ebenfalls für die Wiedererkennung übernehmen.
        await aktualisiereErkennung(image)
        aiRunning = true
        aiError = nil
        do {
            let result = try await WineAIService.identify(image: image)
            let s = result.suggestion
            if let v = s.winzer, !v.isEmpty { product.winzer = v }
            if let v = s.sorte, !v.isEmpty { product.sorte = v }
            if let v = s.jahrgang, !v.isEmpty { product.jahrgang = v }
            if let v = s.farbe, let f = matchFarbe(v) { product.farbe = f }
            if let v = s.art, !v.isEmpty { product.art = v }
            if let inT = result.inputTokens, let outT = result.outputTokens {
                let kosten = ClaudePricing.estimate(inputTokens: inT, outputTokens: outT)
                context.insert(CostEvent(inputTokens: inT, outputTokens: outT, kostenUSD: kosten))
            }
        } catch {
            aiError = error.localizedDescription
        }
        aiRunning = false
    }

    private func matchFarbe(_ raw: String) -> WineColor? {
        let n = raw.lowercased()
        if n.contains("rot") || n.contains("red") { return .rot }
        if n.contains("weiß") || n.contains("weiss") || n.contains("white") { return .weiss }
        if n.contains("rosé") || n.contains("rose") { return .rose }
        return nil
    }
}

/// Kleine Hilfsansicht für ein beschriftetes Textfeld.
struct LabeledField: View {
    let label: String
    @Binding var text: String

    init(_ label: String, text: Binding<String>) {
        self.label = label
        self._text = text
    }

    var body: some View {
        HStack {
            Text(label)
                .foregroundStyle(.secondary)
                .frame(width: 100, alignment: .leading)
            TextField(label, text: $text)
        }
    }
}
