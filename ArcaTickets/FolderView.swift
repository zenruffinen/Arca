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

    private var folderTickets: [TicketEntry] {
        store.tickets(in: folder)
    }

    var body: some View {
        Group {
            if folderTickets.isEmpty {
                ContentUnavailableView {
                    Label("Keine Tickets", systemImage: TicketFolderStyle.style(for: folder).icon)
                } description: {
                    Text("Füge ein Ticket in „\(folder)“ hinzu.")
                } actions: {
                    Button("Ticket hinzufügen") { showAddTicket = true }
                }
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
        .sheet(isPresented: $showAddTicket) {
            AddTicketView(preselectedFolder: folder)
        }
    }

    private func deleteTickets(at offsets: IndexSet) {
        for index in offsets {
            store.deleteTicket(folderTickets[index])
        }
    }
}
