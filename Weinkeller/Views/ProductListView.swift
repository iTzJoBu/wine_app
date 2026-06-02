import SwiftUI
import SwiftData

/// Startbildschirm: durchsuchbare Übersicht aller Getränke mit Filtern,
/// optionaler Gruppierung nach Lagerort und Gesamtsumme.
struct ProductListView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \Product.dateAdded, order: .reverse) private var products: [Product]
    @Query(sort: \Location.dateAdded) private var locations: [Location]
    @AppStorage(SettingsKey.customArten) private var customArten = ""

    @State private var showAdd = false
    @State private var showSettings = false
    @State private var search = ""

    // Filter
    @State private var selectedFarbe: WineColor?
    @State private var selectedArt: String?
    @State private var nurAlkoholfrei = false
    @State private var selectedLocation: Location?
    @State private var gruppieren = false

    private var arten: [String] { ArtStore.all(custom: customArten) }

    var body: some View {
        NavigationStack {
            Group {
                if products.isEmpty {
                    leererZustand
                } else if gruppieren {
                    gruppierteListe
                } else {
                    flacheListe
                }
            }
            .navigationTitle("Weinkeller")
            .searchable(text: $search, prompt: "Suche Sorte, Winzer, Jahrgang, Lagerort")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button { showSettings = true } label: { Image(systemName: "gearshape") }
                }
                ToolbarItem(placement: .topBarTrailing) { filterMenu }
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showAdd = true } label: { Image(systemName: "plus") }
                }
            }
            .sheet(isPresented: $showAdd) { AddProductView() }
            .sheet(isPresented: $showSettings) { SettingsView() }
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

    // MARK: - Flache Liste

    private var flacheListe: some View {
        List {
            Section {
                ForEach(filteredProducts) { product in
                    NavigationLink {
                        ProductDetailView(product: product)
                    } label: {
                        ProductRow(product: product, count: anzeigeAnzahl(product))
                    }
                }
                .onDelete(perform: delete)
            } footer: {
                Text("\(filteredProducts.count) Produkte · \(gesamtFlach) Flaschen gesamt")
            }
        }
    }

    // MARK: - Gruppierte Liste

    private var gruppierteListe: some View {
        List {
            ForEach(gruppen, id: \.0.persistentModelID) { (loc, eintraege) in
                Section {
                    ForEach(eintraege, id: \.0.persistentModelID) { (product, entry) in
                        NavigationLink {
                            ProductDetailView(product: product)
                        } label: {
                            ProductRow(product: product, count: entry.gesamtflaschen)
                        }
                    }
                } header: {
                    HStack {
                        Text(loc.name)
                        Spacer()
                        Text(loc.belegungsText)
                            .foregroundStyle(loc.istUeberbelegt ? .red : .secondary)
                    }
                }
            }
            Section {
                EmptyView()
            } footer: {
                Text("\(gesamtGruppiert) Flaschen in der aktuellen Ansicht")
            }
        }
    }

    private var filterMenu: some View {
        Menu {
            Picker("Farbe", selection: $selectedFarbe) {
                Text("Alle Farben").tag(WineColor?.none)
                ForEach(WineColor.allCases) { Text($0.rawValue).tag(WineColor?.some($0)) }
            }
            Picker("Art", selection: $selectedArt) {
                Text("Alle Arten").tag(String?.none)
                ForEach(arten, id: \.self) { Text($0).tag(String?.some($0)) }
            }
            if !locations.isEmpty {
                Picker("Lagerort", selection: $selectedLocation) {
                    Text("Alle Lagerorte").tag(Location?.none)
                    ForEach(locations) { Text($0.name).tag(Location?.some($0)) }
                }
            }
            Toggle("Nur alkoholfrei", isOn: $nurAlkoholfrei)
            Divider()
            Toggle("Nach Lagerort gruppieren", isOn: $gruppieren)
            if filterAktiv {
                Divider()
                Button(role: .destructive) { filterZuruecksetzen() } label: {
                    Label("Filter zurücksetzen", systemImage: "xmark.circle")
                }
            }
        } label: {
            Image(systemName: filterAktiv ? "line.3.horizontal.decrease.circle.fill" : "line.3.horizontal.decrease.circle")
        }
    }

    // MARK: - Filterlogik

    private var filterAktiv: Bool {
        selectedFarbe != nil || selectedArt != nil || nurAlkoholfrei || selectedLocation != nil
    }

    private func filterZuruecksetzen() {
        selectedFarbe = nil
        selectedArt = nil
        nurAlkoholfrei = false
        selectedLocation = nil
    }

    /// Prüft Farbe/Art/alkoholfrei/Suche – optional auch den Lagerort-Filter.
    private func matches(_ p: Product, applyLocation: Bool) -> Bool {
        if let f = selectedFarbe, p.farbe != f { return false }
        if let a = selectedArt, p.art != a { return false }
        if nurAlkoholfrei, !p.alkoholfrei { return false }
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
                || inLagerort
            if !treffer { return false }
        }
        return true
    }

    private var filteredProducts: [Product] {
        products.filter { matches($0, applyLocation: true) }
    }

    /// Anzahl, die in der flachen Liste pro Produkt angezeigt wird.
    /// Mit Lagerort-Filter nur die Flaschen dort, sonst die Gesamtzahl.
    private func anzeigeAnzahl(_ p: Product) -> Int {
        if let loc = selectedLocation {
            return p.stockEntries
                .filter { $0.location?.persistentModelID == loc.persistentModelID }
                .reduce(0) { $0 + $1.gesamtflaschen }
        }
        return p.gesamtflaschen
    }

    private var gesamtFlach: Int {
        filteredProducts.reduce(0) { $0 + anzeigeAnzahl($1) }
    }

    /// Gruppierte Daten: je Lagerort die passenden Produkte mit ihrem dortigen Eintrag.
    private var gruppen: [(Location, [(Product, StockEntry)])] {
        let zuZeigen = selectedLocation.map { [$0] } ?? locations
        return zuZeigen.compactMap { loc in
            let eintraege: [(Product, StockEntry)] = loc.stockEntries
                .filter { !$0.istLeer }
                .compactMap { entry in
                    guard let p = entry.product, matches(p, applyLocation: false) else { return nil }
                    return (p, entry)
                }
                .sorted { $0.0.sorte.localizedCaseInsensitiveCompare($1.0.sorte) == .orderedAscending }
            return eintraege.isEmpty ? nil : (loc, eintraege)
        }
    }

    private var gesamtGruppiert: Int {
        gruppen.reduce(0) { sum, gruppe in
            sum + gruppe.1.reduce(0) { $0 + $1.1.gesamtflaschen }
        }
    }

    private func delete(_ offsets: IndexSet) {
        let liste = filteredProducts
        for index in offsets where index < liste.count {
            context.delete(liste[index])
        }
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
                Text(product.sorte.isEmpty ? "Unbenannt" : product.sorte)
                    .font(.headline)
                    .foregroundStyle(.primary)
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
            if product.farbe != .keine {
                HStack(spacing: 3) {
                    Circle().fill(product.farbe.swatch).frame(width: 7, height: 7)
                    Text(product.farbe.rawValue)
                }
            }
            Text(product.art)
                .padding(.horizontal, 6).padding(.vertical, 1)
                .background(Color.accentColor.opacity(0.15), in: Capsule())
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
}
