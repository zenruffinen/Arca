# Arca – Architektur

Übersicht über den Aufbau der App **Arca** (Version 2.4.0).
Die Diagramme sind in [Mermaid](https://mermaid.js.org) geschrieben und werden
direkt in **Obsidian** (Lesemodus) sowie auf **GitHub** als Grafik dargestellt.

---

## 1. App-Aufbau & Datenfluss

```mermaid
flowchart TD
    A["ArcaApp.swift<br/>(App-Einstieg)"] --> L["LockView<br/>PIN / Face ID"]
    L --> C["ContentView<br/>(Router)"]

    C -->|iPhone| IP["iPhone-Layout<br/>ArcaTabBar + Wischen"]
    C -->|iPad| PAD["iPad-Layout<br/>NavigationSplitView + Sidebar"]

    IP --> SEC
    PAD --> SEC

    subgraph SEC["Bereiche (ArcaSection)"]
        H["Home / Start"]
        V["Vault / Passwörter"]
        D["Dokumente"]
        N["Notizen"]
        T["Tasks / Listen"]
        S["Einstellungen"]
    end

    SEC <--> STORE["AppStore<br/>(ObservableObject = zentraler Zustand)"]

    STORE --> P1["iCloud Drive<br/>(JSON-Dateien)"]
    STORE --> P2["Keychain<br/>(Passwörter, PIN)"]
    STORE --> P3["UserDefaults<br/>(Einstellungen, Schnellzugriff)"]
    STORE --> P4["Dateien<br/>(PDFs, Bilder, Videos)"]
```

---

## 2. Datenmodell (Models.swift)

```mermaid
flowchart LR
    STORE["AppStore"] --> VE["VaultEntry<br/>Titel, Benutzer, Passwort, URL"]
    STORE --> DE["DocumentEntry<br/>Titel, Typ, Datei, Kategorie"]
    STORE --> NE["NoteEntry<br/>Titel, Text, Blitzidee, angepinnt"]
    STORE --> LE["ListEntry<br/>Titel, Farbe"]
    LE --> CI["ChecklistItem<br/>Text, erledigt"]
    STORE --> CAT["documentCategories<br/>+ Schnellansicht (Home)"]
```

---

## 3. Unterstützende Bausteine

```mermaid
flowchart TD
    APP["Arca"] --> UI["ArcaDesign.swift<br/>Design-System: Karten, Icon, Header"]
    APP --> MGR["Manager"]
    MGR --> KC["KeychainManager"]
    MGR --> SP["SpeechManager<br/>(Diktat)"]
    MGR --> QR["QRScanner"]
    APP --> EXTRA["Extras"]
    EXTRA --> W["ArcaWidget<br/>(Homescreen-Widget)"]
    EXTRA --> INT["ArcaIntents<br/>(Siri / Kurzbefehle)"]
    EXTRA --> EGG["SpiderGame<br/>(verstecktes Easter-Egg)"]
```

---

## Kurz zusammengefasst

- **Einstieg:** `ArcaApp` → Sperre (`LockView`) → `ContentView` als Weiche zwischen
  **iPhone** (Tab-Leiste) und **iPad** (Sidebar / Split View).
- **6 Bereiche:** Start, Passwörter, Dokumente, Notizen, Tasks, Einstellungen.
- **Herzstück:** der `AppStore` – hält alle Daten und speichert sie verschlüsselt in
  **iCloud, Keychain, UserDefaults** und als **Dateien**.
- **Drumherum:** Design-System, Manager (Keychain / Diktat / QR), Widget,
  Siri-Intents und das versteckte Spiel.

---

## Dateiübersicht

| Datei | Aufgabe |
|-------|---------|
| `arca/ArcaApp.swift` | App-Einstiegspunkt |
| `arca/LockView.swift` | Sperrbildschirm (PIN / Face ID), Glas-Icon |
| `arca/ContentView.swift` | Haupt-UI & Router, fast alle Ansichten |
| `arca/AppStore.swift` | Zentraler Zustand & Persistenz (iCloud / Keychain) |
| `arca/Models.swift` | Datenmodelle (Vault, Dokument, Notiz, Liste …) |
| `arca/ArcaDesign.swift` | Design-System (Karten, Icon-Kacheln, Header) |
| `arca/KeychainManager.swift` | Sicheres Speichern von Passwörtern & PIN |
| `arca/SpeechManager.swift` | Diktat / Sprache-zu-Text |
| `arca/QRScanner.swift` | QR-Code-Scanner |
| `arca/SpiderGame.swift` | Verstecktes Mini-Spiel (Easter-Egg) |
| `arca/ArcaIntents.swift` | Siri / Kurzbefehle |
| `ArcaWidget/ArcaWidget.swift` | Homescreen-Widget |

---

*Entwickler: Hans zen Ruffinen · Stand: Version 2.4.0 (Build 31)*
