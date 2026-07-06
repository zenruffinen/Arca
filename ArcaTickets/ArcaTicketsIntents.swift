//
//  ArcaTicketsIntents.swift
//  ArcaTickets
//
//  Entwickler: Hans zen Ruffinen
//

import AppIntents

// MARK: - In-process intent delivery

extension Notification.Name {
    static let arcaHolidayNavigate = Notification.Name("com.hansruffin.ArcaTickets.navigate")
}

enum ArcaHolidayIntentNavigation {
    static let appGroup = "group.com.hansruffin.ArcaTickets"
    static let navigationKey = "intentNavigation"

    static func post(_ destination: String) {
        UserDefaults(suiteName: appGroup)?.set(destination, forKey: navigationKey)
        NotificationCenter.default.post(name: .arcaHolidayNavigate, object: destination)
    }

    @MainActor
    static func consumePending() -> String? {
        guard let defaults = UserDefaults(suiteName: appGroup),
              let destination = defaults.string(forKey: navigationKey) else { return nil }
        defaults.removeObject(forKey: navigationKey)
        return destination
    }
}

// MARK: - Siri Shortcuts

struct OpenArcaHolidayIntent: AppIntent {
    static var title: LocalizedStringResource = "Arca Holiday öffnen"
    static var description = IntentDescription("Öffnet Arca Holiday auf dem Ferien-Hero")
    static var openAppWhenRun: Bool = true

    @MainActor
    func perform() async throws -> some IntentResult {
        ArcaHolidayIntentNavigation.post("open")
        return .result()
    }
}

struct ShowNextTicketIntent: AppIntent {
    static var title: LocalizedStringResource = "Nächstes Ticket zeigen"
    static var description = IntentDescription("Öffnet d'Boarding Card mit dim nächste Ticket")
    static var openAppWhenRun: Bool = true

    @MainActor
    func perform() async throws -> some IntentResult {
        ArcaHolidayIntentNavigation.post("boarding")
        return .result()
    }
}

struct ArcaHolidayShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: OpenArcaHolidayIntent(),
            phrases: [
                "Öffne \(.applicationName)",
                "\(.applicationName) öffnen",
                "Zeig \(.applicationName)"
            ],
            shortTitle: "Arca Holiday",
            systemImageName: "airplane.departure"
        )
        AppShortcut(
            intent: ShowNextTicketIntent(),
            phrases: [
                "Zeig nächstes Ticket in \(.applicationName)",
                "Nächstes Ticket in \(.applicationName)",
                "\(.applicationName) Boarding Card"
            ],
            shortTitle: "Nächstes Ticket",
            systemImageName: "ticket.fill"
        )
    }
}

// MARK: - Nächste Schritte (iOS 27+)
//
// Wallet: PKPassLibrary + PassKit — Boarding-PDF als PKPass exportieren
//   (nur wenn Airline-Pass verfügbar; sonst QR-Fullscreen beibehalten).
