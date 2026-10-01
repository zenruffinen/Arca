# Arca auf dem iPhone Duo

Stand 01.10.2026 — aufgenommen im Simulator (iOS 27.1, Device Hub),
ohne echtes Gerät. Diese Notiz hält fest, was wir wissen, damit die
Arbeit wieder aufgenommen werden kann, sobald es Geräte gibt oder Apple
die SwiftUI-Seite nachzieht.

## Entscheidung

**Wir warten.** Das Fundament ist gelegt (siehe „Erledigt"), der Rest
ruht. Gründe:

1. Die beiden entscheidenden APIs für die Faltregion gibt es in
   iOS 27.1 **nur in UIKit**, nicht in SwiftUI. Heute gebaute
   `UIViewRepresentable`-Brücken wären Wegwerfcode.
2. Der Simulator zeigt Geometrie, nicht Gefühl. Ob eine Taste auf dem
   Falz stört oder die Leiste auf dem kurzen Außendisplay drückt, merkt
   man in der Hand.
3. Die große Frage ist die Leiste (siehe unten) — eine Entscheidung
   über das Gesicht der App, die man nicht auf Verdacht trifft.

## Das Gerät

Zwei Displays, in Punkten:

| Display | Maße | Size Class | Wann |
|---|---|---|---|
| außen | 466 × 678 | compact | zugeklappt |
| innen | 669 × 951 | regular | aufgeklappt |

Das Außendisplay ist **breiter und kürzer** als ein normales iPhone
(iPhone 18 Pro: 402 × 874). Deshalb legt das System dort Toolbars,
Tab-Bars und die Statusleiste **senkrecht an die Seite**, um Höhe für
Inhalt zu sparen.

Im Simulator: Device Hub (`/Applications/Xcode.app/Contents/Applications/DeviceHub.app`
— die Simulator.app gibt es in Xcode 27 nicht mehr). Unten die drei
Posen **Closed · Book · Open**. In der Book-Pose läuft der Falz
**senkrecht** durch die Mitte.

Screenshots pro Display:

```bash
xcrun simctl io <udid> enumerate          # zeigt beide Display-UUIDs
xcrun simctl io <udid> screenshot --display <uuid> bild.png
```

Ohne `--display` erwischt man das innere — zugeklappt ist das schwarz.

## Erledigt

Beides ist kein Duo-Sonderfall, sondern gilt überall:

- **„‹ Space"-Knopf** (`ContentView.swift`) lag als `.overlay` über dem
  Inhalt und verdeckte auf dem Duo die Kopfzeile („…ues Dokument").
  Jetzt `.safeAreaInset(edge: .top)`.
- **Sperrbildschirm** (`LockView.swift`) brauchte mit festen 32 pt
  Abstand und 92er Logo rund 700 pt; außen sind es 678. Ragte oben und
  unten heraus. Jetzt misst er die Höhe und wird unter 720 pt enger
  (Abstände 18, Logo 62).

## Offen

### 1. Die Leiste — die große Frage

`ArcaTabBar` (`ArcaLeiste.swift`) ist handgebaut. Apples Kernpunkt beim
Duo: Tab-Bars wandern auf dem Außendisplay an die **Seite**. Das bekommt
man automatisch *nur* mit Standard-Komponenten. Unsere Kapsel bleibt
unten und kostet ~90 von 678 Punkten.

Drei Wege, keiner davon umsonst:

- **Native `TabView`** — seitliche Platzierung, `tabBarMinimizeBehavior`
  und die Duo-Kompression gratis. Kostet die schwebende Kapsel mit Bogen,
  zentralem Plus und Besen. Das ist die Handschrift der App.
- **Eigene Leiste selbst seitlich legen** — Handschrift bleibt, aber es
  ist Handarbeit gegen das System, und die HIG rät ausdrücklich davon ab,
  die Bar-Platzierung selbst zu bestimmen.
- **So lassen** — funktioniert, nutzt die Höhe aber schlecht.

Am echten Gerät entscheiden.

### 2. Faltregion

In der Book-Pose läuft der Falz senkrecht durch die Mitte. Beim
Sperrbildschirm liegt er zwischen der zweiten und dritten Ziffernspalte.
Auch die Schreibtisch-Schienen im iPad-Layout könnten über den Knick
laufen.

Apples Werkzeuge dafür — **und was fehlt**:

| API | SwiftUI (27.1) | UIKit (27.1) |
|---|---|---|
| `ReservedRegion` | **nein** | ja (`UIViewReservedRegion.h`) |
| `ArrangementView` | **nein** | ja (`UIArrangementViewController.h`) |
| `ToolbarItemVisibilityPriority` | ja | ja |
| `ToolbarVerticalCompressionBehavior` | ja | ja |
| `ToolbarOverflowMenu` | ja | ja |

Geprüft im SwiftUI-`.swiftinterface` des iOS-27.1-SDK. Die HIG nennt
SwiftUI-Varianten, im SDK sind sie (noch) nicht.

### 3. Feste Breiten

- `ContentView.swift`: `let inhaltsBreite: CGFloat = 410` — Schwelle für
  die Schreibtisch-Schienen. Funktioniert auf dem Duo zufällig richtig,
  ist aber eine display-abhängige Zahl, die die HIG ausdrücklich
  vermeiden will.
- `Start.swift`: `homeContentMaxWidth = 700` im regular-Layout. Als
  Lesebreite legitim, aber einmal prüfen.

### 4. Toolbar-Prioritäten

Die Unterseiten (Dokumente, Tresor, Notizen, Aufgaben, Notfall …) nutzen
in 12 Dateien echte `.toolbar` — die wandern auf dem Duo automatisch an
die Seite. Noch nicht genutzt: `ToolbarItemVisibilityPriority`, damit bei
Platzmangel die wichtigen Aktionen zuletzt in den Überlaufknopf rutschen.
Das ginge schon heute und schadet auf keinem Gerät.

## Quelle

[Designing for iPhone Duo](https://developer.apple.com/design/human-interface-guidelines/designing-for-iphone-duo)
(Apple HIG, neu am 09.09.2026)
