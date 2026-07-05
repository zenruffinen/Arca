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
    private var emptyMessage: (title: String, description: String) {
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
