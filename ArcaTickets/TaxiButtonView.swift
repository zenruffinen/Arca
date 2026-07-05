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
            TravelTaxiDecoration()
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
                Label("Taxinummer bearbeiten", systemImage: "pencil")
            }
        }
        .accessibilityLabel(contact.hasPhoneNumber
            ? "Taxi rufen, \(contact.displayCompanyName), \(contact.displayPhoneNumber)"
            : "Taxi, Taxinummer eintragen")
        .accessibilityHint(contact.hasPhoneNumber ? "Anrufen" : "Nummer eintragen")
        .sheet(isPresented: $showEditSheet) {
            TaxiContactEditorView()
        }
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
                    Text("Einmal eintragen — danach reicht ein Tap auf das Auto zum Anrufen.")
                }
            }
            .navigationTitle("Taxinummer")
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
