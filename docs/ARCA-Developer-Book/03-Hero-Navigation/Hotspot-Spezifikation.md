---
title: Hotspot-Spezifikation
tags: [arca, developer-book, hero, hotspot]
typ: doku
status: entwurf
projekt: ARCA Suite
kurz: Formale Spezifikation der Hero-Hotspots (ID, Koordinaten, Aktion).
---

# Hotspot-Spezifikation

> [!todo] Tabellen je Hero vervollständigen
> Ausgangspunkt: [[Navigationsgitter]] und Code in `UnterwegsHeroIllustrationView`, `ArcaHolidayView`, `ArcaPetHomeView`. Vault: [[Vault-Link]]

## Pflichtfelder (Soll)

| Feld | Beschreibung |
|---|---|
| `id` | Stabiler String |
| Titel / Accessibility | Sichtbar oder VoiceOver |
| `point` | Zentrum normalisiert 0…1 |
| `hitSize` | Relative Trefferfläche |
| Aktion | Sheet, Navigation, Kleck, … |

## TODO

- Unterwägs-Hotspot-Tabelle
- Holiday-Klecks-Tabelle
- Pet-Kategorie-Tabelle
