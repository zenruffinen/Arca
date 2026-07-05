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

enum SwissDialectPhrases {
    static let heroPhrase = SwissDialectPhrase(
        id: "unterwaegs-huraahh",
        text: "Unterwäää..gs huraahh",
        design: .rounded,
        weight: .black,
        isItalic: true,
        rotationDegrees: -2.8,
        fontSize: 30
    )

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

    static func uiFont(size: CGFloat, weight: UIFont.Weight = .black) -> UIFont {
        let base = UIFont.systemFont(ofSize: size, weight: weight)
        if let descriptor = base.fontDescriptor.withDesign(.rounded)?
            .withSymbolicTraits([.traitBold, .traitItalic]) {
            return UIFont(descriptor: descriptor, size: size)
        }
        return base
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
            appearance.largeTitleTextAttributes = [
                .font: SwissDialectComicStyle.uiFont(size: 34, weight: .black),
                .foregroundColor: UIColor.label
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
        case .eachVisit: return "Bei jedem Besuch"
        case .daily: return "Täglich wechseln"
        case .locked: return "Lieblingsspruch"
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
            UserDefaults.standard.string(forKey: favoriteKey) ?? SwissDialectPhrases.heroPhrase.id
        }
        set {
            UserDefaults.standard.set(newValue, forKey: favoriteKey)
        }
    }

    static func phrase(for id: String) -> SwissDialectPhrase {
        SwissDialectPhrases.all.first { $0.id == id } ?? SwissDialectPhrases.heroPhrase
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

    private static let heroWeight = 0.48

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

    var body: some View {
        Text(phrase.text)
            .swissDialectComicText(
                size: isHero ? max(phrase.fontSize, 28) : max(phrase.fontSize, 22),
                weight: isHero ? .black : .heavy,
                design: phrase.design,
                italic: phrase.isItalic || phrase.design == .rounded,
                tracking: isHero ? 1.0 : 0.8,
                rotation: appeared ? phrase.rotationDegrees * (isHero ? 1.6 : 1.4) : phrase.rotationDegrees * 0.3
            )
            .lineLimit(isHero ? 2 : 1)
            .minimumScaleFactor(isHero ? 0.75 : 0.85)
            .scaleEffect(appeared ? (isHero ? 1.04 : 1) : 0.9)
            .opacity(appeared ? 1 : 0.55)
            .animation(.spring(response: 0.45, dampingFraction: isHero ? 0.62 : 0.72), value: appeared)
            .accessibilityLabel(phrase.text)
            .onAppear {
                phrase = SwissDialectPreferences.currentPhrase()
                appeared = true
            }
    }
}
