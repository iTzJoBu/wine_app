import SwiftUI
import SwiftData
import UniformTypeIdentifiers

/// Einstellungen: KI-Anbieter & Schlüssel, Arten verwalten, Lagerorte,
/// Export/Import und (bei Anthropic) die geschätzten Claude-Kosten.
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
                if provider == .anthropic { kostenSection }
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
            Picker("Anbieter", selection: $aiProviderRaw) {
                ForEach(AIProvider.allCases) { p in
                    Text(p.anzeigeName).tag(p.rawValue)
                }
            }
        } header: {
            Text("KI-Anbieter")
        } footer: {
            Text("Bestimmt, welcher Dienst bei 'Mit KI nachschlagen' verwendet wird.")
        }
    }

    @ViewBuilder
    private var schluesselSection: some View {
        if provider == .gemini {
            Section {
                SecureField("AIza…", text: $geminiKey)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
            } header: {
                Text("Google-Gemini-API-Schlüssel")
            } footer: {
                Text("Kostenlos erhältlich unter aistudio.google.com. Wird nur lokal gespeichert und nur an Google gesendet, wenn du 'Mit KI nachschlagen' antippst.")
            }
        } else {
            Section {
                SecureField("sk-ant-…", text: $anthropicKey)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
            } header: {
                Text("Anthropic-(Claude-)API-Schlüssel")
            } footer: {
                Text("Erhältlich unter console.anthropic.com. Wird nur lokal gespeichert und nur an Anthropic gesendet, wenn du 'Mit KI nachschlagen' antippst.")
            }
        }
    }

    // MARK: - Claude-Kosten

    private var kostenSection: some View {
        Section {
            LabeledContent("Geschätzte Kosten gesamt", value: formatUSD(kostenGesamt))
            LabeledContent("… letzte 28 Tage", value: formatUSD(kosten28Tage))
        } header: {
            Text("Claude-Kosten (Schätzung)")
        } footer: {
            Text("Nur eine Schätzung auf Basis der verbrauchten Token und der hinterlegten Preise (\(formatUSD(ClaudePricing.inputUSDPerMillion))/Mio. Input, \(formatUSD(ClaudePricing.outputUSDPerMillion))/Mio. Output für claude-opus-4-8). Keine offizielle Abrechnung.")
        }
    }

    private var kostenGesamt: Double {
        costEvents.reduce(0) { $0 + $1.kostenUSD }
    }

    private var kosten28Tage: Double {
        let grenze = Calendar.current.date(byAdding: .day, value: -28, to: .now) ?? .now
        return costEvents.filter { $0.datum >= grenze }.reduce(0) { $0 + $1.kostenUSD }
    }

    private func formatUSD(_ value: Double) -> String {
        String(format: "$%.4f", value)
    }

    // MARK: - Arten verwalten

    private var artenSection: some View {
        Section {
            // Eingebaute Arten: per Schalter aktivierbar/deaktivierbar.
            ForEach(ArtStore.builtIn, id: \.self) { art in
                Toggle(art, isOn: builtInAktivBinding(art))
            }
            // Eigene Arten: löschbar.
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
            Text("Eingebaute Arten kannst du per Schalter deaktivieren (sie verschwinden dann aus der Auswahl). Eigene Arten lassen sich per Wischen löschen.")
        }
    }

    private var eigeneArten: [String] {
        ArtStore.parse(customArten).filter { !ArtStore.builtIn.contains($0) }
    }

    /// Bindung für den Aktiv-Schalter einer eingebauten Art.
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
            Text("Export erzeugt eine JSON-Datei mit allen Produkten, Lagerorten, Beständen und Anzeigebildern. Beim Import werden die Daten zusammengeführt: Ein Produkt gilt nur bei gleicher EAN oder gleicher Sorte + Winzer + Jahrgang als identisch, und ein bereits vorhandener Bestand (gleicher Lagerort, gleiche Anzahl) wird nicht doppelt gebucht.")
        }
    }

    private func exportieren() {
        let backup = BackupService.makeBackup(products: products, locations: locations)
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
                BackupService.merge(backup, into: context, existingProducts: products, existingLocations: locations)
                meldung = "Import erfolgreich: \(backup.products.count) Produkte und \(backup.locations.count) Lagerorte verarbeitet."
            } catch {
                meldung = "Import fehlgeschlagen: \(error.localizedDescription)"
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
