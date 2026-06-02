import SwiftUI

/// Einstellungen: Hier wird optional der KI-API-Schlüssel hinterlegt.
struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage("anthropicAPIKey") private var apiKey = ""

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    SecureField("sk-ant-…", text: $apiKey)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                } header: {
                    Text("KI-API-Schlüssel (Anthropic / Claude)")
                } footer: {
                    Text("""
                    Optional. Mit einem eigenen Schlüssel kann die App auf Knopfdruck \
                    das Etikett per KI analysieren. Einen Schlüssel bekommst du unter \
                    console.anthropic.com. Er wird ausschließlich lokal auf deinem iPhone gespeichert \
                    und nur an Anthropic gesendet, wenn du "Mit KI nachschlagen" antippst.
                    """)
                }

                Section {
                    Text("Die normale Etikett-Erkennung (Text + Barcode) funktioniert auch ohne Schlüssel komplett offline auf deinem Gerät.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
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
}
