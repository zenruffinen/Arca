//
//  NotfallView.swift
//  ArcaTickets
//
//  Entwickler: Hans zen Ruffinen
//

import SwiftUI

struct NotfallView: View {
    @EnvironmentObject private var store: TicketStore

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                header
                PersonalIDCardView()
                swissEmergencySection
                CollapsibleContactCategoriesView(
                    title: "Wichtigi Nummerä",
                    defaultExpanded: [.notfall]
                )

                LegalFootnote(text: LegalCopy.emergencyDisclaimer, icon: "exclamationmark.triangle")
                    .padding(.horizontal, 4)
                    .padding(.top, 4)
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 32)
        }
        .background {
            ZStack {
                Color(.systemGroupedBackground)
                LinearGradient(
                    colors: [Color.red.opacity(0.06), Color(.systemGroupedBackground)],
                    startPoint: .top,
                    endPoint: .center
                )
                .ignoresSafeArea()
            }
        }
        .navigationTitle(ArcaTicketsStrings.tabNotfall)
        .navigationBarTitleDisplayMode(.large)
    }

    private var header: some View {
        HStack(spacing: 12) {
            Image(systemName: "phone.circle.fill")
                .font(.system(size: 36))
                .foregroundStyle(.red)
                .symbolRenderingMode(.hierarchical)

            VStack(alignment: .leading, spacing: 2) {
                Text("Im Ernstfall schnell parat")
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                Text("Ein Tap zum Aarufe — alles a eim Ort")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(.top, 4)
    }

    private var swissEmergencySection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Schwiizer Notruf", systemImage: "sos")
                .font(.system(size: 15, weight: .bold, design: .rounded))
                .foregroundStyle(.red)

            HStack(spacing: 10) {
                ForEach(SwissEmergencyDefaults.numbers) { emergency in
                    SwissEmergencyButton(emergency: emergency)
                }
            }
        }
    }
}

struct SwissEmergencyButton: View {
    let emergency: SwissEmergencyNumber

    var body: some View {
        Button {
            if let url = emergency.telURL {
                TicketsHaptics.mediumImpact()
                UIApplication.shared.open(url)
            }
        } label: {
            VStack(spacing: 8) {
                Image(systemName: emergency.icon)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(.white)
                    .frame(width: 40, height: 40)
                    .background(.red, in: Circle())

                Text(emergency.label)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)

                Text(emergency.number)
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundStyle(.red)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .padding(.horizontal, 6)
            .background {
                RoundedRectangle(cornerRadius: ArcaTicketsDesign.chipRadius, style: .continuous)
                    .fill(Color(.secondarySystemGroupedBackground))
                    .overlay {
                        RoundedRectangle(cornerRadius: ArcaTicketsDesign.chipRadius, style: .continuous)
                            .strokeBorder(.red.opacity(0.2), lineWidth: 1)
                    }
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(emergency.label), \(emergency.number), aarufe")
    }
}
