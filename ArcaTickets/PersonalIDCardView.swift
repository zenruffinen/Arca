//
//  PersonalIDCardView.swift
//  ArcaTickets
//
//  Entwickler: Hans zen Ruffinen
//

import SwiftUI

struct PersonalIDCardView: View {
    @EnvironmentObject private var store: TicketStore
    @State private var isExpanded = false
    @State private var showEditor = false

    @State private var localCard: PersonalIDCard

    init(card: PersonalIDCard? = nil) {
        _localCard = State(initialValue: card ?? .empty)
    }

    private var card: PersonalIDCard { store.personalIDCard }

    var body: some View {
        VStack(spacing: 0) {
            collapsedHeader

            if isExpanded {
                expandedContent
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .boardingPassCard(tint: ArcaTicketsDesign.travelOcean)
        .animation(.spring(response: 0.38, dampingFraction: 0.82), value: isExpanded)
        .onChange(of: store.personalIDCard) { _, updated in
            localCard = updated
        }
        .sheet(isPresented: $showEditor) {
            PersonalIDCardEditorView(card: card)
        }
    }

    private var collapsedHeader: some View {
        Button {
            withAnimation(.spring(response: 0.38, dampingFraction: 0.82)) {
                isExpanded.toggle()
            }
            TicketsHaptics.lightImpact()
        } label: {
            HStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [ArcaTicketsDesign.travelOcean, ArcaTicketsDesign.travelSky],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 44, height: 32)
                    Image(systemName: "person.text.rectangle.fill")
                        .font(.body.weight(.semibold))
                        .foregroundStyle(.white)
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text("Meine Visitenkarte")
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundStyle(.primary)
                    Text(card.isConfigured
                         ? card.displayName
                         : "Für den Notfall griffbereit")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Spacer(minLength: 0)

                Text(isExpanded ? "Einklappen" : "Ausklappen")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(ArcaTicketsDesign.travelOcean)

                Image(systemName: "chevron.right")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(ArcaTicketsDesign.travelOcean)
                    .rotationEffect(.degrees(isExpanded ? 90 : 0))
            }
            .padding(16)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Meine Visitenkarte, \(isExpanded ? "einklappen" : "ausklappen")")
    }

    @ViewBuilder
    private var expandedContent: some View {
        VStack(spacing: 0) {
            perforatedDivider

            VStack(alignment: .leading, spacing: 14) {
                idFieldRow(label: "Name", value: card.name, icon: "person.fill")
                idFieldRow(label: "Passnummer", value: card.passportNumber, icon: "airplane.departure")
                idFieldRow(label: "AHV-Nummer", value: card.ahvNumber, icon: "number")

                if let nationality = card.nationality, !nationality.isEmpty {
                    idFieldRow(label: "Nationalität", value: nationality, icon: "globe")
                }
                if let birthDate = card.birthDate {
                    idFieldRow(
                        label: "Geburtsdatum",
                        value: birthDate.formatted(date: .abbreviated, time: .omitted),
                        icon: "calendar"
                    )
                }
                if let bloodType = card.bloodType, !bloodType.isEmpty {
                    idFieldRow(label: "Blutgruppe", value: bloodType, icon: "drop.fill")
                }

                if !card.isConfigured {
                    Text("Trage deine wichtigsten Daten ein — im Notfall schnell vorzeigen.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.leading)
                }

                Button {
                    showEditor = true
                } label: {
                    Label("Bearbeiten", systemImage: "pencil")
                        .font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .foregroundStyle(ArcaTicketsDesign.travelOcean)
                        .background(ArcaTicketsDesign.travelOcean.opacity(0.1), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                }
                .buttonStyle(.plain)
            }
            .padding(16)
        }
    }

    private func idFieldRow(label: String, value: String, icon: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(ArcaTicketsDesign.travelOcean)
                .frame(width: 22)

            VStack(alignment: .leading, spacing: 2) {
                Text(label.uppercased())
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(.secondary)
                    .tracking(0.6)
                Text(value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "—" : value)
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .foregroundStyle(value.isEmpty ? .tertiary : .primary)
            }

            Spacer(minLength: 0)
        }
    }

    private var perforatedDivider: some View {
        HStack(spacing: 6) {
            ForEach(0..<20, id: \.self) { _ in
                Circle()
                    .fill(Color(.separator).opacity(0.5))
                    .frame(width: 4, height: 4)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 6)
        .background(Color(.separator).opacity(0.08))
    }
}

struct PersonalIDCardEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var store: TicketStore

    @State private var name: String
    @State private var passportNumber: String
    @State private var ahvNumber: String
    @State private var nationality: String
    @State private var hasBirthDate: Bool
    @State private var birthDate: Date
    @State private var bloodType: String

    init(card: PersonalIDCard) {
        _name = State(initialValue: card.name)
        _passportNumber = State(initialValue: card.passportNumber)
        _ahvNumber = State(initialValue: card.ahvNumber)
        _nationality = State(initialValue: card.nationality ?? "")
        _hasBirthDate = State(initialValue: card.birthDate != nil)
        _birthDate = State(initialValue: card.birthDate ?? Date())
        _bloodType = State(initialValue: card.bloodType ?? "")
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Vollständiger Name", text: $name)
                    TextField("Passnummer", text: $passportNumber)
                        .textInputAutocapitalization(.characters)
                    TextField("AHV-Nummer", text: $ahvNumber)
                        .keyboardType(.numbersAndPunctuation)
                } header: {
                    Text("Pflichtangaben")
                } footer: {
                    Text("Diese Daten werden in iCloud gespeichert und sind durch die App-Sperre geschützt.")
                }

                Section("Optional") {
                    TextField("Nationalität", text: $nationality)
                    Toggle("Geburtsdatum", isOn: $hasBirthDate.animation())
                    if hasBirthDate {
                        DatePicker("Datum", selection: $birthDate, displayedComponents: .date)
                    }
                    TextField("Blutgruppe", text: $bloodType)
                }
            }
            .navigationTitle("Visitenkarte")
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
        }
    }

    private func save() {
        let card = PersonalIDCard(
            name: name.trimmingCharacters(in: .whitespacesAndNewlines),
            passportNumber: passportNumber.trimmingCharacters(in: .whitespacesAndNewlines),
            ahvNumber: ahvNumber.trimmingCharacters(in: .whitespacesAndNewlines),
            nationality: nationality.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : nationality,
            birthDate: hasBirthDate ? birthDate : nil,
            bloodType: bloodType.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : bloodType
        )
        store.updatePersonalIDCard(card)
        TicketsHaptics.lightImpact()
    }
}
