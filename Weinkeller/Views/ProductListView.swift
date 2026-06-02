import SwiftUI
import SwiftData

/// Startbildschirm: durchsuchbare Übersicht aller Getränke, IMMER nach Lagerort
/// gruppiert (inkl. einer Gruppe „Ohne Lagerort"), mit ein-/ausklappbaren Filtern.
struct ProductListView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \Product.dateAdded, order: .reverse) private var products: [Product]
    @Query(sort: \Location.dateAdded) private var locations: [Location]
    @AppStorage(SettingsKey.customArten) private var customArten = ""
    @AppStorage(SettingsKey.deaktivierteArten) private var deaktivierteArten = ""

    @State private var showAdd = false
    @State private var showSettings = false
    @State private var showFilter = false
    @State private var search = ""

    // Filter
    @State private var selectedFarbe: WineColor?
    @State private var selectedArt: String?
    @State private var nurAlkoholfrei = false
    @State private var nurFavoriten = false
    @State private var selectedLocation: Location?

    private var arten: [String] { ArtStore.effective(custom: customArten, deaktiviert: deaktivierteArten) }

    var body: some View {
        NavigationStack {
            Group {
                if products.isEmpty {
                    leererZustand
                } else {
                    gruppierteListe
                }
            }
            .navigationTitle("Weinkeller")
            .searchable(text: $search, prompt: "Suche Sorte, Winzer, Jahrgang, Lagerort, beliebt bei")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button { showSettings = true } label: { Image(systemName: "gearshape") }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showFilter = true } label: {
                        Image(systemName: filterAktiv ? "line.3.horizontal.decrease.circle.fill" : "line.3.horizontal.decrease.circle")
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showAdd = true } label: { Image(systemName: "plus") }
                }
            }
            .sheet(isPresented: $showAdd) { AddProductView() }
            .sheet(isPresented: $showSettings) { SettingsView() }
            .sheet(isPresented: $showFilter) {
                FilterSheet(
                    selectedFarbe: $selectedFarbe,
                    selectedArt: $selectedArt,
                    nurAlkoholfrei: $nurAlkoholfrei,
                    nurFavoriten: $nurFavoriten,
                    selectedLocation: $selectedLocation,
                    arten: arten,
                    locations: locations
                )
            }
        }
    }

    // MARK: - Zustände

    private var leererZustand: some View {
        ContentUnavailableView {
            Label("Noch keine Getränke", systemImage: "wineglass")
        } description: {
            Text("Tippe oben rechts auf +, um das Etikett deines ersten Getränks zu fotografieren.")
        }
    }

    // MARK: - Gruppierte Liste

    private var gruppierteListe: some View {
        List {
            ForEach(gruppen, id: \.id) { gruppe in
                Section {
                    ForEach(gruppe.eintraege, id: \.0.persistentModelID) { (product, count) in
                        NavigationLink {
                            ProductDetailView(product: product)
                        } label: {
                            ProductRow(product: product, count: count)
                        }
                    }
                } header: {
                    HStack {
                        Text(gruppe.titel)
                        Spacer()
                        if let loc = gruppe.location {
                            Text(loc.belegungsText)
                                .foregroundStyle(loc.istUeberbelegt ? .red : .secondary)
                        }
                    }
                }
            }
            Section {
                EmptyView()
            } footer: {
                Text("\(gesamtAnzahl) Flaschen in der aktuellen Ansicht")
            }
        }
    }

    // MARK: - Filterlogik

    private var filterAktiv: Bool {
        selectedFarbe != nil || selectedArt != nil || nurAlkoholfrei || nurFavoriten || selectedLocation != nil
    }

    /// Prüft Farbe/Art/alkoholfrei/Favoriten/Suche – optional auch den Lagerort-Filter.
    private func matches(_ p: Product, applyLocation: Bool) -> Bool {
        if let f = selectedFarbe, p.farbe != f { return false }
        if let a = selectedArt, p.art != a { return false }
        if nurAlkoholfrei, !p.alkoholfrei { return false }
        if nurFavoriten, !p.favorit { return false }
        if applyLocation, let loc = selectedLocation {
            let hatDort = p.stockEntries.contains {
                $0.location?.persistentModelID == loc.persistentModelID && !$0.istLeer
            }
            if !hatDort { return false }
        }
        if !search.isEmpty {
            let q = search.lowercased()
            let inLagerort = p.stockEntries.contains { ($0.location?.name.lowercased().contains(q) ?? false) }
            let treffer = p.sorte.lowercased().contains(q)
                || p.winzer.lowercased().contains(q)
                || p.jahrgang.lowercased().contains(q)
                || p.art.lowercased().contains(q)
                || p.beliebtBei.lowercased().contains(q)
                || inLagerort
            if !treffer { return false }
        }
        return true
    }

    /// Eine Gruppe der Übersicht (Lagerort oder „Ohne Lagerort").
    private struct Gruppe {
        let id: String
        let titel: String
        let location: Location?
        let eintraege: [(Product, Int)]
    }

    /// Baut die nach Lagerort gruppierten Daten auf. Produkte ohne Bestand landen
    /// in der Gruppe „Ohne Lagerort" (nur wenn kein Lagerort-Filter aktiv ist).
    private var gruppen: [Gruppe] {
        var result: [Gruppe] = []

        let zuZeigen = selectedLocation.map { [$0] } ?? locations
        for loc in zuZeigen {
            let eintraege: [(Product, Int)] = loc.stockEntries
                .filter { !$0.istLeer }
                .compactMap { entry -> (Product, Int)? in
                    guard let p = entry.product, matches(p, applyLocation: false) else { return nil }
                    return (p, entry.anzahl)
                }
                .sorted { $0.0.sorte.localizedCaseInsensitiveCompare($1.0.sorte) == .orderedAscending }
            if !eintraege.isEmpty {
                result.append(Gruppe(id: loc.persistentModelID.hashValue.description,
                                     titel: loc.name, location: loc, eintraege: eintraege))
            }
        }

        if selectedLocation == nil {
            let ohne: [(Product, Int)] = products
                .filter { $0.gesamtflaschen == 0 && matches($0, applyLocation: false) }
                .map { ($0, 0) }
                .sorted { $0.0.sorte.localizedCaseInsensitiveCompare($1.0.sorte) == .orderedAscending }
            if !ohne.isEmpty {
                result.append(Gruppe(id: "ohne-lagerort", titel: "Ohne Lagerort", location: nil, eintraege: ohne))
            }
        }

        return result
    }

    private var gesamtAnzahl: Int {
        gruppen.reduce(0) { sum, gruppe in
            sum + gruppe.eintraege.reduce(0) { $0 + $1.1 }
        }
    }
}

// MARK: - Filter-Sheet (ein-/ausklappbare Kategorien)

/// Filter mit ein- und ausklappbaren Kategorien (Farbe, Art, alkoholfrei,
/// Favoriten, Lagerort).
struct FilterSheet: View {
    @Environment(\.dismiss) private var dismiss

    @Binding var selectedFarbe: WineColor?
    @Binding var selectedArt: String?
    @Binding var nurAlkoholfrei: Bool
    @Binding var nurFavoriten: Bool
    @Binding var selectedLocation: Location?

    let arten: [String]
    let locations: [Location]

    @State private var expandFarbe = false
    @State private var expandArt = false
    @State private var expandStatus = false
    @State private var expandLagerort = false

    private var filterAktiv: Bool {
        selectedFarbe != nil || selectedArt != nil || nurAlkoholfrei || nurFavoriten || selectedLocation != nil
    }

    var body: some View {
        NavigationStack {
            Form {
                DisclosureGroup(isExpanded: $expandFarbe) {
                    auswahlZeile(titel: "Alle Farben", aktiv: selectedFarbe == nil) { selectedFarbe = nil }
                    ForEach(WineColor.allCases) { f in
                        auswahlZeile(titel: f.rawValue, aktiv: selectedFarbe == f) {
                            selectedFarbe = (selectedFarbe == f) ? nil : f
                        }
                    }
                } label: {
                    kategorieLabel("Farbe", wert: selectedFarbe?.rawValue)
                }

                DisclosureGroup(isExpanded: $expandArt) {
                    auswahlZeile(titel: "Alle Arten", aktiv: selectedArt == nil) { selectedArt = nil }
                    ForEach(arten, id: \.self) { a in
                        auswahlZeile(titel: a, aktiv: selectedArt == a) {
                            selectedArt = (selectedArt == a) ? nil : a
                        }
                    }
                } label: {
                    kategorieLabel("Art", wert: selectedArt)
                }

                DisclosureGroup(isExpanded: $expandStatus) {
                    Toggle("Nur alkoholfrei", isOn: $nurAlkoholfrei)
                    Toggle("Nur Favoriten", isOn: $nurFavoriten)
                } label: {
                    kategorieLabel("Status", wert: statusWert)
                }

                if !locations.isEmpty {
                    DisclosureGroup(isExpanded: $expandLagerort) {
                        auswahlZeile(titel: "Alle Lagerorte", aktiv: selectedLocation == nil) { selectedLocation = nil }
                        ForEach(locations) { loc in
                            auswahlZeile(titel: loc.name, aktiv: selectedLocation?.persistentModelID == loc.persistentModelID) {
                                selectedLocation = (selectedLocation?.persistentModelID == loc.persistentModelID) ? nil : loc
                            }
                        }
                    } label: {
                        kategorieLabel("Lagerort", wert: selectedLocation?.name)
                    }
                }

                if filterAktiv {
                    Section {
                        Button(role: .destructive) { zuruecksetzen() } label: {
                            Label("Filter zurücksetzen", systemImage: "xmark.circle")
                        }
                    }
                }
            }
            .navigationTitle("Filter")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Fertig") { dismiss() }
                }
            }
        }
    }

    private var statusWert: String? {
        var teile: [String] = []
        if nurAlkoholfrei { teile.append("alkoholfrei") }
        if nurFavoriten { teile.append("Favoriten") }
        return teile.isEmpty ? nil : teile.joined(separator: ", ")
    }

    private func kategorieLabel(_ titel: String, wert: String?) -> some View {
        HStack {
            Text(titel)
            Spacer()
            if let wert {
                Text(wert).foregroundStyle(.secondary)
            }
        }
    }

    private func auswahlZeile(titel: String, aktiv: Bool, aktion: @escaping () -> Void) -> some View {
        Button(action: aktion) {
            HStack {
                Text(titel).foregroundStyle(.primary)
                Spacer()
                if aktiv { Image(systemName: "checkmark").foregroundStyle(.tint) }
            }
        }
    }

    private func zuruecksetzen() {
        selectedFarbe = nil
        selectedArt = nil
        nurAlkoholfrei = false
        nurFavoriten = false
        selectedLocation = nil
    }
}

/// Eine Zeile in der Übersicht: Sorte oben groß, Winzer darunter klein/grau.
struct ProductRow: View {
    let product: Product
    let count: Int

    var body: some View {
        HStack(spacing: 12) {
            thumbnail
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 4) {
                    if product.favorit {
                        Image(systemName: "star.fill")
                            .font(.caption)
                            .foregroundStyle(.yellow)
                    }
                    Text(product.sorte.isEmpty ? "Unbenannt" : product.sorte)
                        .font(.headline)
                        .foregroundStyle(.primary)
                }
                Text(product.winzer.isEmpty ? "Unbekannter Winzer" : product.winzer)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                badges
            }
            Spacer()
            Text("\(count)")
                .font(.title3.weight(.semibold))
                .monospacedDigit()
        }
        .padding(.vertical, 4)
    }

    @ViewBuilder
    private var thumbnail: some View {
        if let data = product.anzeigebildData, let uiImage = UIImage(data: data) {
            Image(uiImage: uiImage)
                .resizable().scaledToFill()
                .frame(width: 48, height: 64)
                .clipShape(RoundedRectangle(cornerRadius: 6))
        } else {
            RoundedRectangle(cornerRadius: 6)
                .fill(Color.secondary.opacity(0.15))
                .frame(width: 48, height: 64)
                .overlay(Image(systemName: "wineglass").foregroundStyle(.secondary))
        }
    }

    private var badges: some View {
        HStack(spacing: 6) {
            // Die Art ist in der jeweiligen Weinfarbe hinterlegt (rot/weiß/rosé),
            // bei unbekannter Farbe neutral grau.
            Text(product.art)
                .padding(.horizontal, 6).padding(.vertical, 1)
                .background(artHintergrund, in: Capsule())
                .overlay(Capsule().strokeBorder(artRand, lineWidth: 0.5))
            if !product.jahrgang.isEmpty { Text(product.jahrgang) }
            if product.alkoholfrei {
                Text("alkoholfrei")
                    .padding(.horizontal, 6).padding(.vertical, 1)
                    .background(Color.green.opacity(0.15), in: Capsule())
            }
        }
        .font(.caption2)
        .foregroundStyle(.secondary)
    }

    private var artHintergrund: Color {
        product.farbe == .keine ? Color.secondary.opacity(0.18) : product.farbe.swatch.opacity(0.35)
    }

    private var artRand: Color {
        product.farbe == .keine ? Color.secondary.opacity(0.25) : product.farbe.swatch.opacity(0.6)
    }
}
