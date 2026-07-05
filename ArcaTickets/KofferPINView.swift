//
//  KofferPINView.swift
//  ArcaTickets
//
//  Entwickler: Hans zen Ruffinen
//

import SwiftUI

// MARK: - Floating Klecks (Unterwegs)

struct KofferPINFloatingDecoration: View {
    @EnvironmentObject private var store: TicketStore
    @State private var showSheet = false
    @State private var pinRevealed = false

    private let tilt: Double = -6
    private var hasPIN: Bool { store.kofferPIN != nil }

    private var displayPIN: String {
        guard let pin = store.kofferPIN else { return "" }
        return pinRevealed ? pin : String(repeating: "•", count: pin.count)
    }

    var body: some View {
        Button {
            TicketsHaptics.lightImpact()
            if hasPIN {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.72)) {
                    pinRevealed.toggle()
                }
            } else {
                showSheet = true
            }
        } label: {
            klecksGraphic
        }
        .buttonStyle(.plain)
        .simultaneousGesture(
            LongPressGesture(minimumDuration: 0.45).onEnded { _ in
                TicketsHaptics.lightImpact()
                showSheet = true
            }
        )
        .accessibilityLabel(hasPIN
            ? "Koffer-PIN, \(pinRevealed ? "sichtbar" : "verborgen")"
            : "Koffer-PIN, noch nicht gespeichert")
        .accessibilityHint(hasPIN
            ? "Tippen zum Ein- oder Ausblenden, gedrückt halten zum Bearbeiten"
            : "Tippen zum Eintragen")
        .sheet(isPresented: $showSheet) {
            KofferPINSheet()
        }
        .onChange(of: store.kofferPIN) { _, _ in
            pinRevealed = false
        }
    }

    private var klecksGraphic: some View {
        ZStack {
            KlecksBlobShape()
                .fill(
                    RadialGradient(
                        colors: [
                            ArcaTicketsDesign.travelOcean.opacity(0.20),
                            ArcaTicketsDesign.travelGlassPurple.opacity(0.12),
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
                                    ArcaTicketsDesign.travelOcean.opacity(0.65),
                                    ArcaTicketsDesign.travelGlassPurple.opacity(0.45)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1.5
                        )
                }
                .shadow(color: ArcaTicketsDesign.travelOcean.opacity(0.22), radius: 8, y: 3)

            VStack(spacing: 2) {
                ZStack {
                    Image(systemName: "suitcase.fill")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [
                                    ArcaTicketsDesign.travelOcean,
                                    ArcaTicketsDesign.travelGlassPurple
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .symbolRenderingMode(.hierarchical)

                    Image(systemName: "lock.fill")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(ArcaTicketsDesign.travelSunset)
                        .offset(x: 10, y: 8)
                }

                if hasPIN {
                    ComicCurvedText(
                        text: displayPIN,
                        style: .pinCode,
                        foreground: ArcaTicketsDesign.travelOcean
                    )
                    .scaleEffect(0.92)
                    .contentTransition(.numericText())

                    Image(systemName: pinRevealed ? "eye.fill" : "eye.slash.fill")
                        .font(.system(size: 7, weight: .bold))
                        .foregroundStyle(ArcaTicketsDesign.travelOcean.opacity(0.55))
                } else {
                    Text("Koffer")
                        .font(.system(size: 8.5, weight: .black, design: .rounded))
                        .foregroundStyle(ArcaTicketsDesign.travelOcean)
                        .lineLimit(1)
                        .minimumScaleFactor(0.65)
                }
            }
            .rotationEffect(.degrees(-tilt))
        }
        .frame(width: 80, height: 78)
        .rotationEffect(.degrees(tilt))
        .accessibilityHidden(true)
    }
}

// MARK: - PIN sheet

struct KofferPINSheet: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var store: TicketStore

    @State private var draftPIN = ""
    @FocusState private var isFocused: Bool

    private var isValidPIN: Bool {
        let digits = draftPIN.filter(\.isNumber)
        return digits.count == draftPIN.count && (3...4).contains(digits.count)
    }

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 20) {
                if store.kofferPIN == nil {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Koffer-Code vergessen? Hier sichern!")
                            .font(.title3.weight(.bold))
                            .fixedSize(horizontal: false, vertical: true)

                        Text("TSA-Schloss, Reisekoffer, Zahlenschloss — 3 oder 4 Ziffern, damit du am Flughafen nicht raten musst.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                } else {
                    Text("Dein Koffer-Code — schnell nachschlagen, wenn das Schloss zickt.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                VStack(spacing: 12) {
                    TextField("z. B. 421", text: $draftPIN)
                        .keyboardType(.numberPad)
                        .textContentType(.oneTimeCode)
                        .font(.system(size: 36, weight: .bold, design: .rounded))
                        .multilineTextAlignment(.center)
                        .focused($isFocused)
                        .onChange(of: draftPIN) { _, newValue in
                            let filtered = String(newValue.filter(\.isNumber).prefix(4))
                            if filtered != newValue { draftPIN = filtered }
                        }

                    if !draftPIN.isEmpty {
                        ComicCurvedText(
                            text: draftPIN,
                            style: .pinCode,
                            foreground: ArcaTicketsDesign.travelOcean
                        )
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 4)
                    }
                }
                .padding(20)
                .background(
                    RoundedRectangle(cornerRadius: ArcaTicketsDesign.cornerRadius, style: .continuous)
                        .fill(Color(.secondarySystemGroupedBackground))
                )

                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: "info.circle.fill")
                        .font(.subheadline)
                        .foregroundStyle(ArcaTicketsDesign.travelOcean.opacity(0.8))
                    Text("Das ist dein Reisekoffer-Schloss — nicht der App-PIN. Trotzdem nur auf deinem Gerät speichern, wenn du dich damit wohlfühlst.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(12)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(ArcaTicketsDesign.travelOcean.opacity(0.08))
                )

                Spacer(minLength: 0)
            }
            .padding(20)
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Koffer-PIN")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Abbrechen") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Sichern") {
                        savePIN()
                    }
                    .fontWeight(.semibold)
                    .disabled(!isValidPIN)
                }
                if store.kofferPIN != nil {
                    ToolbarItem(placement: .bottomBar) {
                        Button("Code löschen", role: .destructive) {
                            store.updateKofferPIN(nil)
                            TicketsHaptics.lightImpact()
                            dismiss()
                        }
                    }
                }
            }
            .onAppear {
                draftPIN = store.kofferPIN ?? ""
                isFocused = true
            }
        }
        .presentationDetents([.medium])
    }

    private func savePIN() {
        guard isValidPIN else { return }
        store.updateKofferPIN(draftPIN)
        TicketsHaptics.mediumImpact()
        dismiss()
    }
}
