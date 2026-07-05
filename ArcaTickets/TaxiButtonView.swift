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
            HStack(spacing: 14) {
                comicCarIcon

                VStack(alignment: .leading, spacing: 3) {
                    Text("Taxi rufen")
                        .font(.system(size: 17, weight: .bold, design: .rounded))
                        .foregroundStyle(.primary)

                    if contact.hasPhoneNumber {
                        Text(contact.displayCompanyName)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(ArcaTicketsDesign.taxiYellowDeep)
                        Text(contact.displayPhoneNumber)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else {
                        Text("Taxinummer eintragen")
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(ArcaTicketsDesign.taxiYellowDeep)
                    }
                }

                Spacer(minLength: 0)

                Image(systemName: contact.hasPhoneNumber ? "phone.arrow.up.right.circle.fill" : "pencil.circle.fill")
                    .font(.title2)
                    .foregroundStyle(
                        contact.hasPhoneNumber
                            ? ArcaTicketsDesign.taxiYellowDeep
                            : ArcaTicketsDesign.taxiYellow.opacity(0.85)
                    )
                    .symbolEffect(.bounce, value: contact.hasPhoneNumber)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background { taxiCardBackground }
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button {
                showEditSheet = true
            } label: {
                Label("Taxinummer bearbeiten", systemImage: "pencil")
            }
        }
        .accessibilityLabel(contact.hasPhoneNumber
            ? "Taxi rufen, \(contact.displayCompanyName), \(contact.displayPhoneNumber)"
            : "Taxi rufen, Taxinummer eintragen")
        .accessibilityHint(contact.hasPhoneNumber ? "Anrufen" : "Nummer eintragen")
        .sheet(isPresented: $showEditSheet) {
            TaxiContactEditorView()
        }
    }

    private var comicCarIcon: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            ArcaTicketsDesign.taxiYellow.opacity(0.35),
                            ArcaTicketsDesign.taxiYellowDeep.opacity(0.22)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 58, height: 52)
                .rotationEffect(.degrees(-8))
                .shadow(color: ArcaTicketsDesign.taxiYellowDeep.opacity(0.35), radius: 6, y: 4)

            Image(systemName: "car.side.fill")
                .font(.system(size: 30, weight: .bold))
                .foregroundStyle(
                    LinearGradient(
                        colors: [ArcaTicketsDesign.taxiYellow, ArcaTicketsDesign.taxiYellowDeep],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .rotationEffect(.degrees(-8))
                .shadow(color: .black.opacity(0.18), radius: 2, y: 2)
        }
        .frame(width: 64, height: 56)
        .accessibilityHidden(true)
    }

    private var taxiCardBackground: some View {
        RoundedRectangle(cornerRadius: ArcaTicketsDesign.cornerRadius, style: .continuous)
            .fill(.ultraThinMaterial)
            .overlay {
                RoundedRectangle(cornerRadius: ArcaTicketsDesign.cornerRadius, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                ArcaTicketsDesign.taxiYellow.opacity(0.22),
                                ArcaTicketsDesign.travelSand.opacity(0.18)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }
            .overlay {
                RoundedRectangle(cornerRadius: ArcaTicketsDesign.cornerRadius, style: .continuous)
                    .strokeBorder(
                        LinearGradient(
                            colors: [
                                ArcaTicketsDesign.taxiYellow.opacity(0.55),
                                ArcaTicketsDesign.taxiYellowDeep.opacity(0.25)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1.5
                    )
            }
            .shadow(color: ArcaTicketsDesign.taxiYellowDeep.opacity(0.18), radius: 10, y: 5)
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
                    TextField("Taxiunternehmen", text: $companyName)
                        .textContentType(.organizationName)
                    TextField("Telefonnummer", text: $phoneNumber)
                        .keyboardType(.phonePad)
                        .textContentType(.telephoneNumber)
                } header: {
                    Text("Taxi")
                } footer: {
                    Text("Dein lokales Taxi — ein Tap auf „Unterwegs“ genügt zum Anrufen.")
                }
            }
            .navigationTitle("Taxi eintragen")
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
                companyName = store.taxiContact.companyName
                phoneNumber = store.taxiContact.phoneNumber
            }
        }
        .presentationDetents([.medium])
    }

    private func save() {
        store.updateTaxiContact(TaxiContact(
            companyName: companyName.trimmingCharacters(in: .whitespacesAndNewlines),
            phoneNumber: phoneNumber.trimmingCharacters(in: .whitespacesAndNewlines)
        ))
        TicketsHaptics.lightImpact()
    }
}
