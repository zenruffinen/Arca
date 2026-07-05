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

    private var contact: GolfContact { store.golfContact }

    private var bergeTicketCount: Int {
        store.tickets.filter { $0.folder == "Berge" }.count
    }

    var body: some View {
        Button {
            handleTap()
        } label: {
            TravelGolfDecoration()
        }
        .buttonStyle(.plain)
        .onLongPressGesture(minimumDuration: 0.45) {
            TicketsHaptics.lightImpact()
            showEditSheet = true
        }
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

    private var accessibilityLabel: String {
        if contact.hasPhoneNumber {
            return "Golf, \(contact.displayClubName), \(contact.displayPhoneNumber)"
        }
        if bergeTicketCount > 0 {
            return "Golf, \(bergeTicketCount) Berge-Tickets, Greenfee-Nummer eintragen"
        }
        return "Golf, Greenfee-Nummer eintragen"
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
