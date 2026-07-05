//
//  FolderView.swift
//  ArcaTickets
//
//  Entwickler: Hans zen Ruffinen
//

import SwiftUI

struct FolderView: View {
    @EnvironmentObject private var store: TicketStore
    let folder: String
    @State private var showAddTicket = false
    @State private var filter: TicketExpiryFilter = .active

    private var folderTickets: [TicketEntry] {
        store.tickets(in: folder, filter: filter)
    }

    private var style: TicketFolderStyle { .style(for: folder) }
    private var tint: Color { ArcaTicketsDesign.tint(for: style.tintName) }
    private var emptyMessage: (title: String, description: String, examples: [String]) {
        TicketFolderStyle.emptyStateMessage(for: folder)
    }

    var body: some View {
        Group {
            if folderTickets.isEmpty {
                folderEmptyState
            } else {
                List {
                    ForEach(folderTickets) { ticket in
                        NavigationLink(value: ticket) {
                            TicketRow(ticket: ticket)
                        }
                    }
                    .onDelete(perform: deleteTickets)
                }
            }
        }
        .navigationTitle(folder)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showAddTicket = true
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .safeAreaInset(edge: .top, spacing: 0) {
            Picker("Filter", selection: $filter) {
                ForEach(TicketExpiryFilter.allCases) { option in
                    Text(option.rawValue).tag(option)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(Color(.systemGroupedBackground))
        }
        .sheet(isPresented: $showAddTicket) {
            AddTicketView(preselectedFolder: folder)
        }
    }

    @ViewBuilder
    private var folderEmptyState: some View {
        if filter != .active && store.ticketCount(in: folder) > 0 {
            ContentUnavailableView {
                Label(filter == .expired ? "Keine abgelaufenen Tickets" : "Keine Tickets",
                      systemImage: filter == .expired ? "clock.badge.xmark" : "tray")
            } description: {
                Text(filter == .expired
                     ? "In „\(folder)“ gibt es keine abgelaufenen Tickets."
                     : "Wechsle den Filter, um andere Tickets zu sehen.")
            }
        } else {
            VStack(spacing: 20) {
                Image(systemName: style.icon)
                    .font(.system(size: 52))
                    .foregroundStyle(tint)
                    .ticketsIconTile(tint: tint, size: 88)

                VStack(spacing: 8) {
                    Text(emptyMessage.title)
                        .font(.title3.weight(.semibold))
                    Text(emptyMessage.description)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }

                if !emptyMessage.examples.isEmpty {
                    FlowLayout(spacing: 8) {
                        ForEach(emptyMessage.examples, id: \.self) { example in
                            Text(example)
                                .font(.caption.weight(.medium))
                                .foregroundStyle(tint)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 5)
                                .background(tint.opacity(0.12), in: Capsule())
                        }
                    }
                }

                Button {
                    showAddTicket = true
                } label: {
                    Label("Ticket hinzufügen", systemImage: "plus.circle.fill")
                        .font(.headline)
                }
                .buttonStyle(.borderedProminent)
            }
            .padding(32)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private func deleteTickets(at offsets: IndexSet) {
        for index in offsets {
            store.deleteTicket(folderTickets[index])
        }
    }
}

private struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = arrange(proposal: proposal, subviews: subviews)
        return result.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = arrange(proposal: proposal, subviews: subviews)
        for (index, position) in result.positions.enumerated() {
            subviews[index].place(
                at: CGPoint(x: bounds.minX + position.x, y: bounds.minY + position.y),
                proposal: .unspecified
            )
        }
    }

    private func arrange(proposal: ProposedViewSize, subviews: Subviews) -> (size: CGSize, positions: [CGPoint]) {
        let maxWidth = proposal.width ?? .infinity
        var positions: [CGPoint] = []
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0
        var maxX: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > maxWidth, x > 0 {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            positions.append(CGPoint(x: x, y: y))
            rowHeight = max(rowHeight, size.height)
            x += size.width + spacing
            maxX = max(maxX, x - spacing)
        }

        return (CGSize(width: maxX, height: y + rowHeight), positions)
    }
}
