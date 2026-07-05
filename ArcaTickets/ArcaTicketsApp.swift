//
//  ArcaTicketsApp.swift
//  ArcaTickets
//
//  Entwickler: Hans zen Ruffinen
//

import SwiftUI

@main
struct ArcaTicketsApp: App {
    init() {
        ArcaTicketsTabBar.configure()
    }

    @StateObject private var store = TicketStore()
    @State private var isUnlocked = false
    @State private var showOnboarding = !OnboardingStorage.hasCompleted
    @State private var pendingImportURL: URL?
    @State private var pendingFolderImportURL: URL?
    @State private var pendingTicketID: UUID?
    @Environment(\.scenePhase) private var scenePhase
    @State private var backgroundedAt: Date?
    private let autoLockTimeout: TimeInterval = 60

    var body: some Scene {
        WindowGroup {
            ZStack {
                ContentView(
                    isUnlocked: isUnlocked,
                    pendingImportURL: $pendingImportURL,
                    pendingFolderImportURL: $pendingFolderImportURL,
                    pendingTicketID: $pendingTicketID
                )
                    .environmentObject(store)

                if showOnboarding {
                    OnboardingView(isPresented: $showOnboarding)
                        .transition(.opacity)
                        .zIndex(2)
                } else if !isUnlocked {
                    TicketsLockView(isUnlocked: $isUnlocked)
                        .environmentObject(store)
                        .transition(.opacity)
                        .zIndex(1)
                }

                if scenePhase == .inactive || scenePhase == .background {
                    Color(.systemBackground)
                        .ignoresSafeArea()
                        .overlay {
                            VStack(spacing: 16) {
                                Image(systemName: "lock.shield.fill")
                                    .font(.system(size: 56))
                                    .foregroundStyle(.secondary)
                                Text("ARCA TICKETS")
                                    .font(.title2.bold())
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .zIndex(3)
                }
            }
            .animation(.easeInOut(duration: 0.2), value: isUnlocked)
            .animation(.easeInOut(duration: 0.25), value: showOnboarding)
            .onOpenURL { url in
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
            default:
                break
            }
        }
    }
}
