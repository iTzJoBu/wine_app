# 🍷 Weinkeller – iPhone-App zur Wein- & Sekt-Inventarisierung

Eine App, mit der du deinen kompletten Getränkebestand (Wein, Sekt, Champagner,
Prosecco …) verwaltest: Du fotografierst das Etikett, die App liest **Sorte,
Winzer und Jahrgang** automatisch aus, erkennt **Barcodes**, du buchst den
Bestand **flaschenweise** auf beliebig viele **Lagerorte** – und behältst über
eine durchsuchbare, nach Lagerort gruppierte Übersicht den Überblick. Alles
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
- ✨ **Optionale KI-Erkennung** – primär **Google Gemini** (Modell
  `gemini-3.1-flash-lite`, mit Fallback auf das Preview-Modell), bei Fehler oder
  erschöpftem Kontingent automatischer **Rückfall** auf den anderen Anbieter mit
  hinterlegtem Schlüssel (**Anthropic Claude**). Die KI füllt **Sorte, Winzer,
  Jahrgang, Farbe, Art und Verschluss** aus. In den Einstellungen wählst du den
  **bevorzugten** Anbieter; gesendet wird das aufgenommene Foto, das danach
  **verworfen** wird. **Wichtig:** Die KI legt **niemals selbstständig neue
  Arten/Klassen** an – „Art" wird nur einem bereits vorhandenen Wert zugeordnet.
- 🎨 **Zwei getrennte Kategorien:** **Farbe** (rot/weiß/rosé) und **Art**
  (Sekt/Champagner/Prosecco/Wein …). In der Übersicht ist die Art-Markierung in
  der **jeweiligen Weinfarbe** hinterlegt (rot Richtung **Bordeaux**, rosé in
  hellerem **Rosa**). Arten lassen sich in den Einstellungen **hinzufügen**,
  eigene wieder löschen und eingebaute per Schalter **deaktivieren**. Dazu ein
  Schalter **„alkoholfrei"** sowie ein Feld **„Verschluss"** (Korken /
  Schraubverschluss / Kronkorken / keine Angabe).
- 🍾 **Bestand rein flaschenweise:** Jeder Lagerort führt schlicht die **Anzahl
  Flaschen** – keine Karton-Logik mehr.
- 📍 **Mehrere Lagerorte pro Produkt:** Ein Produkt kann an mehreren Orten liegen.
  Lagerorte mit **optionaler Kapazität** anlegen, Belegung sehen („12 / 24" bzw.
  nur die Anzahl ohne Limit), Überbelegung wird **rot** hervorgehoben. Produkte
  lassen sich auch **ganz ohne Lagerort** speichern.
- 🔁 **Verschieben & Entnehmen:** Flaschen von einem Lagerort zu einem anderen
  umbuchen – oder dem Bestand als **Verbrauch entnehmen**.
- ⭐ **Notizen, Favoriten & „Beliebt bei:":** Freies Notizfeld, Produkte als
  **Favorit** markieren (in der Übersicht danach filterbar) und ein Feld
  **„Beliebt bei:"** (Namen mit Komma getrennt), das in der Übersicht
  **durchsuchbar** ist.
- 🔍 **Übersicht immer nach Lagerort gruppiert** (Produkte ohne Lagerort in einer
  eigenen Gruppe „Ohne Lagerort"), mit **Suche**, **Gesamtsummen** und
  **ein-/ausklappbaren Filterkategorien** (Farbe, Art, alkoholfrei, Favoriten,
  Lagerort).
- 💾 **Export & Import (versioniert & abwärtskompatibel):** Eine **JSON-Datei**
  mit **allen** Daten – Getränke (inkl. Bilder & aller Felder), eigene
  Klassen/Arten, Lagerorte **und** die hinterlegten API-Schlüssel. Die Datei
  trägt eine `schemaVersion`; ältere Backups werden über Migrationsstufen
  weiterhin korrekt eingelesen, fehlende/unbekannte Felder führen nie zum
  Absturz. Nach dem Import erscheint eine Rückmeldung (Anzahl Getränke,
  Lagerorte, neue Klassen).
- 💶 **Kostenschätzung für beide Anbieter:** Token-Verbrauch (bei Gemini aus
  `usageMetadata`, bei Claude aus `usage`) wird je Anbieter über anpassbare
  Preis-Konstanten in eine grobe **USD-Schätzung** umgerechnet und für die
  **letzten 7 und 28 Tage** angezeigt – klar als Schätzung gekennzeichnet.
- 💾 Alles wird **lokal auf dem iPhone** gespeichert (SwiftData), keine Cloud,
  kein Konto nötig. Die **Analyse-Fotos** für die KI werden nur ausgewertet und
  danach wieder **verworfen** – nur die gewonnenen Daten bleiben.

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
- Name (z. B. „Keller") eingeben. Die **Kapazität** (Anzahl Flaschen, die
  hineinpassen) ist **optional** und lässt sich bequem über den **Ziffernblock**
  eintippen. Ohne Angabe gilt der Lagerort als unbegrenzt.
- Du siehst pro Lagerort die Belegung („12 / 24 belegt" bzw. nur die Anzahl ohne
  Limit) und wie viel noch frei ist; **Überbelegung** wird rot markiert. Vor dem
  Löschen eines belegten Lagerorts warnt die App.

> Tipp: Du kannst Lagerorte auch **direkt beim Buchen** anlegen – im
> Lagerort-Dropdown ist der oberste Eintrag immer **„➕ Neuen Lagerort
> erstellen"**.

### Ein Getränk hinzufügen
1. **+** oben rechts antippen.
2. **„Vorderseite fotografieren"** → das wird das **Anzeigebild**. Die App liest
   automatisch Text & Barcodes.
3. **„Rückseite fotografieren"** → vor der Aufnahme weist die App ausdrücklich
   darauf hin, dass die **Rückseite** gemeint ist. Dieses Foto dient nur der
   KI-Auswertung und wird danach **verworfen**.
4. **„Mit KI nachschlagen"** (optional) ist aktiv, sobald beide Fotos vorliegen –
   gesendet wird ausschließlich die Rückseite (Anbieter & Schlüssel siehe unten).
5. Felder prüfen: **Sorte, Winzer, Jahrgang, Farbe, Art, alkoholfrei**, EAN und
   **Flaschen pro Karton**.
6. **Einlagern:** Lagerort wählen, **Einheit** (Flasche/Karton) und **Menge**.
7. **„Speichern"**. Erkennt die App ein mögliches Duplikat, fragt sie nach:
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
Gesendet wird dabei **nur das Rückseiten-Foto**.

## Arten verwalten (Einstellungen)

Unter **⚙️ Einstellungen → Arten**:
- **Eingebaute Arten** (Wein, Sekt, Champagner, Prosecco) lassen sich per
  **Schalter deaktivieren** – sie verschwinden dann aus allen Auswahllisten.
- Über **„Art hinzufügen"** legst du eigene Arten an (z. B. Crémant, Cava); diese
  kannst du per Wischen wieder löschen.

## Export & Import (Einstellungen)

Unter **⚙️ Einstellungen → Daten sichern**:
- **Exportieren** erzeugt eine **JSON-Datei** mit allen Produkten, Lagerorten,
  Beständen und Anzeigebildern, die du z. B. in „Dateien", iCloud oder per
  AirDrop sichern kannst.
- **Importieren** liest eine solche Datei wieder ein und **führt sie mit dem
  vorhandenen Bestand zusammen** (Duplikate werden erkannt, Bestände addiert).

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
│   ├── SettingsView.swift          # KI, Arten, Lagerorte, Export/Import, Kosten
│   ├── LocationsManagementView.swift # Lagerorte anlegen/bearbeiten/löschen
│   ├── LocationPicker.swift        # Lagerort-Dropdown (+ „Neuen Lagerort erstellen")
│   └── StockSheets.swift           # Bestand buchen & verschieben
├── Services/
│   ├── CameraPicker.swift          # Zugriff auf die Kamera
│   ├── LabelRecognizer.swift       # Offline: Text + Barcodes (Apple Vision)
│   ├── WineAIService.swift         # Optionale KI (Gemini oder Anthropic)
│   ├── ProductMatcher.swift        # Offline-Duplikaterkennung/-Wiedererkennung
│   ├── StockService.swift          # Buchen/Verschieben von Beständen
│   ├── BackupService.swift         # Export/Import als JSON (inkl. Bilder)
│   └── Pricing.swift               # Token-Preise für die Claude-Kostenschätzung
└── Assets.xcassets/                # App-Icon & Akzentfarbe (Apple-Blau)
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
