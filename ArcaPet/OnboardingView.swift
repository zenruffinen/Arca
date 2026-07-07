//
//  OnboardingView.swift
//  ArcaPet
//

import SwiftUI

enum PetOnboardingStorage {
    static let completedKey = "arcapet_onboarding_completed"

    static var hasCompleted: Bool {
        UserDefaults.standard.bool(forKey: completedKey)
    }

    static func markCompleted() {
        UserDefaults.standard.set(true, forKey: completedKey)
    }
}

struct PetOnboardingView: View {
    @Binding var isPresented: Bool
    @State private var page = 0

    private let pages: [(icon: String, title: String, subtitle: String)] = [
        ("pawprint.fill", "Alles für dein Tier", "Impfungen, Chip, Tierarzt — alles an einem Ort."),
        ("doc.fill", "Dokumente sicher", "Fotos und PDFs offline und mit iCloud synchronisiert."),
        ("heart.fill", "Schnell im Notfall", "Wichtige Nummern und Daten immer griffbereit.")
    ]

    var body: some View {
        ZStack {
            ArcaPetDesign.petGradient.ignoresSafeArea()
            VStack(spacing: 0) {
                HStack {
                    Spacer()
                    Button("Überspringen") { finish() }
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.secondary)
                        .petMinTapTarget()
                }
                .padding(.horizontal, 20)
                .padding(.top, 12)

                TabView(selection: $page) {
                    ForEach(Array(pages.enumerated()), id: \.offset) { index, item in
                        VStack(spacing: 24) {
                            Spacer()
                            Image(systemName: item.icon)
                                .font(.system(size: 64, weight: .semibold))
                                .foregroundStyle(ArcaPetDesign.meadowGreen)
                            Text(item.title)
                                .font(.title.bold())
                                .multilineTextAlignment(.center)
                            Text(item.subtitle)
                                .font(.body)
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 32)
                            Spacer()
                        }
                        .tag(index)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .always))

                if page < pages.count - 1 {
                    Button {
                        withAnimation { page += 1 }
                    } label: {
                        Text("Weiter")
                            .font(.system(size: 17, weight: .semibold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .foregroundStyle(.white)
                            .background(ArcaPetDesign.meadowGreen, in: RoundedRectangle(cornerRadius: ArcaPetDesign.cornerRadius, style: .continuous))
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, 32)
                } else {
                    Button(action: finish) {
                        Text("Los geht's")
                            .font(.system(size: 17, weight: .semibold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .foregroundStyle(.white)
                            .background(ArcaPetDesign.meadowGreen, in: RoundedRectangle(cornerRadius: ArcaPetDesign.cornerRadius, style: .continuous))
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, 32)
                }
            }
        }
    }

    private func finish() {
        PetOnboardingStorage.markCompleted()
        withAnimation { isPresented = false }
    }
}
