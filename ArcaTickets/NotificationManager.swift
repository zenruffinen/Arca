//
//  NotificationManager.swift
//  ArcaTickets
//
//  Entwickler: Hans zen Ruffinen
//

import Foundation
import UserNotifications

enum NotificationManager {
    private static let reminderDaysBefore = 1

    static func requestAuthorizationIfNeeded() {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            guard settings.authorizationStatus == .notDetermined else { return }
            UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { _, _ in }
        }
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

                for ticket in tickets {
                    scheduleReminder(for: ticket)
                }
            }
        }
    }

    private static func scheduleReminder(for ticket: TicketEntry) {
        guard let expiry = ticket.expiryDate, expiry > Date() else { return }
        guard let fireDate = Calendar.current.date(
            byAdding: .day,
            value: -reminderDaysBefore,
            to: expiry
        ), fireDate > Date() else { return }

        let content = UNMutableNotificationContent()
        content.title = "Ticket läuft bald ab"
        content.body = "\(ticket.title) läuft morgen ab — rechtzeitig vorzeigen oder erneuern."
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
}
