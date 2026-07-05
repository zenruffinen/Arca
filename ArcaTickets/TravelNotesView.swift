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

    private let tilt: Double = -9
    private var hasNotes: Bool { !store.travelNotes.isEmpty }

    var body: some View {
        Button {
            TicketsHaptics.lightImpact()
            showNotesSheet = true
        } label: {
            klecksGraphic
        }
        .buttonStyle(.plain)
        .accessibilityLabel(hasNotes ? "Reisenotizen, Einträge vorhanden" : "Reisenotizen, leer")
        .accessibilityHint("Tippen zum Öffnen")
        .sheet(isPresented: $showNotesSheet) {
            TravelNotesSheet()
        }
    }

    private var klecksGraphic: some View {
        ZStack {
            KlecksBlobShape()
                .fill(
                    RadialGradient(
                        colors: [
                            ArcaTicketsDesign.travelSunset.opacity(0.22),
                            ArcaTicketsDesign.travelSand.opacity(0.14),
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
                                    ArcaTicketsDesign.travelSunset.opacity(0.65),
                                    ArcaTicketsDesign.travelSand.opacity(0.45)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1.5
                        )
                }
                .shadow(color: ArcaTicketsDesign.travelSunset.opacity(0.2), radius: 8, y: 3)

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
                    .font(.system(size: 9, weight: .black, design: .rounded))
                    .foregroundStyle(ArcaTicketsDesign.travelSunset)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            .rotationEffect(.degrees(-tilt))
        }
        .frame(width: 78, height: 74)
        .rotationEffect(.degrees(tilt))
        .accessibilityHidden(true)
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
                Text("Packliste, Gate-Hinweise, Adressen — alles, was du unterwegs schnell brauchst.")
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
                        Text("Hier tippen …")
                            .font(.system(.body, design: .rounded))
                            .foregroundStyle(.tertiary)
                            .padding(.horizontal, 18)
                            .padding(.vertical, 20)
                            .allowsHitTesting(false)
                    }
                }

                if store.travelNotes.updatedAt != .distantPast, !store.travelNotes.isEmpty {
                    Text("Zuletzt bearbeitet: \(store.travelNotes.updatedAt.formatted(date: .abbreviated, time: .shortened))")
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
                    Button("Fertig") {
                        save()
                        dismiss()
                    }
                }
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Fertig") {
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
