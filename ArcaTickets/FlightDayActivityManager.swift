//
//  FlightDayActivityManager.swift
//  ArcaTickets
//
//  Entwickler: Hans zen Ruffinen
//

import ActivityKit
import Foundation

// MARK: - Attributes (must match ArcaTicketsWidget/FlightDayLiveActivity.swift)

struct FlightDayAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        var flightLine: String
        var gateLine: String
        var baggageLine: String
        var boardingHint: String
    }

    var ticketID: String
    var flightTitle: String
}

// MARK: - Manager

@MainActor
enum FlightDayActivityManager {
    static func sync(with ticket: TicketEntry?) {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }

        if let ticket {
            startOrUpdate(ticket)
        } else {
            endAll()
        }
    }

    static func endAll() {
        Task {
            for activity in Activity<FlightDayAttributes>.activities {
                await activity.end(nil, dismissalPolicy: .immediate)
            }
        }
    }

    private static func startOrUpdate(_ ticket: TicketEntry) {
        let state = contentState(for: ticket)
        let attributes = FlightDayAttributes(
            ticketID: ticket.id.uuidString,
            flightTitle: ticket.title
        )

        if let existing = Activity<FlightDayAttributes>.activities.first {
            Task {
                await existing.update(ActivityContent(state: state, staleDate: staleDate(for: ticket)))
            }
            return
        }

        Task {
            let content = ActivityContent(state: state, staleDate: staleDate(for: ticket))
            _ = try? Activity.request(
                attributes: attributes,
                content: content,
                pushType: nil
            )
        }
    }

    private static func contentState(for ticket: TicketEntry) -> FlightDayAttributes.ContentState {
        FlightDayAttributes.ContentState(
            flightLine: ticket.flightTodayLine,
            gateLine: ticket.gateLine,
            baggageLine: ticket.baggageLine,
            boardingHint: "🛂 Boarding Card"
        )
    }

    private static func staleDate(for ticket: TicketEntry) -> Date? {
        guard let boarding = ticket.boardingTime else { return nil }
        return Calendar.current.date(byAdding: .hour, value: 6, to: boarding)
    }
}

// MARK: - Display lines (shared with hero chip)

extension TicketEntry {
    var flightTodayLine: String {
        if let boarding = boardingTime {
            let time = boarding.formatted(date: .omitted, time: .shortened)
            if Calendar.current.isDateInToday(boarding) {
                return "✈️ Flug hüt \(time)"
            }
            return "✈️ Flug \(time)"
        }
        if let flight = flightNumber, !flight.isEmpty {
            return "✈️ Flug \(flight)"
        }
        return "✈️ Flug hüt"
    }

    var gateLine: String {
        if let gate, !gate.isEmpty {
            return "📍 Gate \(gate)"
        }
        return "📍 Gate —"
    }

    var baggageLine: String {
        if let belt = baggageBelt, !belt.isEmpty {
            return "🧳 Gepäckband \(belt)"
        }
        return "🧳 Gepäckband —"
    }

    var isFlightToday: Bool {
        guard isValid, let boarding = boardingTime else { return false }
        return Calendar.current.isDateInToday(boarding)
    }
}
