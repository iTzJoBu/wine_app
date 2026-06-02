import SwiftUI
import SwiftData

/// Wiederverwendbares Dropdown zur Lagerort-Auswahl.
/// Der OBERSTE Eintrag ist immer „➕ Neuen Lagerort erstellen" und öffnet ein
/// kleines Formular (Name + Kapazität). Der neu erstellte Ort wird direkt gewählt.
struct LocationPicker: View {
    @Query(sort: \Location.dateAdded) private var locations: [Location]
    @Binding var selection: Location?
    @State private var showNew = false

    var body: some View {
        Menu {
            Button {
                showNew = true
            } label: {
                Label("➕ Neuen Lagerort erstellen", systemImage: "plus")
            }
            if !locations.isEmpty {
                Divider()
                ForEach(locations) { loc in
                    Button {
                        selection = loc
                    } label: {
                        if selection?.persistentModelID == loc.persistentModelID {
                            Label("\(loc.name) (\(loc.belegungsText))", systemImage: "checkmark")
                        } else {
                            Text("\(loc.name) (\(loc.belegungsText))")
                        }
                    }
                }
            }
        } label: {
            HStack {
                Text("Lagerort")
                    .foregroundStyle(.primary)
                Spacer()
                Text(selection?.name ?? "wählen")
                    .foregroundStyle(.secondary)
                Image(systemName: "chevron.up.chevron.down")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .sheet(isPresented: $showNew) {
            LocationEditSheet(location: nil) { neu in
                selection = neu
            }
        }
    }
}

/// Kleines Formular zum Anlegen oder Bearbeiten eines Lagerorts.
/// Wird `location` übergeben, ist es der Bearbeiten-Modus, sonst Neu-Modus.
struct LocationEditSheet: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    let location: Location?
    var onSaved: (Location) -> Void = { _ in }

    @State private var name = ""
    @State private var kapazitaet = 24
    @State private var notiz = ""

    private var istNeu: Bool { location == nil }

    var body: some View {
        NavigationStack {
            Form {
                Section("Lagerort") {
                    TextField("Name (z. B. Keller, Garage)", text: $name)
                    Stepper(value: $kapazitaet, in: 1...100000) {
                        Text("Kapazität: \(kapazitaet) Flaschen")
                    }
                }
                Section("Notiz (optional)") {
                    TextField("Notiz", text: $notiz, axis: .vertical)
                }
            }
            .navigationTitle(istNeu ? "Neuer Lagerort" : "Lagerort bearbeiten")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Abbrechen") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Sichern") { save() }
                        .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .onAppear {
                if let location {
                    name = location.name
                    kapazitaet = location.kapazitaet
                    notiz = location.notiz ?? ""
                }
            }
        }
    }

    private func save() {
        let sauberName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let sauberNotiz = notiz.trimmingCharacters(in: .whitespacesAndNewlines)
        let ziel: Location
        if let location {
            location.name = sauberName
            location.kapazitaet = kapazitaet
            location.notiz = sauberNotiz.isEmpty ? nil : sauberNotiz
            ziel = location
        } else {
            let neu = Location(name: sauberName, kapazitaet: kapazitaet, notiz: sauberNotiz.isEmpty ? nil : sauberNotiz)
            context.insert(neu)
            ziel = neu
        }
        onSaved(ziel)
        dismiss()
    }
}
