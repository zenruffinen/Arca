//
//  Models.swift
//  ArcaTickets
//
//  Entwickler: Hans zen Ruffinen
//

import Foundation

extension Notification.Name {
    static let arcaTicketsTabOrderDidChange = Notification.Name("arcaTicketsTabOrderDidChange")
}

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
    var flightNumber: String?
    var seatNumber: String?
    var boardingTime: Date?
    var gate: String?
    var isPinned: Bool

    init(id: UUID = UUID(),
         title: String,
         folder: String,
         expiryDate: Date? = nil,
         fileName: String,
         createdAt: Date = Date(),
         notes: String? = nil,
         isArchived: Bool = false,
         remainingUses: Int? = nil,
         totalUses: Int? = nil,
         flightNumber: String? = nil,
         seatNumber: String? = nil,
         boardingTime: Date? = nil,
         gate: String? = nil,
         isPinned: Bool = false) {
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
        self.flightNumber = flightNumber
        self.seatNumber = seatNumber
        self.boardingTime = boardingTime
        self.gate = gate
        self.isPinned = isPinned
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
        flightNumber = try c.decodeIfPresent(String.self, forKey: .flightNumber)
        seatNumber = try c.decodeIfPresent(String.self, forKey: .seatNumber)
        boardingTime = try c.decodeIfPresent(Date.self, forKey: .boardingTime)
        gate = try c.decodeIfPresent(String.self, forKey: .gate)
        isPinned = try c.decodeIfPresent(Bool.self, forKey: .isPinned) ?? false
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

    var boardingTimeText: String? {
        guard let boardingTime else { return nil }
        return boardingTime.formatted(date: .omitted, time: .shortened)
    }

    var hasTravelDetails: Bool {
        !(flightNumber?.isEmpty ?? true)
            || !(seatNumber?.isEmpty ?? true)
            || boardingTime != nil
            || !(gate?.isEmpty ?? true)
    }

    /// Wichtige Tickets brauchen eine Lösch-Bestätigung.
    var needsDeleteConfirmation: Bool {
        isPinned || hasTravelDetails || expiryDate != nil || remainingUses != nil
    }

    var unterwegsSortDate: Date {
        boardingTime ?? expiryDate ?? createdAt
    }
}

enum InsuranceType: String, Codable, CaseIterable, Identifiable {
    case reiseversicherung = "Reiseversicherung"
    case auslandskrankenversicherung = "Auslandskrankenversicherung"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .reiseversicherung: return "suitcase.fill"
        case .auslandskrankenversicherung: return "cross.case.fill"
        }
    }
}

enum QuickContactCategory: String, Codable, CaseIterable, Identifiable {
    case notfall = "Notfall"
    case flug = "Flug"
    case hotel = "Hotel"
    case event = "Event"
    case familie = "Familie"
    case versicherung = "Versicherung"
    case sonstiges = "Sonstiges"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .notfall: return "exclamationmark.triangle.fill"
        case .flug: return "airplane"
        case .hotel: return "bed.double.fill"
        case .event: return "ticket.fill"
        case .familie: return "person.2.fill"
        case .versicherung: return "shield.lefthalf.filled"
        case .sonstiges: return "phone.fill"
        }
    }

    var tintName: String {
        switch self {
        case .notfall: return "orange"
        case .flug: return "blue"
        case .hotel: return "indigo"
        case .event: return "purple"
        case .familie: return "teal"
        case .versicherung: return "green"
        case .sonstiges: return "gray"
        }
    }

    var displayOrder: Int {
        switch self {
        case .notfall: return 0
        case .flug: return 1
        case .hotel: return 2
        case .event: return 3
        case .familie: return 4
        case .versicherung: return 5
        case .sonstiges: return 6
        }
    }
}

struct QuickContact: Identifiable, Codable, Hashable {
    var id: UUID
    var label: String
    var phoneNumber: String
    var category: QuickContactCategory
    var sortOrder: Int
    var policyNumber: String?
    var insuranceType: InsuranceType?
    var linkedContactID: UUID?

    init(id: UUID = UUID(),
         label: String,
         phoneNumber: String,
         category: QuickContactCategory,
         sortOrder: Int = 0,
         policyNumber: String? = nil,
         insuranceType: InsuranceType? = nil,
         linkedContactID: UUID? = nil) {
        self.id = id
        self.label = label
        self.phoneNumber = phoneNumber
        self.category = category
        self.sortOrder = sortOrder
        self.policyNumber = policyNumber
        self.insuranceType = insuranceType
        self.linkedContactID = linkedContactID
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        label = try c.decode(String.self, forKey: .label)
        phoneNumber = try c.decode(String.self, forKey: .phoneNumber)
        category = try c.decode(QuickContactCategory.self, forKey: .category)
        sortOrder = try c.decodeIfPresent(Int.self, forKey: .sortOrder) ?? 0
        policyNumber = try c.decodeIfPresent(String.self, forKey: .policyNumber)
        insuranceType = try c.decodeIfPresent(InsuranceType.self, forKey: .insuranceType)
        linkedContactID = try c.decodeIfPresent(UUID.self, forKey: .linkedContactID)
    }

    var hasPhoneNumber: Bool {
        !phoneNumber.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var hasPolicyNumber: Bool {
        !(policyNumber?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true)
    }

    var telURL: URL? {
        let cleaned = phoneNumber.filter { $0.isNumber || $0 == "+" }
        guard !cleaned.isEmpty else { return nil }
        return URL(string: "tel://\(cleaned)")
    }

    var displayPhoneNumber: String {
        let trimmed = phoneNumber.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "Nummer eintragen" : trimmed
    }

    var displayPolicyNumber: String? {
        guard let policy = policyNumber?.trimmingCharacters(in: .whitespacesAndNewlines),
              !policy.isEmpty else { return nil }
        return policy
    }

    var insuranceSubtitle: String? {
        guard hasPolicyNumber, let policy = displayPolicyNumber else { return nil }
        return "Polizzen-Nr.: \(policy) — antippen zum Anrufen"
    }
}

struct PersonalIDCard: Codable, Hashable {
    var name: String
    var passportNumber: String
    var ahvNumber: String
    var nationality: String?
    var birthDate: Date?
    var bloodType: String?

    static let empty = PersonalIDCard(
        name: "",
        passportNumber: "",
        ahvNumber: ""
    )

    var isConfigured: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            || !passportNumber.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            || !ahvNumber.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var displayName: String {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "Deine Visitenkarte" : trimmed
    }
}

struct SwissEmergencyNumber: Identifiable {
    let id: String
    let label: String
    let number: String
    let icon: String

    var telURL: URL? {
        URL(string: "tel://\(number)")
    }
}

enum SwissEmergencyDefaults {
    static let numbers: [SwissEmergencyNumber] = [
        SwissEmergencyNumber(id: "police", label: "Polizei", number: "117", icon: "shield.fill"),
        SwissEmergencyNumber(id: "rescue", label: "Rettung", number: "144", icon: "cross.case.fill"),
        SwissEmergencyNumber(id: "eu", label: "EU-Notruf", number: "112", icon: "phone.circle.fill"),
    ]
}

struct QuickContactTemplate: Identifiable {
    let label: String
    let phoneNumber: String
    let category: QuickContactCategory

    var id: String { label }
}

enum QuickContactDefaults {
    static let templates: [QuickContactTemplate] = [
        QuickContactTemplate(label: "Polizei", phoneNumber: "117", category: .notfall),
        QuickContactTemplate(label: "Feuerwehr", phoneNumber: "118", category: .notfall),
        QuickContactTemplate(label: "Rettung", phoneNumber: "144", category: .notfall),
        QuickContactTemplate(label: "EU-Notruf", phoneNumber: "112", category: .notfall),
        QuickContactTemplate(label: "Fluggesellschaft", phoneNumber: "", category: .flug),
        QuickContactTemplate(label: "Veranstalter", phoneNumber: "", category: .event),
        QuickContactTemplate(label: "Reiseunternehmen", phoneNumber: "", category: .sonstiges),
        QuickContactTemplate(label: "Reisebüro", phoneNumber: "", category: .sonstiges),
        QuickContactTemplate(label: "Hotel", phoneNumber: "", category: .hotel),
        QuickContactTemplate(label: "Reiseversicherung", phoneNumber: "", category: .versicherung),
        QuickContactTemplate(label: "Auslandskrankenversicherung", phoneNumber: "", category: .versicherung),
        QuickContactTemplate(label: "Mutter", phoneNumber: "", category: .familie),
        QuickContactTemplate(label: "Vater", phoneNumber: "", category: .familie),
        QuickContactTemplate(label: "Anwalt", phoneNumber: "", category: .sonstiges),
    ]

    static func seedContacts() -> [QuickContact] {
        templates.enumerated().map { index, template in
            let insuranceType: InsuranceType? = {
                guard template.category == .versicherung else { return nil }
                switch template.label {
                case "Reiseversicherung": return .reiseversicherung
                case "Auslandskrankenversicherung": return .auslandskrankenversicherung
                default: return nil
                }
            }()
            return QuickContact(
                label: template.label,
                phoneNumber: template.phoneNumber,
                category: template.category,
                sortOrder: index,
                insuranceType: insuranceType
            )
        }
    }
}

enum ArcaTicketsTab: String, CaseIterable, Identifiable, Hashable {
    case unterwegs
    case alleTickets
    case notfall
    case settings

    static let reorderableCases: [ArcaTicketsTab] = [.unterwegs, .alleTickets, .notfall]

    var id: String { rawValue }

    var label: String {
        switch self {
        case .unterwegs: return "Unterwegs"
        case .alleTickets: return "Alle Tickets"
        case .notfall: return "Notfall"
        case .settings: return "Einstellungen"
        }
    }

    var title: String { label }

    var icon: String {
        switch self {
        case .unterwegs: return "airplane.departure"
        case .alleTickets: return "ticket.fill"
        case .notfall: return "phone.circle.fill"
        case .settings: return "gearshape.fill"
        }
    }
}

enum TabOrderPreferences {
    private static let orderKey = "arcaTicketsTabOrder"
    private static let leadTabKey = "arcaTicketsLeadTab"

    enum LeadTab: String, CaseIterable, Identifiable {
        case unterwegsFirst = "unterwegs"
        case alleTicketsFirst = "alleTickets"

        var id: String { rawValue }

        var label: String {
            switch self {
            case .unterwegsFirst: return "Unterwegs zuerst"
            case .alleTicketsFirst: return "Alle Tickets zuerst"
            }
        }
    }

    static var leadTab: LeadTab {
        get {
            guard let raw = UserDefaults.standard.string(forKey: leadTabKey),
                  let value = LeadTab(rawValue: raw) else { return .unterwegsFirst }
            return value
        }
        set {
            UserDefaults.standard.set(newValue.rawValue, forKey: leadTabKey)
        }
    }

    static func loadReorderable() -> [ArcaTicketsTab] {
        if let raw = UserDefaults.standard.stringArray(forKey: orderKey),
           !raw.isEmpty {
            let tabs = raw.compactMap(ArcaTicketsTab.init(rawValue:))
            if Set(tabs) == Set(ArcaTicketsTab.reorderableCases) {
                return tabs
            }
        }
        return orderFromLeadTab(leadTab)
    }

    static func save(_ order: [ArcaTicketsTab]) {
        let reorderable = order.filter { ArcaTicketsTab.reorderableCases.contains($0) }
        guard Set(reorderable) == Set(ArcaTicketsTab.reorderableCases) else { return }
        UserDefaults.standard.set(reorderable.map(\.rawValue), forKey: orderKey)
        if let first = reorderable.first {
            leadTab = first == .alleTickets ? .alleTicketsFirst : .unterwegsFirst
        }
        NotificationCenter.default.post(name: .arcaTicketsTabOrderDidChange, object: nil)
    }

    static func setLeadTab(_ tab: LeadTab) {
        leadTab = tab
        save(orderFromLeadTab(tab))
    }

    static var reorderableTabOrder: [ArcaTicketsTab] { loadReorderable() }

    static var tabOrder: [ArcaTicketsTab] { loadReorderable() + [.settings] }

    static var defaultTab: ArcaTicketsTab {
        loadReorderable().first ?? .unterwegs
    }

    private static func orderFromLeadTab(_ lead: LeadTab) -> [ArcaTicketsTab] {
        switch lead {
        case .unterwegsFirst:
            return [.unterwegs, .alleTickets, .notfall]
        case .alleTicketsFirst:
            return [.alleTickets, .unterwegs, .notfall]
        }
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
            if name.hasSuffix(TicketStore.sharedFolderSuffix) {
                return TicketFolderStyle(icon: "person.2.fill", tintName: "teal")
            }
            return TicketFolderStyle(icon: "folder.fill", tintName: "gray")
        }
    }

    static func style(for name: String, isShared: Bool) -> TicketFolderStyle {
        if isShared {
            return TicketFolderStyle(icon: "person.2.fill", tintName: "teal")
        }
        return style(for: name)
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
