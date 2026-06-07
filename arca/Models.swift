import Foundation

enum ArcaSection: String, CaseIterable, Identifiable {
    case home = "Start"
    case vault = "Passwörter"
    case documents = "Dokumente"
    case notes = "Notizen"
    case lists = "Tasks"
    case settings = "Einstellungen"

    var id: String { rawValue }
}

struct VaultEntry: Identifiable, Codable, Hashable {
    var id: UUID
    var title: String
    var username: String
    var password: String
    var url: String = ""
    var isFavorite: Bool = false
    var dateCreated: Date = Date()
    var colorTag: Int = 0   // Index in NoteColor.palette (0–5)

    init(id: UUID = UUID(),
         title: String,
         username: String,
         password: String,
         url: String = "",
         isFavorite: Bool = false,
         dateCreated: Date = Date(),
         colorTag: Int = 0) {
        self.id = id
        self.title = title
        self.username = username
        self.password = password
        self.url = url
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
        isFavorite  = try c.decodeIfPresent(Bool.self,   forKey: .isFavorite)  ?? false
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
}

struct DocumentEntry: Identifiable, Codable, Hashable {
    var id = UUID()
    var title: String
    var type: DocumentType
    var filename: String
    var dateAdded: Date
    var category: String = "Sonstiges"
    var subcategory: String = ""

    init(id: UUID = UUID(), title: String, type: DocumentType, filename: String, dateAdded: Date, category: String = "Sonstiges", subcategory: String = "") {
        self.id = id; self.title = title; self.type = type; self.filename = filename
        self.dateAdded = dateAdded; self.category = category; self.subcategory = subcategory
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id          = try c.decodeIfPresent(UUID.self,         forKey: .id)          ?? UUID()
        title       = try c.decode(String.self,                forKey: .title)
        type        = try c.decode(DocumentType.self,          forKey: .type)
        filename    = try c.decode(String.self,                forKey: .filename)
        dateAdded   = try c.decodeIfPresent(Date.self,         forKey: .dateAdded)   ?? Date()
        category    = try c.decodeIfPresent(String.self,       forKey: .category)    ?? "Sonstiges"
        subcategory = try c.decodeIfPresent(String.self,       forKey: .subcategory) ?? ""
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
        dateCreated = try c.decodeIfPresent(Date.self,             forKey: .dateCreated) ?? Date()
        colorTag    = try c.decodeIfPresent(Int.self,              forKey: .colorTag)    ?? 0
    }
}

// Geteilte Aufgabenliste
struct ArcaList: Codable {
    var list: ListEntry
    var exportDate: Date
}
