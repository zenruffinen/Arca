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
    private let tilt: Double = -10

    var body: some View {
        Button {
            handleTap()
        } label: {
            comicTaxiGraphic
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

    private var comicTaxiGraphic: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(.ultraThinMaterial)
                .frame(width: 76, height: 64)
                .overlay {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [
                                    ArcaTicketsDesign.taxiYellow.opacity(0.28),
                                    ArcaTicketsDesign.travelSand.opacity(0.14)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                }
                .overlay {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .strokeBorder(
                            LinearGradient(
                                colors: [
                                    ArcaTicketsDesign.taxiYellow.opacity(0.65),
                                    ArcaTicketsDesign.taxiYellowDeep.opacity(0.3)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1.5
                        )
                }
                .rotationEffect(.degrees(tilt))
                .shadow(color: ArcaTicketsDesign.taxiYellowDeep.opacity(0.28), radius: 8, y: 4)

            VStack(spacing: 2) {
                Text("Taxi")
                    .font(.system(size: 12, weight: .black, design: .rounded))
                    .foregroundStyle(ArcaTicketsDesign.taxiYellowDeep)
                    .shadow(color: .white.opacity(0.6), radius: 0, y: 1)

                Image(systemName: "car.side.fill")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [ArcaTicketsDesign.taxiYellow, ArcaTicketsDesign.taxiYellowDeep],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .shadow(color: .black.opacity(0.15), radius: 2, y: 2)
            }
            .rotationEffect(.degrees(tilt))
        }
        .frame(width: 88, height: 76)
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
