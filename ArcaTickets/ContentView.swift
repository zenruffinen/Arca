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
    @Binding var pendingFolderImportURL: URL?
    @Binding var pendingTicketID: UUID?
    @State private var showAddTicket = false
    @State private var importURL: URL?
    @State private var unterwegsPath = NavigationPath()
    @State private var alleTicketsPath = NavigationPath()
    @State private var selectedTab: ArcaTicketsTab = TabOrderPreferences.defaultTab
    @State private var tabOrder = TabOrderPreferences.tabOrder
    @State private var importedFolderName: String?
    @State private var showFolderImportSuccess = false
    @State private var showFolderImportError = false
    @State private var showContactsSheet = false

    var body: some View {
        TabView(selection: $selectedTab) {
            ForEach(tabOrder) { tab in
                tabRoot(for: tab)
                    .tabItem {
                        Label(tab.title, systemImage: tab.icon)
                    }
                    .tag(tab)
            }
        }
        .ticketsGlassTabBar()
        .ticketsToastOverlay()
        .sheet(isPresented: $showAddTicket) {
            AddTicketView(importURL: importURL)
                .onDisappear { importURL = nil }
        }
        .sheet(isPresented: $showContactsSheet) {
            QuickContactsManagementView()
        }
        .disabled(!isUnlocked)
        .onChange(of: pendingFolderImportURL) { _, url in
            handleIncomingFolderURL(url)
        }
        .onChange(of: pendingImportURL) { _, url in
            handleIncomingURL(url)
        }
        .onChange(of: isUnlocked) { _, unlocked in
            guard unlocked else { return }
            handlePostOnboardingActions()
            handleIncomingFolderURL(pendingFolderImportURL)
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
        .onReceive(NotificationCenter.default.publisher(for: .arcaTicketsTabOrderDidChange)) { _ in
            reloadTabOrder()
        }
        .onAppear {
            reloadTabOrder()
            handlePostOnboardingActions()
            if let url = pendingFolderImportURL {
                handleIncomingFolderURL(url)
            }
            if let url = pendingImportURL {
                handleIncomingURL(url)
            }
            if let id = pendingTicketID, isUnlocked {
                navigateToTicket(id: id)
                pendingTicketID = nil
            }
        }
        .alert("Reise importiert", isPresented: $showFolderImportSuccess) {
            Button("Ordner öffnen") {
                if let name = importedFolderName {
                    selectedTab = .alleTickets
                    alleTicketsPath.append(name)
                }
                importedFolderName = nil
            }
            Button("OK", role: .cancel) {
                importedFolderName = nil
            }
        } message: {
            if let name = importedFolderName {
                Text("Alle Tickets aus der geteilten Reise liegen jetzt in \u{201E}\(name)\u{201C}. Flug, Hotel und Eintritt sind griffbereit.")
            }
        }
        .alert("Das hat nicht geklappt", isPresented: $showFolderImportError) {
            Button("Nochmal versuchen", role: .cancel) {}
        } message: {
            Text("Die Datei konnte nicht gelesen werden. Bitte eine gültige .arcaticketsfolder-Datei wählen.")
        }
    }

    @ViewBuilder
    private func tabRoot(for tab: ArcaTicketsTab) -> some View {
        switch tab {
        case .unterwegs:
            NavigationStack(path: $unterwegsPath) {
                UnderwegsView(showAddTicket: $showAddTicket)
                    .navigationDestination(for: TicketEntry.self) { ticket in
                        TicketDetailView(ticket: ticket)
                    }
            }
        case .alleTickets:
            NavigationStack(path: $alleTicketsPath) {
                HomeView(showAddTicket: $showAddTicket)
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
        case .notfall:
            NavigationStack {
                NotfallView()
            }
        case .settings:
            SettingsView()
        }
    }

    private func reloadTabOrder() {
        let order = TabOrderPreferences.tabOrder
        tabOrder = order
        if !order.contains(selectedTab) {
            selectedTab = TabOrderPreferences.defaultTab
        }
    }

    private func handlePostOnboardingActions() {
        guard isUnlocked else { return }
        if OnboardingStorage.consumeAddTicket() {
            showAddTicket = true
        }
        if OnboardingStorage.consumeContacts() {
            showContactsSheet = true
        }
    }

    private func handleIncomingFolderURL(_ url: URL?) {
        guard let url else { return }
        guard isUnlocked else { return }

        guard store.isFolderSharePackageURL(url) else {
            pendingFolderImportURL = nil
            return
        }

        switch store.importSharedFolder(from: url) {
        case .success(let folderName):
            TicketsHaptics.lightImpact()
            importedFolderName = folderName
            showFolderImportSuccess = true
            pendingFolderImportURL = nil
        case .failure:
            showFolderImportError = true
            pendingFolderImportURL = nil
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
            if store.isFolderSharePackageURL(url) {
                handleIncomingFolderURL(url)
                pendingImportURL = nil
                return
            }
            importURL = ImportStaging.copyToTemporary(url) ?? url
            showAddTicket = true
            pendingImportURL = nil
        }
    }

    private func navigateToTicket(id: UUID) {
        guard let ticket = store.tickets.first(where: { $0.id == id }) else { return }
        if ticket.isPinned || store.unterwegsTickets().contains(where: { $0.id == id }) {
            selectedTab = .unterwegs
            unterwegsPath.append(ticket)
        } else {
            selectedTab = .alleTickets
            alleTicketsPath.append(ticket)
        }
    }
}

enum ImportStaging {
    /// Kopiert geteilte Dateien sofort in ein Temp-Verzeichnis, damit sie nach Onboarding/Entsperren noch verfügbar sind.
    static func copyToTemporary(_ sourceURL: URL) -> URL? {
        let accessing = sourceURL.startAccessingSecurityScopedResource()
        defer { if accessing { sourceURL.stopAccessingSecurityScopedResource() } }

        let ext = sourceURL.pathExtension.isEmpty ? "dat" : sourceURL.pathExtension
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
