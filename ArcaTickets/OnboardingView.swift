//
//  OnboardingView.swift
//  ArcaTickets
//
//  Entwickler: Hans zen Ruffinen
//

import SwiftUI

enum OnboardingStorage {
    static let completedKey = "arcatickets_onboarding_completed"

    static var hasCompleted: Bool {
        UserDefaults.standard.bool(forKey: completedKey)
    }

    static func markCompleted() {
        UserDefaults.standard.set(true, forKey: completedKey)
    }
}

struct OnboardingView: View {
    @Binding var isPresented: Bool
    @State private var page = 0

    private let pages: [(icon: String, title: String, subtitle: String, showFlow: Bool)] = [
        (
            "square.and.arrow.down.fill",
            "Ticket rein",
            "Per Teilen aus Mail oder Safari, Foto oder PDF — in Sekunden gespeichert und sortiert.",
            false
        ),
        (
            "qrcode.viewfinder",
            "Am Schalter zeigen",
            "QR-Code im Vollbild mit maximaler Helligkeit — kein Wühlen in der Tasche.",
            true
        )
    ]

    var body: some View {
        ZStack {
            Color(.systemBackground).ignoresSafeArea()

            VStack(spacing: 0) {
                HStack {
                    Spacer()
                    Button("Überspringen") { finish() }
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 20)
                .padding(.top, 12)

                TabView(selection: $page) {
                    ForEach(Array(pages.enumerated()), id: \.offset) { index, item in
                        onboardingPage(
                            icon: item.icon,
                            title: item.title,
                            subtitle: item.subtitle,
                            showFlow: item.showFlow
                        )
                        .tag(index)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .always))
                .indexViewStyle(.page(backgroundDisplayMode: .always))

                Button {
                    if page < pages.count - 1 {
                        withAnimation { page += 1 }
                    } else {
                        finish()
                    }
                } label: {
                    Text(page < pages.count - 1 ? "Weiter" : "Los geht's")
                        .font(.system(size: 17, weight: .semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .foregroundStyle(.white)
                        .background(Color.accentColor, in: RoundedRectangle(cornerRadius: ArcaTicketsDesign.cornerRadius, style: .continuous))
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 32)
            }
        }
    }

    private func onboardingPage(icon: String, title: String, subtitle: String, showFlow: Bool) -> some View {
        VStack(spacing: 28) {
            Spacer()

            TicketsAppIcon(size: 88)

            if showFlow {
                HStack(spacing: 10) {
                    flowChip("Ticket rein", icon: "square.and.arrow.down.fill")
                    Image(systemName: "arrow.right")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.tertiary)
                    flowChip("Am Schalter zeigen", icon: "qrcode.viewfinder")
                }
                .padding(.horizontal, 20)
            }

            Image(systemName: icon)
                .font(.system(size: 56))
                .foregroundStyle(Color.accentColor)
                .symbolRenderingMode(.hierarchical)

            VStack(spacing: 10) {
                Text(title)
                    .font(.title.bold())
                    .multilineTextAlignment(.center)
                Text(subtitle)
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }

            Spacer()
            Spacer()
        }
    }

    private func flowChip(_ label: String, icon: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.caption.weight(.semibold))
            Text(label)
                .font(.caption.weight(.semibold))
        }
        .foregroundStyle(Color.accentColor)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Color.accentColor.opacity(0.12), in: Capsule())
    }

    private func finish() {
        OnboardingStorage.markCompleted()
        NotificationManager.requestAuthorizationIfNeeded()
        withAnimation { isPresented = false }
    }
}
