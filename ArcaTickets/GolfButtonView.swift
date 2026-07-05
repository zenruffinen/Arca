//
//  GolfButtonView.swift
//  ArcaTickets
//
//  Entwickler: Hans zen Ruffinen
//

import SwiftUI

struct GolfButtonView: View {
    @EnvironmentObject private var store: TicketStore
    @State private var showEditSheet = false

    var style: TravelQuickActionStyle = .card

    private var contact: GolfContact { store.golfContact }

    private var bergeTicketCount: Int {
        store.tickets.filter { $0.folder == "Berge" }.count
    }

    var body: some View {
        Button {
            handleTap()
        } label: {
            Group {
                switch style {
                case .card:
                    cardContent
                case .chip:
                    chipContent
                }
            }
            .background { actionBackground }
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button {
                showEditSheet = true
            } label: {
                Label("Golfclub bearbeiten", systemImage: "pencil")
            }
        }
        .accessibilityLabel(accessibilityLabel)
        .accessibilityHint(contact.hasPhoneNumber ? "Anrufen" : "Kontakt eintragen")
        .sheet(isPresented: $showEditSheet) {
            GolfContactEditorView()
        }
    }

    private var cardContent: some View {
        HStack(spacing: 14) {
            comicGolferIcon(size: .card)

            VStack(alignment: .leading, spacing: 3) {
                Text("Golf")
                    .font(.system(size: 17, weight: .bold, design: .rounded))
                    .foregroundStyle(.primary)

                if contact.hasPhoneNumber {
                    Text(contact.displayClubName)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(ArcaTicketsDesign.golfFairwayDeep)
                    Text(contact.displayPhoneNumber)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    Text(bergeSubtitle)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(ArcaTicketsDesign.golfFairwayDeep)
                        .lineLimit(2)
                }
            }

            Spacer(minLength: 0)

            trailingIcon
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
    }

    private var chipContent: some View {
        VStack(spacing: 8) {
            comicGolferIcon(size: .chip)

            Text("Golf")
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .foregroundStyle(.primary)
                .lineLimit(1)

            Text(chipSubtitle)
                .font(.caption2.weight(.medium))
                .foregroundStyle(ArcaTicketsDesign.golfFairwayDeep)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .minimumScaleFactor(0.85)
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 10)
        .padding(.vertical, 12)
    }

    private var trailingIcon: some View {
        Image(systemName: contact.hasPhoneNumber ? "phone.arrow.up.right.circle.fill" : "pencil.circle.fill")
            .font(.title2)
            .foregroundStyle(
                contact.hasPhoneNumber
                    ? ArcaTicketsDesign.golfFairwayDeep
                    : ArcaTicketsDesign.golfFairway.opacity(0.85)
            )
            .symbolEffect(.bounce, value: contact.hasPhoneNumber)
    }

    private var bergeSubtitle: String {
        if bergeTicketCount > 0 {
            return "\(bergeTicketCount) Berge-Ticket\(bergeTicketCount == 1 ? "" : "s") — Greenfee eintragen"
        }
        return "Greenfee-Nummer eintragen"
    }

    private var chipSubtitle: String {
        if contact.hasPhoneNumber {
            return contact.displayClubName
        }
        if bergeTicketCount > 0 {
            return "\(bergeTicketCount) in Berge"
        }
        return "Wallis-Feeling"
    }

    private var accessibilityLabel: String {
        if contact.hasPhoneNumber {
            return "Golf, \(contact.displayClubName), \(contact.displayPhoneNumber)"
        }
        if bergeTicketCount > 0 {
            return "Golf, \(bergeTicketCount) Berge-Tickets, Greenfee-Nummer eintragen"
        }
        return "Golf, Greenfee-Nummer eintragen"
    }

    private var actionBackground: some View {
        RoundedRectangle(cornerRadius: style == .chip ? ArcaTicketsDesign.chipRadius : ArcaTicketsDesign.cornerRadius, style: .continuous)
            .fill(.ultraThinMaterial)
            .overlay {
                RoundedRectangle(cornerRadius: style == .chip ? ArcaTicketsDesign.chipRadius : ArcaTicketsDesign.cornerRadius, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                ArcaTicketsDesign.golfCyan.opacity(0.20),
                                ArcaTicketsDesign.golfFairway.opacity(0.16)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }
            .overlay {
                RoundedRectangle(cornerRadius: style == .chip ? ArcaTicketsDesign.chipRadius : ArcaTicketsDesign.cornerRadius, style: .continuous)
                    .strokeBorder(
                        LinearGradient(
                            colors: [
                                ArcaTicketsDesign.golfCyan.opacity(0.55),
                                ArcaTicketsDesign.golfFairwayDeep.opacity(0.28)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1.5
                    )
            }
            .shadow(color: ArcaTicketsDesign.golfFairwayDeep.opacity(0.16), radius: style == .chip ? 6 : 10, y: style == .chip ? 3 : 5)
    }

    private func comicGolferIcon(size: TravelQuickActionIconSize) -> some View {
        let tile = size == .card ? CGSize(width: 58, height: 52) : CGSize(width: 46, height: 42)
        let iconFont: Font = size == .card ? .system(size: 30, weight: .bold) : .system(size: 24, weight: .bold)
        let frame = size == .card ? CGSize(width: 64, height: 56) : CGSize(width: 50, height: 46)
        let tilt: Double = size == .card ? 7 : 8

        return ZStack {
            Circle()
                .fill(
                    LinearGradient(
                        colors: [
                            ArcaTicketsDesign.golfCyan.opacity(0.38),
                            ArcaTicketsDesign.golfFairway.opacity(0.24)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: tile.width, height: tile.height)
                .rotationEffect(.degrees(tilt))
                .shadow(color: ArcaTicketsDesign.golfFairwayDeep.opacity(0.32), radius: 5, y: 3)

            Image(systemName: "figure.golf")
                .font(iconFont)
                .foregroundStyle(
                    LinearGradient(
                        colors: [ArcaTicketsDesign.golfCyan, ArcaTicketsDesign.golfFairwayDeep],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .rotationEffect(.degrees(tilt))
                .shadow(color: .black.opacity(0.16), radius: 2, y: 2)
        }
        .frame(width: frame.width, height: frame.height)
        .accessibilityHidden(true)
    }

    private func handleTap() {
        if let url = contact.telURL {
            TicketsHaptics.mediumImpact()
            UIApplication.shared.open(url)
        } else {
            showEditSheet = true
        }
    }
}

struct GolfContactEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var store: TicketStore

    @State private var clubName = ""
    @State private var phoneNumber = ""

    private var bergeTicketCount: Int {
        store.tickets.filter { $0.folder == "Berge" }.count
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Golfclub", text: $clubName)
                        .textContentType(.organizationName)
                    TextField("Telefonnummer", text: $phoneNumber)
                        .keyboardType(.phonePad)
                        .textContentType(.telephoneNumber)
                } header: {
                    Text("Golf")
                } footer: {
                    if bergeTicketCount > 0 {
                        Text("Du hast \(bergeTicketCount) Ticket\(bergeTicketCount == 1 ? "" : "s") im Ordner „Berge“. Pinne Greenfee oder Saisonkarten dort — ein Tap auf „Unterwegs“ genügt zum Anrufen.")
                    } else {
                        Text("Dein Golfclub im Wallis — Greenfee oder Pro-Shop, ein Tap auf „Unterwegs“ genügt zum Anrufen.")
                    }
                }
            }
            .navigationTitle("Golf eintragen")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Abbrechen") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Speichern") {
                        save()
                        dismiss()
                    }
                }
            }
            .onAppear {
                clubName = store.golfContact.clubName
                phoneNumber = store.golfContact.phoneNumber
            }
        }
        .presentationDetents([.medium])
    }

    private func save() {
        store.updateGolfContact(GolfContact(
            clubName: clubName.trimmingCharacters(in: .whitespacesAndNewlines),
            phoneNumber: phoneNumber.trimmingCharacters(in: .whitespacesAndNewlines)
        ))
        TicketsHaptics.lightImpact()
    }
}
