import SwiftUI
import SwiftData

/// Ablauf zum Hinzufügen eines Getränks:
/// 1. Vorderseite fotografieren (= Anzeigebild), App liest offline Text + Barcode.
/// 2. Optional Rückseite/Analyse-Foto (nur für die KI, wird danach verworfen).
/// 3. „Mit KI nachschlagen" (über den Einlager-Feldern).
/// 4. Optional Lagerort + Anzahl Flaschen.
/// 5. Notiz und „Beliebt bei:" ganz unten.
/// 6. Speichern – vorher wird auf mögliche Duplikate geprüft.
struct AddProductView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    @Query private var products: [Product]
    @AppStorage(SettingsKey.customArten) private var customArten = ""
    @AppStorage(SettingsKey.deaktivierteArten) private var deaktivierteArten = ""

    // Bilder
    @State private var anzeigeBild: UIImage?          // Vorderseite, wird gespeichert
    @State private var analyseBild: UIImage?          // nur für KI, wird verworfen
    @State private var showCameraVorderseite = false
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
    @State private var verschluss: ClosureType = .keine
    @State private var ean = ""
    @State private var favorit = false
    @State private var notiz = ""
    @State private var beliebtBei = ""

    // versteckte Erkennungsdaten
    @State private var erkannterText = ""
    @State private var erkannteBarcodes: [String] = []

    // Buchung (Lagerort optional)
    @State private var location: Location?
    @State private var anzahl = 1

    // Duplikat-Handling
    @State private var duplikat: Product?
    @State private var zeigeDuplikatDialog = false

    private var arten: [String] { ArtStore.effective(custom: customArten, deaktiviert: deaktivierteArten) }

    /// KI ist nutzbar, sobald mindestens ein Analyse-Foto vorliegt.
    private var kiBereit: Bool { analyseBild != nil || anzeigeBild != nil }

    var body: some View {
        NavigationStack {
            Form {
                fotoSection
                produktSection
                eanSection
                kiSection
                lagerSection
                if !erkannterText.isEmpty {
                    Section("Offline erkannter Text (wird für die Wiedererkennung gespeichert)") {
                        Text(erkannterText)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
                notizSection
                beliebtBeiSection
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
            .fullScreenCover(isPresented: $showCameraAnalyse) {
                CameraPicker { captured in
                    // Analyse-Foto: nur zur Datengewinnung, wird NICHT gespeichert.
                    analyseBild = captured
                    Task { await recognize(captured) }
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

            // Analyse-Foto = nur für die KI (kein Popup, direkt Kamera).
            Button { showCameraAnalyse = true } label: {
                if analyseBild == nil {
                    Label("Rückseite für KI fotografieren", systemImage: "doc.viewfinder")
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
            Text("Die Vorderseite wird als Anzeigebild gespeichert. Das Rückseiten-Foto dient nur der KI-Auswertung und wird danach verworfen.")
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
            Picker("Verschluss", selection: $verschluss) {
                ForEach(ClosureType.allCases) { Text($0.rawValue).tag($0) }
            }
            Toggle("Alkoholfrei", isOn: $alkoholfrei)
            Toggle(isOn: $favorit) {
                Label("Favorit", systemImage: favorit ? "star.fill" : "star")
            }
        }
    }

    private var eanSection: some View {
        Section("Barcode") {
            TextField("EAN / Barcode", text: $ean)
                .keyboardType(.numbersAndPunctuation)
        }
    }

    private var kiSection: some View {
        Section {
            Button {
                Task { await runAI() }
            } label: {
                if aiRunning {
                    HStack { ProgressView(); Text("KI analysiert das Foto …") }
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
                Text("Sendet das Foto an den in den Einstellungen bevorzugten KI-Anbieter (mit automatischem Fallback), um Sorte, Winzer, Jahrgang, Farbe, Art und Verschluss zu erkennen.")
            } else {
                Text("Erst verfügbar, sobald ein Foto aufgenommen wurde.")
            }
        }
    }

    private var lagerSection: some View {
        Section {
            LocationPicker(selection: $location)
            if location != nil {
                Stepper(value: $anzahl, in: 1...9999) {
                    Text("Anzahl Flaschen: \(anzahl)")
                }
            }
        } header: {
            Text("Einlagern (optional)")
        } footer: {
            Text("Ohne Lagerort wird das Getränk ohne Bestand gespeichert; du kannst den Bestand später jederzeit ergänzen.")
        }
    }

    private var notizSection: some View {
        Section("Notiz") {
            TextField("Notiz", text: $notiz, axis: .vertical)
        }
    }

    private var beliebtBeiSection: some View {
        Section {
            TextField("Namen, mehrere mit Komma trennen", text: $beliebtBei)
        } header: {
            Text("Beliebt bei:")
        } footer: {
            Text("Diese Namen lassen sich in der Übersicht durchsuchen.")
        }
    }

    // MARK: - Logik

    private var canSave: Bool {
        // Lagerort ist NICHT mehr Pflicht.
        !winzer.trimmingCharacters(in: .whitespaces).isEmpty
            || !sorte.trimmingCharacters(in: .whitespaces).isEmpty
            || anzeigeBild != nil
    }

    /// Liest Text + Barcodes vom Foto und füllt leere Felder vor.
    private func recognize(_ image: UIImage) async {
        isRecognizing = true
        let result = await LabelRecognizer.recognize(image)
        isRecognizing = false

        if erkannterText.isEmpty { erkannterText = result.fullText }
        for code in result.barcodes where !erkannteBarcodes.contains(code) {
            erkannteBarcodes.append(code)
        }
        if jahrgang.isEmpty { jahrgang = result.jahrgang }
        if ean.isEmpty { ean = result.ean }
        if sorte.isEmpty, let zeile = result.lines.first(where: { $0.count > 2 }) {
            sorte = zeile
        }
    }

    /// Fragt die KI – bevorzugt mit dem Analyse-Foto, sonst der Vorderseite.
    private func runAI() async {
        guard let bild = analyseBild ?? anzeigeBild else { return }
        aiRunning = true
        aiError = nil
        do {
            let result = try await WineAIService.identify(image: bild)
            let s = result.suggestion
            if let v = s.winzer, !v.isEmpty { winzer = v }
            if let v = s.sorte, !v.isEmpty { sorte = v }
            if let v = s.jahrgang, !v.isEmpty { jahrgang = v }
            if let v = s.farbe, let f = WineColor.fromAI(v) { farbe = f }
            // Art NUR setzen, wenn sie einer vorhandenen Klasse entspricht.
            if let v = s.art, let a = ArtStore.match(v, in: arten) { art = a }
            if let v = s.verschluss, let c = ClosureType.fromAI(v) { verschluss = c }
            erfasseKosten(result)
        } catch {
            aiError = error.localizedDescription
        }
        aiRunning = false
    }

    private func erfasseKosten(_ result: WineAIResult) {
        guard let inT = result.inputTokens, let outT = result.outputTokens else { return }
        let kosten = AIPricing.estimate(provider: result.provider, inputTokens: inT, outputTokens: outT)
        context.insert(CostEvent(anbieter: result.provider.rawValue, inputTokens: inT, outputTokens: outT, kostenUSD: kosten))
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
        guard let duplikat else { return }
        if let location {
            StockService.book(product: duplikat, location: location, anzahl: anzahl, context: context)
        }
        for code in erkannteBarcodes where !duplikat.erkannteBarcodes.contains(code) {
            duplikat.erkannteBarcodes.append(code)
        }
        dismiss()
    }

    /// Legt ein neues Produkt an und bucht (falls Lagerort gewählt) den Bestand.
    private func saveAsNew() {
        let product = Product(
            sorte: sorte.trimmingCharacters(in: .whitespacesAndNewlines),
            winzer: winzer.trimmingCharacters(in: .whitespacesAndNewlines),
            jahrgang: jahrgang.trimmingCharacters(in: .whitespacesAndNewlines),
            farbe: farbe,
            art: art,
            alkoholfrei: alkoholfrei,
            verschluss: verschluss,
            ean: ean.trimmingCharacters(in: .whitespacesAndNewlines),
            notiz: notiz.trimmingCharacters(in: .whitespacesAndNewlines),
            favorit: favorit,
            beliebtBei: beliebtBei.trimmingCharacters(in: .whitespacesAndNewlines),
            anzeigebildData: anzeigeBild?.jpegData(compressionQuality: 0.7),
            erkannterText: erkannterText,
            erkannteBarcodes: erkannteBarcodes
        )
        context.insert(product)
        if let location {
            StockService.book(product: product, location: location, anzahl: anzahl, context: context)
        }
        dismiss()
    }
}
