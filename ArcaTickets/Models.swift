//
//  Models.swift
//  ArcaTickets
//
//  Entwickler: Hans zen Ruffinen
//

import Foundation

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

    init(id: UUID = UUID(),
         title: String,
         folder: String,
         expiryDate: Date? = nil,
         fileName: String,
         createdAt: Date = Date(),
         notes: String? = nil) {
        self.id = id
        self.title = title
        self.folder = folder
        self.expiryDate = expiryDate
        self.fileName = fileName
        self.createdAt = createdAt
        self.notes = notes
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
}

struct TicketFolderStyle {
    let icon: String
    let tintName: String

    static func style(for name: String) -> TicketFolderStyle {
        switch name {
        case "Bahn":
            return TicketFolderStyle(icon: "tram.fill", tintName: "blue")
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
}
