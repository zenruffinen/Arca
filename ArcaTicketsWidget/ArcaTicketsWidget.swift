//
//  ArcaTicketsWidget.swift
//  ArcaTicketsWidget
//
//  Entwickler: Hans zen Ruffinen
//

import WidgetKit
import SwiftUI
import AppIntents

// MARK: - Data

struct ArcaTicketsWidgetData {
    let title: String?
    let folder: String?
    let countdown: String?
    let ticketID: String?
    let hasQR: Bool

    var hasTicket: Bool { title != nil }

    static func load() -> ArcaTicketsWidgetData {
        let d = UserDefaults(suiteName: "group.com.hansruffin.ArcaTickets")
        return ArcaTicketsWidgetData(
            title: d?.string(forKey: "widget_ticketTitle"),
            folder: d?.string(forKey: "widget_ticketFolder"),
            countdown: d?.string(forKey: "widget_countdown"),
            ticketID: d?.string(forKey: "widget_ticketID"),
            hasQR: d?.bool(forKey: "widget_hasQR") ?? false
        )
    }

    static let placeholder = ArcaTicketsWidgetData(
        title: "Zürich–Bern",
        folder: "Bahn",
        countdown: "Noch 2 Tage gültig",
        ticketID: nil,
        hasQR: true
    )
}

// MARK: - Timeline

struct ArcaTicketsEntry: TimelineEntry {
    let date: Date
    let data: ArcaTicketsWidgetData
}

struct ArcaTicketsProvider: TimelineProvider {
    func placeholder(in context: Context) -> ArcaTicketsEntry {
        ArcaTicketsEntry(date: .now, data: .placeholder)
    }

    func getSnapshot(in context: Context, completion: @escaping (ArcaTicketsEntry) -> Void) {
        completion(ArcaTicketsEntry(date: .now, data: .load()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<ArcaTicketsEntry>) -> Void) {
        let entry = ArcaTicketsEntry(date: .now, data: .load())
        let next = Calendar.current.date(byAdding: .hour, value: 1, to: .now)!
        completion(Timeline(entries: [entry], policy: .after(next)))
    }
}

// MARK: - Views

struct ArcaTicketsSmallView: View {
    let data: ArcaTicketsWidgetData

    var body: some View {
        if data.hasTicket, let title = data.title {
            ticketContent(title: title)
        } else {
            emptyContent
        }
    }

    private func ticketContent(title: String) -> some View {
        Button(intent: WidgetShowNextTicketIntent()) {
            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: 5) {
                    Image(systemName: "airplane.departure")
                        .foregroundStyle(Color(red: 0.20, green: 0.85, blue: 0.95))
                    Text("Arca Holiday")
                        .font(.caption.weight(.bold))
                }
                Spacer(minLength: 6)
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(2)
                if let folder = data.folder {
                    Text(folder)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: 4)
                HStack {
                    if let countdown = data.countdown {
                        Text(countdown)
                            .font(.caption2.weight(.medium))
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    if data.hasQR {
                        Image(systemName: "qrcode")
                            .font(.caption)
                            .foregroundStyle(Color(red: 0.10, green: 0.38, blue: 0.72))
                    }
                }
            }
            .padding()
        }
        .buttonStyle(.plain)
        .containerBackground(.fill.tertiary, for: .widget)
    }

    private var emptyContent: some View {
        Button(intent: WidgetOpenArcaHolidayIntent()) {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 5) {
                    Image(systemName: "airplane.departure")
                        .foregroundStyle(Color(red: 0.20, green: 0.85, blue: 0.95))
                    Text("Arca Holiday")
                        .font(.caption.weight(.bold))
                }
                Spacer()
                Text("Kei Ticket")
                    .font(.subheadline.weight(.semibold))
                Text("Tipp zum Öffne")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Spacer()
            }
            .padding()
        }
        .buttonStyle(.plain)
        .containerBackground(.fill.tertiary, for: .widget)
    }
}

struct ArcaTicketsMediumView: View {
    let data: ArcaTicketsWidgetData

    var body: some View {
        if data.hasTicket, let title = data.title {
            Button(intent: WidgetShowNextTicketIntent()) {
                HStack(spacing: 14) {
                    VStack(alignment: .leading, spacing: 6) {
                        Label("Nächsts Ticket", systemImage: "star.fill")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(Color(red: 0.10, green: 0.38, blue: 0.72))
                        Text(title)
                            .font(.headline)
                            .lineLimit(2)
                        if let folder = data.folder {
                            Label(folder, systemImage: "folder.fill")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        if let countdown = data.countdown {
                            Text(countdown)
                                .font(.caption.weight(.medium))
                                .foregroundStyle(.orange)
                        }
                    }
                    Spacer()
                    if data.hasQR {
                        VStack(spacing: 4) {
                            Image(systemName: "qrcode.viewfinder")
                                .font(.system(size: 36))
                                .foregroundStyle(Color(red: 0.10, green: 0.38, blue: 0.72))
                            Text("QR")
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .padding()
            }
            .buttonStyle(.plain)
            .containerBackground(.fill.tertiary, for: .widget)
        } else {
            ArcaTicketsSmallView(data: data)
        }
    }
}

struct ArcaTicketsWidgetEntryView: View {
    @Environment(\.widgetFamily) var family
    let entry: ArcaTicketsEntry

    var body: some View {
        Group {
            switch family {
            case .systemMedium:
                ArcaTicketsMediumView(data: entry.data)
            default:
                ArcaTicketsSmallView(data: entry.data)
            }
        }
    }
}

// MARK: - Widget Definition

struct ArcaTicketsWidget: Widget {
    let kind = "ArcaTicketsWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: ArcaTicketsProvider()) { entry in
            ArcaTicketsWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("Arca Holiday")
        .description("Nächsts Ticket — tipp zum Öffne vo dr Boarding Card.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

@main
struct ArcaTicketsWidgetBundle: WidgetBundle {
    var body: some Widget {
        ArcaTicketsWidget()
        FlightDayLiveActivityWidget()
    }
}
