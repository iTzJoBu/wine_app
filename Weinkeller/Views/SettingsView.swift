import SwiftUI
import SwiftData

/// Einstellungen: KI-Anbieter & Schlüssel, eigene Arten, Lagerorte und (bei
/// Anthropic) die geschätzten Claude-Kosten.
struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss

    @AppStorage(SettingsKey.aiProvider) private var aiProviderRaw = AIProvider.gemini.rawValue
    @AppStorage(SettingsKey.geminiAPIKey) private var geminiKey = ""
    @AppStorage(SettingsKey.anthropicAPIKey) private var anthropicKey = ""
    @AppStorage(SettingsKey.customArten) private var customArten = ""

    @Query private var costEvents: [CostEvent]

    @State private var neueArt = ""

    private var provider: AIProvider {
        AIProvider(rawValue: aiProviderRaw) ?? .gemini
    }

    var body: some View {
        NavigationStack {
            Form {
                providerSection
                schluesselSection
                if provider == .anthropic { kostenSection }
                artenSection
                lagerorteSection
                offlineHinweis
            }
            .navigationTitle("Einstellungen")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Fertig") { dismiss() }
                }
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
            ForEach(ArtStore.builtIn, id: \.self) { art in
                HStack {
                    Text(art)
                    Spacer()
                    Text("eingebaut").font(.caption).foregroundStyle(.secondary)
                }
            }
            ForEach(eigeneArten, id: \.self) { art in
                Text(art)
            }
            .onDelete(perform: loescheArt)

            HStack {
                TextField("Eigene Art (z. B. Crémant, Cava)", text: $neueArt)
                Button("Hinzufügen") { fuegeArtHinzu() }
                    .disabled(neueArt.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        } header: {
            Text("Arten")
        } footer: {
            Text("Eingebaute Arten sind immer verfügbar. Eigene Arten kannst du ergänzen und wieder löschen.")
        }
    }

    private var eigeneArten: [String] {
        ArtStore.parse(customArten).filter { !ArtStore.builtIn.contains($0) }
    }

    private func fuegeArtHinzu() {
        let neu = neueArt.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !neu.isEmpty else { return }
        var liste = eigeneArten
        if !liste.contains(neu) && !ArtStore.builtIn.contains(neu) {
            liste.append(neu)
            customArten = ArtStore.join(liste)
        }
        neueArt = ""
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

    private var offlineHinweis: some View {
        Section {
            Text("Die Etikett-Erkennung (Text + Barcode) und die Duplikat-Prüfung funktionieren auch ohne KI komplett offline auf deinem Gerät.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }
}
