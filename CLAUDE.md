# Arca — Arbeitsregeln

## ⭐ ARCAKit zuerst (Design-Leitlinie der ganzen Suite)

`../ARCAKit` ist die **gemeinsame SwiftUI-Bibliothek** von Arca, Arca Holiday,
Arca Pet und AfterLesson. Sie ist als lokales Swift-Package eingebunden.
**Sie hat nur Wert, wenn wir sie benutzen statt sie zu vergessen.**

**Regel — vor jeder Design-Arbeit:**
1. **Erst in ARCAKit schauen.** Braucht es eine Farbe, Schrift, ein Maß, einen
   Glas-Helfer, einen Schatten, eine Komponente? → prüfen, ob ARCAKit das schon hat:
   - Maße/Abstände/Größen → `ARCASpacing` (Balkenhöhen, Kachelgrößen, Einrückungen …)
   - Farben → `ARCAColors`
   - Schrift → `ARCATypography`
   - Glas & Karten → `ARCAGlassStyle` (`arcaGlass`, `arcaGlassCapsule`,
     `arcaCardBackground`, `arcaIconTile`)
   - Schatten/Glow → `ARCAShadows`
   - Komponenten → `ARCAEmblem`, `ARCAGlassCard`, `ARCATabBar`, `ARCAGlassButton`, …
2. **Nie duplizieren.** Was ARCAKit hat, wird über `import ARCAKit` genutzt — keine
   App-eigene Kopie. (Duplikate kollidieren als mehrdeutige `View`-Extensions.)
3. **Neues Gemeinsames wächst IN ARCAKit.** Ein bewährtes Muster aus der App wird
   dorthin extrahiert (verallgemeinert), dann in der App per `import ARCAKit` ersetzt.
   So wächst die Bibliothek, statt dass die App sie umgeht.

**Der sichtbare Anker:** Jede Design-nahe Datei beginnt mit `import ARCAKit`.
Der Import oben im Code ist die tägliche Erinnerung, dass die Leitlinien da sind.

**Einzige Quelle der Element-Maße:** `ARCAKit/Sources/ARCAKit/Design/ARCASpacing.swift`.
Ändere eine Größe dort — nicht verstreut in der App.

## Bauen / Installieren

- Compile-Check: `xcodebuild -scheme Arca -destination 'generic/platform=iOS' -derivedDataPath <scratch> build CODE_SIGNING_ALLOWED=NO`
- Für Geräte signiert: dasselbe ohne `CODE_SIGNING_ALLOWED=NO`, mit `-allowProvisioningUpdates`
- Installieren: `xcrun devicectl device install app --device "<Name>" <Arca.app>`
- Hans' Geräte: „iPad von Hans", „iPhone Blau", „iPhone Orange" (alles Daily Driver → additiv & sicher ändern)

## Commit

- Nur auf Bitte committen/pushen; Branch statt direkt auf `main`.
- Fußzeile: `Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>`
