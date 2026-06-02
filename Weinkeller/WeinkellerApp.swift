import SwiftUI
import SwiftData

// Einstiegspunkt der App. Hier wird die Datenbank (SwiftData) eingerichtet,
// in der alle Flaschen dauerhaft auf dem iPhone gespeichert werden.
@main
struct WeinkellerApp: App {
    var body: some Scene {
        WindowGroup {
            BottleListView()
        }
        // Legt automatisch die lokale Datenbank für unsere Flaschen an.
        .modelContainer(for: Bottle.self)
    }
}
