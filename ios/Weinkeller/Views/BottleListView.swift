import SwiftUI
import SwiftData

/// Startbildschirm: Liste aller gespeicherten Flaschen mit Suche und Gesamtzahl.
struct BottleListView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \Bottle.dateAdded, order: .reverse) private var bottles: [Bottle]

    @State private var showAdd = false
    @State private var showSettings = false
    @State private var search = ""

    private var filtered: [Bottle] {
        guard !search.isEmpty else { return bottles }
        let query = search.lowercased()
        return bottles.filter {
            $0.winzer.lowercased().contains(query) ||
            $0.sorte.lowercased().contains(query) ||
            $0.jahrgang.contains(query) ||
            $0.lagerort.lowercased().contains(query)
        }
    }

    private var totalBottles: Int {
        bottles.reduce(0) { $0 + $1.quantity }
    }

    var body: some View {
        NavigationStack {
            Group {
                if bottles.isEmpty {
                    ContentUnavailableView {
                        Label("Noch keine Flaschen", systemImage: "wineglass")
                    } description: {
                        Text("Tippe oben rechts auf +, um das Etikett deiner ersten Flasche zu fotografieren.")
                    }
                } else {
                    List {
                        Section {
                            ForEach(filtered) { bottle in
                                NavigationLink {
                                    BottleDetailView(bottle: bottle)
                                } label: {
                                    BottleRow(bottle: bottle)
                                }
                            }
                            .onDelete(perform: delete)
                        } footer: {
                            Text("\(bottles.count) verschiedene Posten · \(totalBottles) Flaschen gesamt")
                        }
                    }
                }
            }
            .navigationTitle("Weinkeller")
            .searchable(text: $search, prompt: "Suche Winzer, Sorte, Lagerort")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        showSettings = true
                    } label: {
                        Image(systemName: "gearshape")
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showAdd = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showAdd) {
                AddBottleView()
            }
            .sheet(isPresented: $showSettings) {
                SettingsView()
            }
        }
    }

    private func delete(_ offsets: IndexSet) {
        for index in offsets {
            context.delete(filtered[index])
        }
    }
}

/// Eine Zeile in der Flaschenliste.
struct BottleRow: View {
    let bottle: Bottle

    var body: some View {
        HStack(spacing: 12) {
            if let data = bottle.bildData, let uiImage = UIImage(data: data) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 48, height: 64)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
            } else {
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color.secondary.opacity(0.15))
                    .frame(width: 48, height: 64)
                    .overlay(
                        Image(systemName: "wineglass")
                            .foregroundStyle(.secondary)
                    )
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(bottle.winzer.isEmpty ? "Unbekannter Winzer" : bottle.winzer)
                    .font(.headline)
                if !bottle.sorte.isEmpty {
                    Text(bottle.sorte)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                HStack(spacing: 6) {
                    if !bottle.jahrgang.isEmpty {
                        Text(bottle.jahrgang)
                    }
                    Text(bottle.typ.rawValue)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 1)
                        .background(Color.accentColor.opacity(0.15), in: Capsule())
                    if !bottle.lagerort.isEmpty {
                        Label(bottle.lagerort, systemImage: "mappin")
                    }
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }

            Spacer()

            Text("×\(bottle.quantity)")
                .font(.title3.weight(.semibold))
                .monospacedDigit()
        }
        .padding(.vertical, 4)
    }
}
