import SwiftUI
import SwiftData

/// Ablauf zum Hinzufügen eines Getränks:
/// 1. Foto vom Etikett (= Anzeigebild) aufnehmen
/// 2. App liest offline Text + Barcode und füllt Felder vor
/// 3. Optional „Mit KI nachschlagen"
/// 4. Lagerort, Einheit (Flasche/Karton) und Menge wählen
/// 5. Speichern – vorher wird auf mögliche Duplikate geprüft.
struct AddProductView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    @Query private var products: [Product]
    @AppStorage(SettingsKey.customArten) private var customArten = ""

    // Bilder
    @State private var anzeigeBild: UIImage?
    @State private var showCameraAnzeige = false
    @State private var showCameraAnalyse = false

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
    @State private var kartonEAN = ""
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

    private var arten: [String] { ArtStore.all(custom: customArten) }

    var body: some View {
        NavigationStack {
            Form {
                fotoSection
                produktSection
                kartonSection
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
            .fullScreenCover(isPresented: $showCameraAnzeige) {
                CameraPicker { captured in
                    anzeigeBild = captured
                    Task { await recognize(captured) }
                }
                .ignoresSafeArea()
            }
            .fullScreenCover(isPresented: $showCameraAnalyse) {
                CameraPicker { captured in
                    // Analyse-Foto: NUR zur Datengewinnung, wird nicht gespeichert.
                    Task { await recognize(captured); await runAI(on: captured) }
                }
                .ignoresSafeArea()
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
        Section("Anzeigebild (Etikett)") {
            if let anzeigeBild {
                Image(uiImage: anzeigeBild)
                    .resizable().scaledToFit()
                    .frame(maxWidth: .infinity).frame(maxHeight: 220)
                Button { showCameraAnzeige = true } label: {
                    Label("Anzeigebild ersetzen", systemImage: "camera")
                }
            } else {
                Button { showCameraAnzeige = true } label: {
                    Label("Foto vom Etikett aufnehmen", systemImage: "camera.fill")
                }
            }
            Button { showCameraAnalyse = true } label: {
                Label("Analyse-Foto (wird nach Auswertung verworfen)", systemImage: "doc.viewfinder")
            }
            if isRecognizing {
                HStack { ProgressView(); Text("Etikett wird gelesen …").foregroundStyle(.secondary) }
            }
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

    private var kartonSection: some View {
        Section {
            TextField("EAN / Barcode (Einzelflasche)", text: $ean)
                .keyboardType(.numbersAndPunctuation)
            TextField("Karton-Barcode (optional)", text: $kartonEAN)
                .keyboardType(.numbersAndPunctuation)
            Stepper(value: $flaschenProKarton, in: 1...100) {
                Text("Flaschen pro Karton: \(flaschenProKarton)")
            }
        } header: {
            Text("Barcodes & Karton")
        } footer: {
            Text("Wird der Karton-Barcode später gescannt, wird automatisch ein ganzer Karton (\(flaschenProKarton) Flaschen) gebucht.")
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
                Task { if let img = anzeigeBild { await runAI(on: img) } }
            } label: {
                if aiRunning {
                    HStack { ProgressView(); Text("KI analysiert das Etikett …") }
                } else {
                    Label("Mit KI nachschlagen", systemImage: "sparkles")
                }
            }
            .disabled(anzeigeBild == nil || aiRunning)

            if let aiError {
                Text(aiError).font(.footnote).foregroundStyle(.red)
            }
        } footer: {
            Text("Optional: Sendet das Foto an den in den Einstellungen gewählten KI-Anbieter, um Winzer, Sorte, Jahrgang, Farbe und Art zu erkennen.")
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

    /// Fragt optional die KI.
    private func runAI(on image: UIImage) async {
        aiRunning = true
        aiError = nil
        do {
            let result = try await WineAIService.identify(image: image)
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
            kartonEAN: kartonEAN.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : kartonEAN.trimmingCharacters(in: .whitespacesAndNewlines),
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
