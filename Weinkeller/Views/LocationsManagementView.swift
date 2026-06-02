import SwiftUI
import SwiftData

/// Verwaltung der Lagerorte: anlegen, bearbeiten, löschen.
/// Zeigt je Lagerort die aktuelle Belegung und hebt Überbelegung farblich hervor.
struct LocationsManagementView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \Location.dateAdded) private var locations: [Location]

    @State private var bearbeiten: Location?
    @State private var neuAnlegen = false
    @State private var loeschKandidat: Location?

    var body: some View {
        List {
            if locations.isEmpty {
                ContentUnavailableView(
                    "Noch keine Lagerorte",
                    systemImage: "tray",
                    description: Text("Lege deinen ersten Lagerort an, z. B. 'Keller' mit Kapazität 24.")
                )
            } else {
                ForEach(locations) { loc in
                    Button {
                        bearbeiten = loc
                    } label: {
                        row(for: loc)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .navigationTitle("Lagerorte")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    neuAnlegen = true
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .sheet(isPresented: $neuAnlegen) {
            LocationEditSheet(location: nil)
        }
        .sheet(item: $bearbeiten) { loc in
            LocationEditSheet(location: loc)
        }
        .confirmationDialog(
            loeschTitel,
            isPresented: Binding(get: { loeschKandidat != nil }, set: { if !$0 { loeschKandidat = nil } }),
            titleVisibility: .visible
        ) {
            Button("Lagerort löschen", role: .destructive) {
                if let loc = loeschKandidat { context.delete(loc) }
                loeschKandidat = nil
            }
            Button("Abbrechen", role: .cancel) { loeschKandidat = nil }
        } message: {
            Text("Der eingelagerte Bestand an diesem Ort wird dabei entfernt.")
        }
    }

    private var loeschTitel: String {
        guard let loc = loeschKandidat else { return "" }
        return "Lagerort \(loc.name) enthält noch \(loc.belegteFlaschen) Flaschen. Wirklich löschen?"
    }

    @ViewBuilder
    private func row(for loc: Location) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(loc.name)
                    .font(.headline)
                if let notiz = loc.notiz, !notiz.isEmpty {
                    Text(notiz)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text("\(loc.belegungsText) belegt")
                    .font(.subheadline.monospacedDigit())
                    .foregroundStyle(loc.istUeberbelegt ? .red : .primary)
                if loc.istUeberbelegt {
                    Text("überbelegt!")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.red)
                } else if let frei = loc.freieKapazitaet {
                    Text("\(frei) frei")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                } else {
                    Text("ohne Limit")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .swipeActions(edge: .trailing) {
            Button(role: .destructive) {
                attemptDelete(loc)
            } label: {
                Label("Löschen", systemImage: "trash")
            }
        }
        .contentShape(Rectangle())
    }

    private func attemptDelete(_ loc: Location) {
        if loc.belegteFlaschen > 0 {
            loeschKandidat = loc
        } else {
            context.delete(loc)
        }
    }
}
