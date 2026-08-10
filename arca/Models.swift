//
//  Models.swift
//  Arca
//
//  Entwickler: Hans zen Ruffinen
//

import Foundation

enum ArcaSection: String, CaseIterable, Identifiable {
    case home = "Start"
    case spaceHub = "Space"
    case vault = "Passwörter"
    case documents = "Dokumente"
    case notes = "Notizen"
    case lists = "Aufgaben"
    case settings = "Einstellungen"

    var id: String { rawValue }
}

struct VaultEntry: Identifiable, Codable, Hashable {
    var id: UUID
    var title: String
    var username: String
    var password: String
    var url: String = ""
    /// Notfall: Sperr-Hotline der Karte (Anruf-Knopf im Notfall-Bereich)
    var sperrHotline: String = ""
    var isFavorite: Bool = false
    var favoritePinned: Bool = false   // „fest": ganz vorn in der Favoriten-Reihe
    var dateCreated: Date = Date()
    var colorTag: Int = 0   // Index in NoteColor.palette (0–5)

    init(id: UUID = UUID(),
         title: String,
         username: String,
         password: String,
         url: String = "",
         sperrHotline: String = "",
         isFavorite: Bool = false,
         dateCreated: Date = Date(),
         colorTag: Int = 0) {
        self.id = id
        self.title = title
        self.username = username
        self.password = password
        self.url = url
        self.sperrHotline = sperrHotline
        self.isFavorite = isFavorite
        self.dateCreated = dateCreated
        self.colorTag = colorTag
    }

    // Custom Decoder: alte Einträge ohne colorTag bleiben kompatibel
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id          = try c.decodeIfPresent(UUID.self,   forKey: .id)          ?? UUID()
        title       = try c.decode(String.self,          forKey: .title)
        username    = try c.decode(String.self,          forKey: .username)
        password    = try c.decode(String.self,          forKey: .password)
        url         = try c.decodeIfPresent(String.self, forKey: .url)         ?? ""
        sperrHotline = try c.decodeIfPresent(String.self, forKey: .sperrHotline) ?? ""
        isFavorite  = try c.decodeIfPresent(Bool.self,   forKey: .isFavorite)  ?? false
        favoritePinned = try c.decodeIfPresent(Bool.self, forKey: .favoritePinned) ?? false
        dateCreated = try c.decodeIfPresent(Date.self,   forKey: .dateCreated) ?? Date()
        colorTag    = try c.decodeIfPresent(Int.self,    forKey: .colorTag)    ?? 0
    }
}

struct NoteEntry: Identifiable, Codable, Hashable {
    var id = UUID()
    var title: String
    var text: String
    var isPinned: Bool = false
    var isFavorite: Bool = false
    var favoritePinned: Bool = false   // „fest": ganz vorn in der Favoriten-Reihe
    var dateCreated: Date = Date()
    var colorTag: Int = 0   // Index in NoteColor.palette (0–5)
    var isQuickIdea: Bool = false  // Blitzidee via Action Button

    init(id: UUID = UUID(),
         title: String,
         text: String,
         isPinned: Bool = false,
         isFavorite: Bool = false,
         dateCreated: Date = Date(),
         colorTag: Int = 0,
         isQuickIdea: Bool = false) {
        self.id = id
        self.title = title
        self.text = text
        self.isPinned = isPinned
        self.isFavorite = isFavorite
        self.dateCreated = dateCreated
        self.colorTag = colorTag
        self.isQuickIdea = isQuickIdea
    }

    // Custom Decoder: alte Notizen bleiben kompatibel
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id           = try c.decodeIfPresent(UUID.self,   forKey: .id)           ?? UUID()
        title        = try c.decode(String.self,          forKey: .title)
        text         = try c.decode(String.self,          forKey: .text)
        isPinned     = try c.decodeIfPresent(Bool.self,   forKey: .isPinned)     ?? false
        isFavorite   = try c.decodeIfPresent(Bool.self,   forKey: .isFavorite)   ?? false
        favoritePinned = try c.decodeIfPresent(Bool.self, forKey: .favoritePinned) ?? false
        dateCreated  = try c.decodeIfPresent(Date.self,   forKey: .dateCreated)  ?? Date()
        colorTag     = try c.decodeIfPresent(Int.self,    forKey: .colorTag)     ?? 0
        isQuickIdea  = try c.decodeIfPresent(Bool.self,   forKey: .isQuickIdea)  ?? false
    }
}

// Geteilte Notiz
struct ArcaNote: Codable {
    var note: NoteEntry
    var exportDate: Date
}

enum DocumentType: String, Codable {
    case pdf = "PDF"
    case image = "Bild"
    case text = "Text"
    case video = "Video"
    case mail = "Mail"
}

struct DocumentEntry: Identifiable, Codable, Hashable {
    var id = UUID()
    var title: String
    var type: DocumentType
    var filename: String
    var dateAdded: Date
    var category: String = "Unsortiert"
    var subcategory: String = ""
    var isFavorite: Bool = false
    var favoritePinned: Bool = false   // „fest": ganz vorn in der Favoriten-Reihe
    var ocrText: String = ""           // beim Scannen erkannter Text (für die Suche)

    init(id: UUID = UUID(), title: String, type: DocumentType, filename: String, dateAdded: Date, category: String = "Unsortiert", subcategory: String = "", ocrText: String = "") {
        self.id = id; self.title = title; self.type = type; self.filename = filename
        self.dateAdded = dateAdded; self.category = category; self.subcategory = subcategory
        self.ocrText = ocrText
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id          = try c.decodeIfPresent(UUID.self,         forKey: .id)          ?? UUID()
        title       = try c.decode(String.self,                forKey: .title)
        type        = try c.decode(DocumentType.self,          forKey: .type)
        filename    = try c.decode(String.self,                forKey: .filename)
        dateAdded   = try c.decodeIfPresent(Date.self,         forKey: .dateAdded)   ?? Date()
        category    = try c.decodeIfPresent(String.self,       forKey: .category)    ?? "Unsortiert"
        subcategory = try c.decodeIfPresent(String.self,       forKey: .subcategory) ?? ""
        isFavorite  = try c.decodeIfPresent(Bool.self,         forKey: .isFavorite)  ?? false
        favoritePinned = try c.decodeIfPresent(Bool.self,      forKey: .favoritePinned) ?? false
        ocrText     = try c.decodeIfPresent(String.self,       forKey: .ocrText)     ?? ""
    }
}

// Geteilter Ordner (für Familien-Teilen)
struct ArcaFolder: Codable {
    var categoryName: String
    var documents: [DocumentEntry]
    var fileData: [String: Data] // filename → Dateiinhalt
    var exportDate: Date
    var subcategories: [String]?
}

struct ChecklistItem: Identifiable, Codable, Hashable {
    var id = UUID()
    var text: String
    var isDone: Bool = false
}

struct ListEntry: Identifiable, Codable, Hashable {
    var id = UUID()
    var title: String
    var items: [ChecklistItem] = []
    var isFavorite: Bool = false
    var favoritePinned: Bool = false   // „fest": ganz vorn in der Favoriten-Reihe
    var dateCreated: Date = Date()
    var colorTag: Int = 0   // Index in NoteColor.palette (0–5)

    init(id: UUID = UUID(),
         title: String,
         items: [ChecklistItem] = [],
         isFavorite: Bool = false,
         dateCreated: Date = Date(),
         colorTag: Int = 0) {
        self.id = id
        self.title = title
        self.items = items
        self.isFavorite = isFavorite
        self.dateCreated = dateCreated
        self.colorTag = colorTag
    }

    // Custom Decoder: alte Listen ohne colorTag bleiben kompatibel
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id          = try c.decodeIfPresent(UUID.self,             forKey: .id)          ?? UUID()
        title       = try c.decode(String.self,                    forKey: .title)
        items       = try c.decodeIfPresent([ChecklistItem].self,  forKey: .items)       ?? []
        isFavorite  = try c.decodeIfPresent(Bool.self,             forKey: .isFavorite)  ?? false
        favoritePinned = try c.decodeIfPresent(Bool.self,          forKey: .favoritePinned) ?? false
        dateCreated = try c.decodeIfPresent(Date.self,             forKey: .dateCreated) ?? Date()
        colorTag    = try c.decodeIfPresent(Int.self,              forKey: .colorTag)    ?? 0
    }
}

// Geteilte Aufgabenliste
struct ArcaList: Codable {
    var list: ListEntry
    var exportDate: Date
}

// MARK: - Favoriten

/// Vereinheitlichter Favorit für die Start-Reihe — reines Anzeige-Modell,
/// gespeist aus den vier Beständen (isFavorite/favoritePinned dort).
enum FavoriteKind: String {
    case document, note, list, vault
}

/// Aussehen der Schreibtisch-Flächen: Titel und Farben — synct über
/// iCloud, damit iPad und Mac dasselbe Pult zeigen.
struct DeskFlaechenStil: Codable {
    var titelLinks: String? = nil
    var titelRechts: String? = nil
    var farbeLinks: Int? = nil
    var farbeRechts: Int? = nil

    init() {}

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        titelLinks  = try c.decodeIfPresent(String.self, forKey: .titelLinks)
        titelRechts = try c.decodeIfPresent(String.self, forKey: .titelRechts)
        farbeLinks  = try c.decodeIfPresent(Int.self,    forKey: .farbeLinks)
        farbeRechts = try c.decodeIfPresent(Int.self,    forKey: .farbeRechts)
    }
}

/// Ein Eintrag auf dem Arca-Schreibtisch (iPad/Mac): kleine Karten
/// links und rechts vom Space — nur Verweise, keine Kopien.
struct DeskItem: Identifiable, Codable, Hashable {
    var id = UUID()
    var kindRaw: String
    var refID: UUID
    var seite: String = "rechts"   // "links" oder "rechts"
    var posX: Double? = nil        // frei positioniert? (Canvas-Koordinaten)
    var posY: Double? = nil
    var colorTag: Int? = nil       // farbiger Rand (NoteColor-Palette)

    var kind: FavoriteKind { FavoriteKind(rawValue: kindRaw) ?? .note }

    init(kind: FavoriteKind, refID: UUID, seite: String) {
        self.kindRaw = kind.rawValue
        self.refID = refID
        self.seite = seite
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id       = try c.decodeIfPresent(UUID.self,   forKey: .id)       ?? UUID()
        kindRaw  = try c.decodeIfPresent(String.self, forKey: .kindRaw)  ?? "note"
        refID    = try c.decode(UUID.self,            forKey: .refID)
        seite    = try c.decodeIfPresent(String.self, forKey: .seite)    ?? "rechts"
        posX     = try c.decodeIfPresent(Double.self, forKey: .posX)
        posY     = try c.decodeIfPresent(Double.self, forKey: .posY)
        colorTag = try c.decodeIfPresent(Int.self,    forKey: .colorTag)
    }
}

struct FavoriteItem: Identifiable, Hashable {
    let id: UUID
    let kind: FavoriteKind
    let title: String
    let subtitle: String
    let pinned: Bool
    let date: Date
}
