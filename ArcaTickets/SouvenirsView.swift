//
//  SouvenirsView.swift
//  ArcaTickets
//
//  Entwickler: Hans zen Ruffinen
//

import SwiftUI

// MARK: - Floating Klecks (Unterwegs)

struct SouvenirsFloatingDecoration: View {
    @EnvironmentObject private var store: TicketStore
    @State private var showSouvenirsSheet = false

    private let tilt: Double = 7
    private var pendingCount: Int { store.opaSouvenirs.filter { !$0.isChecked }.count }

    var body: some View {
        Button {
            TicketsHaptics.lightImpact()
            showSouvenirsSheet = true
        } label: {
            klecksGraphic
        }
        .buttonStyle(.plain)
        .accessibilityLabel(pendingCount > 0
            ? "Souvenirs für Opa, \(pendingCount) offen"
            : "Souvenirs für Opa")
        .accessibilityHint("Tippen zum Öffnen")
        .sheet(isPresented: $showSouvenirsSheet) {
            SouvenirsSheet()
        }
    }

    private var klecksGraphic: some View {
        ZStack {
            KlecksBlobShape()
                .fill(
                    RadialGradient(
                        colors: [
                            Color(red: 1.0, green: 0.45, blue: 0.55).opacity(0.22),
                            ArcaTicketsDesign.travelSunset.opacity(0.14),
                            Color.clear
                        ],
                        center: .center,
                        startRadius: 4,
                        endRadius: 44
                    )
                )
                .frame(width: 82, height: 78)
                .blur(radius: 4)

            KlecksBlobShape()
                .fill(.ultraThinMaterial)
                .frame(width: 72, height: 68)
                .overlay {
                    KlecksBlobShape()
                        .stroke(
                            LinearGradient(
                                colors: [
                                    Color(red: 1.0, green: 0.45, blue: 0.55).opacity(0.7),
                                    ArcaTicketsDesign.travelSunset.opacity(0.5)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1.5
                        )
                }
                .shadow(color: Color(red: 1.0, green: 0.45, blue: 0.55).opacity(0.22), radius: 8, y: 3)

            VStack(spacing: 2) {
                ZStack(alignment: .topTrailing) {
                    Image(systemName: "gift.fill")
                        .font(.system(size: 21, weight: .semibold))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [
                                    Color(red: 1.0, green: 0.45, blue: 0.55),
                                    ArcaTicketsDesign.travelSunset
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .symbolRenderingMode(.hierarchical)

                    if pendingCount > 0 {
                        Circle()
                            .fill(Color(red: 1.0, green: 0.45, blue: 0.55))
                            .frame(width: 7, height: 7)
                            .offset(x: 4, y: -3)
                    }
                }

                Text("Für Opa")
                    .font(.system(size: 8.5, weight: .black, design: .rounded))
                    .foregroundStyle(Color(red: 0.88, green: 0.28, blue: 0.42))
                    .lineLimit(1)
                    .minimumScaleFactor(0.65)
            }
            .rotationEffect(.degrees(-tilt))
        }
        .frame(width: 78, height: 74)
        .rotationEffect(.degrees(tilt))
        .accessibilityHidden(true)
    }
}

// MARK: - Souvenirs sheet

struct SouvenirsSheet: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var store: TicketStore
    @FocusState private var isAddFieldFocused: Bool

    @State private var newItemTitle = ""

    private var souvenirs: [SouvenirItem] { store.opaSouvenirs }

    var body: some View {
        NavigationStack {
            Group {
                if souvenirs.isEmpty {
                    emptyState
                } else {
                    souvenirsList
                }
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Souvenirs für Opa")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Fertig") { dismiss() }
                }
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Hinzufügen") { addItem() }
                        .disabled(newItemTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .safeAreaInset(edge: .bottom) {
                addItemBar
            }
        }
        .presentationDetents([.medium, .large])
    }

    private var emptyState: some View {
        VStack(spacing: 20) {
            Spacer()

            Image(systemName: "heart.gift.fill")
                .font(.system(size: 48))
                .foregroundStyle(
                    LinearGradient(
                        colors: [
                            Color(red: 1.0, green: 0.45, blue: 0.55),
                            ArcaTicketsDesign.travelSunset
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .symbolRenderingMode(.hierarchical)

            Text("Was möchtest du Opa mitbringen?")
                .font(.title3.weight(.semibold))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)

            Text("Schoggi, Käse, ein kleines Andenken — alles, was Opa freut.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 28)

            Spacer()
            Spacer(minLength: 72)
        }
    }

    private var souvenirsList: some View {
        List {
            Section {
                ForEach(souvenirs) { item in
                    SouvenirRow(item: item) {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                            store.toggleOpaSouvenir(id: item.id)
                        }
                        TicketsHaptics.lightImpact()
                    }
                }
                .onDelete(perform: deleteItems)
            } header: {
                Text("Mitbringen")
            } footer: {
                if souvenirs.contains(where: \.isChecked) {
                    Text("Abgehakte Sachen kannst du löschen, wenn sie schon eingepackt sind.")
                }
            }
        }
        .listStyle(.insetGrouped)
    }

    private var addItemBar: some View {
        HStack(spacing: 10) {
            TextField("Neues Souvenir …", text: $newItemTitle)
                .textFieldStyle(.roundedBorder)
                .focused($isAddFieldFocused)
                .submitLabel(.done)
                .onSubmit { addItem() }

            Button {
                addItem()
            } label: {
                Image(systemName: "plus.circle.fill")
                    .font(.title2)
                    .symbolRenderingMode(.hierarchical)
            }
            .disabled(newItemTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            .tint(Color(red: 0.88, green: 0.28, blue: 0.42))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(.bar)
    }

    private func addItem() {
        let trimmed = newItemTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        withAnimation(.spring(response: 0.35, dampingFraction: 0.82)) {
            store.addOpaSouvenir(title: trimmed)
        }
        newItemTitle = ""
        TicketsHaptics.lightImpact()
    }

    private func deleteItems(at offsets: IndexSet) {
        for index in offsets {
            let id = souvenirs[index].id
            store.deleteOpaSouvenir(id: id)
        }
        TicketsHaptics.lightImpact()
    }
}

private struct SouvenirRow: View {
    let item: SouvenirItem
    let onToggle: () -> Void

    var body: some View {
        Button(action: onToggle) {
            HStack(spacing: 12) {
                Image(systemName: item.isChecked ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(item.isChecked
                        ? Color(red: 0.88, green: 0.28, blue: 0.42)
                        : Color(.tertiaryLabel))

                Text(item.title)
                    .font(.body)
                    .foregroundStyle(item.isChecked ? .secondary : .primary)
                    .strikethrough(item.isChecked, color: .secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
