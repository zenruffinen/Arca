//
//  ArcaSymbols.swift
//  Arca
//
//  Eigene, skalierbare Icon-Familie mit dem Arca-Bogen als Form-DNA.
//

import SwiftUI

enum ArcaSymbol: String, CaseIterable, Identifiable {
    case archive = "ArcaArchive"
    case key = "ArcaKey"
    case bolt = "ArcaBolt"
    case document = "ArcaDocument"
    case checklist = "ArcaChecklist"
    case note = "ArcaNote"
    case folder = "ArcaFolder"
    case lock = "ArcaLock"
    case done = "ArcaDone"
    case search = "ArcaSearch"
    case place = "ArcaPlace"
    case calendar = "ArcaCalendar"
    case star = "ArcaStar"
    case home = "ArcaHome"
    case card = "ArcaCard"
    case travel = "ArcaTravel"
    case health = "ArcaHealth"
    case invoice = "ArcaInvoice"
    case settings = "ArcaSettings"
    case scan = "ArcaScan"

    var id: String { rawValue }
}

/// Zeichnet ein Symbol: beginnt der Name mit „Arca", kommt das eigene
/// Vektor-Asset (Template, färbbar) — sonst das SF-Symbol. So lassen
/// sich die Familien Stück für Stück tauschen.
struct ArcaIcon: View {
    let name: String
    var groesse: CGFloat = 16
    var gewicht: Font.Weight = .semibold

    var body: some View {
        if name.hasPrefix("Arca") {
            Image(name)
                .resizable()
                .renderingMode(.template)
                .scaledToFit()
                .frame(width: groesse, height: groesse)
        } else {
            Image(systemName: name)
                .font(.system(size: groesse * 0.92, weight: gewicht))
        }
    }
}

// MARK: - Das Haus als Körper (Leiste)

/// Der Arca-Bogen als Haus: Torbogen mit Tür, gefüllt statt als Strich.
///
/// Das Asset `ArcaHome` ist eine 1,7-Punkt-Linie. Auf 20 Punkt
/// heruntergerechnet wird daraus ein Faden, der neben dem kräftigen
/// Pluszeichen daneben verschwindet. Gefüllt hat das Haus einen Körper —
/// und der Bogen, die Form-DNA der Familie, wird überhaupt erst lesbar.
///
/// Gezeichnet mit Bézier-Vierteln statt `addArc`: in SwiftUIs gespiegelter
/// Y-Achse ist bei `addArc` nie auf Anhieb klar, welche Hälfte man
/// bekommt. Kurven sind länger hingeschrieben, aber eindeutig.
struct ArcaBogenHaus: Shape {

    func path(in rect: CGRect) -> Path {
        // Alles in dem 24er-Raster des Assets, damit das Haus dieselben
        // Proportionen behält wie die gestrichelte Fassung.
        let s = min(rect.width, rect.height) / 24
        let dx = rect.minX + (rect.width - 24 * s) / 2
        let dy = rect.minY + (rect.height - 24 * s) / 2
        func p(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
            CGPoint(x: dx + x * s, y: dy + y * s)
        }

        // Kreis-Viertel als Bézier: k = 0.5523 × Radius
        let kAussen = 0.5523 * 6.5
        let kTuer = 0.5523 * 2.7

        var path = Path()

        // ── Aussenbogen: Wände hoch, Halbkreis darüber ──
        path.move(to: p(5.5, 20.4))
        path.addLine(to: p(5.5, 12.3))
        path.addCurve(to: p(12, 5.8),
                      control1: p(5.5, 12.3 - kAussen),
                      control2: p(12 - kAussen, 5.8))
        path.addCurve(to: p(18.5, 12.3),
                      control1: p(12 + kAussen, 5.8),
                      control2: p(18.5, 12.3 - kAussen))
        path.addLine(to: p(18.5, 20.4))
        path.closeSubpath()

        // ── Die Tür: eigener Teilpfad, wird per evenOdd ausgestanzt ──
        path.move(to: p(9.3, 20.4))
        path.addLine(to: p(9.3, 16.6))
        path.addCurve(to: p(12, 13.9),
                      control1: p(9.3, 16.6 - kTuer),
                      control2: p(12 - kTuer, 13.9))
        path.addCurve(to: p(14.7, 16.6),
                      control1: p(12 + kTuer, 13.9),
                      control2: p(14.7, 16.6 - kTuer))
        path.addLine(to: p(14.7, 20.4))
        path.closeSubpath()

        // ── Der Boden: liegt UNTER den Wänden, nicht in ihnen ──
        //
        // Überlappte er sie, würde evenOdd die Überschneidung wieder
        // ausstanzen und das Haus bekäme Kerben an den Füßen.
        path.addRoundedRect(
            in: CGRect(x: dx + 3.3 * s, y: dy + 20.4 * s,
                       width: 17.4 * s, height: 1.7 * s),
            cornerSize: CGSize(width: 0.85 * s, height: 0.85 * s))

        return path
    }
}

/// Das Haus, wie es in der Leiste steht: gefüllt, mit einem Verlauf, der
/// oben hell anfängt — dieselbe Wölbung wie bei den runden Knöpfen.
struct ArcaHausMarke: View {
    var groesse: CGFloat = 22
    var farbe: Color

    var body: some View {
        ArcaBogenHaus()
            .fill(
                LinearGradient(colors: [farbe.opacity(0.92), farbe],
                               startPoint: .top, endPoint: .bottom),
                style: FillStyle(eoFill: true))
            .frame(width: groesse, height: groesse)
    }
}

struct ArcaSymbolImage: View {
    let symbol: ArcaSymbol
    var size: CGFloat = 24
    var color: Color = ArcaWarm.terrakotta

    var body: some View {
        Image(symbol.rawValue)
            .resizable()
            .renderingMode(.template)
            .scaledToFit()
            .foregroundStyle(color)
            .frame(width: size, height: size)
            .accessibilityHidden(true)
    }
}

#Preview("Arca Icon Family") {
    LazyVGrid(columns: [.init(.adaptive(minimum: 76))], spacing: 24) {
        ForEach(ArcaSymbol.allCases) { symbol in
            VStack(spacing: 8) {
                ArcaSymbolImage(symbol: symbol, size: 30)
                Text(symbol.rawValue.dropFirst(4))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
    }
    .padding(24)
    .background(ArcaWarm.hintergrund)
}
