//
//  TaxiButtonView.swift
//  ArcaTickets
//
//  Entwickler: Hans zen Ruffinen
//

import SwiftUI

enum TaxiContactSlot: String, Identifiable {
    case vacation
    case home

    var id: String { rawValue }

    var navigationTitle: String {
        switch self {
        case .vacation: return "Taxi im Urlaub"
        case .home: return "Taxi diheime"
        }
    }

    var sectionTitle: String {
        switch self {
        case .vacation: return "Unterwegs"
        case .home: return "Dihei"
        }
    }

    var phonePlaceholder: String {
        switch self {
        case .vacation: return "Nummer am Ferienort"
        case .home: return "Nummer dihei"
        }
    }

    var labelPlaceholder: String {
        switch self {
        case .vacation: return "Name vom Taxi (optional)"
        case .home: return "z.B. Züri-Taxi (optional)"
        }
    }

    var footer: String {
        switch self {
        case .vacation: return "Einisch iträge — danach reicht ein Tap zum Aarufe, wenn's im Urlaub pressiert."
        case .home: return "Für wenn's dihei eilig isch — ein Tap und s'Taxi chunnt."
        }
    }

    var emptyCallLabel: String {
        switch self {
        case .vacation: return "Taxinummer iträge"
        case .home: return "Dihei-Nummer iträge"
        }
    }

    var defaultDisplayName: String {
        switch self {
        case .vacation: return "Taxi"
        case .home: return "Taxi diheime"
        }
    }
}

struct TaxiButtonView: View {
    @EnvironmentObject private var store: TicketStore
    @State private var showEditSheet = false

    private var contact: TaxiContact { store.taxiContact }

    var body: some View {
        Button {
            handleTap()
        } label: {
            klecksGraphic
                .unterwegsKlecksTapTarget()
        }
        .buttonStyle(UnterwegsKlecksButtonStyle())
        .simultaneousGesture(
            LongPressGesture(minimumDuration: 0.45).onEnded { _ in
                TicketsHaptics.lightImpact()
                showEditSheet = true
            }
        )
        .contextMenu {
            Button {
                showEditSheet = true
            } label: {
                Label("Taxinummer bearbeite", systemImage: "pencil")
            }
        }
        .accessibilityLabel(contact.hasPhoneNumber
            ? "Taxi rufen, \(contact.displayCompanyName), \(contact.displayPhoneNumber)"
            : "Taxi, Taxinummer iträge")
        .accessibilityHint(contact.hasPhoneNumber ? "Aarufe" : "Nummer iträge")
        .sheet(isPresented: $showEditSheet) {
            TaxiContactEditorView(slot: .vacation)
        }
    }

    private var klecksGraphic: some View {
        UnterwegsKlecksGlass {
            VStack(spacing: 2) {
                Image(systemName: "car.side.fill")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [ArcaTicketsDesign.taxiYellow, ArcaTicketsDesign.taxiYellowDeep],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .symbolRenderingMode(.hierarchical)
                Text("Taxi CH")
                    .unterwegsKlecksLabel()
            }
        }
    }

    private func handleTap() {
        if let url = contact.telURL {
            TicketsHaptics.mediumImpact()
            UIApplication.shared.open(url)
        } else {
            TicketsHaptics.lightImpact()
            showEditSheet = true
        }
    }
}

struct TaxiContactEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var store: TicketStore

    var slot: TaxiContactSlot = .vacation

    @State private var companyName = ""
    @State private var phoneNumber = ""

    private var storedContact: TaxiContact {
        switch slot {
        case .vacation: return store.taxiContact
        case .home: return store.homeTaxiContact
        }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField(slot.phonePlaceholder, text: $phoneNumber)
                        .keyboardType(.phonePad)
                        .textContentType(.telephoneNumber)
                    TextField(slot.labelPlaceholder, text: $companyName)
                        .textContentType(.organizationName)
                } header: {
                    Text(slot.sectionTitle)
                } footer: {
                    Text(slot.footer)
                }
            }
            .navigationTitle(slot.navigationTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(ArcaTicketsStrings.cancel) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(ArcaTicketsStrings.save) {
                        save()
                        dismiss()
                    }
                    .disabled(phoneNumber.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .onAppear {
                companyName = storedContact.companyName
                phoneNumber = storedContact.phoneNumber
            }
        }
        .presentationDetents([.height(300)])
    }

    private func save() {
        let contact = TaxiContact(
            companyName: companyName.trimmingCharacters(in: .whitespacesAndNewlines),
            phoneNumber: phoneNumber.trimmingCharacters(in: .whitespacesAndNewlines)
        )
        switch slot {
        case .vacation:
            store.updateTaxiContact(contact)
        case .home:
            store.updateHomeTaxiContact(contact)
        }
        TicketsHaptics.lightImpact()
    }
}
