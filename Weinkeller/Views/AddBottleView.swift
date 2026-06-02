import SwiftUI
import SwiftData

/// Ablauf zum Hinzufügen einer Flasche:
/// 1. Foto vom Etikett aufnehmen
/// 2. App liest automatisch Text + Barcode (offline) und füllt die Felder vor
/// 3. Optional: "Mit KI nachschlagen"
/// 4. Anzahl eingeben und speichern – danach kann gleich die nächste Flasche folgen.
struct AddBottleView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    @State private var showCamera = false
    @State private var image: UIImage?
    @State private var isRecognizing = false
    @State private var aiRunning = false
    @State private var aiError: String?

    @State private var typ: BottleType = .wein
    @State private var winzer = ""
    @State private var sorte = ""
    @State private var jahrgang = ""
    @State private var ean = ""
    @State private var quantity = 1
    @State private var lagerort = ""
    @State private var notiz = ""
    @State private var erkannterText = ""

    @State private var savedMessage: String?

    var body: some View {
        NavigationStack {
            Form {
                Section("Etikett-Foto") {
                    if let image {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFit()
                            .frame(maxWidth: .infinity)
                            .frame(maxHeight: 220)
                        Button {
                            showCamera = true
                        } label: {
                            Label("Neues Foto aufnehmen", systemImage: "camera")
                        }
                    } else {
                        Button {
                            showCamera = true
                        } label: {
                            Label("Foto vom Etikett aufnehmen", systemImage: "camera.fill")
                        }
                    }
                    if isRecognizing {
                        HStack {
                            ProgressView()
                            Text("Etikett wird gelesen …")
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                Section("Flasche") {
                    Picker("Art", selection: $typ) {
                        ForEach(BottleType.allCases) { type in
                            Text(type.rawValue).tag(type)
                        }
                    }
                    .pickerStyle(.segmented)

                    TextField("Winzer / Weingut", text: $winzer)
                    TextField("Sorte / Name", text: $sorte)
                    TextField("Jahrgang", text: $jahrgang)
                        .keyboardType(.numbersAndPunctuation)
                    TextField("EAN / Barcode", text: $ean)
                        .keyboardType(.numbersAndPunctuation)
                }

                Section("Anzahl") {
                    Stepper(value: $quantity, in: 1...999) {
                        Text("Anzahl: \(quantity)")
                    }
                }

                Section {
                    Button {
                        Task { await runAI() }
                    } label: {
                        if aiRunning {
                            HStack {
                                ProgressView()
                                Text("KI analysiert das Etikett …")
                            }
                        } else {
                            Label("Mit KI nachschlagen", systemImage: "sparkles")
                        }
                    }
                    .disabled(image == nil || aiRunning)

                    if let aiError {
                        Text(aiError)
                            .font(.footnote)
                            .foregroundStyle(.red)
                    }
                } footer: {
                    Text("Optional: Sendet das Foto an die KI, um Winzer, Sorte und Jahrgang automatisch zu erkennen. Benötigt einen API-Schlüssel (siehe Einstellungen).")
                }

                Section {
                    TextField("Lagerort (z. B. Regal 3, Fach B)", text: $lagerort)
                    TextField("Notiz", text: $notiz, axis: .vertical)
                } header: {
                    Text("Lagerort & Notiz")
                } footer: {
                    Text("Den Lagerort kannst du jetzt oder später jederzeit ergänzen.")
                }

                if !erkannterText.isEmpty {
                    Section("Vom Etikett gelesener Text") {
                        Text(erkannterText)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle("Neue Flasche")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Abbrechen") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Menu {
                        Button("Speichern & schließen") { save(close: true) }
                        Button("Speichern & nächste Flasche") { save(close: false) }
                    } label: {
                        Text("Speichern")
                    }
                    .disabled(!canSave)
                }
            }
            .fullScreenCover(isPresented: $showCamera) {
                CameraPicker { captured in
                    image = captured
                    Task { await recognize(captured) }
                }
                .ignoresSafeArea()
            }
            .overlay(alignment: .bottom) {
                if let savedMessage {
                    Text(savedMessage)
                        .font(.callout.weight(.semibold))
                        .padding(.horizontal, 18)
                        .padding(.vertical, 10)
                        .background(.green, in: Capsule())
                        .foregroundStyle(.white)
                        .padding(.bottom, 24)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
        }
    }

    private var canSave: Bool {
        !winzer.trimmingCharacters(in: .whitespaces).isEmpty ||
        !sorte.trimmingCharacters(in: .whitespaces).isEmpty ||
        image != nil
    }

    /// Liest den Text + Barcode vom Foto und füllt leere Felder vor.
    private func recognize(_ image: UIImage) async {
        isRecognizing = true
        let result = await LabelRecognizer.recognize(image)
        isRecognizing = false

        erkannterText = result.fullText
        if jahrgang.isEmpty { jahrgang = result.jahrgang }
        if ean.isEmpty { ean = result.ean }
        if winzer.isEmpty, let firstMeaningfulLine = result.lines.first(where: { $0.count > 2 }) {
            winzer = firstMeaningfulLine
        }
    }

    /// Fragt optional die KI, um die Felder genauer auszufüllen.
    private func runAI() async {
        guard let image else { return }
        aiRunning = true
        aiError = nil
        do {
            let suggestion = try await WineAIService.identify(image: image)
            if let value = suggestion.winzer, !value.isEmpty { winzer = value }
            if let value = suggestion.sorte, !value.isEmpty { sorte = value }
            if let value = suggestion.jahrgang, !value.isEmpty { jahrgang = value }
            if let value = suggestion.typ, let type = BottleType(rawValue: value.capitalized) { typ = type }
        } catch {
            aiError = error.localizedDescription
        }
        aiRunning = false
    }

    private func save(close: Bool) {
        let bottle = Bottle(
            winzer: winzer.trimmingCharacters(in: .whitespacesAndNewlines),
            sorte: sorte.trimmingCharacters(in: .whitespacesAndNewlines),
            jahrgang: jahrgang.trimmingCharacters(in: .whitespacesAndNewlines),
            typ: typ,
            ean: ean.trimmingCharacters(in: .whitespacesAndNewlines),
            quantity: quantity,
            lagerort: lagerort.trimmingCharacters(in: .whitespacesAndNewlines),
            notiz: notiz.trimmingCharacters(in: .whitespacesAndNewlines),
            bildData: image?.jpegData(compressionQuality: 0.7)
        )
        context.insert(bottle)

        if close {
            dismiss()
        } else {
            // Felder für die nächste Flasche zurücksetzen.
            withAnimation { savedMessage = "Gespeichert ✓" }
            Task {
                try? await Task.sleep(for: .seconds(1.5))
                withAnimation { savedMessage = nil }
            }
            image = nil
            winzer = ""
            sorte = ""
            jahrgang = ""
            ean = ""
            quantity = 1
            lagerort = ""
            notiz = ""
            erkannterText = ""
            typ = .wein
        }
    }
}
