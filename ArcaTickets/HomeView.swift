//
//  HomeView.swift
//  ArcaTickets
//
//  Entwickler: Hans zen Ruffinen
//

import SwiftUI

struct HomeView: View {
    @EnvironmentObject private var store: TicketStore
    @Binding var showAddTicket: Bool

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                header

                if store.isCloudSyncPending {
                    HStack(spacing: 8) {
                        ProgressView()
                        Text(store.iCloudStatus.rawValue)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.horizontal, 4)
                }

                if store.tickets.isEmpty {
                    emptyState
                }

                VStack(spacing: 10) {
                    NavigationLink(value: "__all__") {
                        allTicketsCard
                    }
                    .buttonStyle(.plain)

                    ForEach(store.folders, id: \.self) { folder in
                        NavigationLink(value: folder) {
                            TicketsFolderCard(
                                name: folder,
                                count: store.ticketCount(in: folder),
                                isShared: store.isSharedFolder(folder)
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 100)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle(ArcaTicketsStrings.tabAllTickets)
        .navigationBarTitleDisplayMode(.large)
        .overlay(alignment: .bottom) {
            TicketsFAB(title: ArcaTicketsStrings.add) {
                showAddTicket = true
            }
            .padding(.bottom, 24)
        }
    }

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Noch kei Ticket — leg los ✈️")
                .font(.headline)
            Text("Tipp uf Dezue tue oder teil es PDF oder Foto direkt in Arca Tickets.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .ticketsCardBackground(tint: .accentColor, cornerRadius: ArcaTicketsDesign.chipRadius)
    }

    private var header: some View {
        HStack(spacing: 12) {
            TicketsAppIcon(size: 40)
            VStack(alignment: .leading, spacing: 2) {
                Text(store.tickets.isEmpty ? "Willkomme" : "Dini Sammlig")
                    .font(.headline)
                Text(store.tickets.isEmpty
                     ? "Ordne Ticket in Ordner"
                     : "\(store.tickets.count) Ticket in \(store.folders.count) Ordner")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Image(systemName: "folder.fill")
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)
        }
        .padding(.top, 4)
    }

    private var allTicketsCard: some View {
        HStack(spacing: 12) {
            Image(systemName: "tray.full.fill")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(.accent)
                .ticketsIconTile(tint: .accentColor, size: 40)

            VStack(alignment: .leading, spacing: 2) {
                Text("Chronologisch")
                    .font(.system(size: 16, weight: .semibold))
                Text("Alli Ticket uf e Blick")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Text("\(store.tickets.count)")
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .foregroundStyle(.accent)
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(Color.accentColor.opacity(0.12), in: Capsule())

            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.tertiary)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .ticketsCardBackground(tint: .accentColor, cornerRadius: ArcaTicketsDesign.chipRadius)
    }
}

struct AllTicketsView: View {
    @EnvironmentObject private var store: TicketStore
    @State private var ticketToDelete: TicketEntry?
    @State private var showDeleteConfirm = false

    var body: some View {
        List {
            ForEach(store.allTicketsSorted()) { ticket in
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
        }
        .navigationTitle(ArcaTicketsStrings.tabAllTickets)
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

    private func deleteTicket(_ ticket: TicketEntry) {
        if ticket.needsDeleteConfirmation {
            ticketToDelete = ticket
            showDeleteConfirm = true
        } else {
            TicketsHaptics.delete()
            store.deleteTicket(ticket)
        }
    }
}

struct TicketRow: View {
    @EnvironmentObject private var store: TicketStore
    let ticket: TicketEntry
    var showPinIndicator: Bool = false

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: ticket.fileKind == .pdf ? "doc.fill" : "photo.fill")
                .foregroundStyle(ticket.isExpired ? .red : .accent)
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(ticket.title)
                        .font(.body.weight(.medium))
                        .lineLimit(1)
                    if showPinIndicator && ticket.isPinned {
                        Image(systemName: "pin.fill")
                            .font(.caption2)
                            .foregroundStyle(ArcaTicketsDesign.travelSunset)
                    }
                }
                HStack(spacing: 6) {
                    Text(ticket.folder)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    if let flight = ticket.flightNumber, !flight.isEmpty {
                        Text("·")
                            .foregroundStyle(.secondary)
                        Text(flight)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    if let countdown = ticket.expiryCountdownText {
                        Text("·")
                            .foregroundStyle(.secondary)
                        Text(countdown)
                            .font(.caption)
                            .foregroundStyle(ticket.daysUntilExpiry == 0 ? .orange : .secondary)
                    } else if let uses = ticket.usesCountdownText {
                        Text("·")
                            .foregroundStyle(.secondary)
                        Text(uses)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else if let expiry = ticket.expiryDate {
                        Text("·")
                            .foregroundStyle(.secondary)
                        Text(expiry, style: .date)
                            .font(.caption)
                            .foregroundStyle(ticket.isExpired ? .red : .secondary)
                    }
                }
            }

            Spacer(minLength: 0)

            if showPinIndicator {
                Button {
                    store.togglePin(for: ticket)
                } label: {
                    Image(systemName: ticket.isPinned ? "pin.fill" : "pin")
                        .font(.body)
                        .foregroundStyle(ticket.isPinned ? ArcaTicketsDesign.travelSunset : Color.secondary.opacity(0.5))
                }
                .buttonStyle(.plain)
                .ticketsMinTapTarget()
                .accessibilityLabel(ticket.isPinned ? ArcaTicketsStrings.unpinFromUnterwegs : ArcaTicketsStrings.pinOnUnterwegs)
            }
        }
        .padding(.vertical, 2)
    }
}

#Preview {
    HomeView(showAddTicket: .constant(false))
        .environmentObject(TicketStore())
}
