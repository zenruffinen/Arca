//
//  KalenderHeute.swift
//  Arca
//
//  Der Blick in den Kalender auf dem Startbildschirm: die heutigen
//  Termine als Glas-Karte — nur lesend, direkt aus EventKit.
//
//  Entwickler: Hans zen Ruffinen
//

import SwiftUI
import Combine
import EventKit

/// Lädt die heutigen Termine und merkt sich den Berechtigungs-Stand.
@MainActor
final class KalenderHeute: ObservableObject {
    static let shared = KalenderHeute()

    private let ekStore = EKEventStore()
    @Published var termine: [EKEvent] = []
    @Published var status: EKAuthorizationStatus = EKEventStore.authorizationStatus(for: .event)

    /// Termine von jetzt bis Mitternacht (ganztägige bleiben draußen).
    func aktualisiere() {
        status = EKEventStore.authorizationStatus(for: .event)
        guard status == .fullAccess else { return }
        let start = Date()
        guard let ende = Calendar.current.date(
            byAdding: .day, value: 1,
            to: Calendar.current.startOfDay(for: start)) else { return }
        let predicate = ekStore.predicateForEvents(withStart: start, end: ende, calendars: nil)
        termine = ekStore.events(matching: predicate)
            .filter { !$0.isAllDay }
            .sorted { $0.startDate < $1.startDate }
    }

    func erlaubnisAnfragen() {
        Task {
            _ = try? await ekStore.requestFullAccessToEvents()
            aktualisiere()
        }
    }
}

/// Die „Heute"-Karte auf dem Start: Datum + die nächsten Termine.
struct HomeCalendarCard: View {
    @ObservedObject private var kalender = KalenderHeute.shared

    private var datumHeute: String {
        Date().formatted(.dateTime.weekday(.wide).day().month(.wide))
    }

    var body: some View {
        Group {
            switch kalender.status {
            case .fullAccess:
                terminListe
            case .notDetermined:
                verbindenKnopf
            default:
                // Abgelehnt/eingeschränkt: Karte verschwindet still —
                // ändern lässt sich das jederzeit in den iOS-Einstellungen.
                EmptyView()
            }
        }
        .onAppear { kalender.aktualisiere() }
    }

    private var kopfzeile: some View {
        HStack(spacing: 6) {
            Image(systemName: "calendar")
                .font(.system(size: 12, weight: .semibold))
            Text("Heute · \(datumHeute)")
                .textCase(.uppercase)
                .tracking(0.6)
            Spacer()
        }
        .font(.system(size: 12, weight: .semibold))
        .foregroundStyle(.secondary)
    }

    private var terminListe: some View {
        VStack(alignment: .leading, spacing: 8) {
            kopfzeile
            if kalender.termine.isEmpty {
                Text("Keine Termine mehr heute — freier Platz für Ideen.")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            } else {
                ForEach(kalender.termine.prefix(3), id: \.eventIdentifier) { termin in
                    HStack(spacing: 10) {
                        Text(termin.startDate.formatted(date: .omitted, time: .shortened))
                            .font(.system(size: 12, weight: .semibold, design: .rounded))
                            .foregroundStyle(ArcaWarm.terrakotta)
                            .frame(width: 44, alignment: .leading)
                        Text(termin.title ?? "Termin")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(.primary)
                            .lineLimit(1)
                        Spacer(minLength: 0)
                    }
                }
                if kalender.termine.count > 3 {
                    Text("+\(kalender.termine.count - 3) weitere")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 14))
        .contentShape(Rectangle())
        .onTapGesture {
            // Tipp auf die Karte öffnet die Kalender-App beim heutigen Tag
            if let url = URL(string: "calshow:\(Date().timeIntervalSinceReferenceDate)") {
                UIApplication.shared.open(url)
            }
        }
    }

    private var verbindenKnopf: some View {
        Button {
            kalender.erlaubnisAnfragen()
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "calendar.badge.plus")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(ArcaWarm.terrakotta)
                Text("Kalender verbinden — deine heutigen Termine direkt hier.")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                Spacer(minLength: 0)
            }
            .padding(12)
            .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 14))
        }
        .buttonStyle(.plain)
    }
}
