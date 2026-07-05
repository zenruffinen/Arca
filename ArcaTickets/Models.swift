//
//  Models.swift
//  ArcaTickets
//
//  Entwickler: Hans zen Ruffinen
//

import Foundation

enum TicketExpiryFilter: String, CaseIterable, Identifiable {
    case active = "Aktiv"
    case expired = "Abgelaufen"
    case all = "Alle"

    var id: String { rawValue }
}

enum TicketFileKind: String, Codable {
    case image
    case pdf
}

struct TicketEntry: Identifiable, Codable, Hashable {
    var id: UUID
    var title: String
    var folder: String
    var expiryDate: Date?
    var fileName: String
    var createdAt: Date
    var notes: String?
    var isArchived: Bool
    var remainingUses: Int?
    var totalUses: Int?

    init(id: UUID = UUID(),
         title: String,
         folder: String,
         expiryDate: Date? = nil,
         fileName: String,
         createdAt: Date = Date(),
         notes: String? = nil,
         isArchived: Bool = false,
         remainingUses: Int? = nil,
         totalUses: Int? = nil) {
        self.id = id
        self.title = title
        self.folder = folder
        self.expiryDate = expiryDate
        self.fileName = fileName
        self.createdAt = createdAt
        self.notes = notes
        self.isArchived = isArchived
        self.remainingUses = remainingUses
        self.totalUses = totalUses
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        title = try c.decode(String.self, forKey: .title)
        folder = try c.decode(String.self, forKey: .folder)
        expiryDate = try c.decodeIfPresent(Date.self, forKey: .expiryDate)
        fileName = try c.decode(String.self, forKey: .fileName)
        createdAt = try c.decode(Date.self, forKey: .createdAt)
        notes = try c.decodeIfPresent(String.self, forKey: .notes)
        isArchived = try c.decodeIfPresent(Bool.self, forKey: .isArchived) ?? false
        remainingUses = try c.decodeIfPresent(Int.self, forKey: .remainingUses)
        totalUses = try c.decodeIfPresent(Int.self, forKey: .totalUses)
    }

    var fileKind: TicketFileKind {
        let ext = (fileName as NSString).pathExtension.lowercased()
        return ext == "pdf" ? .pdf : .image
    }

    var isExpired: Bool {
        guard let expiryDate else { return false }
        return expiryDate < Date()
    }

    var isValid: Bool {
        guard !isArchived else { return false }
        guard let expiryDate else { return true }
        return expiryDate >= Date()
    }

    var daysUntilExpiry: Int? {
        guard let expiryDate, !isExpired else { return nil }
        let start = Calendar.current.startOfDay(for: Date())
        let end = Calendar.current.startOfDay(for: expiryDate)
        return Calendar.current.dateComponents([.day], from: start, to: end).day
    }

    var expiryCountdownText: String? {
        guard let days = daysUntilExpiry else { return nil }
        switch days {
        case 0: return "Läuft heute ab"
        case 1: return "Noch 1 Tag gültig"
        default: return "Noch \(days) Tage gültig"
        }
    }

    var usesCountdownText: String? {
        guard let remaining = remainingUses else { return nil }
        if let total = totalUses {
            return "Noch \(remaining) von \(total) Eintritten"
        }
        return "Noch \(remaining) Eintritte"
    }
}

struct TicketFolderStyle {
    let icon: String
    let tintName: String

    static func style(for name: String) -> TicketFolderStyle {
        switch name {
        case "Bahn":
            return TicketFolderStyle(icon: "train.side.front.car", tintName: "blue")
        case "Abos":
            return TicketFolderStyle(icon: "creditcard.fill", tintName: "indigo")
        case "Berge":
            return TicketFolderStyle(icon: "mountain.2.fill", tintName: "orange")
        case "Sonstiges":
            return TicketFolderStyle(icon: "ticket.fill", tintName: "gray")
        case "ÖV":
            return TicketFolderStyle(icon: "bus.fill", tintName: "teal")
        case "Events":
            return TicketFolderStyle(icon: "ticket.fill", tintName: "purple")
        case "Parken":
            return TicketFolderStyle(icon: "parkingsign.circle.fill", tintName: "orange")
        default:
            return TicketFolderStyle(icon: "folder.fill", tintName: "gray")
        }
    }

    static func emptyStateMessage(for name: String) -> (title: String, description: String, examples: [String]) {
        switch name {
        case "Bahn":
            return (
                "Noch keine Zugtickets",
                "Speichere SBB-Fahrkarten hier — per Foto, PDF oder Teilen aus der SBB-App.",
                ["Einzelbillette", "Sparbillette", "Tageskarten"]
            )
        case "Abos":
            return (
                "Noch keine Abos",
                "Jahres- und Monatsabos mit längerer Laufzeit — wir erinnern dich 30 Tage vor Ablauf.",
                ["Halbtax", "GA", "ÖV-Abo", "Fitness", "Vignette"]
            )
        case "Berge":
            return (
                "Noch keine Bergtickets",
                "Skipässe und Bergbahnen — Saisonkarten erinnern wir 30 Tage vor Ablauf.",
                ["Skipass", "Saisonkarte", "Skitageskarte", "Bergbahn"]
            )
        case "Sonstiges":
            return (
                "Noch nichts hier",
                "Alles, was in keine andere Kategorie passt — oder eigene Ordner unter Einstellungen.",
                ["Parktickets", "Events", "Mehrfachkarten", "Boarding Pass", "MFK"]
            )
        case "ÖV":
            return (
                "ÖV-Tickets fehlen noch",
                "Bus, Tram und Metro: Importiere dein Ticket und zeig den QR-Code am Schalter.",
                ["Bus", "Tram", "Metro"]
            )
        case "Events":
            return (
                "Keine Event-Tickets",
                "Konzert, Sport oder Festival — lege dein Ticket ab, bevor du losgehst.",
                ["Konzert", "Sport", "Festival"]
            )
        case "Parken":
            return (
                "Keine Parktickets",
                "Parkschein oder Parkhaus-Ticket? Hier landet alles für die Ausfahrt.",
                ["Parkschein", "Parkhaus"]
            )
        default:
            return (
                "Ordner ist leer",
                "Füge ein Ticket hinzu — per Kamera, Galerie, PDF oder Teilen aus einer anderen App.",
                []
            )
        }
    }
}
