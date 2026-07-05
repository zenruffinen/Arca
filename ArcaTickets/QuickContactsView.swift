//
//  QuickContactsView.swift
//  ArcaTickets
//
//  Entwickler: Hans zen Ruffinen
//

import SwiftUI

struct QuickContactsSection: View {
    @EnvironmentObject private var store: TicketStore
    @State private var contactToEdit: QuickContact?
    @State private var showManageAll = false

    private var groupedContacts: [(QuickContactCategory, [QuickContact])] {
        store.quickContactsGroupedByCategory()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("Wichtige Nummern", systemImage: "phone.fill")
                    .font(.system(size: 17, weight: .semibold, design: .rounded))
                Spacer()
                Button("Verwalten") {
                    showManageAll = true
                }
                .font(.subheadline.weight(.medium))
                .ticketsMinTapTarget()
            }
            .padding(.horizontal, 4)

            if groupedContacts.isEmpty {
                emptyHint
            } else {
                VStack(spacing: 16) {
                    ForEach(groupedContacts, id: \.0) { category, contacts in
                        categoryGroup(category: category, contacts: contacts)
                    }
                }
            }
        }
        .sheet(item: $contactToEdit) { contact in
            QuickContactEditorView(contact: contact)
        }
        .sheet(isPresented: $showManageAll) {
            QuickContactsManagementView()
        }
    }

    private var emptyHint: some View {
        VStack(spacing: 8) {
            Text("Polizei, Hotel, Flug — ein Tap zum Anrufen.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Button("Nummern hinzufügen") {
                showManageAll = true
            }
            .font(.subheadline.weight(.semibold))
            .ticketsMinTapTarget()
        }
        .frame(maxWidth: .infinity)
        .padding(20)
        .boardingPassCard()
    }

    private func categoryGroup(category: QuickContactCategory, contacts: [QuickContact]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: category.icon)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(ArcaTicketsDesign.tint(for: category.tintName))
                Text(category.rawValue)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)
                    .tracking(0.8)
            }
            .padding(.horizontal, 4)

            VStack(spacing: 0) {
                ForEach(Array(contacts.enumerated()), id: \.element.id) { index, contact in
                    QuickContactRow(contact: contact) {
                        handleTap(on: contact)
                    }
                    if index < contacts.count - 1 {
                        Divider()
                            .padding(.leading, 52)
                    }
                }
            }
            .boardingPassCard(tint: ArcaTicketsDesign.tint(for: category.tintName))
        }
    }

    private func handleTap(on contact: QuickContact) {
        if let url = contact.telURL {
            TicketsHaptics.lightImpact()
            UIApplication.shared.open(url)
        } else {
            contactToEdit = contact
        }
    }
}

struct QuickContactRow: View {
    let contact: QuickContact
    var action: () -> Void

    private var tint: Color {
        ArcaTicketsDesign.tint(for: contact.category.tintName)
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: "phone.circle.fill")
                    .font(.title2)
                    .foregroundStyle(contact.hasPhoneNumber ? tint : .secondary)

                VStack(alignment: .leading, spacing: 2) {
                    Text(contact.label)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.primary)
                    if let policy = contact.displayPolicyNumber {
                        Text("Polizzen-Nr. \(policy)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Text(contact.displayPhoneNumber)
                        .font(.subheadline)
                        .foregroundStyle(contact.hasPhoneNumber ? .secondary : tint)
                }

                Spacer(minLength: 0)

                if contact.hasPhoneNumber {
                    Image(systemName: "phone.arrow.up.right")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(tint)
                } else {
                    Image(systemName: "pencil")
                        .font(.subheadline)
                        .foregroundStyle(.tertiary)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .frame(minHeight: 44)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(contact.label), \(contact.displayPhoneNumber)")
        .accessibilityHint(contact.hasPhoneNumber ? "Anrufen" : "Nummer eintragen")
    }
}

struct QuickContactsManagementView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var store: TicketStore

    @State private var contactToEdit: QuickContact?
    @State private var showAddSheet = false
    @State private var showTemplatePicker = false

    private var groupedContacts: [(QuickContactCategory, [QuickContact])] {
        store.quickContactsGroupedByCategory()
    }

    var body: some View {
        NavigationStack {
            List {
                if groupedContacts.isEmpty {
                    Section {
                        ContentUnavailableView(
                            "Keine Nummern",
                            systemImage: "phone.slash",
                            description: Text("Füge wichtige Kontakte hinzu — per Vorlage oder manuell.")
                        )
                    }
                } else {
                    ForEach(groupedContacts, id: \.0) { category, contacts in
                        Section {
                            ForEach(contacts) { contact in
                                Button {
                                    contactToEdit = contact
                                } label: {
                                    QuickContactListRow(contact: contact)
                                }
                                .foregroundStyle(.primary)
                            }
                            .onDelete { offsets in
                                deleteContacts(in: contacts, at: offsets)
                            }
                        } header: {
                            Label(category.rawValue, systemImage: category.icon)
                        }
                    }
                }

                Section {
                    Button {
                        showAddSheet = true
                    } label: {
                        Label("Kontakt hinzufügen", systemImage: "plus.circle.fill")
                    }

                    if !store.availableQuickContactTemplates.isEmpty {
                        Button {
                            showTemplatePicker = true
                        } label: {
                            Label("Aus Vorlage hinzufügen", systemImage: "doc.on.doc")
                        }
                    }
                }

                Section {
                    Button("Standard-Vorlagen wiederherstellen", role: .destructive) {
                        store.resetQuickContactsToDefaults()
                    }
                } footer: {
                    Text("Schweizer Notrufnummern: Polizei 117, Feuer 118, Rettung 144, EU 112.")
                }
            }
            .navigationTitle("Wichtige Nummern")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Fertig") { dismiss() }
                }
            }
            .sheet(item: $contactToEdit) { contact in
                QuickContactEditorView(contact: contact)
            }
            .sheet(isPresented: $showAddSheet) {
                QuickContactEditorView(contact: nil)
            }
            .sheet(isPresented: $showTemplatePicker) {
                QuickContactTemplatePickerView()
            }
        }
    }

    private func deleteContacts(in contacts: [QuickContact], at offsets: IndexSet) {
        for index in offsets {
            store.deleteQuickContact(contacts[index])
        }
    }
}

private struct QuickContactListRow: View {
    let contact: QuickContact

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: contact.category.icon)
                .foregroundStyle(ArcaTicketsDesign.tint(for: contact.category.tintName))
                .frame(width: 24)
            VStack(alignment: .leading, spacing: 2) {
                Text(contact.label)
                    .font(.body.weight(.medium))
                if let policy = contact.displayPolicyNumber {
                    Text("Polizzen-Nr. \(policy)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Text(contact.displayPhoneNumber)
                    .font(.caption)
                    .foregroundStyle(contact.hasPhoneNumber ? .secondary : Color.orange)
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
    }
}

struct QuickContactEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var store: TicketStore

    private let existingID: UUID?

    @State private var label: String
    @State private var phoneNumber: String
    @State private var category: QuickContactCategory
    @State private var policyNumber: String
    @State private var insuranceType: InsuranceType?

    init(contact: QuickContact?) {
        existingID = contact?.id
        _label = State(initialValue: contact?.label ?? "")
        _phoneNumber = State(initialValue: contact?.phoneNumber ?? "")
        _category = State(initialValue: contact?.category ?? .sonstiges)
        _policyNumber = State(initialValue: contact?.policyNumber ?? "")
        _insuranceType = State(initialValue: contact?.insuranceType)
    }

    private var isEditing: Bool { existingID != nil }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Name", text: $label)
                    TextField("Telefonnummer", text: $phoneNumber)
                        .keyboardType(.phonePad)
                        .textContentType(.telephoneNumber)
                } header: {
                    Text("Kontakt")
                }

                Section {
                    Picker("Kategorie", selection: $category) {
                        ForEach(QuickContactCategory.allCases) { cat in
                            Label(cat.rawValue, systemImage: cat.icon)
                                .tag(cat)
                        }
                    }
                } header: {
                    Text("Kategorie")
                } footer: {
                    Text("Notfall-Nummern wie Polizei (117) und Rettung (144) sind vorausgefüllt.")
                }

                if category == .versicherung {
                    Section {
                        Picker("Versicherungsart", selection: $insuranceType) {
                            Text("Keine Angabe").tag(InsuranceType?.none)
                            ForEach(InsuranceType.allCases) { type in
                                Label(type.rawValue, systemImage: type.icon)
                                    .tag(Optional(type))
                            }
                        }
                        TextField("Polizzen-Nummer", text: $policyNumber)
                            .textInputAutocapitalization(.characters)
                    } header: {
                        Text("Versicherung")
                    } footer: {
                        Text("Polizzen-Nummer für den Notfall griffbereit — z. B. auf dem Tab „Notfall“.")
                    }
                }
            }
            .navigationTitle(isEditing ? "Kontakt bearbeiten" : "Neuer Kontakt")
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
                    .disabled(label.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    private func save() {
        let trimmedLabel = label.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedPhone = phoneNumber.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedPolicy = policyNumber.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedLabel.isEmpty else { return }

        let resolvedPolicy = trimmedPolicy.isEmpty ? nil : trimmedPolicy
        let resolvedInsuranceType = category == .versicherung ? insuranceType : nil

        if let existingID,
           var existing = store.quickContacts.first(where: { $0.id == existingID }) {
            existing.label = trimmedLabel
            existing.phoneNumber = trimmedPhone
            existing.category = category
            existing.policyNumber = resolvedPolicy
            existing.insuranceType = resolvedInsuranceType
            store.updateQuickContact(existing)
        } else {
            store.addQuickContact(QuickContact(
                label: trimmedLabel,
                phoneNumber: trimmedPhone,
                category: category,
                policyNumber: resolvedPolicy,
                insuranceType: resolvedInsuranceType
            ))
        }
        TicketsHaptics.lightImpact()
    }
}

struct QuickContactTemplatePickerView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var store: TicketStore

    var body: some View {
        NavigationStack {
            List {
                ForEach(QuickContactCategory.allCases.sorted(by: { $0.displayOrder < $1.displayOrder })) { category in
                    let templates = store.availableQuickContactTemplates.filter { $0.category == category }
                    if !templates.isEmpty {
                        Section {
                            ForEach(templates) { template in
                                Button {
                                    store.addQuickContactFromTemplate(template)
                                    TicketsHaptics.lightImpact()
                                    dismiss()
                                } label: {
                                    HStack {
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(template.label)
                                                .font(.body.weight(.medium))
                                            if !template.phoneNumber.isEmpty {
                                                Text(template.phoneNumber)
                                                    .font(.caption)
                                                    .foregroundStyle(.secondary)
                                            } else {
                                                Text("Nummer später eintragen")
                                                    .font(.caption)
                                                    .foregroundStyle(.secondary)
                                            }
                                        }
                                        Spacer()
                                        Image(systemName: "plus.circle.fill")
                                            .foregroundStyle(ArcaTicketsDesign.travelOcean)
                                    }
                                }
                                .foregroundStyle(.primary)
                            }
                        } header: {
                            Label(category.rawValue, systemImage: category.icon)
                        }
                    }
                }
            }
            .navigationTitle("Vorlage wählen")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Abbrechen") { dismiss() }
                }
            }
        }
    }
}
