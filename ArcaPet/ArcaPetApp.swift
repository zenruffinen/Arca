//
//  ArcaPetApp.swift
//  ArcaPet
//

import SwiftUI

@main
struct ArcaPetApp: App {
    @StateObject private var store = PetStore()

    var body: some Scene {
        WindowGroup {
            ArcaPetRootView()
                .environmentObject(store)
        }
    }
}

private struct ArcaPetRootView: View {
    @EnvironmentObject private var store: PetStore
    @Environment(\.scenePhase) private var scenePhase

    @State private var isUnlocked = false
    @State private var showOnboarding = !PetOnboardingStorage.hasCompleted
    @State private var backgroundedAt: Date?

    private let autoLockTimeout: TimeInterval = 60

    var body: some View {
        ZStack {
            ArcaPetHomeView()
                .disabled(!isUnlocked)

            if showOnboarding {
                PetOnboardingView(isPresented: $showOnboarding)
                    .transition(.opacity)
                    .zIndex(2)
            } else if !isUnlocked {
                PetLockView(isUnlocked: $isUnlocked)
                    .transition(.opacity)
                    .zIndex(1)
            }

            if scenePhase == .inactive || scenePhase == .background {
                privacyShield.zIndex(3)
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
            default:
                break
            }
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
                    Text("Arca Pet")
                        .font(.title2.bold())
                        .foregroundStyle(.secondary)
                }
            }
    }
}
