import SwiftUI
import SwiftData
import UniformTypeIdentifiers

/// Einstellungen: KI-Anbieter & Schlüssel, Arten verwalten, Lagerorte,
/// Export/Import (inkl. Schlüssel & Klassen) und die geschätzten Kosten.
struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context

    @AppStorage(SettingsKey.aiProvider) private var aiProviderRaw = AIProvider.gemini.rawValue
    @AppStorage(SettingsKey.geminiAPIKey) private var geminiKey = ""
    @AppStorage(SettingsKey.anthropicAPIKey) private var anthropicKey = ""
    @AppStorage(SettingsKey.customArten) private var customArten = ""
    @AppStorage(SettingsKey.deaktivierteArten) private var deaktivierteArten = ""

    @Query private var costEvents: [CostEvent]
    @Query private var products: [Product]
    @Query private var locations: [Location]

    // Arten hinzufügen
    @State private var zeigeArtHinzufuegen = false
    @State private var neueArt = ""

    // Export / Import
    @State private var exportDocument = BackupDocument(data: Data())
    @State private var showExporter = false
    @State private var showImporter = false
    @State private var meldung: String?

    private var provider: AIProvider {
        AIProvider(rawValue: aiProviderRaw) ?? .gemini
    }

    private var exportDateiname: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return "Weinkeller-Backup-\(formatter.string(from: .now))"
    }

    var body: some View {
        NavigationStack {
            Form {
                providerSection
                schluesselSection
                kostenSection
                artenSection
                lagerorteSection
                exportImportSection
                offlineHinweis
            }
            .navigationTitle("Einstellungen")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Fertig") { dismiss() }
                }
            }
            .alert("Neue Art", isPresented: $zeigeArtHinzufuegen) {
                TextField("z. B. Crémant, Cava", text: $neueArt)
                Button("Hinzufügen") { fuegeArtHinzu() }
                Button("Abbrechen", role: .cancel) { neueArt = "" }
            } message: {
                Text("Gib den Namen einer eigenen Art ein.")
            }
            .fileExporter(
                isPresented: $showExporter,
                document: exportDocument,
                contentType: .json,
                defaultFilename: exportDateiname
            ) { result in
                switch result {
                case .success: meldung = "Backup erfolgreich exportiert."
                case .failure(let error): meldung = "Export fehlgeschlagen: \(error.localizedDescription)"
                }
            }
            .fileImporter(
                isPresented: $showImporter,
                allowedContentTypes: [.json]
            ) { result in
                importieren(result)
            }
            .alert("Hinweis", isPresented: Binding(get: { meldung != nil }, set: { if !$0 { meldung = nil } })) {
                Button("OK", role: .cancel) { meldung = nil }
            } message: {
                Text(meldung ?? "")
            }
        }
    }

    // MARK: - KI-Anbieter

    private var providerSection: some View {
        Section {
            Picker("Bevorzugter Anbieter", selection: $aiProviderRaw) {
                ForEach(AIProvider.allCases) { p in
                    Text(p.anzeigeName).tag(p.rawValue)
                }
            }
        } header: {
            Text("KI-Anbieter")
        } footer: {
            Text("Bestimmt, welcher Dienst bei 'Mit KI nachschlagen' zuerst versucht wird. Schlägt er fehl oder ist das Kontingent erschöpft, wird automatisch auf den anderen Anbieter mit hinterlegtem Schlüssel zurückgefallen.")
        }
    }

    private var schluesselSection: some View {
        Section {
            SecureField("Gemini-Schlüssel (AIza…)", text: $geminiKey)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
            SecureField("Anthropic-Schlüssel (sk-ant-…)", text: $anthropicKey)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
        } header: {
            Text("API-Schlüssel")
        } footer: {
            Text("Gemini: kostenlos erhältlich unter aistudio.google.com. Anthropic: console.anthropic.com. Beide werden nur lokal gespeichert und nur beim Antippen von 'Mit KI nachschlagen' an den jeweiligen Dienst gesendet.")
        }
    }

    // MARK: - Kosten (beide Anbieter)

    private var kostenSection: some View {
        Section {
            ForEach(AIProvider.allCases) { p in
                LabeledContent(p.anzeigeName) {
                    VStack(alignment: .trailing) {
                        Text("7 T: \(formatUSD(kosten(provider: p, tage: 7)))")
                        Text("28 T: \(formatUSD(kosten(provider: p, tage: 28)))")
                            .foregroundStyle(.secondary)
                    }
                    .font(.subheadline.monospacedDigit())
                }
            }
        } header: {
            Text("Geschätzte API-Kosten")
        } footer: {
            Text("Nur Schätzungen auf Basis der verbrauchten Token und hinterlegter Preis-Konstanten je Modell (Gemini: \(formatUSD(AIPricing.geminiInputUSDPerMillion))/Mio. In · \(formatUSD(AIPricing.geminiOutputUSDPerMillion))/Mio. Out; Claude: \(formatUSD(AIPricing.claudeInputUSDPerMillion))/Mio. In · \(formatUSD(AIPricing.claudeOutputUSDPerMillion))/Mio. Out). Keine offizielle Abrechnung; tatsächliche Kosten hängen vom Tarif ab.")
        }
    }

    /// Geschätzte Kosten eines Anbieters in den letzten `tage` Tagen.
    private func kosten(provider: AIProvider, tage: Int) -> Double {
        let grenze = Calendar.current.date(byAdding: .day, value: -tage, to: .now) ?? .now
        return costEvents
            .filter { $0.anbieter == provider.rawValue && $0.datum >= grenze }
            .reduce(0) { $0 + $1.kostenUSD }
    }

    private func formatUSD(_ value: Double) -> String {
        String(format: "$%.4f", value)
    }

    // MARK: - Arten verwalten

    private var artenSection: some View {
        Section {
            ForEach(ArtStore.builtIn, id: \.self) { art in
                Toggle(art, isOn: builtInAktivBinding(art))
            }
            ForEach(eigeneArten, id: \.self) { art in
                Text(art)
            }
            .onDelete(perform: loescheArt)

            Button {
                neueArt = ""
                zeigeArtHinzufuegen = true
            } label: {
                Label("Art hinzufügen", systemImage: "plus")
            }
        } header: {
            Text("Arten")
        } footer: {
            Text("Eingebaute Arten kannst du per Schalter deaktivieren. Eigene Arten lassen sich per Wischen löschen. Die KI legt NIEMALS selbstständig neue Arten an.")
        }
    }

    private var eigeneArten: [String] {
        ArtStore.parse(customArten).filter { !ArtStore.builtIn.contains($0) }
    }

    private func builtInAktivBinding(_ art: String) -> Binding<Bool> {
        Binding(
            get: { !ArtStore.parse(deaktivierteArten).contains(art) },
            set: { aktiv in
                var liste = ArtStore.parse(deaktivierteArten)
                if aktiv {
                    liste.removeAll { $0 == art }
                } else if !liste.contains(art) {
                    liste.append(art)
                }
                deaktivierteArten = ArtStore.join(liste)
            }
        )
    }

    private func fuegeArtHinzu() {
        let neu = neueArt.trimmingCharacters(in: .whitespacesAndNewlines)
        neueArt = ""
        guard !neu.isEmpty else { return }
        var liste = eigeneArten
        if !liste.contains(neu) && !ArtStore.builtIn.contains(neu) {
            liste.append(neu)
            customArten = ArtStore.join(liste)
        }
    }

    private func loescheArt(_ offsets: IndexSet) {
        var liste = eigeneArten
        liste.remove(atOffsets: offsets)
        customArten = ArtStore.join(liste)
    }

    // MARK: - Lagerorte

    private var lagerorteSection: some View {
        Section("Lagerorte") {
            NavigationLink {
                LocationsManagementView()
            } label: {
                Label("Lagerorte verwalten", systemImage: "tray.full")
            }
        }
    }

    // MARK: - Export / Import

    private var exportImportSection: some View {
        Section {
            Button {
                exportieren()
            } label: {
                Label("Exportieren (Backup)", systemImage: "square.and.arrow.up")
            }
            Button {
                showImporter = true
            } label: {
                Label("Importieren", systemImage: "square.and.arrow.down")
            }
        } header: {
            Text("Daten sichern")
        } footer: {
            Text("Export erzeugt EINE JSON-Datei mit allen Getränken (inkl. Anzeigebild), Lagerorten, eigenen Klassen und den API-Schlüsseln. Die Datei trägt eine Schema-Version; auch ältere Backups lassen sich weiterhin importieren. Beim Import werden die Daten zusammengeführt, ohne Bestände doppelt zu zählen.")
        }
    }

    private func exportieren() {
        let einstellungen = SettingsDTO(
            aiProvider: aiProviderRaw,
            geminiAPIKey: geminiKey,
            anthropicAPIKey: anthropicKey,
            customArten: customArten,
            deaktivierteArten: deaktivierteArten
        )
        let backup = BackupService.makeBackup(products: products, locations: locations, einstellungen: einstellungen)
        do {
            let data = try BackupService.encode(backup)
            exportDocument = BackupDocument(data: data)
            showExporter = true
        } catch {
            meldung = "Export fehlgeschlagen: \(error.localizedDescription)"
        }
    }

    private func importieren(_ result: Result<URL, Error>) {
        switch result {
        case .failure(let error):
            meldung = "Import fehlgeschlagen: \(error.localizedDescription)"
        case .success(let url):
            let zugriff = url.startAccessingSecurityScopedResource()
            defer { if zugriff { url.stopAccessingSecurityScopedResource() } }
            do {
                let data = try Data(contentsOf: url)
                let backup = try BackupService.decode(data)
                let summary = BackupService.merge(backup, into: context, existingProducts: products, existingLocations: locations)
                var text = "Import erfolgreich: \(summary.produkte) Getränke, \(summary.lagerorte) Lagerorte, \(summary.klassen) neue Klassen."
                if summary.neuereVersionHinweis {
                    text += "\n\nHinweis: Die Datei stammt aus einer neueren App-Version. Es wurde so viel wie möglich übernommen – aktualisiere die App für volle Kompatibilität."
                }
                meldung = text
            } catch {
                meldung = "Import fehlgeschlagen: Die Datei konnte nicht gelesen werden (\(error.localizedDescription))."
            }
        }
    }

    private var offlineHinweis: some View {
        Section {
            Text("Die Etikett-Erkennung (Text + Barcode) und die Duplikat-Prüfung funktionieren auch ohne KI komplett offline auf deinem Gerät.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }
}
