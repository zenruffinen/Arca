//
//  ArcaTicketsApp.swift
//  ArcaTickets
//
//  Entwickler: Hans zen Ruffinen
//

import SwiftUI
import AppIntents

@main
struct ArcaTicketsApp: App {
    @StateObject private var store = TicketStore()

    init() {
        ArcaHolidayShortcuts.updateAppShortcutParameters()
    }

    var body: some Scene {
        WindowGroup {
            ArcaTicketsRootView()
                .environmentObject(store)
        }
    }
}

/// Root shell — `scenePhase` gehört in eine View, nicht in `App` (stabiler auf iOS-Betas).
private struct ArcaTicketsRootView: View {
    @EnvironmentObject private var store: TicketStore
    @Environment(\.scenePhase) private var scenePhase

    @State private var isUnlocked = false
    @State private var showOnboarding = !OnboardingStorage.hasCompleted
    @State private var pendingImportURL: URL?
    @State private var pendingFolderImportURL: URL?
    @State private var pendingTicketID: UUID?
    @State private var backgroundedAt: Date?

    private let autoLockTimeout: TimeInterval = 60

    var body: some View {
        ZStack {
            ContentView(
                isUnlocked: isUnlocked,
                pendingImportURL: $pendingImportURL,
                pendingFolderImportURL: $pendingFolderImportURL,
                pendingTicketID: $pendingTicketID
            )

            if showOnboarding {
                OnboardingView(isPresented: $showOnboarding)
                    .transition(.opacity)
                    .zIndex(2)
            } else if !isUnlocked {
                TicketsLockView(isUnlocked: $isUnlocked)
                    .transition(.opacity)
                    .zIndex(1)
            }

            if scenePhase == .inactive || scenePhase == .background {
                privacyShield
                    .zIndex(3)
            }
        }
        .animation(.easeInOut(duration: 0.2), value: isUnlocked)
        .animation(.easeInOut(duration: 0.25), value: showOnboarding)
        .onChange(of: scenePhase) { _, phase in
            switch phase {
            case .background:
                backgroundedAt = Date()
            case .active:
                if isUnlocked, let bg = backgroundedAt,
                   Date().timeIntervalSince(bg) > autoLockTimeout {
                    isUnlocked = false
                }
                backgroundedAt = nil
                store.reloadFromCloud()
                if isUnlocked {
                    store.consumeHolidayIntentNavigation()
                }
            default:
                break
            }
        }
        .onOpenURL(perform: handleOpenURL)
        .onReceive(NotificationCenter.default.publisher(for: .arcaHolidayNavigate)) { note in
            guard isUnlocked, let destination = note.object as? String else { return }
            store.applyHolidayIntentNavigation(destination)
        }
    }

    private var privacyShield: some View {
        Color(.systemBackground)
            .ignoresSafeArea()
            .overlay {
                VStack(spacing: 16) {
                    Image(systemName: "lock.shield.fill")
                        .font(.system(size: 56))
                        .foregroundStyle(.secondary)
                    Text("Arca Holiday")
                        .font(.title2.bold())
                        .foregroundStyle(.secondary)
                }
            }
    }

    private func handleOpenURL(_ url: URL) {
        if url.scheme == "arcatickets", url.host == "ticket",
           let idString = url.pathComponents.dropFirst().first,
           let id = UUID(uuidString: idString) {
            pendingTicketID = id
        } else if store.isBackupCandidateURL(url) {
            store.pendingBackupURL = ImportStaging.copyToTemporary(url) ?? url
        } else if store.isFolderSharePackageURL(url) {
            pendingFolderImportURL = ImportStaging.copyToTemporary(url) ?? url
        } else if url.isFileURL || url.scheme == "file" {
            pendingImportURL = ImportStaging.copyToTemporary(url) ?? url
        } else {
            pendingImportURL = url
        }
    }
}
