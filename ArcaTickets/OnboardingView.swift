//
//  OnboardingView.swift
//  ArcaTickets
//
//  Entwickler: Hans zen Ruffinen
//

import SwiftUI

enum OnboardingStorage {
    static let completedKey = "arcatickets_onboarding_completed"
    static let pendingAddTicketKey = "arcatickets_pending_add_ticket"
    static let pendingContactsKey = "arcatickets_pending_contacts"

    static var hasCompleted: Bool {
        UserDefaults.standard.bool(forKey: completedKey)
    }

    static func markCompleted() {
        UserDefaults.standard.set(true, forKey: completedKey)
    }

    static func requestAddTicket() {
        UserDefaults.standard.set(true, forKey: pendingAddTicketKey)
    }

    static func requestContacts() {
        UserDefaults.standard.set(true, forKey: pendingContactsKey)
    }

    static func consumeAddTicket() -> Bool {
        let pending = UserDefaults.standard.bool(forKey: pendingAddTicketKey)
        if pending { UserDefaults.standard.set(false, forKey: pendingAddTicketKey) }
        return pending
    }

    static func consumeContacts() -> Bool {
        let pending = UserDefaults.standard.bool(forKey: pendingContactsKey)
        if pending { UserDefaults.standard.set(false, forKey: pendingContactsKey) }
        return pending
    }
}

struct OnboardingView: View {
    @Binding var isPresented: Bool
    @State private var page = 0

    private let pages: [(icon: String, title: String, subtitle: String, accent: String)] = [
        (
            "airplane.departure",
            "Alles dabei. Sorglos reisen.",
            "Flug, Bahn, Skipass — alles an einem Ort. Kein Wühlen, kein Stress.",
            "travel"
        ),
        (
            "square.and.arrow.down.fill",
            "Ticket rein",
            "Per Teilen aus Mail oder Safari, Foto oder PDF — in Sekunden gespeichert.",
            "import"
        ),
        (
            "pin.fill",
            "Unterwegs griffbereit",
            "Pinne dein nächstes Ticket, trage Flug & Sitz ein — und halte wichtige Nummern parat.",
            "unterwegs"
        )
    ]

    var body: some View {
        ZStack {
            ArcaTicketsDesign.travelGradient
                .ignoresSafeArea()

            VStack(spacing: 0) {
                HStack {
                    Spacer()
                    Button("Überspringen") { finish() }
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.secondary)
                        .ticketsMinTapTarget()
                }
                .padding(.horizontal, 20)
                .padding(.top, 12)

                TabView(selection: $page) {
                    ForEach(Array(pages.enumerated()), id: \.offset) { index, item in
                        onboardingPage(
                            icon: item.icon,
                            title: item.title,
                            subtitle: item.subtitle,
                            showFlow: index == 1,
                            showGettingStarted: index == pages.count - 1
                        )
                        .tag(index)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .always))
                .indexViewStyle(.page(backgroundDisplayMode: .always))

                if page < pages.count - 1 {
                    Button {
                        withAnimation { page += 1 }
                    } label: {
                        Text("Weiter")
                            .font(.system(size: 17, weight: .semibold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .foregroundStyle(.white)
                            .background(
                                LinearGradient(
                                    colors: [ArcaTicketsDesign.travelOcean, ArcaTicketsDesign.travelSky],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                ),
                                in: RoundedRectangle(cornerRadius: ArcaTicketsDesign.cornerRadius, style: .continuous)
                            )
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, 32)
                }
            }
        }
    }

    private func onboardingPage(
        icon: String,
        title: String,
        subtitle: String,
        showFlow: Bool,
        showGettingStarted: Bool
    ) -> some View {
        VStack(spacing: 24) {
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
                .font(.system(size: 52))
                .foregroundStyle(ArcaTicketsDesign.travelOcean)
                .symbolRenderingMode(.hierarchical)
                .symbolEffect(.bounce, value: page)

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

            if showGettingStarted {
                VStack(spacing: 12) {
                    Text("Bereit für deine erste Reise?")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.secondary)

                    Button {
                        OnboardingStorage.requestAddTicket()
                        finish()
                    } label: {
                        Label("Erstes Ticket hinzufügen", systemImage: "plus.circle.fill")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(ArcaTicketsDesign.travelOcean)

                    Button {
                        OnboardingStorage.requestContacts()
                        finish()
                    } label: {
                        Label("Wichtige Nummern einrichten", systemImage: "phone.fill")
                            .font(.subheadline.weight(.semibold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                    }
                    .buttonStyle(.bordered)

                    Button("Später — App entdecken") {
                        finish()
                    }
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .padding(.top, 4)
                }
                .padding(.horizontal, 28)
            }

            Spacer()
            if !showGettingStarted { Spacer() }
        }
    }

    private func flowChip(_ label: String, icon: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.caption.weight(.semibold))
            Text(label)
                .font(.caption.weight(.semibold))
        }
        .foregroundStyle(ArcaTicketsDesign.travelOcean)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(ArcaTicketsDesign.travelOcean.opacity(0.12), in: Capsule())
    }

    private func finish() {
        OnboardingStorage.markCompleted()
        NotificationManager.requestAuthorizationIfNeeded()
        withAnimation { isPresented = false }
    }
}
