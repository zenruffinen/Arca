//
//  ArcaDesign.swift
//  Arca
//
//  Entwickler: Hans zen Ruffinen
//  iOS 26 Liquid Glass — Design-Tokens und wiederverwendbare Bausteine
//

import SwiftUI
import AVFoundation
import CoreHaptics
import ARCAKit   // Leitlinie: gemeinsame Maße & Glas-Helfer kommen aus ARCAKit

// MARK: - Design Tokens
//
// Element-Maße (Balkenhöhen, Kachelgrößen, Einrückungen) leben in
// ARCAKit → ARCASpacing. Hier stehen nur app-spezifische Tokens.

enum ArcaDesign {
    static let cornerRadius: CGFloat = 20
    static let chipRadius: CGFloat = 14
    static let iconTileSize: CGFloat = 44

    static let documentBlue = Color.blue
    static let documentTeal = Color.teal
    static let documentOrange = Color.orange
    static let documentIndigo = Color.indigo

    static func hubStyle(for category: String) -> ArcaHubStyle {
        switch category {
        case "Reise":
            return ArcaHubStyle(icon: "airplane", tint: documentBlue, title: "Reise", subtitle: "Pass, Tickets, Hotel")
        case "Papiere":
            return ArcaHubStyle(icon: "person.text.rectangle", tint: documentTeal, title: "Papiere", subtitle: "Ausweis, Führerschein")
        case "Gesundheit":
            return ArcaHubStyle(icon: "cross.case.fill", tint: .pink, title: "Gesundheit", subtitle: "Karten, Befunde")
        case "Rechnungen":
            return ArcaHubStyle(icon: "eurosign.circle.fill", tint: documentOrange, title: "Rechnungen", subtitle: "Belege & Quittungen")
        case "Verträge":
            return ArcaHubStyle(icon: "signature", tint: documentIndigo, title: "Verträge", subtitle: "Wichtige Verträge")
        default:
            return ArcaHubStyle(icon: "folder.fill", tint: .secondary, title: category, subtitle: "Dokumente")
        }
    }

    static let homeHubCategories = ["Reise", "Papiere", "Rechnungen", "Verträge"]
}

// MARK: - Warme Farbwelt (Redesign-Brief 04.08.: Warmweiß, Creme, Terrakotta)

/// Die Palette des Space: keine bunten Flächen — Farbe tragen nur Icons
/// und der Terrakotta-Akzent. Alle Töne passen sich dem Dunkelmodus an.
enum ArcaWarm {
    /// Seitenhintergrund: Warmweiß statt System-Grau
    static let hintergrund = Color(UIColor { trait in
        trait.userInterfaceStyle == .dark
            ? UIColor(red: 0.11, green: 0.10, blue: 0.095, alpha: 1)
            : UIColor(red: 0.98, green: 0.965, blue: 0.94, alpha: 1)
    })
    /// Creme: die Hero-Bühne und verschlossene Karten
    static let creme = Color(UIColor { trait in
        trait.userInterfaceStyle == .dark
            ? UIColor(red: 0.16, green: 0.145, blue: 0.13, alpha: 1)
            : UIColor(red: 0.955, green: 0.93, blue: 0.885, alpha: 1)
    })
    /// Karten: Weiß mit Hauch von Wärme
    static let karte = Color(UIColor { trait in
        trait.userInterfaceStyle == .dark
            ? UIColor(red: 0.155, green: 0.145, blue: 0.14, alpha: 1)
            : UIColor.white
    })
    /// Der eine Akzent der App
    static let terrakotta = Color(red: 0.78, green: 0.40, blue: 0.25)
    /// Das Ideen-Gelb — warme Glühlampe (Bernstein, gut lesbar auf Creme)
    static let ideenGelb = Color(red: 0.86, green: 0.60, blue: 0.02)
    /// Haarlinie für Kartenränder
    static let haarlinie = Color.primary.opacity(0.07)
}

struct ArcaHubStyle {
    let icon: String
    let tint: Color
    let title: String
    let subtitle: String
}

/// Eine der vier Arca-Säulen auf der Startseite.
struct ArcaPillarSpec: Identifiable {
    let id: String
    let section: ArcaSection
    let title: String
    let subtitle: String
    let icon: String
    let tint: Color
    let count: Int
    let detail: String
}

struct ArcaQuickAction: Identifiable {
    let id: String
    let title: String
    let icon: String
    let tint: Color
}

// MARK: - Glass Helpers
//
// arcaGlass / arcaGlassCapsule / arcaCardBackground / arcaIconTile
// leben jetzt in ARCAKit (ARCAGlassStyle.swift) und kommen über
// `import ARCAKit`. Keine App-Kopien mehr — sonst kollidiert es.

// MARK: - Home Header

struct ArcaHomeHeader: View {
    var vault: Int
    var documents: Int
    var tasks: Int
    var notes: Int
    var onLogoTap: () -> Void

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            Button(action: onLogoTap) {
                ArcaGlassIcon(size: 40)
            }
            .buttonStyle(.plain)

            Text("Arca")
                .font(.system(size: 22, weight: .bold, design: .rounded))

            Spacer()

            HeaderStatPills(vault: vault, documents: documents, tasks: tasks, notes: notes)
        }
    }
}

// MARK: - Pillar Card (Dokumente · Tasks · Passwörter · Notizen)

struct ArcaPillarCard: View {
    let pillar: ArcaPillarSpec
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .center) {
                    Image(systemName: pillar.icon)
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(pillar.tint)
                        .arcaIconTile(tint: pillar.tint, size: 36)
                    Spacer()
                    Text("\(pillar.count)")
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundStyle(pillar.tint)
                }

                Text(pillar.title)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(.primary)

                Text(pillar.subtitle)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)

                Text(pillar.detail)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(pillar.tint)
                    .lineLimit(1)
            }
            .padding(12)
            .frame(maxWidth: .infinity, minHeight: 108, alignment: .leading)
            .arcaCardBackground(tint: pillar.tint, cornerRadius: 16)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Quick Action Chip

struct ArcaQuickActionChip: View {
    let action: ArcaQuickAction
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 5) {
                Image(systemName: action.icon)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(action.tint)
                    .arcaIconTile(tint: action.tint, size: 34)
                Text(action.title)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.primary)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .minimumScaleFactor(0.85)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .padding(.horizontal, 4)
            .arcaCardBackground(tint: action.tint, cornerRadius: 12)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Ordner-Schnellzugriff (wie in der Dokumentenliste)

struct ArcaFolderQuickCard: View {
    let name: String
    let icon: String
    let tint: Color
    let bg: Color
    let count: Int
    var action: (() -> Void)? = nil
    /// Ausklapp-Zustand (Ordner öffnet sich direkt auf dem Start)
    var isExpanded: Bool = false
    /// Sprung in den Dokumente-Bereich (kleiner Pfeil rechts)
    var onOpen: (() -> Void)? = nil

    var body: some View {
        let content = HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(tint)
                .frame(width: 34, height: 34)
                .background(bg.opacity(0.85), in: RoundedRectangle(cornerRadius: 8, style: .continuous))

            Text(name)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.primary)
                .lineLimit(2)
                .multilineTextAlignment(.leading)

            Spacer(minLength: 4)

            Text(count > 99 ? "99+" : "\(count)")
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .foregroundStyle(tint)
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(bg.opacity(0.7), in: Capsule())

            if let onOpen {
                Button(action: onOpen) {
                    Image(systemName: "arrow.right.circle")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(tint.opacity(0.8))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Ordner im Dokumente-Bereich öffnen")
            }
            if onOpen != nil {
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .rotationEffect(.degrees(isExpanded ? 90 : 0))
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .glassEffect(.regular.tint(tint.opacity(0.10)),
                     in: RoundedRectangle(cornerRadius: ArcaDesign.chipRadius))

        if let action {
            // Kein Button: der würde auf dem Mac das Klick-und-Ziehen
            // (draggable) schlucken. Tippen togglet, Ziehen zieht.
            content
                .contentShape(Rectangle())
                .onTapGesture { action() }
        } else {
            content
        }
    }
}

// MARK: - Recent Document Chip

struct ArcaRecentDocumentCard: View {
    let title: String
    let typeLabel: String
    let tint: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 5) {
                Image(systemName: "doc.fill")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(tint)
                Text(title)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                Text(typeLabel)
                    .font(.system(size: 9))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            .padding(10)
            .frame(width: 96, alignment: .leading)
            .arcaCardBackground(tint: tint, cornerRadius: 12)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - „Zuletzt geöffnet"-Karte (kompakt, alle Typen)

struct ArcaZuletztKarte: View {
    /// Füllt die verfügbare Breite, statt ARCASpacing.recentCardWidth zu
    /// nehmen — für Reihen mit fester, kleiner Anzahl.
    var fuellt: Bool = false
    let item: FavoriteItem
    let action: () -> Void

    private var icon: String {
        switch item.kind {
        case .document: return "ArcaDocument"
        case .note:     return "ArcaIdee"
        case .list:     return "ArcaChecklist"
        case .vault:    return "ArcaLock"
        }
    }
    private var tint: Color {
        switch item.kind {
        case .document: return .orange
        case .note:     return ArcaWarm.ideenGelb
        case .list:     return .green
        case .vault:    return .blue
        }
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                ArcaIcon(name: icon, groesse: 15)
                    .foregroundStyle(tint)
                    .frame(width: 30, height: 30)
                    .background(tint.opacity(0.14), in: RoundedRectangle(cornerRadius: 9))
                VStack(alignment: .leading, spacing: 1) {
                    Text(item.title)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                    Text(item.subtitle)
                        .font(.system(size: 9.5))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            // Zwei Karten teilen sich die Reihe: dann ist nichts
            // angeschnitten und der Rand stimmt. Feste Breite nur, wo die
            // Karte in einer laufenden Reihe steht.
            .frame(maxWidth: fuellt ? .infinity : ARCASpacing.recentCardWidth,
                   alignment: .leading)
            .glassEffect(.regular.tint(tint.opacity(0.08)), in: RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - More Areas Chip (Passwörter, Notizen, Tasks)

struct ArcaMoreAreaChip: View {
    let icon: String
    let title: String
    let count: Int
    let tint: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(tint)
                    .arcaIconTile(tint: tint, size: 36)
                VStack(alignment: .leading, spacing: 1) {
                    Text(title)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.primary)
                    Text(count == 0 ? "Leer" : "\(count) Einträge")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .arcaCardBackground(tint: tint, cornerRadius: ArcaDesign.chipRadius)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Primary CTA

struct ArcaPrimaryButton: View {
    let title: String
    let icon: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Label(title, systemImage: icon)
                .font(.system(size: 16, weight: .semibold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .foregroundStyle(.white)
                .background(Color.accentColor, in: RoundedRectangle(cornerRadius: ArcaDesign.cornerRadius, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Section Label

struct ArcaSectionTitle: View {
    let title: String
    var icon: String? = nil

    var body: some View {
        HStack(spacing: 5) {
            if let icon {
                ArcaIcon(name: icon, groesse: 13)
            }
            Text(title)
                .textCase(.uppercase)
                .tracking(0.6)
        }
        .font(.system(size: 13, weight: .semibold))
        .foregroundStyle(.secondary)
    }
}

/// Aufklappbare Sektionsüberschrift (Chevron + optional Zähler).
struct ArcaCollapsibleSectionHeader: View {
    let title: String
    var count: Int? = nil
    let isCollapsed: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: "chevron.right")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(.secondary)
                    .rotationEffect(.degrees(isCollapsed ? 0 : 90))
                Text(title)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)
                    .tracking(0.5)
                Spacer()
                if let count {
                    Text("\(count)")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color(.tertiarySystemFill), in: Capsule())
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Kategorie-Karte (Mockup: schmale Glas-Karten, eine Reihe)

/// Schmale, hohe Kategorie-Karte (~60×150) für die durchlaufende Reihe:
/// Icon oben, Name klein darunter, Anzahl. Liquid-Glass, farblich getönt.
struct ArcaKategorieKarte: View {
    let name: String
    let icon: String
    let farben: NoteColor
    let anzahl: Int
    /// Wie kraeftig der Farbton im Glas liegt.
    ///
    /// Standard 0,55 fuer die Gruppen. Die festgenagelte „Angepinnt"-Kachel
    /// nimmt weniger: unter ihr laufen die Gruppen durch, und man soll sie
    /// dabei durchscheinen sehen — sonst wirkt die Kachel wie ein Deckel
    /// statt wie eine Scheibe.
    var tintDeckkraft: Double = 0.55

    var body: some View {
        VStack(spacing: 3) {
            ArcaIcon(name: icon, groesse: 17)
                .foregroundStyle(farben.accent)
                .frame(width: 36, height: 36)
                .background(farben.bg, in: RoundedRectangle(cornerRadius: 10))
            Text(name)
                .font(.system(size: 10.5, weight: .semibold))
                .foregroundStyle(.primary)
                .lineLimit(2)
                .multilineTextAlignment(.center)
                .minimumScaleFactor(0.8)
                .fixedSize(horizontal: false, vertical: true)
            Text("\(anzahl)")
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundStyle(farben.accent)
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 6)
        .frame(width: ARCASpacing.categoryTileWidth, height: ARCASpacing.categoryTileHeight)
        .glassEffect(.regular.tint(farben.bg.opacity(tintDeckkraft)),
                     in: RoundedRectangle(cornerRadius: 15))
        .overlay(RoundedRectangle(cornerRadius: 15)
            .strokeBorder(farben.accent.opacity(0.14), lineWidth: 1))
    }
}

// MARK: - Ordner mit Vorschau (Studie, Reihe 2)

/// Die Silhouette eines Ordners: Lasche oben links, Körper darunter.
///
/// EINE durchgehende Kontur, nicht zwei übereinandergelegte Rechtecke.
/// Als zwei Rechtecke sieht die Füllung zwar richtig aus, aber jeder
/// Strich zeichnet beide Umrisse — auch die Kanten, die mitten in der
/// Form liegen. Dann hat der Ordner eine Naht quer durch die Lasche.
struct ArcaOrdnerForm: Shape {
    /// Anteil der Breite, den die Lasche einnimmt.
    var laschenBreite: CGFloat = 0.46
    /// Anteil der Höhe, um den die Lasche über dem Körper steht.
    var laschenHoehe: CGFloat = 0.14
    var radius: CGFloat = 15

    func path(in rect: CGRect) -> Path {
        let w = rect.width
        let h = rect.height
        let lh = h * laschenHoehe
        let r = min(radius, min(w, h) / 2)
        let lw = min(w * laschenBreite, w - r * 2)
        let lr = min(r * 0.55, lh * 0.9)   // Ecken der Lasche
        let kr = min(r * 0.5, lh)          // Kehle zwischen Lasche und Körper

        func pt(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
            CGPoint(x: rect.minX + x, y: rect.minY + y)
        }

        var p = Path()
        p.move(to: pt(0, h - r))
        // Linke Kante ganz hoch — Lasche und Körper haben dieselbe Flucht
        p.addLine(to: pt(0, lr))
        p.addQuadCurve(to: pt(lr, 0), control: pt(0, 0))
        p.addLine(to: pt(lw - lr, 0))
        p.addQuadCurve(to: pt(lw, lr), control: pt(lw, 0))
        // Rechte Laschenkante hinunter, dann die Kehle auf die Körperkante
        p.addLine(to: pt(lw, lh - kr))
        p.addQuadCurve(to: pt(lw + kr, lh), control: pt(lw, lh))
        // Körper: Oberkante, rechte Kante, Unterkante
        p.addLine(to: pt(w - r, lh))
        p.addQuadCurve(to: pt(w, lh + r), control: pt(w, lh))
        p.addLine(to: pt(w, h - r))
        p.addQuadCurve(to: pt(w - r, h), control: pt(w, h))
        p.addLine(to: pt(r, h))
        p.addQuadCurve(to: pt(0, h - r), control: pt(0, h))
        p.closeSubpath()
        return p
    }
}

/// Die Vordertasche des Ordners: oben eine gerade Kante, unten die
/// Rundung des Ordners selbst.
///
/// Oben nur ein Hauch Radius. Eine runde Oberkante sähe aus wie eine
/// zweite Karte, die im Ordner liegt — die Tasche ist aber die Vorderseite
/// des Ordners und muss an seinen Seiten anschließen.
struct ArcaTaschenForm: Shape {
    var untenRadius: CGFloat = 15
    var obenRadius: CGFloat = 3

    func path(in rect: CGRect) -> Path {
        Path(
            UnevenRoundedRectangle(
                topLeadingRadius: obenRadius,
                bottomLeadingRadius: untenRadius,
                bottomTrailingRadius: untenRadius,
                topTrailingRadius: obenRadius,
                style: .continuous
            ).path(in: rect).cgPath
        )
    }
}

/// Ein Blatt in der Ordner-Vorschau: das Vorschaubild auf weißem Papier,
/// leicht gekippt. Ohne die Kippung sähen zwei Blätter wie ein Block aus.
private struct ArcaVorschauBlatt: View {
    let url: URL
    let typ: DocumentType
    var winkel: Double
    /// Die Kategorie-Karte zeigt groesseres Papier als die alte Ordner-
    /// Kachel; ohne eigenes Mass blieben die Blaetter dort Briefmarken.
    var breite: CGFloat = ARCASpacing.ordnerBlattWidth
    var hoehe: CGFloat = ARCASpacing.ordnerBlattHeight

    var body: some View {
        DocThumbnail(url: url, type: typ,
                     groesse: CGSize(width: breite, height: hoehe))
            .frame(width: breite, height: hoehe)
            .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
            // Weißer Rand: das Blatt ist Papier, das im Ordner steckt —
            // ohne ihn klebt das Bild direkt auf dem Glas.
            .overlay(
                RoundedRectangle(cornerRadius: 5, style: .continuous)
                    .strokeBorder(.white.opacity(0.95), lineWidth: 1.5)
            )
            .shadow(color: .black.opacity(0.20), radius: 2.5, x: 0, y: 1.5)
            .rotationEffect(.degrees(winkel))
    }
}

/// Deterministische Streuzahl zwischen 0 und 1.
///
/// `hashValue` taugt dafür nicht: Swift würfelt den Hash-Startwert pro
/// Programmlauf neu, die Flecken säßen nach jedem Start woanders. Ein
/// eigener, fester Hash sorgt dafür, dass „Urlaub" immer dasselbe Glas
/// hat — nur eben ein anderes als „Rechnungen".
private func arcaStreuwert(_ saat: Int, _ i: Int) -> CGFloat {
    var x = UInt64(truncatingIfNeeded: saat &* 73856093 ^ ((i &+ 1) &* 19349663))
    x ^= x >> 33
    x = x &* 0xff51afd7ed558ccd
    x ^= x >> 33
    return CGFloat(x % 997) / 997.0
}

private func arcaSaat(_ text: String) -> Int {
    var h = 5381
    for b in text.utf8 { h = (h &* 33) &+ Int(b) }
    return h
}

/// Die Unebenheiten im Glas: ein paar weiche Farbwolken, die sich
/// überlagern.
///
/// Ein gleichmäßiger Farbton sieht aus wie eingefärbtes Plastik. Was das
/// Glas in der Studie lebendig macht, sind Stellen, an denen die Farbe
/// dichter steht, und andere, an denen sie fast verschwindet — als wäre
/// sie hineingegossen und nicht ganz verrührt.
private struct ArcaGlasFlecken: View {
    let tint: Color
    let saat: Int
    var anzahl: Int = 4

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            ZStack {
                ForEach(0..<anzahl, id: \.self) { i in
                    let x = arcaStreuwert(saat, i * 4)
                    let y = arcaStreuwert(saat, i * 4 + 1)
                    let groesse = arcaStreuwert(saat, i * 4 + 2)
                    let dichte = arcaStreuwert(saat, i * 4 + 3)
                    Ellipse()
                        .fill(tint.opacity(0.07 + 0.13 * Double(dichte)))
                        .frame(width: w * (0.45 + 0.40 * groesse),
                               height: h * (0.34 + 0.34 * (1 - groesse)))
                        .offset(x: w * (x - 0.5), y: h * (y - 0.5))
                        .blur(radius: 9)
                }
            }
            .frame(width: w, height: h)
        }
        .allowsHitTesting(false)
    }
}

/// Ein unbeschriebenes Blatt — der zweite Platz, wenn nur ein Dokument da
/// ist. Ohne ihn rutscht das einzelne Blatt in die Mitte und jeder Ordner
/// der Reihe ist anders aufgebaut.
///
/// Bewusst OHNE gestrichelten Rand: gestrichelt heißt „hier fehlt etwas,
/// tu was hinein". Der Ordner sagt aber nur, wie viel drin ist. Blasses
/// Papier ist ruhig genug, um nicht gelesen zu werden.
private struct ArcaLeeresBlatt: View {
    var body: some View {
        RoundedRectangle(cornerRadius: 5, style: .continuous)
            .fill(.white.opacity(0.45))
            .overlay(
                RoundedRectangle(cornerRadius: 5, style: .continuous)
                    .strokeBorder(.white.opacity(0.7), lineWidth: 1.5)
            )
            .shadow(color: .black.opacity(0.10), radius: 2, x: 0, y: 1)
            .frame(width: ARCASpacing.ordnerBlattWidth,
                   height: ARCASpacing.ordnerBlattHeight)
            .rotationEffect(.degrees(3.5))
    }
}

/// Eine Kategorie als ruhige Karte — die „Arca Category Card".
///
/// Loest am 01.10. den Glasordner mit Lasche und Vordertasche ab. Der
/// Ordner war ein Bild eines Dateisystems; drei davon nebeneinander sahen
/// aus wie ein Regal mit Aktenmappen. Die Karte zeigt stattdessen eine
/// Sammlung: eine runde Glaslinse mit dem Symbol, dahinter das echte
/// Papier, darunter eine eigene Leiste mit Name, Anzahl und Winkel.
///
/// Drei Regeln halten sie ruhig:
///
/// 1. EIN Glas-Layer. Nur die Linse traegt `glassEffect` — die Karte
///    selbst ist ein zarter Farbverlauf. Glas auf Glas rendert falsch
///    (die Regel aus ARCAKit) und wuerde hier ausserdem schreien.
/// 2. Die Farbe kommt aus der Kategorie, aber nur als Hauch. Im Dunkeln
///    aus `accent` statt aus `bg`: die hellen Pastelltoene von `bg`
///    wurden auf schwarzem Grund schlammig, und Gelb war von Rot nicht
///    mehr zu unterscheiden.
/// 3. Im Zweifel weniger. Kein harter Schatten, keine 3D-Kante, kein
///    zweiter Glanz — Liquid Glass bringt seinen eigenen mit.
struct ArcaCategoryCard: View {
    let name: String
    let icon: String
    let farben: NoteColor
    let anzahl: Int
    /// Bis zu zwei Dokumente für die Vorschau — (Datei, Typ).
    var vorschau: [(url: URL, typ: DocumentType)] = []
    /// „Angepinnt" liegt fest und traegt weniger Farbe, damit man die
    /// Karten erkennt, die dahinter vorbeiziehen.
    var tintDeckkraft: Double = 1.0

    @Environment(\.colorScheme) private var schema
    private var dunkel: Bool { schema == .dark }

    // Die Karte waechst mit der Systemschrift — aber nur bis zu einem
    // Punkt.
    //
    // Ungebremst folgt @ScaledMetric dem Textfaktor eins zu eins: bei den
    // Accessibility-Groessen sind das rund 230 %, und eine einzelne Karte
    // nahm den halben Schirm ein, waehrend die Linse darin klein blieb.
    // Der Deckel bei 1,3 laesst dem Namen Luft, haelt aber das Verhaeltnis
    // von Linse, Papier und Leiste zusammen; den Rest faengt der
    // minimumScaleFactor des Namens ab.
    @ScaledMetric(relativeTo: .subheadline) private var skala: CGFloat = 100
    private var faktor: CGFloat { min(skala / 100, 1.3) }

    private var breite: CGFloat { ARCASpacing.kategorieKarteWidth * faktor }
    private var hoehe: CGFloat { ARCASpacing.kategorieKarteHeight * faktor }
    private var leistenHoehe: CGFloat { ARCASpacing.kategorieBarHeight * faktor }
    private var linsenMass: CGFloat { ARCASpacing.kategorieLinse * faktor }
    private var blattBreite: CGFloat { ARCASpacing.kategorieBlattWidth * faktor }
    private var blattHoehe: CGFloat { ARCASpacing.kategorieBlattHeight * faktor }

    private var radius: CGFloat { ARCASpacing.kategorieKarteRadius }

    private var dokumentWort: String { anzahl == 1 ? "Dokument" : "Dokumente" }

    var body: some View {
        VStack(spacing: 0) {
            buehne
            leiste
        }
        .frame(width: breite, height: hoehe)
        .background(kartenFlaeche)
        .clipShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
        // Eine Haarlinie, mehr nicht: sie trennt die Karte vom warmen
        // Untergrund, ohne sie einzurahmen.
        .overlay {
            RoundedRectangle(cornerRadius: radius, style: .continuous)
                .strokeBorder(Color.primary.opacity(dunkel ? 0.10 : 0.07), lineWidth: 0.5)
        }
        .shadow(color: .black.opacity(dunkel ? 0.26 : 0.07), radius: 3, y: 1)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(name), \(anzahl) \(dokumentWort)")
        .accessibilityHint("Öffnet die Kategorie")
        .accessibilityAddTraits(.isButton)
    }

    // MARK: Oben — Linse vor dem Papier

    private var buehne: some View {
        ZStack(alignment: .leading) {
            papier
                .frame(maxWidth: .infinity, alignment: .trailing)
                .padding(.trailing, 12)
            linse
                .padding(.leading, 12)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    /// Die Glaslinse — das charakteristische Element der Karte.
    ///
    /// Sie traegt mehr Farbe als die Karte, sonst verschwindet sie darin:
    /// im ersten Anlauf (Tint 0,18 auf einer kraeftig gefuellten Flaeche)
    /// war sie ein flacher Kreis. Jetzt steht sie als eigenes Stueck Glas
    /// vor einer sehr zarten Flaeche — das Gefaelle macht die Linse.
    private var linse: some View {
        ArcaIcon(name: icon, groesse: 21 * faktor)
            .foregroundStyle(farben.accent)
            .frame(width: linsenMass, height: linsenMass)
            .glassEffect(
                .regular.tint(farben.accent.opacity(tintDeckkraft * (dunkel ? 0.34 : 0.26))),
                in: Circle())
    }

    /// Das Papier dahinter: bis zu zwei echte Vorschauen, leicht gegen-
    /// einander versetzt. Es soll zu sehen sein, nicht zu dominieren —
    /// deshalb steht es rechts und teils hinter der Linse.
    private var papier: some View {
        ZStack(alignment: .topLeading) {
            if vorschau.isEmpty {
                // Leere Kategorie: eine stille Silhouette statt erfundener
                // Dokumente. Das Layout bleibt damit dasselbe.
                leeresBlatt
            } else {
                ForEach(Array(vorschau.prefix(2).enumerated()), id: \.offset) { i, blatt in
                    ArcaVorschauBlatt(url: blatt.url, typ: blatt.typ,
                                      winkel: i == 0 ? -4 : 4.5,
                                      breite: blattBreite, hoehe: blattHoehe)
                        .offset(x: CGFloat(i) * 12, y: CGFloat(i) * -4)
                        .zIndex(Double(i))
                }
            }
        }
        .frame(width: blattBreite + 12 * faktor, height: blattHoehe,
               alignment: .topLeading)
    }

    /// Die Silhouette fuer eine leere Kategorie: ein Blatt, keine Daten.
    ///
    /// Zwei angedeutete Linien sagen „hier kaeme ein Dokument hin" — eine
    /// nackte Flaeche las sich als Fehler im Layout. Nichts davon ist
    /// erfundener Inhalt, es sind zwei Striche.
    private var leeresBlatt: some View {
        RoundedRectangle(cornerRadius: 5, style: .continuous)
            .fill(dunkel ? Color.white.opacity(0.10) : Color.white.opacity(0.72))
            .overlay(alignment: .top) {
                VStack(alignment: .leading, spacing: 5) {
                    Capsule().frame(height: 2.5).frame(maxWidth: .infinity)
                    Capsule().frame(height: 2.5).frame(maxWidth: 22)
                }
                .foregroundStyle(Color.primary.opacity(dunkel ? 0.13 : 0.09))
                .padding(.horizontal, 7)
                .padding(.top, 12)
            }
            .overlay(
                RoundedRectangle(cornerRadius: 5, style: .continuous)
                    .strokeBorder(.white.opacity(dunkel ? 0.18 : 0.85), lineWidth: 1.5)
            )
            .shadow(color: .black.opacity(dunkel ? 0.22 : 0.10), radius: 2, y: 1)
            .frame(width: blattBreite, height: blattHoehe)
            .rotationEffect(.degrees(3.5))
    }

    // MARK: Unten — Name · Anzahl · Winkel

    private var leiste: some View {
        HStack(spacing: 6) {
            Text(name)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.65)
            Spacer(minLength: 2)
            Text("\(anzahl)")
                .font(.subheadline.weight(.bold))
                .foregroundStyle(farben.accent)
                .monospacedDigit()
            Image(systemName: "chevron.right")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 10)
        .frame(maxWidth: .infinity)
        .frame(height: leistenHoehe)
        .background {
            // Eine eigene Flaeche, hell abgesetzt — sie gehoert zur Karte,
            // ist aber als eigene Leiste zu erkennen.
            Rectangle()
                .fill(dunkel ? Color.white.opacity(0.07) : Color.white.opacity(0.50))
                .overlay(alignment: .top) {
                    Rectangle()
                        .fill(Color.primary.opacity(dunkel ? 0.10 : 0.06))
                        .frame(height: 0.5)
                }
        }
    }

    // MARK: Die Flaeche

    /// Ein Hauch Kategoriefarbe, von oben links nach unten rechts
    /// auslaufend. Im Dunkeln traegt `accent` den Ton: `bg` ist eine
    /// helle Pastellfarbe und wird auf schwarzem Grund zu Schlamm.
    /// Im ersten Anlauf standen hier 0,55 — das war eine Pastellflaeche,
    /// keine Transparenz, und die Linse verschwand darin. Ein Drittel
    /// davon reicht: die Farbe soll die Kategorie andeuten, nicht die
    /// Karte ausmalen.
    private var kartenFlaeche: some View {
        let ton = dunkel ? farben.accent : farben.bg
        let oben = (dunkel ? 0.16 : 0.30) * tintDeckkraft
        let unten = (dunkel ? 0.05 : 0.10) * tintDeckkraft
        return LinearGradient(
            colors: [ton.opacity(oben), ton.opacity(unten)],
            startPoint: .topLeading, endPoint: .bottomTrailing)
            .background(dunkel ? Color.white.opacity(0.05) : Color.white.opacity(0.62))
    }
}

#Preview("Kategorie-Karten") {
    let rose = NoteColor(bg: ArcaWarm.terrakotta.opacity(0.20),
                         accent: ArcaWarm.terrakotta, name: "Rose")
    let gold = NoteColor(bg: ArcaWarm.ideenGelb.opacity(0.20),
                         accent: ArcaWarm.ideenGelb, name: "Gold")
    return ScrollView(.horizontal) {
        HStack(spacing: 10) {
            // Leer
            ArcaCategoryCard(name: "Unsortiert", icon: "tray.full",
                             farben: gold, anzahl: 0)
            // Langer Name
            ArcaCategoryCard(name: "Versicherungsunterlagen", icon: "shield",
                             farben: rose, anzahl: 12)
            // Angepinnt — weniger Farbe
            ArcaCategoryCard(name: "Angepinnt", icon: "pin.fill",
                             farben: rose, anzahl: 5, tintDeckkraft: 0.45)
        }
        .padding(20)
    }
    .frame(height: 200)
    .background(ArcaWarm.hintergrund)
}

/// „+ Kategorie hinzufügen" — der leere Platz am Ende der Kategorienreihe.
///
/// Folgt seit 01.10. der Form der Kategorie-Karte: gleiches Mass, gleicher
/// Radius, gestrichelt statt gefuellt. Vorher stand hier noch ein Ordner
/// mit Lasche neben lauter Karten.
struct ArcaOrdnerHinzufuegenKarte: View {
    // Derselbe gedeckelte Faktor wie bei der Kategorie-Karte — sonst
    // stuenden in der Reihe zwei verschieden grosse Karten.
    @ScaledMetric(relativeTo: .subheadline) private var skala: CGFloat = 100
    private var faktor: CGFloat { min(skala / 100, 1.3) }

    private var breite: CGFloat { ARCASpacing.kategorieKarteWidth * faktor }
    private var hoehe: CGFloat { ARCASpacing.kategorieKarteHeight * faktor }
    private var linsenMass: CGFloat { ARCASpacing.kategorieLinse * faktor }

    private var radius: CGFloat { ARCASpacing.kategorieKarteRadius }

    var body: some View {
        VStack(spacing: 7) {
            Image(systemName: "plus")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(ArcaWarm.terrakotta)
                .frame(width: linsenMass, height: linsenMass)
                .background(Circle().strokeBorder(ArcaWarm.terrakotta.opacity(0.45),
                                                  style: StrokeStyle(lineWidth: 1.5, dash: [4, 3])))
            Text("Kategorie hinzufügen")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .minimumScaleFactor(0.7)
        }
        .padding(.horizontal, 8)
        .frame(width: breite, height: hoehe)
        .background {
            RoundedRectangle(cornerRadius: radius, style: .continuous)
                .fill(Color.primary.opacity(0.03))
        }
        .overlay {
            RoundedRectangle(cornerRadius: radius, style: .continuous)
                .strokeBorder(Color.secondary.opacity(0.28),
                              style: StrokeStyle(lineWidth: 1, dash: [5, 4]))
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Kategorie hinzufügen")
        .accessibilityAddTraits(.isButton)
    }
}

/// „+ Kategorie hinzufügen" — gleiche schmale Form, Glas.
struct ArcaKategorieHinzufuegenKarte: View {
    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: "plus")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(ArcaWarm.terrakotta)
                .frame(width: 36, height: 36)
                .background(Circle().strokeBorder(ArcaWarm.terrakotta.opacity(0.45),
                                                  style: StrokeStyle(lineWidth: 1.5, dash: [4, 3])))
            Text("Kategorie\nhinzufügen")
                .font(.system(size: 9.5, weight: .medium))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(width: ARCASpacing.categoryTileWidth, height: ARCASpacing.categoryTileHeight)
        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 15))
        .overlay(RoundedRectangle(cornerRadius: 15)
            .strokeBorder(Color.secondary.opacity(0.22), style: StrokeStyle(lineWidth: 1, dash: [5, 4])))
    }
}

// MARK: - Dreh-Regler (Jog-Wheel) zum Durchblättern

/// Ein horizontales Riffel-Rad im Glas-Look: mit dem Finger drehen blättert
/// durch die Gruppen — die Riffeln rotieren wie ein Zylinder, jede Rastung
/// gibt einen Haptik-Tick + „grrr"-Klick. `onNotch(+1/-1)` pro Rastung.
struct ArcaDrehregler: View {
    var breite: CGFloat = 210
    var hoehe: CGFloat = 38
    var tint: Color = ArcaWarm.terrakotta
    var fraction: Double            // 0…1 echte Scroll-Position (treibt die Rotation)
    var anzahl: Int
    let onFraction: (Double) -> Void

    @State private var lokal: Double? = nil     // Fraktion während des Ziehens
    @State private var startFrac: Double = 0
    @State private var letzterIdx: Int = 0
    @State private var motor = DrehHaptik()
    private let scrubProNotch: CGFloat = 34     // Finger-Pixel pro Karte

    private var kantenBlende: LinearGradient {
        LinearGradient(stops: [
            .init(color: .clear, location: 0.0),
            .init(color: .black, location: 0.14),
            .init(color: .black, location: 0.86),
            .init(color: .clear, location: 1.0)
        ], startPoint: .leading, endPoint: .trailing)
    }

    private func idxVon(_ f: Double) -> Int {
        Int((f * Double(max(anzahl - 1, 0))).rounded())
    }

    var body: some View {
        let frac = lokal ?? fraction
        // Rotation ∝ Kartenindex: pro Karte eine halbe Umdrehungs-Einheit
        let phase = CGFloat(frac) * CGFloat(max(anzahl - 1, 1)) * 0.5
        let ribs = 46
        Canvas { ctx, size in
            let w = size.width, h = size.height
            let cx = w / 2
            let R = w / 2
            let step = (Double.pi * 2) / Double(ribs)
            for i in 0..<ribs {
                let a = Double(phase) + Double(i) * step
                let c = cos(a)                    // >0 = Vorderseite
                if c <= 0.06 { continue }
                let s = sin(a)
                let x = cx + CGFloat(s) * R * 0.94
                let ribW = CGFloat(0.6 + 2.6 * c)
                let rect = CGRect(x: x - ribW / 2, y: h * 0.20, width: ribW, height: h * 0.60)
                // Schatten links = Relief
                let sr = CGRect(x: x - ribW / 2 - 1.0, y: h * 0.20, width: 1.0, height: h * 0.60)
                ctx.fill(Path(roundedRect: sr, cornerRadius: 0.5),
                         with: .color(.black.opacity(0.14 * c)))
                // Farbkern in der Gruppenfarbe
                ctx.fill(Path(roundedRect: rect, cornerRadius: ribW / 2),
                         with: .color(tint.opacity(0.22 + 0.42 * c)))
                // Glanzkante hell und schmaler → Metall-Riffel-Look
                let hlW = max(0.6, ribW * 0.55)
                let hl = CGRect(x: x - hlW / 2, y: h * 0.20, width: hlW, height: h * 0.60)
                ctx.fill(Path(roundedRect: hl, cornerRadius: hlW / 2),
                         with: .color(.white.opacity(0.12 + 0.42 * c)))
            }
        }
        .frame(width: breite, height: hoehe)
        .mask(kantenBlende)
        .background(
            Capsule().fill(
                LinearGradient(colors: [.black.opacity(0.18), .clear, .clear, .black.opacity(0.18)],
                               startPoint: .leading, endPoint: .trailing))
        )
        .glassEffect(.regular.tint(tint.opacity(0.26)), in: Capsule())
        // 3D-Zylinder: heller Scheitel oben, sanfter Schatten unten
        .overlay(
            Capsule().fill(
                LinearGradient(stops: [
                    .init(color: .white.opacity(0.48), location: 0.0),
                    .init(color: .white.opacity(0.12), location: 0.30),
                    .init(color: .clear, location: 0.55),
                    .init(color: .black.opacity(0.16), location: 1.0)
                ], startPoint: .top, endPoint: .bottom))
                .allowsHitTesting(false)
        )
        // schmale Specular-Glanzlinie ganz oben
        .overlay(alignment: .top) {
            Capsule()
                .fill(.white.opacity(0.6))
                .frame(height: 2)
                .padding(.horizontal, breite * 0.14)
                .padding(.top, 3)
                .blur(radius: 1)
                .allowsHitTesting(false)
        }
        .overlay(Capsule().strokeBorder(.white.opacity(0.3), lineWidth: 1))
        .overlay(Capsule().strokeBorder(tint.opacity(0.55), lineWidth: 1))
        .contentShape(Capsule())
        .animation(.easeInOut(duration: 0.25), value: tint)
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { v in
                    if lokal == nil {
                        lokal = fraction
                        startFrac = fraction
                        letzterIdx = idxVon(fraction)
                    }
                    let spanne = CGFloat(max(anzahl - 1, 1)) * scrubProNotch
                    // 0…1 geklemmt = harter Anschlag links UND rechts
                    let nf = min(max(startFrac + Double(v.translation.width / spanne), 0), 1)
                    lokal = nf
                    onFraction(nf)
                    let idx = idxVon(nf)
                    if idx != letzterIdx {           // an den Enden fest → kein Tick mehr
                        letzterIdx = idx
                        motor.tick(intensitaet: 0.85)
                    }
                }
                .onEnded { _ in lokal = nil }
        )
        .onAppear { motor.vorbereiten() }
        .accessibilityLabel("Gruppen durchblättern")
    }
}

// MARK: - Dreh-Motor: Core-Haptics-Ratsch + synthetisierter Holz-Klick

/// Erzeugt pro Rastung einen scharfen Haptik-Transienten (Apple-Watch-Krone-
/// Gefühl, schnell gedreht = „grrr") plus einen kurzen, selbst berechneten
/// Holz-Klick — ganz ohne mitgelieferte Ton-Datei.
final class DrehHaptik {
    private var engine: CHHapticEngine?
    private let audio = AVAudioEngine()
    private let spieler = AVAudioPlayerNode()
    private var klick: AVAudioPCMBuffer?
    private var bereit = false

    func vorbereiten() {
        guard !bereit else { return }
        bereit = true
        if CHHapticEngine.capabilitiesForHardware().supportsHaptics {
            engine = try? CHHapticEngine()
            engine?.isAutoShutdownEnabled = true
            engine?.resetHandler = { [weak self] in try? self?.engine?.start() }
            try? engine?.start()
        }
        tonAufbauen()
    }

    private func tonAufbauen() {
        let sr = 44_100.0, dauer = 0.013
        let n = AVAudioFrameCount(sr * dauer)
        guard let fmt = AVAudioFormat(standardFormatWithSampleRate: sr, channels: 1),
              let buf = AVAudioPCMBuffer(pcmFormat: fmt, frameCapacity: n) else { return }
        buf.frameLength = n
        let p = buf.floatChannelData![0]
        var tief: Float = 0
        for i in 0..<Int(n) {
            let t = Double(i) / sr
            let huell = Float(exp(-t / 0.0022))            // schnelles Abklingen
            let rausch = Float.random(in: -1...1)
            tief = tief * 0.55 + rausch * 0.45             // Tiefpass → hölzern
            let ton = Float(sin(2 * Double.pi * 1650 * t)) // leichter Klang
            p[i] = (tief * 0.75 + ton * 0.25) * huell * 0.45
        }
        klick = buf
        try? AVAudioSession.sharedInstance().setCategory(.ambient, options: [.mixWithOthers])
        try? AVAudioSession.sharedInstance().setActive(true)
        audio.attach(spieler)
        audio.connect(spieler, to: audio.mainMixerNode, format: fmt)
        try? audio.start()
        spieler.play()
    }

    func tick(intensitaet: Float) {
        if let engine {
            let ev = CHHapticEvent(eventType: .hapticTransient, parameters: [
                CHHapticEventParameter(parameterID: .hapticIntensity, value: intensitaet),
                CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.85)
            ], relativeTime: 0)
            if let pat = try? CHHapticPattern(events: [ev], parameters: []),
               let pl = try? engine.makePlayer(with: pat) {
                try? pl.start(atTime: CHHapticTimeImmediate)
            }
        }
        if let klick {
            spieler.scheduleBuffer(klick, at: nil, options: .interrupts, completionHandler: nil)
        }
    }
}

// MARK: - Kleines Arca-Smiley (der Bogen = das Lächeln)

/// Ein winziges Gesicht: zwei Punkte + ein Arca-Bogen als Lächeln.
struct ArcaSmiley: View {
    var farbe: Color = .secondary
    var body: some View {
        Canvas { ctx, size in
            let w = size.width, h = size.height
            let r = max(0.8, w * 0.085)
            for ex in [w * 0.34, w * 0.66] {
                ctx.fill(Path(ellipseIn: CGRect(x: ex - r, y: h * 0.34 - r, width: 2 * r, height: 2 * r)),
                         with: .color(farbe))
            }
            var laecheln = Path()
            laecheln.addArc(center: CGPoint(x: w * 0.5, y: h * 0.36), radius: w * 0.26,
                            startAngle: .degrees(25), endAngle: .degrees(155), clockwise: false)
            ctx.stroke(laecheln, with: .color(farbe),
                       style: StrokeStyle(lineWidth: max(1, w * 0.09), lineCap: .round))
        }
    }
}
