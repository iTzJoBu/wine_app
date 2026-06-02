import SwiftUI
import SwiftData

/// Detailansicht einer Flasche – alle Felder sind direkt bearbeitbar.
/// Änderungen werden automatisch in der Datenbank gespeichert.
struct BottleDetailView: View {
    @Bindable var bottle: Bottle
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        Form {
            if let data = bottle.bildData, let uiImage = UIImage(data: data) {
                Section {
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFit()
                        .frame(maxWidth: .infinity)
                        .frame(maxHeight: 260)
                }
            }

            Section("Flasche") {
                Picker("Art", selection: $bottle.typ) {
                    ForEach(BottleType.allCases) { type in
                        Text(type.rawValue).tag(type)
                    }
                }
                LabeledField("Winzer", text: $bottle.winzer)
                LabeledField("Sorte", text: $bottle.sorte)
                LabeledField("Jahrgang", text: $bottle.jahrgang)
                LabeledField("EAN", text: $bottle.ean)
            }

            Section("Bestand") {
                Stepper(value: $bottle.quantity, in: 0...999) {
                    Text("Anzahl: \(bottle.quantity)")
                }
            }

            Section("Lagerort & Notiz") {
                LabeledField("Lagerort", text: $bottle.lagerort)
                TextField("Notiz", text: $bottle.notiz, axis: .vertical)
            }

            Section {
                Button(role: .destructive) {
                    context.delete(bottle)
                    dismiss()
                } label: {
                    Label("Flasche löschen", systemImage: "trash")
                }
            }
        }
        .navigationTitle(bottle.winzer.isEmpty ? "Flasche" : bottle.winzer)
        .navigationBarTitleDisplayMode(.inline)
    }
}

/// Kleine Hilfsansicht für ein beschriftetes Textfeld.
struct LabeledField: View {
    let label: String
    @Binding var text: String

    init(_ label: String, text: Binding<String>) {
        self.label = label
        self._text = text
    }

    var body: some View {
        HStack {
            Text(label)
                .foregroundStyle(.secondary)
                .frame(width: 90, alignment: .leading)
            TextField(label, text: $text)
        }
    }
}
