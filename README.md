# 🍷 Weinkeller – iPhone-App zur Wein- & Sekt-Inventarisierung

Eine App, mit der du deinen kompletten Getränkebestand (Wein, Sekt, Champagner,
Prosecco …) verwaltest: Du fotografierst das Etikett, die App liest **Sorte,
Winzer und Jahrgang** automatisch aus, erkennt **Barcodes**, du buchst den
Bestand **flaschen- oder kartonweise** auf beliebig viele **Lagerorte** – und
behältst über eine durchsuchbare, filterbare Übersicht den Überblick. Alles
bleibt **lokal auf deinem iPhone**.

> **Wichtig:** iPhone-Apps lassen sich nur auf einem **Mac mit Xcode** bauen
> und installieren. Der komplette Quellcode liegt hier im Wurzelverzeichnis
> bereit – die folgenden Schritte führen dich von Null bis zur App auf deinem
> iPhone.

---

## Was die App kann

- 📷 **Foto vom Etikett** als Anzeigebild – genau **ein** Bild pro Produkt,
  jederzeit ersetzbar.
- 🔎 **Offline-Erkennung auf dem Gerät** (kostenlos) mit Apple Vision:
  Text vom Etikett (Sorte/Winzer/Jahrgang werden vorbefüllt) **und** Barcodes (EAN).
- 🧠 **Offline-Wiedererkennung:** Der erkannte Text und die Barcodes werden je
  Produkt **unsichtbar** gespeichert und beim nächsten Scan zum Abgleich genutzt –
  funktioniert auch ohne KI.
- 🧾 **Duplikat-Erkennung:** Beim Hinzufügen prüft die App, ob es das Getränk
  schon gibt (erst per EAN, sonst per Winzer+Sorte+Jahrgang und Textähnlichkeit).
  Du kannst dann **zusammenführen** (Bestand hinzubuchen) oder ein **neues
  Produkt** anlegen. *Verschiedene Jahrgänge gelten bewusst als verschiedene
  Produkte.*
- ✨ **Optionale KI-Erkennung**, umschaltbar zwischen **Google Gemini
  (kostenlos)** und **Anthropic Claude** – füllt Winzer, Sorte, Jahrgang, Farbe
  und Art automatisch aus.
- 🎨 **Zwei getrennte Kategorien:** **Farbe** (rot/weiß/rosé) und **Art**
  (Sekt/Champagner/Prosecco/Wein …). Die Art-Liste ist in den Einstellungen
  **erweiterbar** (z. B. Crémant, Cava). Dazu ein Schalter **„alkoholfrei"**.
- 📦 **Flaschen & Kartons kombiniert:** Beim Buchen Einheit wählen (Flasche oder
  Karton), „Flaschen pro Karton" pro Produkt einstellbar (Standard 6), optionaler
  **Karton-Barcode**.
- 📍 **Mehrere Lagerorte pro Produkt:** Ein Produkt kann an mehreren Orten liegen.
  Lagerorte mit **Kapazität** anlegen, Belegung sehen („12 / 24"), Überbelegung
  wird **rot** hervorgehoben.
- 🔁 **Verschieben:** Menge + Einheit von einem Lagerort zu einem anderen umbuchen.
- 🔍 **Übersicht mit Filtern** (Farbe, Art, alkoholfrei, Lagerort – kombinierbar),
  **Suche**, Umschalter **„Nach Lagerort gruppieren"** und **Gesamtsummen**.
- 💶 **Claude-Kostenschätzung:** Bei Anbieter „Anthropic" wird der Tokenverbrauch
  ausgelesen und lokal in eine grobe USD-Schätzung umgerechnet (gesamt & letzte
  28 Tage).
- 💾 Alles wird **lokal auf dem iPhone** gespeichert (SwiftData), keine Cloud,
  kein Konto nötig. **Analyse-Fotos**, die nur zur Datengewinnung dienen, werden
  nach der Auswertung wieder **verworfen** – nur die gewonnenen Daten bleiben.

---

## Was du brauchst

1. **Einen Mac** (MacBook, iMac o. ä.) mit aktuellem macOS
2. **Xcode 16** (kostenlos aus dem Mac App Store)
3. Eine **Apple-ID** (dieselbe wie für den App Store). Eine **kostenlose**
   Apple-ID reicht, um die App auf dein eigenes iPhone zu laden.
4. Dein **iPhone** (mit **iOS 17** oder neuer) + Ladekabel

---

## Schritt für Schritt: App aufs iPhone bringen

### 1. Projekt auf den Mac holen
Lade dieses Repository auf deinen Mac (z. B. über GitHub „Code → Download ZIP",
dann entpacken). Das Xcode-Projekt liegt direkt im **Wurzelverzeichnis**:
die Datei **`Weinkeller.xcodeproj`**.

### 2. Projekt in Xcode öffnen
Doppelklick auf **`Weinkeller.xcodeproj`**. Xcode öffnet sich.

### 3. Mit deiner Apple-ID anmelden (einmalig)
- Menü **Xcode → Settings… → Accounts**
- Auf **„+"** klicken → **Apple ID** → mit deiner Apple-ID anmelden

### 4. Signierung einstellen
- Links in der Dateiliste oben auf **„Weinkeller"** (blaues Projekt-Symbol) klicken
- In der Mitte den Reiter **„Signing & Capabilities"** wählen
- Häkchen bei **„Automatically manage signing"** setzen
- Bei **„Team"** dein Apple-ID-Team auswählen (dein Name)
- Falls eine Fehlermeldung zur **„Bundle Identifier"** erscheint: ändere
  `com.weinkeller.app` in etwas Eindeutiges, z. B. `com.deinname.weinkeller`

### 5. iPhone anschließen
- iPhone per Kabel an den Mac anschließen
- Am iPhone **„Diesem Computer vertrauen"** bestätigen
- In Xcode oben in der Leiste (neben dem ▶︎-Knopf) dein **iPhone** als Ziel auswählen

### 6. App starten
- Oben links auf den **▶︎ (Play)**-Knopf klicken
- Xcode baut die App und installiert sie auf deinem iPhone

### 7. App auf dem iPhone vertrauen (nur beim ersten Mal)
Beim ersten Start zeigt das iPhone „Nicht vertrauter Entwickler":
- Am iPhone: **Einstellungen → Allgemein → VPN & Geräteverwaltung**
- Deine Apple-ID antippen → **„Vertrauen"**
- App erneut öffnen ✅

> **Hinweis zur kostenlosen Apple-ID:** Apps laufen damit **7 Tage**, danach
> einfach in Xcode erneut auf ▶︎ drücken. Mit einem (kostenpflichtigen)
> Apple-Developer-Account entfällt diese Begrenzung.

---

## Die App benutzen

### Zuerst: Lagerorte anlegen
Damit du Bestand einlagern kannst, brauchst du mindestens einen Lagerort.
- **⚙️ Einstellungen → Lagerorte → Lagerorte verwalten → +**
- Name (z. B. „Keller") und **Kapazität** (Anzahl Flaschen, die hineinpassen)
  eingeben.
- Du siehst pro Lagerort die Belegung („12 / 24 belegt") und wie viel noch frei
  ist; **Überbelegung** wird rot markiert. Vor dem Löschen eines belegten
  Lagerorts warnt die App.

> Tipp: Du kannst Lagerorte auch **direkt beim Buchen** anlegen – im
> Lagerort-Dropdown ist der oberste Eintrag immer **„➕ Neuen Lagerort
> erstellen"**.

### Ein Getränk hinzufügen
1. **+** oben rechts antippen.
2. **„Foto vom Etikett aufnehmen"** → das wird das **Anzeigebild**. Die App liest
   automatisch Text & Barcodes.
   - Alternativ **„Analyse-Foto"**: ein zusätzliches Foto nur zur Daten-/KI-
     Auswertung, das danach **verworfen** wird.
3. Optional **„Mit KI nachschlagen"** (Anbieter & Schlüssel siehe unten).
4. Felder prüfen: **Sorte, Winzer, Jahrgang, Farbe, Art, alkoholfrei**, EAN,
   optional **Karton-Barcode** und **Flaschen pro Karton**.
5. **Einlagern:** Lagerort wählen, **Einheit** (Flasche/Karton) und **Menge**.
6. **„Speichern"**. Erkennt die App ein mögliches Duplikat, fragt sie nach:
   **Zusammenführen** (Bestand zum bestehenden Produkt hinzubuchen) oder **als
   neues Produkt anlegen**.

### Übersicht, Suche & Filter
- Pro Zeile steht die **Sorte oben groß**, der **Winzer darunter klein/grau**,
  rechts die **Gesamt-Flaschenzahl**. Die **Fußzeile** zeigt die Summe.
- Über das **Filter-Symbol** (oben rechts) filterst du nach **Farbe, Art,
  alkoholfrei** und **Lagerort** (alles kombinierbar) und schaltest **„Nach
  Lagerort gruppieren"** ein. Im gruppierten Modus gibt es je Lagerort eine
  Überschrift mit Belegung („12 / 24").
- **Suche** und **Summen** beziehen sich immer auf die **aktuell gefilterte**
  Ansicht.

### Detailansicht
- Alle Felder direkt **bearbeitbar**.
- **Bestand je Lagerort** wird aufgelistet, z. B. *„Keller: 1 Karton (6) +
  2 Flaschen = 8"* und *„Garage: 4 Flaschen"*.
- **„Bestand buchen"** (zusätzliche Flaschen/Kartons einlagern) und
  **„Verschieben"** (Menge zwischen zwei Lagerorten umbuchen). Leere Bestände
  werden automatisch entfernt.
- Anzeigebild ersetzen, Produkt löschen.

---

## Optional: KI-Erkennung aktivieren

Die App funktioniert komplett ohne KI (Text-/Barcode-Erkennung und Duplikat-
Prüfung laufen offline auf dem iPhone). Für die genauere **KI-Erkennung** wählst
du in **⚙️ Einstellungen → KI-Anbieter** einen Anbieter und hinterlegst den
passenden Schlüssel:

### Variante A – Google Gemini (kostenlos)
1. Schlüssel kostenlos unter **aistudio.google.com** erstellen (beginnt oft mit `AIza…`).
2. In den Einstellungen Anbieter **„Google Gemini (kostenlos)"** wählen und den
   Schlüssel eintragen.

### Variante B – Anthropic Claude
1. Schlüssel unter **console.anthropic.com** erstellen (beginnt mit `sk-ant-…`).
2. In den Einstellungen Anbieter **„Anthropic Claude"** wählen und den Schlüssel
   eintragen.
3. Es erscheint zusätzlich der Bereich **„Claude-Kosten (Schätzung)"** mit den
   geschätzten Gesamtkosten und denen der letzten 28 Tage.

Der Schlüssel wird **nur lokal** auf deinem iPhone gespeichert und ausschließlich
beim Antippen von „Mit KI nachschlagen" an den gewählten Anbieter gesendet.

> **Kosten-Hinweis:** Die angezeigten Claude-Kosten sind eine **Schätzung** auf
> Basis der verbrauchten Token und der im Code hinterlegten Preise für
> `claude-opus-4-8` (anpassbar in `Services/Pricing.swift`). Es ist **keine**
> offizielle Abrechnung. Gemini ist in der Regel kostenlos; daher wird dort kein
> Kostenbereich angezeigt.
>
> Sollte der Gemini-Modellname `gemini-2.5-flash` einmal Probleme machen, kannst
> du in `Services/WineAIService.swift` auf `gemini-flash-latest` umstellen.

---

## Falls sich das Projekt nicht öffnen lässt (Plan B)

Sollte Xcode die `.xcodeproj` nicht öffnen, kannst du das Projekt selbst neu
anlegen – der Code bleibt derselbe:

1. Xcode → **File → New → Project… → iOS → App**
2. **Product Name:** `Weinkeller`, **Interface:** SwiftUI, **Storage:** SwiftData,
   **Language:** Swift
3. Speicherort wählen → das erzeugt einen Ordner `Weinkeller/`
4. Die von Xcode erzeugten Beispieldateien (z. B. `ContentView.swift`,
   `Item.swift`) löschen
5. Im Finder **alle Dateien** aus dem `Weinkeller/`-Ordner dieses Repos
   (die Ordner `Models`, `Views`, `Services`, `Assets.xcassets` und
   `WeinkellerApp.swift`) in den `Weinkeller/`-Ordner deines neuen Projekts kopieren
6. Unter **Signing & Capabilities** wie oben dein Team einstellen
7. Unter dem Target → **Info** die Zeile **„Privacy - Camera Usage Description"**
   hinzufügen mit Text: *„Die Kamera wird genutzt, um die Etiketten deiner
   Flaschen zu fotografieren."*
8. ▶︎ drücken

---

## Aufbau des Codes (für Neugierige)

```
Weinkeller.xcodeproj/               # Xcode-Projektdatei
Weinkeller/
├── WeinkellerApp.swift             # App-Start + lokale Datenbank (SwiftData)
├── Models/
│   ├── Product.swift               # Produkt (Sorte, Winzer, Jahrgang, Farbe, Art …)
│   ├── Location.swift              # Lagerort (Name, Kapazität, Belegung)
│   ├── StockEntry.swift            # Bestand je Produkt+Lagerort (Kartons + Flaschen)
│   ├── CostEvent.swift             # Geschätzte Claude-Kostenbuchung
│   └── Enums.swift                 # Farbe, Einheit, KI-Anbieter, Art-Verwaltung
├── Views/
│   ├── ProductListView.swift       # Übersicht: Suche, Filter, Gruppierung, Summen
│   ├── AddProductView.swift        # Hinzufügen inkl. Duplikat-Erkennung
│   ├── ProductDetailView.swift     # Bearbeiten + Bestand je Lagerort
│   ├── SettingsView.swift          # KI-Anbieter/Schlüssel, Arten, Lagerorte, Kosten
│   ├── LocationsManagementView.swift # Lagerorte anlegen/bearbeiten/löschen
│   ├── LocationPicker.swift        # Lagerort-Dropdown (+ „Neuen Lagerort erstellen")
│   └── StockSheets.swift           # Bestand buchen & verschieben
├── Services/
│   ├── CameraPicker.swift          # Zugriff auf die Kamera
│   ├── LabelRecognizer.swift       # Offline: Text + Barcodes (Apple Vision)
│   ├── WineAIService.swift         # Optionale KI (Gemini oder Anthropic)
│   ├── ProductMatcher.swift        # Offline-Duplikaterkennung/-Wiedererkennung
│   ├── StockService.swift          # Buchen/Verschieben von Beständen
│   └── Pricing.swift               # Token-Preise für die Claude-Kostenschätzung
└── Assets.xcassets/                # App-Icon & Akzentfarbe
```

**Datenmodell in Kürze**

- **Product** ⟷ viele **StockEntry** (je Lagerort einer) ⟷ **Location**.
- **Gesamtflaschen** eines Bestands = `Kartons × Flaschen/Karton + Einzelflaschen`.
- Versteckte Felder `erkannterText` und `erkannteBarcodes` dienen nur der
  Offline-Wiedererkennung und werden nicht angezeigt.

**Technik:** SwiftUI · SwiftData (lokale Speicherung) · Apple Vision (Text- &
Barcode-Erkennung, offline) · Google-Gemini-/Anthropic-API (optionale KI).
Mindest-iOS: **17.0**.

Viel Freude mit deinem digitalen Weinkeller! 🥂
