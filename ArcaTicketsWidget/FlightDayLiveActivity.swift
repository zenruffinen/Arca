//
//  FlightDayLiveActivity.swift
//  ArcaTicketsWidget
//
//  Entwickler: Hans zen Ruffinen
//

import ActivityKit
import WidgetKit
import SwiftUI

// MARK: - Attributes (must match ArcaTickets/FlightDayActivityManager.swift)

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

// MARK: - Live Activity UI

struct FlightDayLiveActivityView: View {
    let context: ActivityViewContext<FlightDayAttributes>

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(context.attributes.flightTitle)
                .font(.caption.weight(.bold))
                .foregroundStyle(.secondary)
                .lineLimit(1)

            flightRow(context.state.flightLine)
            flightRow(context.state.boardingHint)
            flightRow(context.state.gateLine)
            flightRow(context.state.baggageLine)
        }
        .padding(14)
        .activityBackgroundTint(Color(red: 0.10, green: 0.38, blue: 0.72).opacity(0.18))
        .activitySystemActionForegroundColor(Color(red: 0.20, green: 0.85, blue: 0.95))
    }

    private func flightRow(_ text: String) -> some View {
        Text(text)
            .font(.subheadline.weight(.semibold))
            .lineLimit(1)
            .minimumScaleFactor(0.8)
    }
}

struct FlightDayLiveActivityCompact: View {
    let context: ActivityViewContext<FlightDayAttributes>

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "airplane.departure")
            Text(compactFlightTime(from: context.state.flightLine))
                .font(.caption.weight(.bold))
        }
    }

    private func compactFlightTime(from line: String) -> String {
        line.replacingOccurrences(of: "✈️ ", with: "")
    }
}

struct FlightDayLiveActivityMinimal: View {
    let context: ActivityViewContext<FlightDayAttributes>

    var body: some View {
        Image(systemName: "airplane.departure")
            .font(.caption.weight(.bold))
    }
}

struct FlightDayLiveActivityExpanded: View {
    let context: ActivityViewContext<FlightDayAttributes>

    var body: some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text(context.state.flightLine)
                    .font(.headline.weight(.bold))
                Text(context.state.gateLine)
                    .font(.subheadline)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 4) {
                Text(context.state.boardingHint)
                    .font(.caption.weight(.semibold))
                Text(context.state.baggageLine)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 8)
    }
}

// MARK: - Widget registration

struct FlightDayLiveActivityWidget: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: FlightDayAttributes.self) { context in
            FlightDayLiveActivityView(context: context)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    FlightDayLiveActivityCompact(context: context)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Text(context.state.gateLine)
                        .font(.caption.weight(.bold))
                }
                DynamicIslandExpandedRegion(.bottom) {
                    FlightDayLiveActivityExpanded(context: context)
                }
            } compactLeading: {
                FlightDayLiveActivityMinimal(context: context)
            } compactTrailing: {
                Text(compactGate(from: context.state.gateLine))
                    .font(.caption2.weight(.bold))
            } minimal: {
                FlightDayLiveActivityMinimal(context: context)
            }
        }
    }

    private func compactGate(from line: String) -> String {
        line.replacingOccurrences(of: "📍 ", with: "")
    }
}
