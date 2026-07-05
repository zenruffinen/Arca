//
//  TravelNotesView.swift
//  ArcaTickets
//
//  Entwickler: Hans zen Ruffinen
//

import SwiftUI

// MARK: - Floating Klecks (Unterwegs)

struct NotizenFloatingDecoration: View {
    @EnvironmentObject private var store: TicketStore
    @State private var showNotesSheet = false

    private var hasNotes: Bool { !store.travelNotes.isEmpty }

    var body: some View {
        Button {
            TicketsHaptics.lightImpact()
            showNotesSheet = true
        } label: {
            klecksGraphic
                .unterwegsKlecksTapTarget()
        }
        .buttonStyle(UnterwegsKlecksButtonStyle())
        .accessibilityLabel(hasNotes ? "Reisenotize, Iiträg vorhande" : "Reisenotize, leer")
        .accessibilityHint("Tippen zum Öffne")
        .sheet(isPresented: $showNotesSheet) {
            TravelNotesSheet()
        }
    }

    private var klecksGraphic: some View {
        UnterwegsKlecksGlass {
            VStack(spacing: 3) {
                ZStack(alignment: .topTrailing) {
                    Image(systemName: "note.text")
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [ArcaTicketsDesign.travelSunset, ArcaTicketsDesign.travelOcean],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .symbolRenderingMode(.hierarchical)
                    if hasNotes {
                        Circle()
                            .fill(ArcaTicketsDesign.travelSunset)
                            .frame(width: 7, height: 7)
                            .offset(x: 4, y: -3)
                    }
                }
                Text("Notizen")
                    .unterwegsKlecksLabel()
            }
        }
    }
}

// MARK: - Quick notes sheet

struct TravelNotesSheet: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var store: TicketStore
    @FocusState private var isFocused: Bool

    @State private var draftText = ""

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 16) {
                Text("Packliste, Gate-Hinwiis, Adresse — alles, was du unterwägs schnell bruchsch.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                ZStack(alignment: .topLeading) {
                    TextEditor(text: $draftText)
                        .font(.system(.body, design: .rounded))
                        .scrollContentBackground(.hidden)
                        .padding(12)
                        .background(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(Color(.secondarySystemGroupedBackground))
                        )
                        .overlay {
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .strokeBorder(ArcaTicketsDesign.travelSky.opacity(0.25), lineWidth: 1)
                        }
                        .focused($isFocused)
                        .frame(minHeight: 200)

                    if draftText.isEmpty {
                        Text("Da tippe …")
                            .font(.system(.body, design: .rounded))
                            .foregroundStyle(.tertiary)
                            .padding(.horizontal, 18)
                            .padding(.vertical, 20)
                            .allowsHitTesting(false)
                    }
                }

                if store.travelNotes.updatedAt != .distantPast, !store.travelNotes.isEmpty {
                    Text("Zletscht bearbeitet: \(store.travelNotes.updatedAt.formatted(date: .abbreviated, time: .shortened))")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }

                Spacer(minLength: 0)
            }
            .padding(20)
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Reisenotizen")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(ArcaTicketsStrings.done) {
                        save()
                        dismiss()
                    }
                }
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button(ArcaTicketsStrings.done) {
                        isFocused = false
                    }
                }
            }
            .onAppear {
                draftText = store.travelNotes.text
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                    isFocused = true
                }
            }
            .onDisappear {
                save()
            }
        }
        .presentationDetents([.medium, .large])
    }

    private func save() {
        let trimmed = draftText.trimmingCharacters(in: .whitespacesAndNewlines)
        let notes = TravelNotes(
            text: draftText,
            updatedAt: trimmed.isEmpty && store.travelNotes.isEmpty ? store.travelNotes.updatedAt : Date()
        )
        if notes != store.travelNotes {
            store.updateTravelNotes(notes)
        }
    }
}
