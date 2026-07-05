//
//  WidgetDataUpdater.swift
//  ArcaTickets
//
//  Entwickler: Hans zen Ruffinen
//

import Foundation
import WidgetKit

enum WidgetDataUpdater {
    static let appGroupID = "group.com.hansruffin.ArcaTickets"

    static func update(from tickets: [TicketEntry]) {
        let defaults = UserDefaults(suiteName: appGroupID)
        let next = nextValidTicket(from: tickets)

        if let ticket = next {
            defaults?.set(ticket.title, forKey: "widget_ticketTitle")
            defaults?.set(ticket.folder, forKey: "widget_ticketFolder")
            defaults?.set(ticket.expiryCountdownText ?? "Gültig", forKey: "widget_countdown")
            defaults?.set(ticket.id.uuidString, forKey: "widget_ticketID")
            defaults?.set(ticket.fileKind == .image, forKey: "widget_hasQR")
        } else {
            defaults?.removeObject(forKey: "widget_ticketTitle")
            defaults?.removeObject(forKey: "widget_ticketFolder")
            defaults?.removeObject(forKey: "widget_countdown")
            defaults?.removeObject(forKey: "widget_ticketID")
            defaults?.set(false, forKey: "widget_hasQR")
        }

        WidgetCenter.shared.reloadAllTimelines()
    }

    private static func nextValidTicket(from tickets: [TicketEntry]) -> TicketEntry? {
        let valid = tickets.filter(\.isValid)
        let withExpiry = valid
            .filter { $0.expiryDate != nil }
            .sorted { ($0.expiryDate ?? .distantFuture) < ($1.expiryDate ?? .distantFuture) }
        if let soonest = withExpiry.first { return soonest }
        return valid.max(by: { $0.createdAt < $1.createdAt })
    }
}
