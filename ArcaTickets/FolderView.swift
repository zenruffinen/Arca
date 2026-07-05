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
    @State private var ticketToDelete: TicketEntry?
    @State private var showDeleteConfirm = false
    @State private var shareItem: ShareURLItem?
    @State private var showShareEmptyAlert = false

    private var folderTickets: [TicketEntry] {
        store.tickets(in: folder, filter: filter)
    }

    private var allFolderTickets: [TicketEntry] {
        store.tickets(in: folder, filter: .all)
    }

    private var style: TicketFolderStyle { .style(for: folder, isShared: store.isSharedFolder(folder)) }
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
                    Section {
                        ForEach(folderTickets) { ticket in
                            NavigationLink(value: ticket) {
                                TicketRow(ticket: ticket, showPinIndicator: true)
                            }
                            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                Button(role: .destructive) {
                                    ticketToDelete = ticket
                                    showDeleteConfirm = true
                                } label: {
                                    Label("Löschen", systemImage: "trash")
                                }
                            }
                        }
                    } footer: {
                        shareHintFooter
                    }
                }
            }
        }
        .navigationTitle(folder)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                HStack(spacing: 16) {
                    Button {
                        shareFolder()
                    } label: {
                        Image(systemName: "person.2.fill")
                    }
                    .accessibilityLabel("Mit Familie teilen")

                    Button {
                        showAddTicket = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
        }
        .sheet(item: $shareItem) { item in
            ShareSheet(activityItems: [item.url])
        }
        .alert("Nichts zu teilen", isPresented: $showShareEmptyAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Füge mindestens ein Ticket in diesen Ordner hinzu, bevor du ihn teilst.")
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
        .alert("Ticket löschen?", isPresented: $showDeleteConfirm) {
            Button("Abbrechen", role: .cancel) { ticketToDelete = nil }
            Button("Löschen", role: .destructive) {
                if let ticket = ticketToDelete {
                    TicketsHaptics.delete()
                    store.deleteTicket(ticket)
                }
                ticketToDelete = nil
            }
        } message: {
            if let ticket = ticketToDelete {
                Text("\u{201E}\(ticket.title)\u{201C} wird unwiderruflich gelöscht.")
            }
        }
    }

    private func shareFolder() {
        guard !allFolderTickets.isEmpty else {
            showShareEmptyAlert = true
            return
        }
        if let url = store.exportFolder(folder) {
            TicketsHaptics.lightImpact()
            shareItem = ShareURLItem(url: url)
        }
    }

    private var shareHintFooter: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label("Reise teilen — Familie erhält alle Tickets", systemImage: "person.2.fill")
                .font(.subheadline.weight(.semibold))
            Text("Einmal teilen, jeder hat Flug, Hotel, Eintritt griffbereit. Tippe oben auf das Familien-Symbol und sende per AirDrop oder Nachrichten.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.top, 4)
    }

    @ViewBuilder
    private var folderEmptyState: some View {
        if filter != .active && store.ticketCount(in: folder) > 0 {
            ContentUnavailableView {
                Label(filter == .expired ? "Keine abgelaufenen Tickets" : "Keine Tickets",
                      systemImage: filter == .expired ? "clock.badge.xmark" : "tray")
            } description: {
                Text(filter == .expired
                     ? "In \u{201E}\(folder)\u{201C} gibt es keine abgelaufenen Tickets."
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
