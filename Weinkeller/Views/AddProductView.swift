import SwiftUI
import SwiftData

/// Ablauf zum Hinzufügen eines Getränks:
/// 1. Vorderseite fotografieren (= Anzeigebild), App liest offline Text + Barcode.
/// 2. Rückseite fotografieren (nur für die KI, wird danach verworfen).
/// 3. Optional „Mit KI nachschlagen" (erst möglich, wenn beide Fotos vorliegen).
/// 4. Lagerort, Einheit (Flasche/Karton) und Menge wählen.
/// 5. Speichern – vorher wird auf mögliche Duplikate geprüft.
struct AddProductView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    @Query private var products: [Product]
    @AppStorage(SettingsKey.customArten) private var customArten = ""
    @AppStorage(SettingsKey.deaktivierteArten) private var deaktivierteArten = ""

    // Bilder
    @State private var anzeigeBild: UIImage?          // Vorderseite, wird gespeichert
    @State private var rueckseiteBild: UIImage?       // Rückseite, nur für KI, wird verworfen
    @State private var showCameraVorderseite = false
    @State private var showCameraRueckseite = false
    @State private var zeigeRueckseiteHinweis = false

    // Erkennungszustand
    @State private var isRecognizing = false
    @State private var aiRunning = false
    @State private var aiError: String?

    // Produktfelder
    @State private var sorte = ""
    @State private var winzer = ""
    @State private var jahrgang = ""
    @State private var farbe: WineColor = .keine
    @State private var art = "Wein"
    @State private var alkoholfrei = false
    @State private var ean = ""
    @State private var flaschenProKarton = 6

    // versteckte Erkennungsdaten
    @State private var erkannterText = ""
    @State private var erkannteBarcodes: [String] = []

    // Buchung
    @State private var location: Location?
    @State private var unit: StockUnit = .flasche
    @State private var menge = 1

    // Duplikat-Handling
    @State private var duplikat: Product?
    @State private var zeigeDuplikatDialog = false

    private var arten: [String] { ArtStore.effective(custom: customArten, deaktiviert: deaktivierteArten) }

    /// KI ist erst nutzbar, wenn Vorder- UND Rückseite fotografiert wurden.
    private var kiBereit: Bool { anzeigeBild != nil && rueckseiteBild != nil }

    var body: some View {
        NavigationStack {
            Form {
                fotoSection
                produktSection
                eanSection
                lagerSection
                kiSection
                if !erkannterText.isEmpty {
                    Section("Offline erkannter Text (wird für die Wiedererkennung gespeichert)") {
                        Text(erkannterText)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle("Neues Getränk")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Abbrechen") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Speichern") { speichernAntippen() }
                        .disabled(!canSave)
                }
            }
            .onAppear {
                if !arten.contains(art) { art = arten.first ?? "Wein" }
            }
            .fullScreenCover(isPresented: $showCameraVorderseite) {
                CameraPicker { captured in
                    anzeigeBild = captured
                    Task { await recognize(captured) }
                }
                .ignoresSafeArea()
            }
            .fullScreenCover(isPresented: $showCameraRueckseite) {
                CameraPicker { captured in
                    // Rückseite: nur zur Datengewinnung, wird NICHT gespeichert.
                    rueckseiteBild = captured
                    Task { await recognize(captured) }
                }
                .ignoresSafeArea()
            }
            .alert("Rückseite fotografieren", isPresented: $zeigeRueckseiteHinweis) {
                Button("Kamera öffnen") { showCameraRueckseite = true }
                Button("Abbrechen", role: .cancel) {}
            } message: {
                Text("Bitte fotografiere jetzt die RÜCKSEITE des Etiketts. Dort stehen meist die Details, die die KI auswertet. Dieses Foto wird nur analysiert und danach wieder verworfen.")
            }
            .confirmationDialog(
                "Dieses Getränk existiert evtl. schon",
                isPresented: $zeigeDuplikatDialog,
                titleVisibility: .visible
            ) {
                Button("Zusammenführen (Bestand hinzubuchen)") { merge() }
                Button("Als neues Produkt anlegen") { saveAsNew() }
                Button("Abbrechen", role: .cancel) {}
            } message: {
                if let d = duplikat {
                    Text("Treffer: \(d.sorte) – \(d.winzer) \(d.jahrgang)\n\nMöchtest du den Bestand dort hinzubuchen oder ein neues Produkt anlegen?")
                }
            }
        }
    }

    // MARK: - Sections

    private var fotoSection: some View {
        Section {
            // Vorderseite = Anzeigebild
            if let anzeigeBild {
                Image(uiImage: anzeigeBild)
                    .resizable().scaledToFit()
                    .frame(maxWidth: .infinity).frame(maxHeight: 220)
                Button { showCameraVorderseite = true } label: {
                    Label("Vorderseite ersetzen", systemImage: "camera")
                }
            } else {
                Button { showCameraVorderseite = true } label: {
                    Label("Vorderseite fotografieren (Anzeigebild)", systemImage: "camera.fill")
                }
            }

            // Rückseite = nur für die KI
            Button { zeigeRueckseiteHinweis = true } label: {
                if rueckseiteBild == nil {
                    Label("Rückseite fotografieren (für KI)", systemImage: "doc.viewfinder")
                } else {
                    Label("Rückseite aufgenommen ✓ – neu aufnehmen", systemImage: "checkmark.circle")
                }
            }

            if isRecognizing {
                HStack { ProgressView(); Text("Etikett wird gelesen …").foregroundStyle(.secondary) }
            }
        } header: {
            Text("Fotos")
        } footer: {
            Text("Die Vorderseite wird als Anzeigebild gespeichert. Die Rückseite dient nur der KI-Auswertung und wird danach verworfen.")
        }
    }

    private var produktSection: some View {
        Section("Getränk") {
            TextField("Sorte / Name", text: $sorte)
            TextField("Winzer / Weingut", text: $winzer)
            TextField("Jahrgang", text: $jahrgang)
                .keyboardType(.numbersAndPunctuation)
            Picker("Farbe", selection: $farbe) {
                ForEach(WineColor.allCases) { Text($0.rawValue).tag($0) }
            }
            Picker("Art", selection: $art) {
                ForEach(arten, id: \.self) { Text($0).tag($0) }
            }
            Toggle("Alkoholfrei", isOn: $alkoholfrei)
        }
    }

    private var eanSection: some View {
        Section {
            TextField("EAN / Barcode (Einzelflasche)", text: $ean)
                .keyboardType(.numbersAndPunctuation)
            Stepper(value: $flaschenProKarton, in: 1...100) {
                Text("Flaschen pro Karton: \(flaschenProKarton)")
            }
        } header: {
            Text("Barcode & Karton")
        }
    }

    private var lagerSection: some View {
        Section("Einlagern") {
            LocationPicker(selection: $location)
            Picker("Einheit", selection: $unit) {
                ForEach(StockUnit.allCases) { Text($0.rawValue).tag($0) }
            }
            .pickerStyle(.segmented)
            Stepper(value: $menge, in: 1...9999) {
                Text("Menge: \(menge)")
            }
            if unit == .karton {
                Text("= \(menge * flaschenProKarton) Flaschen")
                    .font(.footnote).foregroundStyle(.secondary)
            }
        }
    }

    private var kiSection: some View {
        Section {
            Button {
                Task { await runAI() }
            } label: {
                if aiRunning {
                    HStack { ProgressView(); Text("KI analysiert die Rückseite …") }
                } else {
                    Label("Mit KI nachschlagen", systemImage: "sparkles")
                }
            }
            .disabled(!kiBereit || aiRunning)

            if let aiError {
                Text(aiError).font(.footnote).foregroundStyle(.red)
            }
        } footer: {
            if kiBereit {
                Text("Sendet die RÜCKSEITE an den in den Einstellungen gewählten KI-Anbieter, um Winzer, Sorte, Jahrgang, Farbe und Art zu erkennen.")
            } else {
                Text("Erst verfügbar, wenn Vorder- und Rückseite fotografiert wurden. Es wird ausschließlich die Rückseite an die KI gesendet.")
            }
        }
    }

    // MARK: - Logik

    private var canSave: Bool {
        let hatInhalt = !winzer.trimmingCharacters(in: .whitespaces).isEmpty
            || !sorte.trimmingCharacters(in: .whitespaces).isEmpty
            || anzeigeBild != nil
        return hatInhalt && location != nil
    }

    /// Liest Text + Barcodes vom Foto und füllt leere Felder vor.
    private func recognize(_ image: UIImage) async {
        isRecognizing = true
        let result = await LabelRecognizer.recognize(image)
        isRecognizing = false

        if erkannterText.isEmpty { erkannterText = result.fullText }
        // Barcodes sammeln (Dubletten vermeiden)
        for code in result.barcodes where !erkannteBarcodes.contains(code) {
            erkannteBarcodes.append(code)
        }
        if jahrgang.isEmpty { jahrgang = result.jahrgang }
        if ean.isEmpty { ean = result.ean }
        if sorte.isEmpty, let zeile = result.lines.first(where: { $0.count > 2 }) {
            sorte = zeile
        }
    }

    /// Fragt die KI – ausschließlich mit der Rückseite.
    private func runAI() async {
        guard let bild = rueckseiteBild else { return }
        aiRunning = true
        aiError = nil
        do {
            let result = try await WineAIService.identify(image: bild)
            let s = result.suggestion
            if let v = s.winzer, !v.isEmpty { winzer = v }
            if let v = s.sorte, !v.isEmpty { sorte = v }
            if let v = s.jahrgang, !v.isEmpty { jahrgang = v }
            if let v = s.farbe, let f = matchFarbe(v) { farbe = f }
            if let v = s.art, !v.isEmpty { art = matchArt(v) }
            // Claude-Kosten erfassen (nur bei Anthropic liefert usage Werte).
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

    private func matchArt(_ raw: String) -> String {
        let treffer = arten.first { $0.caseInsensitiveCompare(raw) == .orderedSame }
        return treffer ?? raw
    }

    /// Beim Antippen von „Speichern": zuerst auf Duplikate prüfen.
    private func speichernAntippen() {
        if let match = ProductMatcher.findMatch(
            in: products, ean: ean, barcodes: erkannteBarcodes,
            winzer: winzer, sorte: sorte, jahrgang: jahrgang, text: erkannterText
        ) {
            duplikat = match
            zeigeDuplikatDialog = true
        } else {
            saveAsNew()
        }
    }

    /// Bucht den Bestand auf das vorhandene (Duplikat-)Produkt.
    private func merge() {
        guard let duplikat, let location else { return }
        StockService.book(product: duplikat, location: location, unit: unit, menge: menge, context: context)
        // Neue Barcodes ggf. ergänzen, damit künftige Scans treffen.
        for code in erkannteBarcodes where !duplikat.erkannteBarcodes.contains(code) {
            duplikat.erkannteBarcodes.append(code)
        }
        dismiss()
    }

    /// Legt ein neues Produkt an und bucht den Bestand.
    private func saveAsNew() {
        guard let location else { return }
        let product = Product(
            sorte: sorte.trimmingCharacters(in: .whitespacesAndNewlines),
            winzer: winzer.trimmingCharacters(in: .whitespacesAndNewlines),
            jahrgang: jahrgang.trimmingCharacters(in: .whitespacesAndNewlines),
            farbe: farbe,
            art: art,
            alkoholfrei: alkoholfrei,
            ean: ean.trimmingCharacters(in: .whitespacesAndNewlines),
            flaschenProKarton: flaschenProKarton,
            anzeigebildData: anzeigeBild?.jpegData(compressionQuality: 0.7),
            erkannterText: erkannterText,
            erkannteBarcodes: erkannteBarcodes
        )
        context.insert(product)
        StockService.book(product: product, location: location, unit: unit, menge: menge, context: context)
        dismiss()
    }
}
