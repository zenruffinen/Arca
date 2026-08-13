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

// MARK: - Design Tokens

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

extension View {
    /// Ein Glas-Layer pro Element — keine Verschachtelung (iOS 26 Rendering).
    @ViewBuilder
    func arcaGlass(
        tint: Color? = nil,
        interactive: Bool = false,
        in shape: some Shape = RoundedRectangle(cornerRadius: ArcaDesign.cornerRadius, style: .continuous)
    ) -> some View {
        let glass: Glass = {
            var base = Glass.regular
            if let tint { base = base.tint(tint) }
            if interactive { base = base.interactive() }
            return base
        }()
        self.glassEffect(glass, in: shape)
    }

    @ViewBuilder
    func arcaGlassCapsule(tint: Color? = nil, interactive: Bool = false) -> some View {
        arcaGlass(tint: tint, interactive: interactive, in: Capsule())
    }

    /// Solide Kartenfläche — zuverlässig lesbar, Glas-Optik nur dezent am Rand.
    func arcaCardBackground(tint: Color = .blue, cornerRadius: CGFloat = ArcaDesign.cornerRadius) -> some View {
        background {
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(Color(.secondarySystemGroupedBackground))
                .overlay {
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .fill(tint.opacity(0.08))
                }
        }
    }

    func arcaIconTile(tint: Color, size: CGFloat = ArcaDesign.iconTileSize) -> some View {
        frame(width: size, height: size)
            .background(tint.opacity(0.14), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

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
        .frame(width: 60, height: 94)
        .glassEffect(.regular.tint(farben.bg.opacity(0.55)),
                     in: RoundedRectangle(cornerRadius: 15))
        .overlay(RoundedRectangle(cornerRadius: 15)
            .strokeBorder(farben.accent.opacity(0.14), lineWidth: 1))
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
        .frame(width: 60, height: 94)
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
        .glassEffect(.regular.tint(tint.opacity(0.22)), in: Capsule())
        .overlay(Capsule().strokeBorder(.white.opacity(0.2), lineWidth: 1))
        .overlay(Capsule().strokeBorder(tint.opacity(0.5), lineWidth: 1))
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
