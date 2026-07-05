//
//  SwissDialectPhrases.swift
//  ArcaTickets
//
//  Entwickler: Hans zen Ruffinen
//

import SwiftUI

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
    static let all: [SwissDialectPhrase] = [
        SwissDialectPhrase(id: "sorglos-reise", text: "Sorglos reise", design: .rounded, weight: .bold, rotationDegrees: -1.5),
        SwissDialectPhrase(id: "sorglos-unterwegs", text: "Sorglos unterwegs", design: .serif, weight: .semibold),
        SwissDialectPhrase(id: "alles-debii", text: "Alles debii", design: .rounded, weight: .heavy, isItalic: true, rotationDegrees: 2),
        SwissDialectPhrase(id: "uf-und-davon", text: "Uf und davon", design: .serif, weight: .bold),
        SwissDialectPhrase(id: "uf-dr-reis", text: "Uf dr Reis", design: .rounded, weight: .bold, isItalic: true, rotationDegrees: -2),
        SwissDialectPhrase(id: "onderwaegs", text: "Onderwägs", design: .serif, weight: .black, rotationDegrees: 1),
        SwissDialectPhrase(id: "ungerwegs", text: "Ungerwegs", design: .rounded, weight: .semibold, rotationDegrees: 1.5),
        SwissDialectPhrase(id: "druf-dra", text: "Druf & dra", design: .serif, weight: .bold, isItalic: true, rotationDegrees: -1),
        SwissDialectPhrase(id: "underwegs", text: "Underwegs", design: .rounded, weight: .bold),
    ]

    static let tabLabel = "Underwegs"
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
            UserDefaults.standard.string(forKey: favoriteKey) ?? SwissDialectPhrases.all[0].id
        }
        set {
            UserDefaults.standard.set(newValue, forKey: favoriteKey)
        }
    }

    static func phrase(for id: String) -> SwissDialectPhrase {
        SwissDialectPhrases.all.first { $0.id == id } ?? SwissDialectPhrases.all[0]
    }

    static func currentPhrase() -> SwissDialectPhrase {
        switch rotationMode {
        case .locked:
            return phrase(for: favoritePhraseID)
        case .daily:
            return dailyPhrase()
        case .eachVisit:
            return SwissDialectPhrases.all.randomElement() ?? SwissDialectPhrases.all[0]
        }
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

        let index = Int.random(in: SwissDialectPhrases.all.indices)
        UserDefaults.standard.set(today, forKey: dailyDayKey)
        UserDefaults.standard.set(index, forKey: dailyIndexKey)
        return SwissDialectPhrases.all[index]
    }
}

struct SwissDialectHeaderPhrase: View {
    @State private var phrase = SwissDialectPhrases.all[0]
    @State private var appeared = false

    var body: some View {
        Text(phrase.text)
            .font(.system(size: phrase.fontSize, weight: phrase.weight, design: phrase.design))
            .italic(phrase.isItalic)
            .rotationEffect(.degrees(appeared ? phrase.rotationDegrees : phrase.rotationDegrees * 0.4))
            .scaleEffect(appeared ? 1 : 0.94)
            .opacity(appeared ? 1 : 0.6)
            .animation(.spring(response: 0.45, dampingFraction: 0.78), value: appeared)
            .accessibilityLabel(phrase.text)
            .onAppear {
                phrase = SwissDialectPreferences.currentPhrase()
                appeared = true
            }
    }
}
