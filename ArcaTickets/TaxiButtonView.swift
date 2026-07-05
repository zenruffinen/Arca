//
//  TaxiButtonView.swift
//  ArcaTickets
//
//  Entwickler: Hans zen Ruffinen
//

import SwiftUI

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
            TaxiContactEditorView()
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

    @State private var companyName = ""
    @State private var phoneNumber = ""

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Telefonnummer", text: $phoneNumber)
                        .keyboardType(.phonePad)
                        .textContentType(.telephoneNumber)
                    TextField("Taxiunternehmen (optional)", text: $companyName)
                        .textContentType(.organizationName)
                } header: {
                    Text("Taxi")
                } footer: {
                    Text("Einisch iträge — danach reicht ein Tap uf s'Auto zum Aarufe.")
                }
            }
            .navigationTitle("Taxinummer")
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
                companyName = store.taxiContact.companyName
                phoneNumber = store.taxiContact.phoneNumber
            }
        }
        .presentationDetents([.height(280)])
    }

    private func save() {
        store.updateTaxiContact(TaxiContact(
            companyName: companyName.trimmingCharacters(in: .whitespacesAndNewlines),
            phoneNumber: phoneNumber.trimmingCharacters(in: .whitespacesAndNewlines)
        ))
        TicketsHaptics.lightImpact()
    }
}
