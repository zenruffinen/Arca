---
title: Hero-Grafiken
tags: [arca, developer-book, hero, assets, grafik]
typ: doku
status: entwurf
projekt: ARCA Suite
kurz: Asset-Pfade und Varianten der Hero-Illustrationen (Ferien-Grafik, Plakatwand, Pet).
---

# Hero-Grafiken

Siehe auch: [[Navigationsgitter]] · [[Hotspot-Spezifikation]] · [[Vault-Link]]

---

## Übersicht

| App / Oberfläche | Variante | Asset-Name | Imageset-Pfad |
|---|---|---|---|
| Tickets · Unterwägs | Ferien-Grafik | `UnterwegsHeroIllustration` | `ArcaTickets/Assets.xcassets/UnterwegsHeroIllustration.imageset/` |
| Tickets · Holiday | Klecks-Hero | `ArcaHolidayHero` | `ArcaTickets/Assets.xcassets/ArcaHolidayHero.imageset/` |
| Pet · Home | Pet-Hero | `ArcaPetHero` | `ArcaPet/Assets.xcassets/ArcaPetHero.imageset/` |

Plakatwand nutzt **keine** eigene Hintergrund-PNG als Hero-Asset: die Szene wird in SwiftUI gezeichnet (`TravelSceneGraphic` / Glas-Rahmen), nicht als Vollbild-Illustration.

---

## Ferien-Grafik vs. Plakatwand (Unterwägs)

Umschaltung über `UnterwegsViewMode` in `UnterwegsHeroIllustrationView.swift`:

| Modus | UI-Name | Rolle |
|---|---|---|
| `.ferienGrafik` | Ferien-Grafik | Vollbild-/Einstiegsillustration mit versteckten Hotspots auf der Zeichnung |
| `.plakatwand` | Glas-Plakatwand | Interaktive Glas-Notizen auf der Ferien-Plakatwand (`UnterwegsSceneAnchor`) |

Einstellungen (UserDefaults-Keys u. a.):

- `unterwegs.viewMode`
- `unterwegs.einstiegEnabled` — Ferien-Grafik als Einstieg beim Öffnen des Tabs
- `unterwegs.ferienTapHintDismissed`

> [!example] Code-Einstieg
> - Ferien: `UnterwegsFerienEinstiegView` / `UnterwegsHeroHotspotLayer` → `Image("UnterwegsHeroIllustration")`
> - Plakatwand: `UnterwegsHeroIllustrationScene` → `GlasPlakatwandFrame` + Anker aus `TravelSceneGraphic.swift`

---

## Holiday-Hero

- Asset: `Image("ArcaHolidayHero")`
- Aspekt im Code: `473.0 / 1024.0` (vertikales Plakat)
- Hotspots an Farbklecks-Positionen (`ArcaHolidayKleck.point`)

## Pet-Hero

- Asset: `Image("ArcaPetHero")`
- Gleiches Aspektverhältnis wie Holiday (473×1024-Logik)
- Kategorie-Hotspots + Add-Pet-Zone

---

## Pflege-Hinweise

1. Neue Grafik → Imageset anlegen, Namen im Code und in dieser Seite synchron halten
2. Hotspot-Koordinaten anpassen, wenn sich die Illustration ändert → [[Hotspot-Spezifikation]]
3. Originale / Briefings für Illustratoren im Vault: [[Vault-Link]]
