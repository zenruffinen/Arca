---
title: Arca Tickets
tags:
  - Arca
  - ArcaTickets
  - Produkt
date: 2026-07-05
status: Killer App MVP
---

# Arca Tickets

> [!note] Verwandtes Projekt
> Arca Tickets ist ein schlanker Ableger von [[Arca]] — fokussiert auf Fahrkarten und digitale Tickets, ohne Vault, Notizen oder Tasks.

#Arca #ArcaTickets #Produkt

---

## In Xcode starten

> [!important] Kein separates Projekt
> Arca Tickets liegt **nicht** in `ArcaTickets.xcodeproj` (gibt es nicht), sondern als **eigenes Target** im bestehenden **`Arca.xcodeproj`**.

1. **`Arca.xcodeproj`** öffnen (nicht nur den Ordner `arca/` oder `ArcaTickets/`)
2. Oben links im Scheme-Dropdown **`ArcaTickets`** wählen (nicht „Arca“)
3. Simulator wählen, z. B. **iPhone 17**
4. **⌘R** zum Bauen und Starten

**Projektstruktur auf der Platte:**

```
Arca/
├── arca/                    ← Haupt-App Arca
├── ArcaTickets/             ← Swift-Quellen, Assets, Info.plist
├── Arca.xcodeproj           ← beide Apps in einem Projekt
│   └── xcshareddata/xcschemes/
│       ├── Arca.xcscheme
│       └── ArcaTickets.xcscheme
└── docs/Arca-Tickets.md
```

**Scheme fehlt?** Scheme-Dropdown → **Manage Schemes…** → **ArcaTickets** aktivieren (Häkchen „Shared“).

**Build auf echtem iPhone schlägt fehl?** iCloud-Container `iCloud.com.hansruffin.ArcaTickets` muss in [developer.apple.com](https://developer.apple.com) für die App-ID `com.hansruffin.ArcaTickets` angelegt sein. Im **Simulator** funktioniert der Build ohne dieses Setup.

---

## Killer-App-Positionierung

**Das schnellste Ticket in der Tasche — speichern, vorzeigen, rechtzeitig erinnert.**

Arca Tickets ist bewusst **klein und fokussiert**: keine Reiseplanung, kein Wallet-Export, kein OCR. Stattdessen drei Momente, in denen jede andere App zu langsam ist:

| Moment | Killer-Feature | Warum es zählt |
|--------|----------------|----------------|
| **Am Schalter** | QR/Barcode-Vollbild mit max. Helligkeit, Wisch zum Schließen | Scanner muss sofort lesen — kein Zoomen, kein Suchen |
| **Unterwegs** | Nächstes Ticket als Hero-Karte + „Am Schalter zeigen" | Ein Tap statt Ordner durchsuchen |
| **Vor Ablauf** | Lokale Erinnerung 1 Tag vorher | Ticket vergessen = Geld verloren |

**Differenzierung gegenüber Wallet & Konkurrenz:** PDF-Tickets, Screenshots und Fremdanbieter-QR-Codes, die Apple Wallet nicht kennt — plus schneller Import per Teilen und PIN/Face-ID-Schutz.

---

## Produktvision

**Alle Fahrkarten und Tickets an einem Ort — schnell abrufbar, sicher gespeichert, rechtzeitig erinnert.**

Arca Tickets ist eine dedizierte iOS-App für Reisende und Eventbesucher: Foto oder PDF importieren, in Ordner sortieren, QR-Code im Vollbild vorzeigen — ohne den Overhead der vollständigen [[Arca]]-Produktivitäts-Suite.

---

## Killer-Features (v1 — implementiert)

| # | Feature | Status | Beschreibung |
|---|---------|--------|--------------|
| 1 | **QR/Barcode Vollbild** | ✅ | Vision-Erkennung (QR, Aztec, Code128 …), Helligkeit 100 %, Wisch nach unten zum Schließen, Button „Am Schalter zeigen" prominent im Detail |
| 2 | **Schnell hinzufügen** | ✅ | Prominenter FAB „Hinzufügen", Dokumenttypen (PDF/Bild) für Import aus anderen Apps, `.onOpenURL`-Handler |
| 3 | **Nächstes Ticket** | ✅ | Hero-Karte auf dem Homescreen — baldigst ablaufendes gültiges Ticket oben |
| 4 | **Ablauf-Erinnerung** | ✅ | Lokale Push 1 Tag vor Ablauf (`UserNotifications`) |
| 5 | **Deutsche UI** | ✅ | Durchgängig deutsche, freundliche Texte |
| 6 | **Onboarding** | ✅ | 3 Screens beim ersten Start (überspringbar): Speichern → QR zeigen → Fertig |
| 7 | **App Icon** | ✅ | Arca-Familien-Icon: Glass-Ticket mit A-Logo, QR-Motiv & Dark-Mode-Variante |

---

## Zielgruppe

| Segment | Bedarf |
|---------|--------|
| **Pendler & Vielflieger** | Bahn-, Flug- und Bus-Tickets schnell am Schalter vorzeigen |
| **Konzert- & Sportfans** | Event-Tickets mit QR-Code, Ablaufdatum im Blick |
| **Gelegenheitsreisende** | Einfache App ohne Lernkurve — kein Passwort-Manager nötig |
| **Bestehende Arca-Nutzer** | Leichtgewichtige Alternative, wenn nur Tickets gebraucht werden |

> [!tip] Positionierung
> Nicht konkurrieren mit Wallet (Apple Pay) — sondern ergänzen: PDF-Tickets, Screenshots, Fremdanbieter-QR-Codes, die Wallet nicht unterstützt.

---

## MVP-Features (v1)

| Feature | Beschreibung | Priorität |
|---------|--------------|-----------|
| **Ticket hinzufügen** | Foto (Kamera/Galerie) oder PDF importieren | 🔴 Must-have |
| **Ordner** | Tickets nach Reise, Event oder eigenen Kategorien gruppieren | 🔴 Must-have |
| **QR Vollbild** | Erkannten oder eingebetteten QR-Code fullscreen, hohe Helligkeit | 🔴 Must-have |
| **Ablauf-Erinnerungen** | Lokale Push-Benachrichtigung X Stunden/Tage vor Gültigkeitsende | 🔴 Must-have |
| **Widget** | Nächstes Ticket auf dem Homescreen (Titel, Countdown, Schnellzugriff) | 🟡 Should-have |
| **PIN / Face ID** | App-Sperre über Keychain (wie [[Arca]]) | 🔴 Must-have |
| **iCloud Sync** | Tickets und Metadaten geräteübergreifend synchronisieren | 🔴 Must-have |

---

## Explizit NICHT in v1

> [!warning] Scope-Grenze
> Alles, was Arca Tickets schlank hält, kommt bewusst später oder gar nicht.

- ❌ Passwort-Vault / Tresor
- ❌ Notizen, Tasks, Listen
- ❌ KI-Features / Diktat
- ❠️ Siri / Kurzbefehle (v2)
- ❌ Ticket-Kauf oder Integration mit Bahn-/Flug-APIs
- ❌ Automatische Kalender-Synchronisation (v2)
- ❌ iPad-optimiertes Split-View-Layout (v1 nur iPhone-first)
- ❌ Android / Web
- ❌ Teilen von Tickets mit anderen Nutzern
- ❌ OCR / automatische Felderkennung (Reisedatum, Sitzplatz) — v2

---

## UI-Skizze

### Hauptansicht (iPhone)

```
┌─────────────────────────────┐
│  🔒  Arca Tickets      ⚙️   │
├─────────────────────────────┤
│  📁 Alle Tickets            │
│  ├─ 🚆 Zürich–Bern  05.07.  │
│  ├─ ✈️  TXL→FCO     12.07.  │
│  └─ 🎫 Konzert       20.07.  │
│                             │
│  📁 Reise Sommer 2026       │
│  └─ 🚌 Bus Pass      01.08.  │
│                             │
│         ┌─────────┐         │
│         │    ＋    │         │
│         └─────────┘         │
└─────────────────────────────┘
```

### Ticket-Detail → QR Vollbild

```
┌─────────────────────────────┐
│  ←  SBB Zürich–Bern           │
├─────────────────────────────┤
│                             │
│      ┌───────────────┐      │
│      │  ▓▓▓ QR ▓▓▓   │      │
│      │  ▓▓▓▓▓▓▓▓▓▓▓   │      │
│      │  ▓▓▓▓▓▓▓▓▓▓▓   │      │
│      └───────────────┘      │
│                             │
│  Gültig bis: 05.07. 23:59   │
│  [  Vollbild QR anzeigen  ] │
└─────────────────────────────┘
```

### Navigationsfluss (Mermaid)

```mermaid
flowchart TD
    A["App-Start"] --> B["LockView<br/>PIN / Face ID"]
    B --> C["Ticket-Liste<br/>+ Ordner"]
    C --> D["Ticket hinzufügen<br/>Foto / PDF"]
    C --> E["Ticket-Detail"]
    E --> F["QR Vollbild<br/>max. Helligkeit"]
    E --> G["Erinnerung setzen"]
    C --> H["Widget<br/>Nächstes Ticket"]
```

---

## Technische Architektur

> [!note] Wiederverwendung aus [[Arca]]
> Arca Tickets teilt sich ein **ArcaCore**-Framework mit der Haupt-App. Kein Copy-Paste — gemeinsame Bausteine als Swift Package oder Xcode Framework Target.

### Bundle & Targets

| Eigenschaft | Wert |
|-------------|------|
| **Bundle ID** | `com.hansruffin.ArcaTickets` |
| **Widget Bundle ID** | `com.hansruffin.ArcaTickets.ArcaTicketsWidget` |
| **Team** | LE6TQB8QE5 (wie [[Arca]]) |
| **Plattform** | iOS (iPhone-first), Deployment Target analog Arca |
| **Sprache** | Swift 5, SwiftUI |

### ArcaCore — gemeinsame Bausteine

| Modul (aus [[Arca]]) | Nutzung in Arca Tickets |
|----------------------|-------------------------|
| `ArcaDesign.swift` | Karten, Icon-Kacheln, Header, Farbsystem |
| `KeychainManager.swift` | PIN-Speicherung, sichere Metadaten |
| `LockView.swift` | App-Sperre (PIN / Face ID) |
| iCloud-Persistenz-Muster | JSON-Metadaten + Datei-Assets in iCloud Container |
| Widget-Infrastruktur | Timeline Provider, App Group |

### Projektstruktur (Ist-Stand MVP)

Arca Tickets ist ein **Target in `Arca.xcodeproj`**, kein eigenes Xcode-Projekt.

```
Arca.xcodeproj
├── arca/                        ← Arca Haupt-App
├── ArcaTickets/                 ← Arca Tickets App (Target: ArcaTickets)
│   ├── ArcaTicketsApp.swift
│   ├── TicketStore.swift        ← ObservableObject, iCloud
│   ├── Models.swift
│   ├── ContentView.swift, HomeView.swift, FolderView.swift
│   ├── TicketDetailView.swift, QRFullscreenView.swift, AddTicketView.swift
│   ├── LockView.swift, KeychainManager.swift   ← lokal kopiert (ArcaCore noch nicht extrahiert)
│   ├── OnboardingView.swift, NotificationManager.swift, SettingsView.swift
│   ├── ArcaTicketsDesign.swift, Assets.xcassets, ArcaTicketsInfo.plist
│   └── ArcaTickets.entitlements
└── ArcaWidget/                  ← nur für Arca, nicht für Tickets
```

**Noch nicht umgesetzt (Roadmap):** `ArcaCore`-Framework, `ArcaTicketsWidget/`, `ArcaTicketsTests/`, separates `ArcaTickets.xcodeproj`.

### Datenmodell (v1)

```mermaid
flowchart LR
    STORE["TicketStore"] --> TE["TicketEntry<br/>Titel, Ablauf, QR-Pfad"]
    STORE --> TF["TicketFolder<br/>Name, Farbe, Icon"]
    TF --> TE
    STORE --> P1["iCloud Drive<br/>JSON + Dateien"]
    STORE --> P2["Keychain<br/>PIN"]
    STORE --> P3["UserDefaults<br/>Einstellungen"]
    STORE --> P4["Lokale Dateien<br/>PDF, JPEG, PNG"]
```

### Datenfluss

```mermaid
flowchart TD
    A["ArcaTicketsApp"] --> L["LockView<br/>(lokal in ArcaTickets/)"]
    L --> C["ContentView"]
    C --> LIST["Ticket-Liste / Ordner"]
    LIST <--> STORE["TicketStore"]
    STORE --> IC["iCloud Container<br/>com.hansruffin.ArcaTickets"]
    STORE --> KC["Keychain<br/>(KeychainManager.swift)"]
    LIST --> ADD["Import<br/>PhotosPicker / DocumentPicker"]
    LIST --> QR["QRFullscreenView"]
    W["ArcaTicketsWidget"] --> STORE
```

### iCloud Container

- Separater Container: `iCloud.com.hansruffin.ArcaTickets`
- Kein Datenaustausch mit `com.hansruffin.Arca` — eigenständige App, optional später Export/Import

---

## App Store Positionierung

| Feld | Inhalt (Entwurf) |
|------|------------------|
| **Name** | Arca Tickets |
| **Untertitel** | Fahrkarten & Tickets griffbereit |
| **Kategorie** | Reisen (`public.app-category.travel`) |
| **Keywords** | ticket,fahrkarte,bahn,flug,qr,reise,zug,event,konzert,wallet,boarding pass |
| **Kurzbeschreibung** | Speichere Fahrkarten und Event-Tickets als Foto oder PDF. QR-Code im Vollbild, Ablauf-Erinnerungen und iCloud-Sync — sicher und übersichtlich. |
| **Langbeschreibung** | Arca Tickets hält deine digitalen Tickets an einem Ort: Import per Foto oder PDF, Sortierung in Ordnern, QR-Code-Vollbild für schnelles Vorzeigen am Schalter, Push-Erinnerungen vor Ablauf und Synchronisation über iCloud. Mit PIN oder Face ID geschützt. Die schlanke Schwester von Arca — nur Tickets, nichts Überflüssiges. |

> [!tip] ASO-Hinweis
> „Fahrkarte" und „QR" sind starke deutsche Suchbegriffe; englische Keywords (`boarding pass`, `travel`) für internationale Sichtbarkeit mischen.

---

## Roadmap

### Phase 0 — Konzept & Setup
- [x] Produktkonzept dokumentieren
- [ ] ArcaCore aus [[Arca]] extrahieren
- [x] Xcode-Target `ArcaTickets` in `Arca.xcodeproj` anlegen (+ Shared Scheme)
- [x] App Icon & Branding (Arca-Familie)

### Phase 1 — Killer App MVP (v1.0)
- [x] TicketStore + Models
- [x] Import: Foto & PDF (+ Dokumenttypen / Teilen)
- [x] Ordner-Verwaltung (Standard-Ordner)
- [x] QR/Barcode-Erkennung & Vollbild-Ansicht (Vision, Wisch-Dismiss)
- [x] Ablauf-Erinnerungen (1 Tag vorher, UNUserNotificationCenter)
- [x] Nächstes Ticket Hero-Karte
- [x] Onboarding (3 Screens)
- [x] LockView + Keychain
- [x] iCloud Sync
- [ ] Homescreen-Widget (nächstes Ticket)
- [ ] TestFlight Beta

### Phase 2 — v1.x
- [ ] Siri / Kurzbefehle („Zeig mein nächstes Ticket")
- [ ] Kalender-Integration (Ablaufdatum → Event)
- [ ] iPad-Layout (NavigationSplitView)
- [ ] OCR: automatische Erkennung von Datum & Route
- [ ] App Store Launch

### Phase 3 — v2+
- [ ] Live-Aktivitäten (Countdown bis Abfahrt)
- [ ] Apple Watch Companion (QR am Handgelenk)
- [ ] Optional: Arca-Import (Tickets aus Arca-Dokumente exportieren)
- [ ] Lokalisierung EN, FR, IT

---

## Killer-Flow testen

1. **Build:** `xcodebuild -scheme ArcaTickets -destination 'platform=iOS Simulator,name=iPhone 17' build`
2. **Onboarding:** App neu installieren → 3 Screens durchlaufen oder überspringen → PIN setzen
3. **Schnell hinzufügen:** FAB „Hinzufügen" → Foto/PDF wählen, Ablaufdatum setzen → speichern
4. **Teilen-Import:** PDF oder Screenshot in einer anderen App → „Teilen" → „Arca Tickets" (erscheint bei registrierten Dokumenttypen)
5. **Nächstes Ticket:** Homescreen zeigt Hero-Karte mit Countdown („Noch X Tage gültig")
6. **Am Schalter:** Hero-Karte oder Ticket-Detail → „Am Schalter zeigen" → Vollbild, Helligkeit max → nach unten wischen zum Schließen
7. **Erinnerung:** Ticket mit Ablauf morgen oder übermorgen anlegen → Benachrichtigung erlauben → Erinnerung 1 Tag vorher

---

## Offene Fragen

- [x] Eigenes App Icon oder Arca-Subbrand → Glass-Ticket-Icon in Arca-Familie (A + QR, Light/Dark)
- [ ] Freemium vs. Einmalkauf vs. kostenlos?
- [ ] Maximale Ticket-Anzahl in Free-Tier (falls Freemium)?
- [ ] QR-Erkennung: Vision Framework vs. Core Image?

---

## Verknüpfungen

- [[Arca]] — Haupt-App (Produktivitäts-Suite)
- [[ARCHITEKTUR]] — Technische Referenz Arca (falls im Vault)
- Entwickler: Hans zen Ruffinen

---

*Stand: 2026-07-05 · Status: Killer App MVP*
