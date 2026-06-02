# 🍷 Weinkeller – iPhone-App zur Wein- & Sekt-Inventarisierung

Eine App, mit der du deinen Wein- und Sektbestand verwaltest: Du fotografierst
das Etikett, die App liest **Winzer, Sorte und Jahrgang** automatisch aus,
erkennt den **EAN-Barcode** und du speicherst die **Anzahl** der Flaschen –
inklusive **Lagerort** im Keller.

> **Wichtig:** iPhone-Apps lassen sich nur auf einem **Mac mit Xcode** bauen
> und installieren. Der komplette Quellcode liegt hier bereit – die folgenden
> Schritte führen dich von Null bis zur App auf deinem iPhone.

---

## Was die App kann

- 📷 **Foto vom Etikett** aufnehmen
- 🔎 **Automatische Erkennung auf dem Gerät** (kostenlos, offline):
  Text vom Etikett (Winzer/Sorte/Jahrgang werden vorausgefüllt) **und** EAN-Barcode
- ✨ **Optional: KI-Erkennung** per Anthropic/Claude (genauer, benötigt einen
  eigenen API-Schlüssel – siehe unten)
- 🔢 **Anzahl** je Flasche erfassen, danach direkt mit der **nächsten** weitermachen
- 📍 **Lagerort** und **Notiz** (kann auch nachträglich ergänzt werden)
- 📚 Übersicht aller Flaschen mit **Suche** und **Gesamtzahl**, jederzeit bearbeitbar
- 💾 Alles wird **lokal auf dem iPhone** gespeichert (Datenbank + Etiketten-Fotos)

---

## Was du brauchst

1. **Einen Mac** (MacBook, iMac o. ä.) mit aktuellem macOS
2. **Xcode 16** (kostenlos aus dem Mac App Store)
3. Eine **Apple-ID** (die hast du schon – dieselbe wie für den App Store).
   Eine **kostenlose** Apple-ID reicht, um die App auf dein eigenes iPhone zu laden.
4. Dein **iPhone** + Ladekabel

---

## Schritt für Schritt: App aufs iPhone bringen

### 1. Projekt auf den Mac holen
Lade dieses Repository auf deinen Mac (z. B. über GitHub „Code → Download ZIP",
dann entpacken). Die App liegt im Ordner **`ios/`**.

### 2. Projekt in Xcode öffnen
Doppelklick auf **`ios/Weinkeller.xcodeproj`**. Xcode öffnet sich.

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

1. **+** oben rechts antippen
2. **„Foto vom Etikett aufnehmen"** → Etikett fotografieren
3. Die App liest automatisch Text & Barcode und füllt die Felder vor
4. Optional **„Mit KI nachschlagen"** für eine genauere Erkennung
5. Felder prüfen/korrigieren, **Anzahl** einstellen, ggf. **Lagerort** eintragen
6. **„Speichern"** → entweder **schließen** oder direkt **„nächste Flasche"**
7. Auf der Startseite siehst du alle Flaschen; Tippen öffnet die Detailansicht
   zum Bearbeiten oder Löschen

---

## Optional: KI-Erkennung aktivieren

Die App funktioniert komplett ohne KI (Text- und Barcode-Erkennung laufen
offline auf dem iPhone). Für die genauere **KI-Erkennung**:

1. Einen API-Schlüssel unter **console.anthropic.com** erstellen
2. In der App oben links auf **⚙️ (Einstellungen)**
3. Schlüssel einfügen (beginnt mit `sk-ant-…`)

Der Schlüssel wird **nur lokal** auf deinem iPhone gespeichert und ausschließlich
beim Antippen von „Mit KI nachschlagen" an Anthropic gesendet. Achtung: Jede
KI-Anfrage kann (geringe) Kosten verursachen – je nach Anthropic-Tarif.

---

## Falls sich das Projekt nicht öffnen lässt (Plan B)

Sollte Xcode die `.xcodeproj` nicht öffnen, kannst du das Projekt in 2 Minuten
selbst neu anlegen – der Code bleibt derselbe:

1. Xcode → **File → New → Project… → iOS → App**
2. **Product Name:** `Weinkeller`, **Interface:** SwiftUI, **Storage:** SwiftData,
   **Language:** Swift
3. Speicherort wählen → das erzeugt einen Ordner `Weinkeller/`
4. Die von Xcode erzeugten Beispieldateien (z. B. `ContentView.swift`,
   `Item.swift`) löschen
5. Im Finder **alle Dateien** aus diesem `ios/Weinkeller/`-Ordner
   (die Ordner `Models`, `Views`, `Services`, `Assets.xcassets` und
   `WeinkellerApp.swift`) in den `Weinkeller/`-Ordner deines neuen Projekts kopieren
6. In Xcode unter **Signing & Capabilities** wie oben dein Team einstellen
7. Unter dem Target → **Info** die Zeile **„Privacy - Camera Usage Description"**
   hinzufügen mit Text: *„Die Kamera wird genutzt, um Etiketten zu fotografieren."*
8. ▶︎ drücken

---

## Aufbau des Codes (für Neugierige)

```
ios/Weinkeller/
├── WeinkellerApp.swift          # App-Start + Datenbank
├── Models/
│   └── Bottle.swift             # Datenmodell einer Flasche
├── Views/
│   ├── BottleListView.swift     # Übersicht aller Flaschen
│   ├── AddBottleView.swift      # Hinzufügen (Foto → Erkennung → Speichern)
│   ├── BottleDetailView.swift   # Bearbeiten/Löschen einer Flasche
│   └── SettingsView.swift       # KI-API-Schlüssel
└── Services/
    ├── CameraPicker.swift       # Zugriff auf die Kamera
    ├── LabelRecognizer.swift    # Offline-Erkennung: Text + EAN-Barcode
    └── WineAIService.swift      # Optionale KI-Erkennung (Anthropic)
```

Viel Freude mit deinem digitalen Weinkeller! 🥂
