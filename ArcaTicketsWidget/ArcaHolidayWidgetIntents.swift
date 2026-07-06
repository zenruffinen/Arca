//
//  ArcaHolidayWidgetIntents.swift
//  ArcaTicketsWidget
//
//  Entwickler: Hans zen Ruffinen
//

import AppIntents

private enum WidgetIntentBridge {
    static let appGroup = "group.com.hansruffin.ArcaTickets"
    static let navigationKey = "intentNavigation"

    static func open(_ destination: String) {
        UserDefaults(suiteName: appGroup)?.set(destination, forKey: navigationKey)
    }
}

struct WidgetOpenArcaHolidayIntent: AppIntent {
    static var title: LocalizedStringResource = "Arca Holiday öffnen"
    static var openAppWhenRun: Bool = true

    func perform() async throws -> some IntentResult {
        WidgetIntentBridge.open("open")
        return .result()
    }
}

struct WidgetShowNextTicketIntent: AppIntent {
    static var title: LocalizedStringResource = "Nächstes Ticket zeigen"
    static var openAppWhenRun: Bool = true

    func perform() async throws -> some IntentResult {
        WidgetIntentBridge.open("boarding")
        return .result()
    }
}
