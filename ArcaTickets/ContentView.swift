//
//  ContentView.swift
//  ArcaTickets
//
//  Entwickler: Hans zen Ruffinen
//

import SwiftUI

struct ContentView: View {
    let isUnlocked: Bool
    @EnvironmentObject private var store: TicketStore
    @Binding var pendingImportURL: URL?
    @State private var showAddTicket = false
    @State private var showSettings = false
    @State private var importURL: URL?

    var body: some View {
        NavigationStack {
            HomeView(showAddTicket: $showAddTicket, showSettings: $showSettings)
                .navigationDestination(for: String.self) { folder in
                    if folder == "__all__" {
                        AllTicketsView()
                    } else {
                        FolderView(folder: folder)
                    }
                }
                .navigationDestination(for: TicketEntry.self) { ticket in
                    TicketDetailView(ticket: ticket)
                }
        }
        .sheet(isPresented: $showAddTicket) {
            AddTicketView(importURL: importURL)
                .onDisappear { importURL = nil }
        }
        .sheet(isPresented: $showSettings) {
            SettingsView()
        }
        .disabled(!isUnlocked)
        .onChange(of: pendingImportURL) { _, url in
            guard let url, isUnlocked else { return }
            importURL = url
            showAddTicket = true
            pendingImportURL = nil
        }
        .onAppear {
            if let url = pendingImportURL, isUnlocked {
                importURL = url
                showAddTicket = true
                pendingImportURL = nil
            }
        }
    }
}
