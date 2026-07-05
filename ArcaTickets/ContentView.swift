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
    @Binding var pendingTicketID: UUID?
    @State private var showAddTicket = false
    @State private var showSettings = false
    @State private var importURL: URL?
    @State private var navigationPath = NavigationPath()

    var body: some View {
        NavigationStack(path: $navigationPath) {
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
            handleIncomingURL(url)
        }
        .onChange(of: isUnlocked) { _, unlocked in
            guard unlocked else { return }
            handleIncomingURL(pendingImportURL)
            if let id = pendingTicketID {
                navigateToTicket(id: id)
                pendingTicketID = nil
            }
        }
        .onChange(of: pendingTicketID) { _, id in
            guard let id, isUnlocked else { return }
            navigateToTicket(id: id)
            pendingTicketID = nil
        }
        .onAppear {
            if let url = pendingImportURL {
                handleIncomingURL(url)
            }
            if let id = pendingTicketID, isUnlocked {
                navigateToTicket(id: id)
                pendingTicketID = nil
            }
        }
    }

    private func handleIncomingURL(_ url: URL?) {
        guard let url else { return }
        guard isUnlocked else { return }

        if url.scheme == "arcatickets" {
            pendingImportURL = nil
            if url.host == "ticket",
               let idString = url.pathComponents.dropFirst().first,
               let id = UUID(uuidString: idString) {
                navigateToTicket(id: id)
            }
            return
        }

        if url.isFileURL || url.scheme == "file" {
            importURL = ImportStaging.copyToTemporary(url) ?? url
            showAddTicket = true
            pendingImportURL = nil
        }
    }

    private func navigateToTicket(id: UUID) {
        guard let ticket = store.tickets.first(where: { $0.id == id }) else { return }
        navigationPath.append(ticket)
    }
}

enum ImportStaging {
    /// Kopiert geteilte Dateien sofort in ein Temp-Verzeichnis, damit sie nach Onboarding/Entsperren noch verfügbar sind.
    static func copyToTemporary(_ sourceURL: URL) -> URL? {
        let accessing = sourceURL.startAccessingSecurityScopedResource()
        defer { if accessing { sourceURL.stopAccessingSecurityScopedResource() } }

        let ext = sourceURL.pathExtension.isEmpty ? "jpg" : sourceURL.pathExtension
        let dest = FileManager.default.temporaryDirectory
            .appendingPathComponent("arcatickets-import-\(UUID().uuidString).\(ext)")
        do {
            if FileManager.default.fileExists(atPath: dest.path) {
                try FileManager.default.removeItem(at: dest)
            }
            try FileManager.default.copyItem(at: sourceURL, to: dest)
            return dest
        } catch {
            return nil
        }
    }
}
