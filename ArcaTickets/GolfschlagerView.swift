//
//  GolfschlagerView.swift
//  ArcaTickets
//
//  Entwickler: Hans zen Ruffinen
//

import SwiftUI

// MARK: - Floating Klecks (Unterwegs)

struct GolfschlagerFloatingDecoration: View {
    @EnvironmentObject private var store: TicketStore
    @State private var showSheet = false
    @State private var tagRevealed = false

    private let tilt: Double = 8
    private var contact: GolfContact { store.golfContact }
    private var travel: GolfschlaegerInfo { store.golfschlaegerInfo }

    private var hasBagTag: Bool { travel.hasBagTag }
    private var hasPhone: Bool { contact.hasPhoneNumber }

    private var displayTag: String {
        let tag = travel.displayBagTag
        guard hasBagTag else { return "" }
        return tagRevealed ? tag : String(repeating: "•", count: min(tag.count, 6))
    }

    private var comicLine: String? {
        if hasBagTag { return displayTag }
        if let snippet = contact.comicPhoneSnippet { return snippet }
        if travel.checkedIn { return "✓" }
        return nil
    }

    var body: some View {
        Button {
            TicketsHaptics.lightImpact()
            handleTap()
        } label: {
            klecksGraphic
        }
        .buttonStyle(.plain)
        .simultaneousGesture(
            LongPressGesture(minimumDuration: 0.45).onEnded { _ in
                TicketsHaptics.lightImpact()
                showSheet = true
            }
        )
        .accessibilityLabel(accessibilityLabel)
        .accessibilityHint(accessibilityHint)
        .sheet(isPresented: $showSheet) {
            GolfschlaegerSheet()
        }
        .onChange(of: store.golfschlaegerInfo) { _, _ in
            tagRevealed = false
        }
    }

    private var accessibilityLabel: String {
        var parts = ["Golfschläger"]
        if hasPhone {
            parts.append("\(contact.displayClubName), \(contact.displayPhoneNumber)")
        }
        if hasBagTag {
            parts.append("Bag-Tag, \(tagRevealed ? "sichtbar" : "verborgen")")
        }
        if travel.checkedIn {
            parts.append("eingecheckt")
        }
        return parts.joined(separator: ", ")
    }

    private var accessibilityHint: String {
        if hasPhone {
            return "Tippen zum Anrufen, gedrückt halten zum Bearbeiten"
        }
        if hasBagTag {
            return "Tippen zum Ein- oder Ausblenden, gedrückt halten zum Bearbeiten"
        }
        return "Tippen zum Eintragen"
    }

    private func handleTap() {
        if let url = contact.telURL {
            TicketsHaptics.mediumImpact()
            UIApplication.shared.open(url)
        } else if hasBagTag {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.72)) {
                tagRevealed.toggle()
            }
        } else {
            showSheet = true
        }
    }

    private var klecksGraphic: some View {
        ComicStarburstKlecks(palette: .golf, tilt: tilt) {
            VStack(spacing: 2) {
                ZStack {
                    Image(systemName: "figure.golf")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(
                            LinearGradient(
                                colors: ComicStarburstPalette.golf.icon,
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .symbolRenderingMode(.hierarchical)

                    Image(systemName: "bag.fill")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundStyle(ArcaTicketsDesign.golfFairway)
                        .offset(x: 10, y: 8)
                        .opacity(0.9)

                    if travel.checkedIn {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(ArcaTicketsDesign.golfFairway)
                            .offset(x: -10, y: -9)
                    }
                }

                if let line = comicLine, !line.isEmpty {
                    ComicCurvedText(
                        text: line,
                        style: .golfTag,
                        foreground: ComicStarburstPalette.golf.label
                    )
                    .scaleEffect(0.88)
                    .contentTransition(.numericText())

                    if hasBagTag {
                        Image(systemName: tagRevealed ? "eye.fill" : "eye.slash.fill")
                            .font(.system(size: 7, weight: .bold))
                            .foregroundStyle(ComicStarburstPalette.golf.label.opacity(0.55))
                    } else if hasPhone {
                        Image(systemName: "phone.fill")
                            .font(.system(size: 7, weight: .bold))
                            .foregroundStyle(ComicStarburstPalette.golf.label.opacity(0.55))
                    }
                } else {
                    Text("Golf")
                        .font(.system(size: 8, weight: .black, design: .rounded))
                        .foregroundStyle(ComicStarburstPalette.golf.label)
                        .lineLimit(1)
                        .minimumScaleFactor(0.65)
                }
            }
            .rotationEffect(.degrees(-tilt * 0.35))
        }
    }
}

// MARK: - Sheet

struct GolfschlaegerSheet: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var store: TicketStore

    @State private var clubName = ""
    @State private var phoneNumber = ""
    @State private var airlinePolicyNote = ""
    @State private var bagTagNumber = ""
    @State private var checkedIn = false
    @State private var note = ""

    private var bergeTicketCount: Int {
        store.tickets.filter { $0.folder == "Berge" }.count
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Golfclub", text: $clubName)
                        .textContentType(.organizationName)
                    TextField("Greenfee / Pro-Shop", text: $phoneNumber)
                        .keyboardType(.phonePad)
                        .textContentType(.telephoneNumber)
                } header: {
                    Text("Golfclub")
                } footer: {
                    if bergeTicketCount > 0 {
                        Text("Du hast \(bergeTicketCount) Ticket\(bergeTicketCount == 1 ? "" : "s") im Ordner „Berge“. Ein Tap auf den Klecks genügt zum Anrufen.")
                    } else {
                        Text("Dein Golfclub im Wallis — Greenfee oder Pro-Shop, ein Tap auf den Klecks genügt zum Anrufen.")
                    }
                }

                Section {
                    TextField("z. B. SWISS Golfbag bis 23 kg", text: $airlinePolicyNote, axis: .vertical)
                        .lineLimit(2...4)
                    TextField("Bag-Tag / PIN", text: $bagTagNumber)
                        .textInputAutocapitalization(.characters)
                    Toggle("Golfschläger eingecheckt", isOn: $checkedIn)
                    TextField("Notiz (Reminder)", text: $note, axis: .vertical)
                        .lineLimit(2...5)
                } header: {
                    Text("Golfschläger Reise")
                } footer: {
                    Text("Airline-Regeln, Bag-Tag am Flughafen und Check-in-Status — alles griffbereit wie beim Koffer-PIN.")
                }

                if !bagTagNumber.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Section {
                        ComicCurvedText(
                            text: bagTagNumber.trimmingCharacters(in: .whitespacesAndNewlines),
                            style: .golfTag,
                            foreground: ArcaTicketsDesign.golfFairwayDeep
                        )
                        .frame(maxWidth: .infinity)
                        .listRowBackground(Color(.secondarySystemGroupedBackground))
                    } header: {
                        Text("Vorschau")
                    }
                }
            }
            .navigationTitle("Golfschläger")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Abbrechen") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Sichern") {
                        save()
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
                if store.golfschlaegerInfo.hasContent {
                    ToolbarItem(placement: .bottomBar) {
                        Button("Reise-Infos löschen", role: .destructive) {
                            store.updateGolfschlaegerInfo(.empty)
                            airlinePolicyNote = ""
                            bagTagNumber = ""
                            checkedIn = false
                            note = ""
                            TicketsHaptics.lightImpact()
                        }
                    }
                }
            }
            .onAppear { loadDrafts() }
        }
        .presentationDetents([.large])
    }

    private func loadDrafts() {
        clubName = store.golfContact.clubName
        phoneNumber = store.golfContact.phoneNumber
        airlinePolicyNote = store.golfschlaegerInfo.airlinePolicyNote
        bagTagNumber = store.golfschlaegerInfo.bagTagNumber
        checkedIn = store.golfschlaegerInfo.checkedIn
        note = store.golfschlaegerInfo.note
    }

    private func save() {
        store.updateGolfContact(GolfContact(
            clubName: clubName.trimmingCharacters(in: .whitespacesAndNewlines),
            phoneNumber: phoneNumber.trimmingCharacters(in: .whitespacesAndNewlines)
        ))
        store.updateGolfschlaegerInfo(GolfschlaegerInfo(
            airlinePolicyNote: airlinePolicyNote.trimmingCharacters(in: .whitespacesAndNewlines),
            bagTagNumber: bagTagNumber.trimmingCharacters(in: .whitespacesAndNewlines),
            checkedIn: checkedIn,
            note: note.trimmingCharacters(in: .whitespacesAndNewlines)
        ))
        TicketsHaptics.mediumImpact()
    }
}
