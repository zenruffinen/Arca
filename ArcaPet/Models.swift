//
//  Models.swift
//  ArcaPet
//

import Foundation
import SwiftUI

struct PetProfile: Codable, Hashable {
    var name: String
    var species: String
    var breed: String?
    var birthDate: Date?
    var chipNumber: String?
    var vetName: String?
    var vetPhone: String?
    var notes: String?

    static let placeholder = PetProfile(
        name: "Socke",
        species: "Hund",
        breed: nil,
        birthDate: nil,
        chipNumber: nil,
        vetName: nil,
        vetPhone: nil,
        notes: nil
    )
}

enum PetDocumentCategory: String, Codable, CaseIterable, Identifiable {
    case impfung
    case chip
    case tierarzt
    case medikamente
    case dokumente
    case notfall

    var id: String { rawValue }

    var label: String {
        switch self {
        case .impfung: return "IMPFUNG"
        case .chip: return "CHIP"
        case .tierarzt: return "TIERARZT"
        case .medikamente: return "MEDIKAMENTE"
        case .dokumente: return "DOKUMENTE"
        case .notfall: return "NOTFALL"
        }
    }
}

struct PetDocument: Identifiable, Codable, Hashable {
    var id: UUID
    var title: String
    var category: PetDocumentCategory
    var fileName: String
    var createdAt: Date
    var expiryDate: Date?
    var notes: String?

    init(
        id: UUID = UUID(),
        title: String,
        category: PetDocumentCategory,
        fileName: String,
        createdAt: Date = Date(),
        expiryDate: Date? = nil,
        notes: String? = nil
    ) {
        self.id = id
        self.title = title
        self.category = category
        self.fileName = fileName
        self.createdAt = createdAt
        self.expiryDate = expiryDate
        self.notes = notes
    }
}

enum PetContactCategory: String, Codable, CaseIterable, Identifiable {
    case tierarzt
    case notfall
    case familie
    case sonstiges

    var id: String { rawValue }

    var label: String {
        switch self {
        case .tierarzt: return "Tierarzt"
        case .notfall: return "Notfall"
        case .familie: return "Familie"
        case .sonstiges: return "Sonstiges"
        }
    }
}

struct QuickContact: Identifiable, Codable, Hashable {
    var id: UUID
    var label: String
    var phoneNumber: String
    var category: PetContactCategory
    var sortOrder: Int

    init(
        id: UUID = UUID(),
        label: String,
        phoneNumber: String,
        category: PetContactCategory,
        sortOrder: Int = 0
    ) {
        self.id = id
        self.label = label
        self.phoneNumber = phoneNumber
        self.category = category
        self.sortOrder = sortOrder
    }

    var hasPhoneNumber: Bool {
        !phoneNumber.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}

enum PetContactDefaults {
    static func seedContacts() -> [QuickContact] {
        [
            QuickContact(label: "Tierarzt", phoneNumber: "", category: .tierarzt, sortOrder: 0),
            QuickContact(label: "Tiernotruf", phoneNumber: "044 211 21 21", category: .notfall, sortOrder: 1),
            QuickContact(label: "Polizei", phoneNumber: "117", category: .notfall, sortOrder: 2),
        ]
    }
}

enum ArcaPetHomeCategory: String, CaseIterable, Identifiable {
    case gesundheit
    case dokumente
    case termine
    case futter
    case notfall
    case fotos

    var id: String { rawValue }

    var title: String {
        switch self {
        case .gesundheit: return "Gesundheit"
        case .dokumente: return "Dokumente"
        case .termine: return "Termine"
        case .futter: return "Futter & Ernährung"
        case .notfall: return "Notfall"
        case .fotos: return "Fotos & Notizen"
        }
    }

    var subtitle: String {
        switch self {
        case .gesundheit: return "Impfungen, Untersuchungen, Medikamente"
        case .dokumente: return "Impfausweis, Chipnummer, Versicherung"
        case .termine: return "Erinnerungen, Kontrolle, Tierarztbesuche"
        case .futter: return "Futter, Mengen, Allergien"
        case .notfall: return "Notfallkontakte, Tierarzt"
        case .fotos: return "Erinnerungen, Bilder, persönliche Notizen"
        }
    }

    var icon: String {
        switch self {
        case .gesundheit: return "shield.lefthalf.filled"
        case .dokumente: return "doc.text.fill"
        case .termine: return "calendar"
        case .futter: return "fork.knife.circle.fill"
        case .notfall: return "heart.text.square.fill"
        case .fotos: return "photo.on.rectangle.angled"
        }
    }

    var tint: Color {
        ArcaPetDesign.tint(for: self)
    }

    var sheet: ArcaPetSheet {
        switch self {
        case .gesundheit: return .gesundheit
        case .dokumente: return .dokumente
        case .termine: return .termine
        case .futter: return .futter
        case .notfall: return .notfall
        case .fotos: return .fotos
        }
    }

    var accessibilityHint: String { subtitle }

    /// Center point on the vertical hero (473×1024, baked UI mockup).
    var point: CGPoint {
        switch self {
        case .gesundheit: CGPoint(x: 0.27, y: 0.505)
        case .dokumente:  CGPoint(x: 0.73, y: 0.505)
        case .termine:    CGPoint(x: 0.27, y: 0.605)
        case .futter:     CGPoint(x: 0.73, y: 0.605)
        case .notfall:    CGPoint(x: 0.27, y: 0.705)
        case .fotos:      CGPoint(x: 0.73, y: 0.705)
        }
    }

    var hitSize: CGSize {
        CGSize(width: 0.42, height: 0.088)
    }
}

enum ArcaPetAddPetHotspot {
    static let point = CGPoint(x: 0.50, y: 0.805)
    static let hitSize = CGSize(width: 0.86, height: 0.065)
    static let rippleTint = ArcaPetDesign.glassCyan
}

enum ArcaPetSheet: Identifiable {
    case gesundheit, dokumente, termine, futter, notfall, fotos, addPet, settings

    var id: String {
        switch self {
        case .gesundheit: return "gesundheit"
        case .dokumente: return "dokumente"
        case .termine: return "termine"
        case .futter: return "futter"
        case .notfall: return "notfall"
        case .fotos: return "fotos"
        case .addPet: return "addPet"
        case .settings: return "settings"
        }
    }
}
