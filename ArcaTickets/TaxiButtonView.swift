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
            klecksGraphic
        }
        .buttonStyle(.plain)
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

    private var klecksGraphic: some View {
        ZStack {
            KlecksBlobShape()
                .fill(
                    RadialGradient(
                        colors: [
                            ArcaTicketsDesign.taxiYellow.opacity(0.32),
                            ArcaTicketsDesign.taxiYellowDeep.opacity(0.16),
                            Color.clear
                        ],
                        center: .center,
                        startRadius: 4,
                        endRadius: 44
                    )
                )
                .frame(width: 86, height: 82)
                .blur(radius: 4)

            KlecksBlobShape()
                .fill(.ultraThinMaterial)
                .frame(width: 76, height: 72)
                .overlay {
                    KlecksBlobShape()
                        .stroke(
                            LinearGradient(
                                colors: [
                                    ArcaTicketsDesign.taxiYellow.opacity(0.7),
                                    ArcaTicketsDesign.taxiYellowDeep.opacity(0.45)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1.5
                        )
                }
                .shadow(color: ArcaTicketsDesign.taxiYellowDeep.opacity(0.22), radius: 8, y: 3)

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

                Text("Taxi")
                    .font(.system(size: 9, weight: .black, design: .rounded))
                    .foregroundStyle(ArcaTicketsDesign.taxiYellowDeep)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            .rotationEffect(.degrees(tilt))
        }
        .frame(width: 80, height: 78)
        .rotationEffect(.degrees(tilt))
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
