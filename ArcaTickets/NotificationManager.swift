//
//  NotificationManager.swift
//  ArcaTickets
//
//  Entwickler: Hans zen Ruffinen
//

import Foundation
import UserNotifications

enum NotificationManager {
    private static let standardReminderDays = 1
    private static let longTermReminderDays = 30

    private static let aboKeywords = [
        "halbtax", "halb tax", "ga ", " ga", "generalabonnement", "general-abo",
        "öv-abo", "oev-abo", "abo", "vignette", "fitness", "museumspass",
        "museums-pass", "swiss pass", "swisspass"
    ]

    private static let seasonKeywords = [
        "saisonkarte", "saison", "jahreskarte", "jahrespass", "jahres-skipass",
        "jahresskipass", "winterpass", "sommerpass"
    ]

    static func requestAuthorizationIfNeeded() {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            guard settings.authorizationStatus == .notDetermined else { return }
            UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { _, _ in }
        }
    }

    static func reminderDaysBefore(for ticket: TicketEntry) -> Int {
        if ticket.folder == "Abos" || matchesAboKeywords(ticket.title) {
            return longTermReminderDays
        }
        if ticket.folder == "Berge", matchesSeasonKeywords(ticket.title) {
            return longTermReminderDays
        }
        return standardReminderDays
    }

    static func rescheduleAll(for tickets: [TicketEntry]) {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            guard settings.authorizationStatus == .authorized else { return }
            let center = UNUserNotificationCenter.current()
            center.getPendingNotificationRequests { requests in
                let ticketIDs = Set(tickets.map(\.id.uuidString))
                let stale = requests
                    .map(\.identifier)
                    .filter { id in
                        ticketIDs.contains(id) == false && id.hasPrefix("expiry-")
                    }
                center.removePendingNotificationRequests(withIdentifiers: stale)

                for ticket in tickets where !ticket.isArchived {
                    scheduleReminder(for: ticket)
                }
            }
        }
    }

    private static func scheduleReminder(for ticket: TicketEntry) {
        guard let expiry = ticket.expiryDate, expiry > Date() else { return }
        let daysBefore = reminderDaysBefore(for: ticket)
        guard let fireDate = Calendar.current.date(
            byAdding: .day,
            value: -daysBefore,
            to: expiry
        ), fireDate > Date() else { return }

        let content = UNMutableNotificationContent()
        content.title = daysBefore > 1 ? "Abo lauft bald ab" : "Ticket lauft bald ab"
        if daysBefore > 1 {
            content.body = "\(ticket.title) lauft in 30 Tag ab — rächtziitig erneuere."
        } else {
            content.body = "\(ticket.title) lauft morn ab — rächtziitig zeige oder erneuere."
        }
        content.sound = .default

        let components = Calendar.current.dateComponents(
            [.year, .month, .day, .hour, .minute],
            from: fireDate
        )
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        let request = UNNotificationRequest(
            identifier: "expiry-\(ticket.id.uuidString)",
            content: content,
            trigger: trigger
        )
        UNUserNotificationCenter.current().add(request)
    }

    static func removeReminder(for ticket: TicketEntry) {
        UNUserNotificationCenter.current().removePendingNotificationRequests(
            withIdentifiers: ["expiry-\(ticket.id.uuidString)"]
        )
    }

    private static func matchesAboKeywords(_ title: String) -> Bool {
        let normalized = title.lowercased()
        return aboKeywords.contains { normalized.contains($0) }
    }

    private static func matchesSeasonKeywords(_ title: String) -> Bool {
        let normalized = title.lowercased()
        return seasonKeywords.contains { normalized.contains($0) }
    }
}
