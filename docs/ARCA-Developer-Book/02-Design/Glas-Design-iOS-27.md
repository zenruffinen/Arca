---
title: Glas-Design (iOS 27)
tags: [arca, developer-book, design, glas, ios]
typ: doku
status: aktiv
projekt: ARCA Suite
kurz: Glas-/Liquid-Glass-Sprache und iOS-27-Ausrichtung.
---

# Glas-Design (iOS 27)

Stand 17.07.2026 — Fakten direkt aus dem SDK der Xcode-27-Beta verifiziert, umgesetzt in ARCAKit v0.3.

## Die Lage seit WWDC 2026

- **Liquid Glass ist ab iOS 27 verpflichtend.** Der Kompatibilitätsschalter aus iOS 26 entfällt — es gibt kein Zurück zum alten Look.
- **Liquid Glass 2:** überarbeitete Material-Token und Richtlinien kommen mit dem SDK. Apps, die auf System-Glass aufbauen, erben sie **automatisch**.
- **Transparenzregler:** Nutzer können Glas systemweit abschwächen (Antwort auf Lesbarkeitskritik). System-Glass reagiert von selbst — eigene Blur-Bastelei nicht.

**Konsequenz für die Suite:** Wir bauen ausschließlich auf `glassEffect` & Co. auf (`arcaGlass`, `arcaGlassCapsule`), nie auf eigene Material-Imitate. Dann sind iOS-27-Token und Regler geschenkt.

## Material-Hierarchie der Suite

1. **Bühne** — `ARCAGlassBackground` (Nachtblau + Lichtkreise): der ruhige Grund, auf dem Glas erst wirkt. Kein Glas.
2. **Glasflächen** — Karten, Header, Pillen via `arcaGlass`/`arcaGlassCapsule`: getöntes System-Glass + `arcaHairline()` (0,5-pt-Lichtrand).
3. **Solide Inseln** — `arcaCardBackground`: für Inhalte, die vor unruhigem Grund zuverlässig lesbar bleiben müssen (Listen, Text).

**Regel aus ARCA Main (gilt weiter):** Ein Glas-Layer pro Element — verschachteltes Glas rendert falsch.

## Nutzung: Plakatwand vs. Sheets

- **Plakatwand / Startbildschirme:** Glas-Aktionskarten (`ARCAGlassActionCard`) und Hero-Header (`ARCAHeroHeader`) auf der Bühne.
- **Sheets & Formulare:** solide Flächen (`arcaCardBackground`), Glas höchstens für die eine Hauptaktion (`.arcaGlassProminent`).

## Abgrenzung zu System-Glass

ARCAKit ersetzt System-Glass nicht — es **töntet und rahmt** es (Suite-Farben, Haarlinie, Radien aus `ARCAGlassStyle`). Tab-Bars und Toolbars überlassen wir dem System komplett.

## iOS-27-APIs in ARCAKit

- `arcaCrossFadeNavigation()` → `.navigationTransition(.crossFade)` ab iOS 27; doppelt abgesichert (`#if compiler(>=6.4)` + `#available(iOS 27)`), baut also mit Xcode 26 **und** 27.
- Mindestziel bleibt **iOS 26**, solange die Apps damit ausliefern.
- Noch ungenutzt, beobachten: `ToolbarOverflowMenu`, `TabsPickerStyle`, neues Dokument-API, umsortierbare Listen.

Details und Herkunft jedes Bausteins: ARCAKit-Notiz im Vault ([[Vault-Link]]).
