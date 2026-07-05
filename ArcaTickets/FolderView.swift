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
    @State private var showShareGuide = false

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
                            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                Button(role: .destructive) {
                                    deleteTicket(ticket)
                                } label: {
                                    Label(ArcaTicketsStrings.delete, systemImage: "trash")
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
                        beginShare()
                    } label: {
                        Image(systemName: "person.2.fill")
                    }
                    .ticketsMinTapTarget()
                    .accessibilityLabel("Mit Familie teile")

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
        .sheet(isPresented: $showShareGuide) {
            FolderShareGuideView(folderName: folder) {
                showShareGuide = false
                shareFolder()
            }
            .presentationDetents([.medium, .large])
        }
        .alert("Nüt zum Teile", isPresented: $showShareEmptyAlert) {
            Button(ArcaTicketsStrings.ok, role: .cancel) {}
        } message: {
            Text("Füeg mindestens es Ticket in dene Ordner hinzue, bevor du ihn teilsch.")
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
        .alert("Ticket lösche?", isPresented: $showDeleteConfirm) {
            Button(ArcaTicketsStrings.cancel, role: .cancel) { ticketToDelete = nil }
            Button(ArcaTicketsStrings.delete, role: .destructive) {
                if let ticket = ticketToDelete {
                    TicketsHaptics.delete()
                    store.deleteTicket(ticket)
                }
                ticketToDelete = nil
            }
        } message: {
            if let ticket = ticketToDelete {
                Text("\u{201E}\(ticket.title)\u{201C} würklich lösche? Das gaht nöd rückgängig.")
            }
        }
    }

    private func beginShare() {
        guard !allFolderTickets.isEmpty else {
            showShareEmptyAlert = true
            return
        }
        showShareGuide = true
    }

    private func deleteTicket(_ ticket: TicketEntry) {
        if ticket.needsDeleteConfirmation {
            ticketToDelete = ticket
            showDeleteConfirm = true
        } else {
            TicketsHaptics.delete()
            store.deleteTicket(ticket)
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
            Label("Reise teile — Familie überchunnt alli Ticket", systemImage: "person.2.fill")
                .font(.subheadline.weight(.semibold))
            Text("Einisch teile, jede/r het Flug, Hotel, Iitritt griffbereit. Tipp obe uf s'Familie-Symbol und send per AirDrop oder Nachrichte.")
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(LegalCopy.familyShareWarning)
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .padding(.top, 4)
    }

    @ViewBuilder
    private var folderEmptyState: some View {
        if filter != .active && store.ticketCount(in: folder) > 0 {
            ContentUnavailableView {
                Label(filter == .expired ? "Kei abgloffeni Ticket" : "Kei Ticket",
                      systemImage: filter == .expired ? "clock.badge.xmark" : "tray")
            } description: {
                Text(filter == .expired
                     ? "In \u{201E}\(folder)\u{201C} git's kei abgloffeni Ticket."
                     : "Wechsle de Filter, zum anderi Ticket z'gseh.")
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
                    Label("Ticket hinzuefüege", systemImage: "plus.circle.fill")
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
