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

    var body: some View {
        ArcaHolidayView()
            .ticketsToastOverlay()
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
            }
            .onAppear {
                handlePostOnboardingActions()
                if let url = pendingFolderImportURL {
                    handleIncomingFolderURL(url)
                }
                if let url = pendingImportURL {
                    handleIncomingURL(url)
                }
            }
    }

    private func handlePostOnboardingActions() {
        guard isUnlocked else { return }
        if OnboardingStorage.consumeContacts() {
            // Kontakte über Istellige → Nummerä erreichbar
        }
    }

    private func handleIncomingFolderURL(_ url: URL?) {
        guard let url, isUnlocked else { return }
        guard store.isFolderSharePackageURL(url) else {
            pendingFolderImportURL = nil
            return
        }
        switch store.importSharedFolder(from: url) {
        case .success:
            TicketsHaptics.lightImpact()
            pendingFolderImportURL = nil
        case .failure:
            pendingFolderImportURL = nil
        }
    }

    private func handleIncomingURL(_ url: URL?) {
        guard let url, isUnlocked else { return }

        if url.scheme == "arcatickets" {
            pendingImportURL = nil
            return
        }

        if url.isFileURL || url.scheme == "file" {
            if store.isFolderSharePackageURL(url) {
                handleIncomingFolderURL(url)
            }
            pendingImportURL = nil
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

#Preview {
    ContentView(
        isUnlocked: true,
        pendingImportURL: .constant(nil),
        pendingFolderImportURL: .constant(nil),
        pendingTicketID: .constant(nil)
    )
    .environmentObject(TicketStore())
}
