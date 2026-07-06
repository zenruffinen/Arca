//
//  SwissDialectPhrases.swift
//  ArcaTickets
//
//  Entwickler: Hans zen Ruffinen
//

import SwiftUI
import UIKit

struct SwissDialectPhrase: Identifiable, Hashable {
    let id: String
    let text: String
    let design: Font.Design
    let weight: Font.Weight
    let isItalic: Bool
    let rotationDegrees: Double
    let fontSize: CGFloat

    init(
        id: String,
        text: String,
        design: Font.Design = .rounded,
        weight: Font.Weight = .bold,
        isItalic: Bool = false,
        rotationDegrees: Double = 0,
        fontSize: CGFloat = 18
    ) {
        self.id = id
        self.text = text
        self.design = design
        self.weight = weight
        self.isItalic = isItalic
        self.rotationDegrees = rotationDegrees
        self.fontSize = fontSize
    }
}

// MARK: - UI string catalog (Schweizerdeutsch, konsistent)

enum ArcaTicketsStrings {

    // Tabs
    static let tabAllTickets = "Alli Tickets"
    static let tabNotfall = "Notfall"
    static let tabSettings = "Istellige"

    // Häufige Aktionen
    static let add = "Dezue tue"
    static let addFull = "Hinzuefüege"
    static let addFirstTrip = "Ersti Reise hinzuefüege"
    static let addBoardingPass = "Boarding Pass hinzufüge"
    static let cancel = "Abbräche"
    static let save = "Speichere"
    static let backup = "Sichere"
    static let done = "Fertig"
    static let delete = "Lösche"
    static let deleteTicketTitle = "Ticket lösche?"
    static let deleteAllTickets = "Alli Tickets lösche"
    static let deleteAllTicketsTitle = "Alli Tickets lösche?"
    static let edit = "Bearbeite"
    static let `continue` = "Witer"
    static let close = "Schliesse"
    static let retry = "Nochmal probiere"
    static let ok = "OK"
    static let merge = "Zämmefüege"
    static let replace = "Ersetze"
    static let proceed = "Fortfahre"
    static let create = "Erstelle"
    static let renew = "Erneuere"
    static let skip = "Überspringe"
    static let manage = "Verwalte"

    // Unterwägs / Tickets
    static let pinOnUnterwegs = "Uf Unterwägs anhefte"
    static let unpinFromUnterwegs = "Vo Unterwägs löse"
    static let noPinnedOnUnterwegs = "No nüt agheftet"
    static let showAtCounter = "Am Schalter zeige"
    static let moreTickets = "Wiiteri Tickets"
    static let travelTip = "Tipp ✈️"
    static let reiseTip = "Reisetipp"
    static let wusstestDu = "Wüssisch?"

    // Fehler / Erfolg
    static let didNotWork = "Das het nöd klappet"
    static let importSuccess = "Import erfolgriich"
    static let importFailed = "Import fehlgschlage"
    static let backupFailed = "Sicherig fehlgschlage"

    // VoiceOver (etwas standardisiert)
    static let voZeerschtOpen = "Zeerscht im Vollbild öffne"
    static let voContinueTickets = "Witer zu Tickets und Plakatwand"
}

enum SwissDialectPhrases {
    static let heroPhrase = SwissDialectPhrase(
        id: "unterwaegs-hero",
        text: "Unterwägs",
        design: .rounded,
        weight: .bold,
        isItalic: false,
        rotationDegrees: 0,
        fontSize: 26
    )

    static let legacyHeroPhraseID = "unterwaegs-huraahh"

    static let all: [SwissDialectPhrase] = [
        heroPhrase,
        SwissDialectPhrase(id: "sorglos-reise", text: "Sorglos reise", design: .rounded, weight: .bold, rotationDegrees: -1.5),
        SwissDialectPhrase(id: "sorglos-unterwegs", text: "Sorglos unterwegs", design: .serif, weight: .semibold),
        SwissDialectPhrase(id: "alles-debii", text: "Alles debii", design: .rounded, weight: .heavy, isItalic: true, rotationDegrees: 2),
        SwissDialectPhrase(id: "uf-und-davon", text: "Uf und davon", design: .serif, weight: .bold),
        SwissDialectPhrase(id: "uf-dr-reis", text: "Uf dr Reis", design: .rounded, weight: .bold, isItalic: true, rotationDegrees: -2),
        SwissDialectPhrase(id: "onderwaegs", text: "Onderwägs", design: .serif, weight: .black, rotationDegrees: 1),
        SwissDialectPhrase(id: "ungerwegs", text: "Ungerwegs", design: .rounded, weight: .semibold, rotationDegrees: 1.5),
        SwissDialectPhrase(id: "druf-dra", text: "Druf & dra", design: .serif, weight: .bold, isItalic: true, rotationDegrees: -1),
        SwissDialectPhrase(id: "underwegs", text: "Unterwägs", design: .rounded, weight: .bold),
    ]

    static let tabLabel = "Unterwägs"

    static let tabComicPhrase = SwissDialectPhrase(
        id: "tab-unterwegs",
        text: tabLabel,
        design: .rounded,
        weight: .black,
        isItalic: true,
        rotationDegrees: -1.2,
        fontSize: 10
    )
}

enum SwissDialectComicStyle {
    static func font(size: CGFloat, weight: Font.Weight = .black, design: Font.Design = .rounded) -> Font {
        .system(size: size, weight: weight, design: design)
    }

    static func uiFont(size: CGFloat, weight: UIFont.Weight = .bold, italic: Bool = false) -> UIFont {
        let base = UIFont.systemFont(ofSize: size, weight: weight)
        var traits: UIFontDescriptor.SymbolicTraits = []
        if weight >= .bold { traits.insert(.traitBold) }
        if italic { traits.insert(.traitItalic) }
        if let descriptor = base.fontDescriptor.withDesign(.rounded)?
            .withSymbolicTraits(traits) {
            return UIFont(descriptor: descriptor, size: size)
        }
        return base
    }
}

struct ComicCurvedTextStyle: Equatable {
    var size: CGFloat = 15
    var weight: Font.Weight = .black
    var design: Font.Design = .rounded
    var italic: Bool = true
    var characterSpacing: CGFloat = 0.4
    var tracking: CGFloat = 0.8
    var waveAmplitude: CGFloat = 2.8
    var waveRotation: Double = 5.5
    var baselineRotation: Double = -2
    var wavePhaseStep: Double = 0.58

    static let hero = ComicCurvedTextStyle(
        size: 30,
        weight: .black,
        characterSpacing: 0.6,
        tracking: 1.0,
        waveAmplitude: 4.2,
        waveRotation: 7,
        baselineRotation: -2.8,
        wavePhaseStep: 0.52
    )

    static let glassHint = ComicCurvedTextStyle(
        size: 14,
        weight: .heavy,
        characterSpacing: 0.35,
        tracking: 0.7,
        waveAmplitude: 2.2,
        waveRotation: 4.5,
        baselineRotation: -2,
        wavePhaseStep: 0.55
    )

    static let compact = ComicCurvedTextStyle(
        size: 11,
        weight: .bold,
        characterSpacing: 0.25,
        tracking: 0.5,
        waveAmplitude: 1.6,
        waveRotation: 3.5,
        baselineRotation: -1.5,
        wavePhaseStep: 0.6
    )

    static let pinCode = ComicCurvedTextStyle(
        size: 18,
        weight: .black,
        characterSpacing: 1.2,
        tracking: 1.4,
        waveAmplitude: 3.0,
        waveRotation: 6.5,
        baselineRotation: -3,
        wavePhaseStep: 0.48
    )

    static let golfTag = ComicCurvedTextStyle(
        size: 11,
        weight: .black,
        characterSpacing: 0.5,
        tracking: 0.6,
        waveAmplitude: 2.0,
        waveRotation: 5.0,
        baselineRotation: -2.5,
        wavePhaseStep: 0.52
    )

    static let navTitle = ComicCurvedTextStyle(
        size: 17,
        weight: .heavy,
        characterSpacing: 0.3,
        tracking: 0.55,
        waveAmplitude: 1.9,
        waveRotation: 3.8,
        baselineRotation: -1.4,
        wavePhaseStep: 0.56
    )
}

struct ComicCurvedText: View {
    let text: String
    var style: ComicCurvedTextStyle = .glassHint
    var foreground: Color = .primary

    private var characters: [Character] { Array(text) }

    private var minLayoutHeight: CGFloat {
        LayoutSafety.dimension(style.size + style.waveAmplitude * 2 + 4, minimum: 12)
    }

    var body: some View {
        Group {
            if text.isEmpty {
                Color.clear
                    .frame(width: 1, height: minLayoutHeight)
            } else {
                HStack(spacing: style.characterSpacing) {
                    ForEach(Array(characters.enumerated()), id: \.offset) { index, character in
                        let phase = Double(index) * style.wavePhaseStep
                        let yOffset = sin(phase) * style.waveAmplitude
                        let rotation = sin(phase + 0.35) * style.waveRotation

                        Group {
                            if character == " " {
                                Color.clear.frame(width: LayoutSafety.dimension(style.size * 0.28, minimum: 2))
                            } else {
                                Text(String(character))
                                    .font(SwissDialectComicStyle.font(
                                        size: style.size,
                                        weight: style.weight,
                                        design: style.design
                                    ))
                                    .italic(style.italic)
                                    .foregroundStyle(foreground)
                                    .offset(y: yOffset)
                                    .rotationEffect(.degrees(rotation))
                            }
                        }
                    }
                }
                .tracking(style.tracking)
                .rotationEffect(.degrees(style.baselineRotation))
            }
        }
        .frame(minWidth: 1, minHeight: minLayoutHeight)
        .fixedSize(horizontal: true, vertical: true)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(text.isEmpty ? "" : text)
    }
}

extension View {
    func swissDialectComicText(
        size: CGFloat,
        weight: Font.Weight = .black,
        design: Font.Design = .rounded,
        italic: Bool = true,
        tracking: CGFloat = 0.6,
        rotation: Double = 0
    ) -> some View {
        self
            .font(SwissDialectComicStyle.font(size: size, weight: weight, design: design))
            .italic(italic)
            .tracking(tracking)
            .rotationEffect(.degrees(rotation))
    }
}

struct UnterwegsComicNavigationTitleConfigurator: UIViewControllerRepresentable {
    func makeUIViewController(context: Context) -> HookViewController {
        HookViewController()
    }

    func updateUIViewController(_ uiViewController: HookViewController, context: Context) {}

    final class HookViewController: UIViewController {
        override func viewWillAppear(_ animated: Bool) {
            super.viewWillAppear(animated)
            applyComicLargeTitle()
        }

        override func viewDidLayoutSubviews() {
            super.viewDidLayoutSubviews()
            applyComicLargeTitle()
        }

        private func applyComicLargeTitle() {
            guard let nav = navigationController else { return }
            let appearance = nav.navigationBar.standardAppearance.copy()
            let shadow = NSShadow()
            shadow.shadowOffset = CGSize(width: 0, height: 1)
            shadow.shadowBlurRadius = 2.5
            shadow.shadowColor = UIColor.black.withAlphaComponent(0.12)
            appearance.largeTitleTextAttributes = [
                .font: SwissDialectComicStyle.uiFont(size: 34, weight: .bold),
                .foregroundColor: UIColor.label,
                .shadow: shadow
            ]
            nav.navigationBar.standardAppearance = appearance
            nav.navigationBar.scrollEdgeAppearance = appearance
        }
    }
}

enum SwissDialectRotationMode: String, CaseIterable, Identifiable {
    case eachVisit
    case daily
    case locked

    var id: String { rawValue }

    var label: String {
        switch self {
        case .eachVisit: return "Bi jedem Besuch"
        case .daily: return "Täglich wächsle"
        case .locked: return "Lieblings-Spruch"
        }
    }
}

enum SwissDialectPreferences {
    private static let modeKey = "arcaTicketsSwissDialectMode"
    private static let favoriteKey = "arcaTicketsSwissDialectFavorite"
    private static let dailyDayKey = "arcaTicketsSwissDialectDailyDay"
    private static let dailyIndexKey = "arcaTicketsSwissDialectDailyIndex"

    static var rotationMode: SwissDialectRotationMode {
        get {
            guard let raw = UserDefaults.standard.string(forKey: modeKey),
                  let mode = SwissDialectRotationMode(rawValue: raw) else {
                return .eachVisit
            }
            return mode
        }
        set {
            UserDefaults.standard.set(newValue.rawValue, forKey: modeKey)
        }
    }

    static var favoritePhraseID: String {
        get {
            let stored = UserDefaults.standard.string(forKey: favoriteKey) ?? SwissDialectPhrases.heroPhrase.id
            if stored == SwissDialectPhrases.legacyHeroPhraseID {
                return SwissDialectPhrases.heroPhrase.id
            }
            return stored
        }
        set {
            UserDefaults.standard.set(newValue, forKey: favoriteKey)
        }
    }

    static func phrase(for id: String) -> SwissDialectPhrase {
        let resolved = id == SwissDialectPhrases.legacyHeroPhraseID
            ? SwissDialectPhrases.heroPhrase.id
            : id
        return SwissDialectPhrases.all.first { $0.id == resolved } ?? SwissDialectPhrases.heroPhrase
    }

    static func currentPhrase() -> SwissDialectPhrase {
        switch rotationMode {
        case .locked:
            return phrase(for: favoritePhraseID)
        case .daily:
            return dailyPhrase()
        case .eachVisit:
            return weightedRandomPhrase()
        }
    }

    private static let heroWeight = 0.38

    private static func weightedRandomPhrase() -> SwissDialectPhrase {
        if Double.random(in: 0..<1) < heroWeight {
            return SwissDialectPhrases.heroPhrase
        }
        let others = SwissDialectPhrases.all.filter { $0.id != SwissDialectPhrases.heroPhrase.id }
        return others.randomElement() ?? SwissDialectPhrases.heroPhrase
    }

    private static func weightedRandomIndex() -> Int {
        if Double.random(in: 0..<1) < heroWeight {
            return 0
        }
        return Int.random(in: SwissDialectPhrases.all.indices)
    }

    private static func dailyPhrase() -> SwissDialectPhrase {
        let today = Calendar.current.startOfDay(for: Date())
        let storedDay = UserDefaults.standard.object(forKey: dailyDayKey) as? Date

        if let storedDay,
           Calendar.current.isDate(storedDay, inSameDayAs: today),
           let index = UserDefaults.standard.object(forKey: dailyIndexKey) as? Int,
           SwissDialectPhrases.all.indices.contains(index) {
            return SwissDialectPhrases.all[index]
        }

        let index = weightedRandomIndex()
        UserDefaults.standard.set(today, forKey: dailyDayKey)
        UserDefaults.standard.set(index, forKey: dailyIndexKey)
        return SwissDialectPhrases.all[index]
    }
}

struct SwissDialectHeaderPhrase: View {
    @State private var phrase = SwissDialectPhrases.heroPhrase
    @State private var appeared = false

    private var isHero: Bool { phrase.id == SwissDialectPhrases.heroPhrase.id }

    private var curvedStyle: ComicCurvedTextStyle {
        var style = ComicCurvedTextStyle.glassHint
        style.size = max(phrase.fontSize, 20)
        style.weight = .heavy
        style.design = phrase.design
        style.italic = phrase.isItalic || phrase.design == .rounded
        style.baselineRotation = appeared ? phrase.rotationDegrees * 1.15 : phrase.rotationDegrees * 0.3
        return style
    }

    var body: some View {
        Group {
            if isHero {
                Text(phrase.text)
                    .font(.system(size: phrase.fontSize, weight: phrase.weight, design: phrase.design))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [
                                ArcaTicketsDesign.travelOcean,
                                ArcaTicketsDesign.travelGlassCyan
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
            } else {
                ComicCurvedText(text: phrase.text, style: curvedStyle)
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
            }
        }
        .scaleEffect(appeared ? 1 : 0.94)
        .opacity(appeared ? 1 : 0.55)
        .animation(.spring(response: 0.45, dampingFraction: 0.72), value: appeared)
        .onAppear {
            phrase = SwissDialectPreferences.currentPhrase()
            appeared = true
        }
    }
}
