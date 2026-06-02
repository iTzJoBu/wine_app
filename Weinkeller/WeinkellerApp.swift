import SwiftUI
import SwiftData

// Einstiegspunkt der App. Hier wird die lokale Datenbank (SwiftData) eingerichtet,
// in der alle Produkte, Lagerorte, Bestände und (geschätzte) Kosten dauerhaft
// auf dem iPhone gespeichert werden.
@main
struct WeinkellerApp: App {
    var body: some Scene {
        WindowGroup {
            ProductListView()
        }
        // Legt die lokale Datenbank für alle Modelle an.
        .modelContainer(for: [Product.self, Location.self, StockEntry.self, CostEvent.self])
    }
}
