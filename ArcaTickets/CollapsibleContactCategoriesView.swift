//
//  CollapsibleContactCategoriesView.swift
//  ArcaTickets
//
//  Entwickler: Hans zen Ruffinen
//

import SwiftUI

struct CollapsibleContactCategoriesView: View {
    @EnvironmentObject private var store: TicketStore

    let title: String
    let defaultExpanded: Set<QuickContactCategory>

    @State private var expandedCategories: Set<QuickContactCategory>
    @State private var contactToEdit: QuickContact?
    @State private var newContactCategory: QuickContactCategory?

    private var groupedContacts: [(QuickContactCategory, [QuickContact])] {
        store.quickContactsGroupedByCategory()
    }

    init(title: String, defaultExpanded: Set<QuickContactCategory> = []) {
        self.title = title
        self.defaultExpanded = defaultExpanded
        _expandedCategories = State(initialValue: defaultExpanded)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label(title, systemImage: "phone.fill")
                .font(.system(size: 17, weight: .semibold, design: .rounded))
                .padding(.horizontal, 4)

            if groupedContacts.isEmpty {
                emptyHint
            } else {
                VStack(spacing: 10) {
                    ForEach(groupedContacts, id: \.0) { category, contacts in
                        categoryDisclosure(category: category, contacts: contacts)
                    }
                }
            }
        }
        .sheet(item: $contactToEdit) { contact in
            QuickContactEditorView(contact: contact)
        }
        .sheet(item: $newContactCategory) { category in
            QuickContactEditorView(contact: nil, defaultCategory: category)
        }
    }

    private var emptyHint: some View {
        VStack(spacing: 8) {
            Text("Polizei, Hotel, Versicherig — ein Tap zum Aarufe.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(20)
        .boardingPassCard()
    }

    private func categoryDisclosure(category: QuickContactCategory, contacts: [QuickContact]) -> some View {
        DisclosureGroup(
            isExpanded: Binding(
                get: { expandedCategories.contains(category) },
                set: { expanded in
                    if expanded {
                        expandedCategories.insert(category)
                    } else {
                        expandedCategories.remove(category)
                    }
                }
            )
        ) {
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

                if category == .familie {
                    Divider()
                        .padding(.leading, 52)
                    Button {
                        newContactCategory = .familie
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: "plus.circle.fill")
                                .font(.title2)
                                .foregroundStyle(ArcaTicketsDesign.tint(for: category.tintName))
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Familiemitglied hinzufüege")
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundStyle(ArcaTicketsDesign.tint(for: category.tintName))
                                Text("No e Schwester, Bruder oder eigene/i Name")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer(minLength: 0)
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 12)
                        .frame(minHeight: 44)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.top, 4)
        } label: {
            HStack(spacing: 8) {
                Image(systemName: category.icon)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(ArcaTicketsDesign.tint(for: category.tintName))
                Text(category.rawValue)
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                Spacer(minLength: 0)
                Text("\(contacts.count)")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Color(.tertiarySystemFill), in: Capsule())
            }
        }
        .tint(ArcaTicketsDesign.tint(for: category.tintName))
        .padding(14)
        .background {
            RoundedRectangle(cornerRadius: ArcaTicketsDesign.chipRadius, style: .continuous)
                .fill(Color(.secondarySystemGroupedBackground))
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
