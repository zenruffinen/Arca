//
//  Models.swift
//  Arca
//
//  Entwickler: Hans zen Ruffinen
//

import Foundation

/// Wer einen Änderungs-Stempel trägt, kann zusammengeführt werden:
/// beim Sync gewinnt Eintrag für Eintrag der jüngere Stand.
protocol ZeitGestempelt {
    var geaendertAm: Date { get set }
}

enum ArcaSection: String, CaseIterable, Identifiable {
    case home = "Start"
    case spaceHub = "Space"
    case vault = "Passwörter"
    case documents = "Dokumente"
    case notes = "Notizen"
    case lists = "Aufgaben"
    case settings = "Einstellungen"

    var id: String { rawValue }
    /// Was der Nutzer sieht — intern bleibt „Notizen" die Identität.
    var displayName: String {
        switch self {
        case .notes: return "Ideen"
        case .vault: return "Tresor"
        default:     return rawValue
        }
    }
}

/// Art eines Tresor-Eintrags: klassisches Passwort oder Kreditkarte.
enum VaultArt: String, Codable { case passwort, karte }

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
    var geaendertAm: Date = Date()

    // Kreditkarte (nur befüllt, wenn art == .karte)
    var art: VaultArt = .passwort
    var kartennummer: String = ""
    var karteninhaber: String = ""
    var ablauf: String = ""        // MM/JJ
    var pruefnummer: String = ""   // CVV / CVC
    var pin: String = ""
    var kartenBildVorne: String = ""   // Dateiname eingescanntes Foto Vorderseite (filesDirectory)
    var kartenBildHinten: String = ""  // Dateiname eingescanntes Foto Rückseite
    var inApplePay: Bool = false       // Merker: Karte wurde zu Apple Pay hinzugefügt

    init(id: UUID = UUID(),
         title: String,
         username: String,
         password: String,
         url: String = "",
         sperrHotline: String = "",
         isFavorite: Bool = false,
         dateCreated: Date = Date(),
         colorTag: Int = 0,
         art: VaultArt = .passwort,
         kartennummer: String = "",
         karteninhaber: String = "",
         ablauf: String = "",
         pruefnummer: String = "",
         pin: String = "",
         kartenBildVorne: String = "",
         kartenBildHinten: String = "",
         inApplePay: Bool = false) {
        self.id = id
        self.title = title
        self.username = username
        self.password = password
        self.url = url
        self.sperrHotline = sperrHotline
        self.isFavorite = isFavorite
        self.dateCreated = dateCreated
        self.colorTag = colorTag
        self.art = art
        self.kartennummer = kartennummer
        self.karteninhaber = karteninhaber
        self.ablauf = ablauf
        self.pruefnummer = pruefnummer
        self.pin = pin
        self.kartenBildVorne = kartenBildVorne
        self.kartenBildHinten = kartenBildHinten
        self.inApplePay = inApplePay
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
        geaendertAm = try c.decodeIfPresent(Date.self,   forKey: .geaendertAm) ?? dateCreated
        art          = try c.decodeIfPresent(VaultArt.self, forKey: .art)          ?? .passwort
        kartennummer = try c.decodeIfPresent(String.self,  forKey: .kartennummer)  ?? ""
        karteninhaber = try c.decodeIfPresent(String.self, forKey: .karteninhaber) ?? ""
        ablauf       = try c.decodeIfPresent(String.self,  forKey: .ablauf)        ?? ""
        pruefnummer  = try c.decodeIfPresent(String.self,  forKey: .pruefnummer)   ?? ""
        pin          = try c.decodeIfPresent(String.self,  forKey: .pin)           ?? ""
        kartenBildVorne  = try c.decodeIfPresent(String.self, forKey: .kartenBildVorne)  ?? ""
        kartenBildHinten = try c.decodeIfPresent(String.self, forKey: .kartenBildHinten) ?? ""
        inApplePay       = try c.decodeIfPresent(Bool.self,   forKey: .inApplePay)        ?? false
    }
}

extension VaultEntry: ZeitGestempelt {}

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
    var geaendertAm: Date = Date()
    /// Angehängte Fotos (Dateinamen im filesDirectory) — das Korkblatt.
    var fotos: [String] = []
    /// Verknüpfte Arca-Dokumente (IDs).
    var verknuepfteDokumente: [UUID] = []

    init(id: UUID = UUID(),
         title: String,
         text: String,
         isPinned: Bool = false,
         isFavorite: Bool = false,
         dateCreated: Date = Date(),
         colorTag: Int = 0,
         isQuickIdea: Bool = false,
         fotos: [String] = [],
         verknuepfteDokumente: [UUID] = []) {
        self.id = id
        self.title = title
        self.text = text
        self.isPinned = isPinned
        self.isFavorite = isFavorite
        self.dateCreated = dateCreated
        self.colorTag = colorTag
        self.isQuickIdea = isQuickIdea
        self.fotos = fotos
        self.verknuepfteDokumente = verknuepfteDokumente
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
        geaendertAm  = try c.decodeIfPresent(Date.self,   forKey: .geaendertAm)  ?? dateCreated
        fotos        = try c.decodeIfPresent([String].self, forKey: .fotos)      ?? []
        verknuepfteDokumente = try c.decodeIfPresent([UUID].self, forKey: .verknuepfteDokumente) ?? []
    }
}

extension NoteEntry: ZeitGestempelt {}

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
    var geaendertAm: Date = Date()

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
        geaendertAm = try c.decodeIfPresent(Date.self,         forKey: .geaendertAm) ?? dateAdded
    }
}

extension DocumentEntry: ZeitGestempelt {}

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
    var geaendertAm: Date = Date()

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
        geaendertAm = try c.decodeIfPresent(Date.self,             forKey: .geaendertAm) ?? dateCreated
    }
}

extension ListEntry: ZeitGestempelt {}

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
    var geaendertAm: Date = Date()

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
        geaendertAm = try c.decodeIfPresent(Date.self, forKey: .geaendertAm) ?? .distantPast
    }
}

extension DeskItem: ZeitGestempelt {}

struct FavoriteItem: Identifiable, Hashable {
    let id: UUID
    let kind: FavoriteKind
    let title: String
    let subtitle: String
    let pinned: Bool
    let date: Date
}

// MARK: - Digitales Erbe (Nachlass-Mappe)

/// Ein Eintrag in der Nachlass-Mappe — Abo, Konto/Login-Hinweis, wo ein
/// Dokument liegt, eine persönliche Nachricht. Bewusst schlichter Freitext,
/// damit Angehörige alles an einem Ort finden.
struct ErbeEintrag: Identifiable, Codable, Hashable {
    var id = UUID()
    var titel: String = ""
    var inhalt: String = ""
    var kategorie: ErbeKategorie = .sonstiges
    var dateCreated: Date = Date()

    // Rückwärtskompatibel dekodieren (Codable-Hausregel)
    init(id: UUID = UUID(), titel: String = "", inhalt: String = "",
         kategorie: ErbeKategorie = .sonstiges, dateCreated: Date = Date()) {
        self.id = id; self.titel = titel; self.inhalt = inhalt
        self.kategorie = kategorie; self.dateCreated = dateCreated
    }
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        titel = try c.decodeIfPresent(String.self, forKey: .titel) ?? ""
        inhalt = try c.decodeIfPresent(String.self, forKey: .inhalt) ?? ""
        kategorie = try c.decodeIfPresent(ErbeKategorie.self, forKey: .kategorie) ?? .sonstiges
        dateCreated = try c.decodeIfPresent(Date.self, forKey: .dateCreated) ?? Date()
    }
}

enum ErbeKategorie: String, Codable, CaseIterable, Identifiable {
    case abo, konto, dokument, nachricht, sonstiges
    var id: String { rawValue }
    var label: String {
        switch self {
        case .abo:       return "Abo / Vertrag"
        case .konto:     return "Konto / Login"
        case .dokument:  return "Wichtiges Dokument"
        case .nachricht: return "Persönliche Nachricht"
        case .sonstiges: return "Sonstiges"
        }
    }
    var symbol: String {
        switch self {
        case .abo:       return "arrow.triangle.2.circlepath"
        case .konto:     return "person.badge.key.fill"
        case .dokument:  return "doc.text.fill"
        case .nachricht: return "heart.text.square.fill"
        case .sonstiges: return "tray.full.fill"
        }
    }
}

// MARK: - Die Wand: Boards und Anschläge
//
// Ein „Anschlag" ist das, was an einer Wand hängt: ein Verweis auf ein
// Original (Dokument, Idee, Aufgabenliste, Tresor-Eintrag) samt Platz und
// Neigung. Er löst drei Dinge ab, die bisher dasselbe getan haben —
// Favoriten (`isFavorite`), den Schreibtisch (`DeskItem`) und die
// Ideen-Pinnwand (`pinnwandLayout`). Angepinnt IST Favorit.
//
// Koordinaten sind bewusst RELATIV (0…1): dieselbe Wand soll auf iPhone,
// iPad und Mac gleich aussehen. Die alten absoluten Punkte taten das nicht.

/// Wozu eine Wand da ist. Bestimmt, ob und wie sie gezeigt wird.
enum BoardArt: String, Codable {
    /// „Meine Wand" und alle Themen-Boards („Italien im Mai", „Hausbau").
    case wand
    /// Historisch: die Wand, die einmal alle Ideen gespiegelt hat. Seit
    /// dem 26.08. ist sie eine gewöhnliche Wand — der Fall bleibt nur
    /// stehen, damit alte Daten sich noch lesen lassen.
    case ideen
    /// Unsichtbar: trägt die Tresor-Einträge der Startreihe. Passwörter
    /// hängen NIE an einer sichtbaren Wand (siehe Konzept, Abschnitt 2).
    case tresor
    /// Der Arca-Schreibtisch auf iPad/Mac — links und rechts vom Space.
    case schreibtisch
}

/// Wie eine Wand aussieht. Vier Korkplatten hinter Glas — später sollen
/// weitere Beläge als Kauf dazukommen, deshalb ist der Stil ein Wert am
/// Board und keine feste Einstellung.
enum WandStil: String, Codable, CaseIterable, Identifiable {
    /// Honigfarbener Naturkork, mittlere Körnung.
    case korkNatur
    /// Dunkel gerösteter Kork, grobe Körnung, dunkle Schrauben.
    case korkDunkel
    /// Blasser Feinkork, fast sandfarben.
    case korkHell
    /// Alte Korktafel mit abblätternder weißer Farbe und Efeu.
    case korkVintage

    var id: String { rawValue }
    var label: String {
        switch self {
        case .korkNatur:   return "Natur"
        case .korkDunkel:  return "Dunkel"
        case .korkHell:    return "Hell"
        case .korkVintage: return "Vintage"
        }
    }
    /// Braucht dieser Belag helle Schrift?
    var dunkel: Bool { self == .korkDunkel }
}

/// Das Zeichen einer Wand auf dem Start — ein Zettel, ein Block, ein
/// Abzug. Genommen aus dem Aufkleber-Blatt: obere Reihe, zweiter Block.
enum WandSymbol: String, Codable, CaseIterable, Identifiable {
    case zettelGelb, zettelBlau, zettelRosa, notizblock, polaroid
    var id: String { rawValue }
    var label: String {
        switch self {
        case .zettelGelb:  return "Gelber Zettel"
        case .zettelBlau:  return "Blauer Zettel"
        case .zettelRosa:  return "Rosa Zettel"
        case .notizblock:  return "Notizblock"
        case .polaroid:    return "Abzug"
        }
    }
}

struct PinnBoard: Identifiable, Codable, Hashable {
    var id = UUID()
    var name: String = ""
    var artRaw: String = BoardArt.wand.rawValue
    var stilRaw: String = WandStil.korkNatur.rawValue
    var symbolRaw: String = WandSymbol.zettelGelb.rawValue
    /// Nur beim Schreibtisch: „links" oder „rechts".
    var seite: String = ""
    var reihenfolge: Int = 0
    /// Erledigte Vorhaben verschwinden aus dem Wähler, ohne etwas zu löschen.
    var archiviert: Bool = false
    var geaendertAm: Date = Date()

    var art: BoardArt { BoardArt(rawValue: artRaw) ?? .wand }
    var stil: WandStil { WandStil(rawValue: stilRaw) ?? .korkNatur }
    var symbol: WandSymbol { WandSymbol(rawValue: symbolRaw) ?? .zettelGelb }

    init(id: UUID = UUID(), name: String, art: BoardArt = .wand,
         stil: WandStil = .korkNatur, symbol: WandSymbol = .zettelGelb,
         seite: String = "", reihenfolge: Int = 0) {
        self.id = id; self.name = name; self.artRaw = art.rawValue
        self.stilRaw = stil.rawValue; self.symbolRaw = symbol.rawValue
        self.seite = seite; self.reihenfolge = reihenfolge
    }

    // Codable-Hausregel: alles einzeln und mit Vorgabe dekodieren
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id          = try c.decodeIfPresent(UUID.self,   forKey: .id)          ?? UUID()
        name        = try c.decodeIfPresent(String.self, forKey: .name)        ?? ""
        artRaw      = try c.decodeIfPresent(String.self, forKey: .artRaw)      ?? BoardArt.wand.rawValue
        stilRaw     = try c.decodeIfPresent(String.self, forKey: .stilRaw)     ?? WandStil.korkNatur.rawValue
        symbolRaw   = try c.decodeIfPresent(String.self, forKey: .symbolRaw)   ?? WandSymbol.zettelGelb.rawValue
        seite       = try c.decodeIfPresent(String.self, forKey: .seite)       ?? ""
        reihenfolge = try c.decodeIfPresent(Int.self,    forKey: .reihenfolge) ?? 0
        archiviert  = try c.decodeIfPresent(Bool.self,   forKey: .archiviert)  ?? false
        geaendertAm = try c.decodeIfPresent(Date.self,   forKey: .geaendertAm) ?? Date()
    }
}

extension PinnBoard: ZeitGestempelt {}

/// Die festen Wände. Ihre IDs sind auf ALLEN Geräten gleich — sonst legt
/// jedes Gerät bei der Migration seine eigene „Meine Wand" an und der
/// Sync führt zwei Wände zusammen, die dasselbe meinen.
enum SystemBoard {
    static let meineWand   = UUID(uuidString: "A2C40000-0000-4000-A000-000000000001")!
    static let ideen       = UUID(uuidString: "A2C40000-0000-4000-A000-000000000002")!
    static let tresor      = UUID(uuidString: "A2C40000-0000-4000-A000-000000000003")!
    static let pultLinks   = UUID(uuidString: "A2C40000-0000-4000-A000-000000000004")!
    static let pultRechts  = UUID(uuidString: "A2C40000-0000-4000-A000-000000000005")!

    static var vorgaben: [PinnBoard] {
        [PinnBoard(id: meineWand,  name: "Meine Wand",   art: .wand, stil: .korkNatur, symbol: .zettelGelb, reihenfolge: 0),
         PinnBoard(id: ideen,      name: "Ideen",        art: .wand, stil: .korkHell,  symbol: .zettelBlau, reihenfolge: 1),
         PinnBoard(id: tresor,     name: "Tresor",       art: .tresor,       reihenfolge: 90),
         PinnBoard(id: pultLinks,  name: "Pult links",   art: .schreibtisch, seite: "links",  reihenfolge: 91),
         PinnBoard(id: pultRechts, name: "Pult rechts",  art: .schreibtisch, seite: "rechts", reihenfolge: 92)]
    }
}

struct Anschlag: Identifiable, Codable, Hashable {
    var id = UUID()
    var boardID: UUID
    var kindRaw: String
    var refID: UUID
    /// Relativ zur Wandbreite bzw. -höhe (0…1).
    var x: Double = 0.5
    var y: Double = 0.5
    /// Grad — beim Anpinnen gewürfelt, damit es nach Papier aussieht.
    var drehung: Double = 0
    /// Hat der Nutzer den Zettel selbst hingehängt? Sonst wird er
    /// automatisch gestreut (und darf sich beim Nachrücken bewegen).
    var platziert: Bool = false
    /// „Fest ganz vorn" aus der alten Favoriten-Reihe. Übergangsweise:
    /// sobald die Wand die Reihe ersetzt, wird daraus schlicht die obere
    /// Reihe der Wand — und das Feld kann weg.
    var festVorn: Bool = false
    /// Farbiger Rand — vom Schreibtisch übernommen.
    var farbe: Int? = nil
    /// Eigener Name auf der Wand, falls überschrieben (Schreibtisch kann das).
    var titelUeberschrieben: String? = nil
    var geaendertAm: Date = Date()

    var kind: FavoriteKind { FavoriteKind(rawValue: kindRaw) ?? .note }

    init(id: UUID? = nil, boardID: UUID, kind: FavoriteKind, refID: UUID,
         x: Double = 0.5, y: Double = 0.5, drehung: Double = 0,
         platziert: Bool = false, festVorn: Bool = false, farbe: Int? = nil,
         titelUeberschrieben: String? = nil) {
        self.id = id ?? Anschlag.abgeleiteteID(board: boardID, kind: kind, ref: refID)
        self.boardID = boardID
        self.kindRaw = kind.rawValue
        self.refID = refID
        self.x = x; self.y = y; self.drehung = drehung
        self.platziert = platziert
        self.festVorn = festVorn
        self.farbe = farbe
        self.titelUeberschrieben = titelUeberschrieben
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id       = try c.decodeIfPresent(UUID.self,   forKey: .id)      ?? UUID()
        boardID  = try c.decodeIfPresent(UUID.self,   forKey: .boardID) ?? SystemBoard.meineWand
        kindRaw  = try c.decodeIfPresent(String.self, forKey: .kindRaw) ?? "note"
        refID    = try c.decode(UUID.self,            forKey: .refID)
        x        = try c.decodeIfPresent(Double.self, forKey: .x)       ?? 0.5
        y        = try c.decodeIfPresent(Double.self, forKey: .y)       ?? 0.5
        drehung  = try c.decodeIfPresent(Double.self, forKey: .drehung) ?? 0
        platziert = try c.decodeIfPresent(Bool.self,  forKey: .platziert) ?? false
        festVorn = try c.decodeIfPresent(Bool.self,   forKey: .festVorn)  ?? false
        farbe    = try c.decodeIfPresent(Int.self,    forKey: .farbe)
        titelUeberschrieben = try c.decodeIfPresent(String.self, forKey: .titelUeberschrieben)
        geaendertAm = try c.decodeIfPresent(Date.self, forKey: .geaendertAm) ?? Date()
    }

    /// Immer dieselbe ID für dieselbe Kombination (Wand, Art, Original).
    /// Wichtig für die Migration: iPhone und iPad rechnen unabhängig
    /// voneinander — und kommen auf denselben Anschlag statt auf zwei.
    static func abgeleiteteID(board: UUID, kind: FavoriteKind, ref: UUID) -> UUID {
        var b = withUnsafeBytes(of: board.uuid) { [UInt8]($0) }
        let r = withUnsafeBytes(of: ref.uuid)   { [UInt8]($0) }
        for i in 0..<16 { b[i] ^= r[i] }
        b[0] = b[0] &+ kindStempel(kind)
        return UUID(uuid: (b[0], b[1], b[2],  b[3],  b[4],  b[5],  b[6],  b[7],
                           b[8], b[9], b[10], b[11], b[12], b[13], b[14], b[15]))
    }

    private static func kindStempel(_ kind: FavoriteKind) -> UInt8 {
        switch kind {
        case .document: return 11
        case .note:     return 23
        case .list:     return 37
        case .vault:    return 53
        }
    }
}

extension Anschlag: ZeitGestempelt {}
