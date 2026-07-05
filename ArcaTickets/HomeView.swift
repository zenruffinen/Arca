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
    @Binding var showSettings: Bool

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                if let next = store.nextTicket {
                    NextTicketHeroCard(ticket: next)
                }

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
                            TicketsFolderCard(name: folder, count: store.ticketCount(in: folder))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 100)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Arca Tickets")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showSettings = true
                } label: {
                    Image(systemName: "gearshape")
                        .accessibilityLabel("Einstellungen")
                }
            }
        }
        .overlay(alignment: .bottom) {
            Button {
                showAddTicket = true
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "plus")
                        .font(.title3.bold())
                    Text("Hinzufügen")
                        .font(.system(size: 17, weight: .semibold))
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 24)
                .padding(.vertical, 16)
                .background(Color.accentColor, in: Capsule())
                .shadow(color: .black.opacity(0.18), radius: 10, y: 4)
            }
            .padding(.bottom, 24)
            .accessibilityLabel("Ticket hinzufügen")
        }
    }

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Noch keine Tickets")
                .font(.headline)
            Text("Tippe auf Hinzufügen oder teile ein PDF oder Foto direkt in Arca Tickets.")
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
                Text(store.tickets.isEmpty ? "Willkommen" : "Deine Fahrkarten")
                    .font(.headline)
                Text(store.tickets.isEmpty
                     ? "Alles griffbereit für unterwegs"
                     : "\(store.tickets.count) Tickets gespeichert")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Image(systemName: "lock.shield.fill")
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
                Text("Alle Tickets")
                    .font(.system(size: 16, weight: .semibold))
                Text("Übersicht aller Ordner")
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

struct NextTicketHeroCard: View {
    @EnvironmentObject private var store: TicketStore
    let ticket: TicketEntry
    @State private var showQRFullscreen = false

    private var style: TicketFolderStyle { .style(for: ticket.folder) }
    private var tint: Color { ArcaTicketsDesign.tint(for: style.tintName) }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Label("Nächstes Ticket", systemImage: "star.fill")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(tint)
                Spacer()
                if let countdown = ticket.expiryCountdownText {
                    Text(countdown)
                        .font(.caption.weight(.medium))
                        .foregroundStyle(ticket.isExpired ? .red : .secondary)
                }
            }

            NavigationLink(value: ticket) {
                HStack(spacing: 12) {
                    Image(systemName: style.icon)
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundStyle(tint)
                        .ticketsIconTile(tint: tint, size: 48)

                    VStack(alignment: .leading, spacing: 4) {
                        Text(ticket.title)
                            .font(.system(size: 18, weight: .bold))
                            .foregroundStyle(.primary)
                            .lineLimit(2)
                        HStack(spacing: 6) {
                            Text(ticket.folder)
                            if let expiry = ticket.expiryDate {
                                Text("·")
                                Text(expiry, style: .date)
                            }
                        }
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    }

                    Spacer(minLength: 0)

                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.tertiary)
                }
            }
            .buttonStyle(.plain)

            if ticket.fileKind == .image {
                Button {
                    TicketsHaptics.mediumImpact()
                    showQRFullscreen = true
                } label: {
                    Label("Am Schalter zeigen", systemImage: "qrcode.viewfinder")
                        .font(.system(size: 16, weight: .semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .foregroundStyle(.white)
                        .background(tint, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(16)
        .ticketsCardBackground(tint: tint, cornerRadius: ArcaTicketsDesign.cornerRadius)
        .fullScreenCover(isPresented: $showQRFullscreen) {
            QRFullscreenView(imageURL: store.fileURL(for: ticket.fileName))
        }
    }
}

struct AllTicketsView: View {
    @EnvironmentObject private var store: TicketStore

    var body: some View {
        List {
            ForEach(store.allTicketsSorted()) { ticket in
                NavigationLink(value: ticket) {
                    TicketRow(ticket: ticket)
                }
            }
            .onDelete(perform: deleteTickets)
        }
        .navigationTitle("Alle Tickets")
    }

    private func deleteTickets(at offsets: IndexSet) {
        let sorted = store.allTicketsSorted()
        for index in offsets {
            store.deleteTicket(sorted[index])
        }
    }
}

struct TicketRow: View {
    let ticket: TicketEntry

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: ticket.fileKind == .pdf ? "doc.fill" : "photo.fill")
                .foregroundStyle(ticket.isExpired ? .red : .accent)
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 3) {
                Text(ticket.title)
                    .font(.body.weight(.medium))
                    .lineLimit(1)
                HStack(spacing: 6) {
                    Text(ticket.folder)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    if let countdown = ticket.expiryCountdownText {
                        Text("·")
                            .foregroundStyle(.secondary)
                        Text(countdown)
                            .font(.caption)
                            .foregroundStyle(ticket.daysUntilExpiry == 0 ? .orange : .secondary)
                    } else if let expiry = ticket.expiryDate {
                        Text("·")
                            .foregroundStyle(.secondary)
                        Text(expiry, style: .date)
                            .font(.caption)
                            .foregroundStyle(ticket.isExpired ? .red : .secondary)
                    }
                }
            }
        }
        .padding(.vertical, 2)
    }
}
