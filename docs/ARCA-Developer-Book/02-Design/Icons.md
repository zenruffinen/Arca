---
title: Icons
tags: [arca, developer-book, design, icons]
typ: doku
status: aktiv
projekt: ARCA Suite
kurz: SF Symbols und eigene App-Icons der ARCA Suite.
---

# Icons

Arca verwendet für zentrale Produktfunktionen eine eigene monochrome
Vektor-Familie. Ihr wiederkehrendes Motiv ist der Rundbogen: als Griff,
Öffnung oder Bewegungslinie. Die Symbole werden wie SF Symbols über
`foregroundStyle` eingefärbt und bleiben in jeder Größe scharf.

## Formensprache

- 24 × 24 Einheiten, optische Mitte bei 12 × 12
- 1,7 Einheiten Strichstärke
- runde Linienenden und Verbindungen
- keine Flächen; Terrakotta ist die Standardfarbe
- pro Symbol mindestens ein Rundbogen als gemeinsame DNA

## Katalog

| Swift-Name | Asset | Bedeutung |
|---|---|---|
| `.archive` | `ArcaArchive` | Ablage, Tresor, Archiv |
| `.key` | `ArcaKey` | Passwörter, Zugang |
| `.bolt` | `ArcaBolt` | Schnellaktion, Automation |
| `.document` | `ArcaDocument` | Dokumente |
| `.checklist` | `ArcaChecklist` | Aufgaben, Prüfung |
| `.note` | `ArcaNote` | Notizen |
| `.folder` | `ArcaFolder` | Ordner, Sammlung |
| `.lock` | `ArcaLock` | Schutz, gesperrt |

## SwiftUI

```swift
ArcaSymbolImage(symbol: .archive, size: 28)

ArcaSymbolImage(symbol: .key, size: 20, color: .primary)
    .symbolEffect(.pulse, value: isUnlocked)
```

Die SVGs liegen als Template-Assets im Asset-Katalog, bewahren ihre
Vektordaten und übernehmen deshalb jede `foregroundStyle`-Farbe. Für
Bedienelemente ergänzt der umgebende Button sein semantisches
Accessibility-Label; das dekorative Symbol selbst ist ausgeblendet.
