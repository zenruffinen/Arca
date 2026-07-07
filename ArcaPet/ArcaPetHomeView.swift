//
//  ArcaPetHomeView.swift
//  ArcaPet
//

import SwiftUI

// MARK: - Main screen (Holiday-style hero + hotspots)

struct ArcaPetHomeView: View {
    @EnvironmentObject private var store: PetStore
    @AppStorage("arcaPet.tapHintDismissed") private var tapHintDismissed = false

    @State private var activeSheet: ArcaPetSheet?
    @State private var tapHintVisible = false
    @State private var kleckWiggle = false

    private let heroAspect: CGFloat = 473.0 / 1024.0

    var body: some View {
        ZStack {
            GeometryReader { geo in
                let size = LayoutSafety.size(geo.size)

                ZStack {
                    Color.black.ignoresSafeArea()

                    heroImage(in: size)

                    if size.width > 1, size.height > 1 {
                        ForEach(ArcaPetHomeCategory.allCases) { category in
                            ArcaPetHotspot(
                                center: category.point,
                                hitSize: category.hitSize,
                                rippleTint: category.tint,
                                containerSize: size,
                                accessibilityLabel: category.title,
                                accessibilityHint: category.accessibilityHint
                            ) {
                                open(category.sheet)
                            }
                        }

                        ArcaPetHotspot(
                            center: ArcaPetAddPetHotspot.point,
                            hitSize: ArcaPetAddPetHotspot.hitSize,
                            rippleTint: ArcaPetAddPetHotspot.rippleTint,
                            containerSize: size,
                            accessibilityLabel: "Neues Haustier hinzufügen",
                            accessibilityHint: "Profil für deinen Vierbeiner erstellen"
                        ) {
                            open(.addPet)
                        }
                    }
                }
            }
            .ignoresSafeArea()

            overlayChrome
        }
        .statusBarHidden(true)
        .sheet(item: $activeSheet) { sheet in
            petSheet(for: sheet)
                .presentationBackground(.ultraThinMaterial)
                .presentationDragIndicator(.visible)
        }
        .onAppear {
            presentTapHintIfNeeded()
            withAnimation(.easeInOut(duration: 1.4).repeatForever(autoreverses: true)) {
                kleckWiggle = true
            }
        }
        .onChange(of: tapHintDismissed) { _, dismissed in
            if !dismissed {
                presentTapHintIfNeeded()
            } else {
                tapHintVisible = false
            }
        }
        .onChange(of: store.pendingSheet) { _, sheet in
            guard let sheet else { return }
            activeSheet = sheet
            store.pendingSheet = nil
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Arca Pet — tippe auf die Kategorien")
    }

    @ViewBuilder
    private func heroImage(in size: CGSize) -> some View {
        Image("ArcaPetHero")
            .resizable()
            .aspectRatio(heroAspect, contentMode: .fill)
            .frame(width: size.width, height: size.height)
            .clipped()
            .accessibilityHidden(true)
    }

    private var overlayChrome: some View {
        VStack {
            GlassEffectContainer(spacing: 16) {
                HStack(alignment: .top) {
                    welcomeBadge

                    Spacer()

                    settingsButton
                }
            }
            .padding(.horizontal, 14)
            .padding(.top, 6)

            Spacer()

            if tapHintVisible {
                tapHintBanner
                    .padding(.horizontal, 20)
                    .padding(.bottom, 16)
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
            }
        }
        .safeAreaPadding(.bottom, 4)
    }

    private var welcomeBadge: some View {
        let petName = store.profile.name.trimmingCharacters(in: .whitespacesAndNewlines)
        let greeting = petName.isEmpty ? "Hallo" : "Hallo, \(petName)"

        return HStack(spacing: 4) {
            Text(greeting)
                .font(.system(size: 20, weight: .bold, design: .rounded))
            Text("🐾")
                .font(.system(size: 14))
        }
        .foregroundStyle(.white.opacity(0.92))
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .petGlass(
            tint: ArcaPetDesign.glassCyan.opacity(0.45),
            interactive: true,
            in: Capsule()
        )
        .shadow(color: .black.opacity(0.25), radius: 6, y: 2)
        .accessibilityLabel("\(greeting) — Willkommen bei Arca Pet")
    }

    private var settingsButton: some View {
        Button {
            PetHaptics.lightImpact()
            activeSheet = .settings
        } label: {
            Image(systemName: "gearshape.fill")
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(.white.opacity(0.9))
                .frame(width: 40, height: 40)
                .petGlass(
                    tint: ArcaPetDesign.navyGlow.opacity(0.4),
                    interactive: true,
                    in: Circle()
                )
        }
        .buttonStyle(.glass)
        .accessibilityLabel("Einstellungen")
    }

    private var tapHintBanner: some View {
        HStack(spacing: 8) {
            Image(systemName: "hand.tap.fill")
                .font(.caption.weight(.bold))
                .symbolEffect(.bounce, value: kleckWiggle)
            Text("Tippe auf die Kacheln — alles parat! 🐾")
                .font(.caption.weight(.semibold))
        }
        .foregroundStyle(.white.opacity(0.92))
        .padding(.horizontal, 18)
        .padding(.vertical, 10)
        .petGlass(
            tint: ArcaPetDesign.glassTeal.opacity(0.35),
            interactive: false,
            in: Capsule()
        )
        .shadow(color: ArcaPetDesign.glassCyan.opacity(0.2), radius: 8, y: 3)
    }

    private func presentTapHintIfNeeded() {
        guard !tapHintDismissed else { return }
        tapHintVisible = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 5.5) {
            withAnimation(.easeOut(duration: 0.5)) {
                tapHintVisible = false
            }
            tapHintDismissed = true
        }
    }

    private func open(_ sheet: ArcaPetSheet) {
        PetHaptics.mediumImpact()
        activeSheet = sheet
    }

    @ViewBuilder
    private func petSheet(for sheet: ArcaPetSheet) -> some View {
        switch sheet {
        case .settings:
            PetSettingsView()
        case .addPet:
            PetAddPetSheet()
        case .gesundheit:
            PetGesundheitSheet()
        case .dokumente:
            PetDokumenteSheet()
        case .termine:
            PetTermineSheet()
        case .futter:
            PetFutterSheet()
        case .notfall:
            PetNotfallSheet()
        case .fotos:
            PetFotosSheet()
        }
    }
}

// MARK: - Hotspot (invisible tap + ripple)

private struct ArcaPetHotspot: View {
    let center: CGPoint
    let hitSize: CGSize
    let rippleTint: Color
    let containerSize: CGSize
    let accessibilityLabel: String
    let accessibilityHint: String
    var onTap: () -> Void

    @State private var rippleScale: CGFloat = 0.6
    @State private var rippleOpacity: Double = 0
    @State private var tapCount = 0

    private var hitWidth: CGFloat {
        LayoutSafety.dimension(hitSize.width * containerSize.width, minimum: 44)
    }
    private var hitHeight: CGFloat {
        LayoutSafety.dimension(hitSize.height * containerSize.height, minimum: 44)
    }
    private var positionX: CGFloat {
        LayoutSafety.dimension(center.x * containerSize.width, minimum: 0)
    }
    private var positionY: CGFloat {
        LayoutSafety.dimension(center.y * containerSize.height, minimum: 0)
    }

    var body: some View {
        Button {
            tapCount += 1
            playRipple()
            onTap()
        } label: {
            ZStack {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(rippleTint.opacity(rippleOpacity * 0.28))
                    .frame(width: hitWidth * 1.02, height: hitHeight * 1.02)
                    .scaleEffect(rippleScale)

                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(rippleTint.opacity(rippleOpacity), lineWidth: 2)
                    .frame(width: hitWidth * 1.04, height: hitHeight * 1.04)
                    .scaleEffect(rippleScale)

                Color.clear
                    .frame(width: hitWidth, height: hitHeight)
            }
            .frame(width: hitWidth, height: hitHeight)
            .contentShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .buttonStyle(PetHotspotButtonStyle(tint: rippleTint))
        .sensoryFeedback(.impact(weight: .medium, intensity: 0.85), trigger: tapCount)
        .position(x: positionX, y: positionY)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityHint(accessibilityHint)
    }

    private func playRipple() {
        rippleScale = 0.7
        rippleOpacity = 0.9
        withAnimation(.easeOut(duration: 0.5)) {
            rippleScale = 1.15
            rippleOpacity = 0
        }
    }
}

private struct PetHotspotButtonStyle: ButtonStyle {
    let tint: Color

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .overlay {
                if configuration.isPressed {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(tint.opacity(0.18))
                }
            }
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.spring(response: 0.2, dampingFraction: 0.68), value: configuration.isPressed)
    }
}

// MARK: - Category sheets

private struct PetAddPetSheet: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var store: PetStore

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    petSheetIntro(
                        emoji: "➕",
                        title: "Neues Haustier",
                        subtitle: "Erstelle ein Profil für deinen Vierbeiner."
                    )

                    petReadOnlyCard(
                        title: "Aktuelles Tier",
                        icon: "pawprint.fill",
                        tint: ArcaPetDesign.glassCyan,
                        content: "\(store.profile.name) — \(store.profile.species)"
                    )

                    settingsLinkButton(tint: ArcaPetDesign.glassCyan)
                }
                .padding(16)
                .padding(.bottom, 24)
            }
            .background(petSheetBackground)
            .navigationTitle("Haustier")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Fertig") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
}

private struct PetGesundheitSheet: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var store: PetStore

    private var healthDocs: [PetDocument] {
        store.documents.filter { $0.category == .impfung || $0.category == .medikamente }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    petSheetIntro(
                        emoji: "🛡️",
                        title: "Gesundheit",
                        subtitle: "Impfungen, Untersuchungen, Medikamente."
                    )

                    if let vet = store.profile.vetName, !vet.isEmpty {
                        petReadOnlyCard(
                            title: "Tierarzt",
                            icon: "stethoscope",
                            tint: ArcaPetDesign.glassTeal,
                            content: [vet, store.profile.vetPhone ?? ""]
                                .filter { !$0.isEmpty }
                                .joined(separator: " · ")
                        )
                    }

                    petDocumentListCard(
                        title: "Dokumente",
                        icon: "cross.case.fill",
                        tint: ArcaPetDesign.glassTeal,
                        documents: healthDocs,
                        emptyText: "Noch keine Gesundheitsdokumente hinterlegt."
                    )

                    settingsLinkButton(tint: ArcaPetDesign.glassTeal)
                }
                .padding(16)
                .padding(.bottom, 24)
            }
            .background(petSheetBackground)
            .navigationTitle("Gesundheit")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Fertig") { dismiss() }
                }
            }
        }
        .presentationDetents([.large])
    }
}

private struct PetDokumenteSheet: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var store: PetStore

    private var docItems: [PetDocument] {
        store.documents.filter { $0.category == .dokumente || $0.category == .chip }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    petSheetIntro(
                        emoji: "📄",
                        title: "Dokumente",
                        subtitle: "Impfausweis, Chipnummer, Versicherung."
                    )

                    if let chip = store.profile.chipNumber, !chip.isEmpty {
                        petReadOnlyCard(
                            title: "Chipnummer",
                            icon: "dot.radiowaves.left.and.right",
                            tint: ArcaPetDesign.skyBlue,
                            content: chip
                        )
                    }

                    petDocumentListCard(
                        title: "Hinterlegte Dokumente",
                        icon: "doc.text.fill",
                        tint: ArcaPetDesign.skyBlue,
                        documents: docItems,
                        emptyText: "Noch keine Dokumente hinterlegt."
                    )

                    settingsLinkButton(tint: ArcaPetDesign.skyBlue)
                }
                .padding(16)
                .padding(.bottom, 24)
            }
            .background(petSheetBackground)
            .navigationTitle("Dokumente")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Fertig") { dismiss() }
                }
            }
        }
        .presentationDetents([.large])
    }
}

private struct PetTermineSheet: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    petSheetIntro(
                        emoji: "📅",
                        title: "Termine",
                        subtitle: "Erinnerungen, Kontrolle, Tierarztbesuche."
                    )

                    petReadOnlyCard(
                        title: "Kommende Termine",
                        icon: "calendar",
                        tint: ArcaPetDesign.glassAmber,
                        content: "Noch keine Termine hinterlegt. Trage Tierarzt-Termine in den Einstellungen ein."
                    )

                    settingsLinkButton(tint: ArcaPetDesign.glassAmber)
                }
                .padding(16)
                .padding(.bottom, 24)
            }
            .background(petSheetBackground)
            .navigationTitle("Termine")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Fertig") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
}

private struct PetFutterSheet: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    petSheetIntro(
                        emoji: "🍽️",
                        title: "Futter & Ernährung",
                        subtitle: "Futter, Mengen, Allergien, Unverträglichkeiten."
                    )

                    petReadOnlyCard(
                        title: "Ernährung",
                        icon: "fork.knife.circle.fill",
                        tint: ArcaPetDesign.meadowGreen,
                        content: "Noch keine Futterinfos hinterlegt. Notizen und Details in den Einstellungen ergänzen."
                    )

                    settingsLinkButton(tint: ArcaPetDesign.meadowGreen)
                }
                .padding(16)
                .padding(.bottom, 24)
            }
            .background(petSheetBackground)
            .navigationTitle("Futter")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Fertig") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
}

private struct PetNotfallSheet: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var store: PetStore

    private var emergencyContacts: [QuickContact] {
        store.quickContacts.filter { $0.category == .notfall || $0.category == .tierarzt }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    petSheetIntro(
                        emoji: "🚨",
                        title: "Notfall",
                        subtitle: "Notfallkontakte, Tierarzt, wichtige Infos."
                    )

                    VStack(alignment: .leading, spacing: 10) {
                        Label("Schnell anrufen", systemImage: "phone.fill")
                            .font(.system(size: 15, weight: .bold, design: .rounded))
                            .foregroundStyle(ArcaPetDesign.alertRed)

                        if emergencyContacts.isEmpty {
                            Text("Keine Notfallkontakte hinterlegt.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        } else {
                            ForEach(emergencyContacts) { contact in
                                PetContactCallRow(contact: contact, tint: ArcaPetDesign.alertRed)
                            }
                        }
                    }
                    .padding(16)
                    .petGlass(
                        tint: ArcaPetDesign.alertRed.opacity(0.2),
                        in: RoundedRectangle(cornerRadius: 16, style: .continuous)
                    )

                    settingsLinkButton(tint: ArcaPetDesign.alertRed)
                }
                .padding(16)
                .padding(.bottom, 24)
            }
            .background(petSheetBackground)
            .navigationTitle("Notfall")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Fertig") { dismiss() }
                }
            }
        }
        .presentationDetents([.large])
    }
}

private struct PetFotosSheet: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var store: PetStore

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    petSheetIntro(
                        emoji: "📷",
                        title: "Fotos & Notizen",
                        subtitle: "Erinnerungen, Bilder, persönliche Notizen."
                    )

                    petReadOnlyCard(
                        title: "Notizen",
                        icon: "note.text",
                        tint: ArcaPetDesign.glassCyan,
                        content: store.profile.notes?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
                            ? (store.profile.notes ?? "")
                            : "Noch keine Notizen hinterlegt."
                    )

                    settingsLinkButton(tint: ArcaPetDesign.glassCyan)
                }
                .padding(16)
                .padding(.bottom, 24)
            }
            .background(petSheetBackground)
            .navigationTitle("Fotos & Notizen")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Fertig") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
}

// MARK: - Shared sheet chrome

@ViewBuilder
private func petSheetIntro(emoji: String, title: String, subtitle: String) -> some View {
    HStack(alignment: .top, spacing: 12) {
        Text(emoji)
            .font(.system(size: 32))
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.system(size: 20, weight: .black, design: .rounded))
            Text(subtitle)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        Spacer(minLength: 0)
    }
    .padding(.bottom, 4)
}

private var petSheetBackground: some View {
    ZStack {
        Color(.systemGroupedBackground)
        LinearGradient(
            colors: [
                ArcaPetDesign.navyGlow.opacity(0.12),
                ArcaPetDesign.glassCyan.opacity(0.06),
                Color(.systemGroupedBackground)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()
    }
}

private func petReadOnlyCard(title: String, icon: String, tint: Color, content: String) -> some View {
    VStack(alignment: .leading, spacing: 8) {
        Label(title, systemImage: icon)
            .font(.system(size: 15, weight: .bold, design: .rounded))
            .foregroundStyle(tint)

        Text(content)
            .font(.system(.body, design: .rounded))
            .foregroundStyle(content.hasPrefix("Noch keine") || content.hasPrefix("Noch kein") ? .secondary : .primary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(14)
            .petGlass(
                tint: tint.opacity(0.22),
                in: RoundedRectangle(cornerRadius: 14, style: .continuous)
            )
    }
}

private func petDocumentListCard(
    title: String,
    icon: String,
    tint: Color,
    documents: [PetDocument],
    emptyText: String
) -> some View {
    VStack(alignment: .leading, spacing: 8) {
        Label(title, systemImage: icon)
            .font(.system(size: 15, weight: .bold, design: .rounded))
            .foregroundStyle(tint)

        if documents.isEmpty {
            Text(emptyText)
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .petGlass(
                    tint: tint.opacity(0.18),
                    in: RoundedRectangle(cornerRadius: 14, style: .continuous)
                )
        } else {
            VStack(spacing: 8) {
                ForEach(documents) { doc in
                    HStack {
                        Text(doc.title)
                            .font(.subheadline.weight(.semibold))
                        Spacer()
                        Text(doc.category.label)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(12)
                    .background(tint.opacity(0.08), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                }
            }
            .padding(14)
            .petGlass(
                tint: tint.opacity(0.18),
                in: RoundedRectangle(cornerRadius: 14, style: .continuous)
            )
        }
    }
}

private struct PetSettingsLinkButton: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var store: PetStore
    let tint: Color

    var body: some View {
        Button {
            dismiss()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                store.pendingSheet = .settings
            }
        } label: {
            Label("In Einstellungen bearbeiten", systemImage: "gearshape.fill")
                .font(.subheadline.weight(.semibold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
        }
        .buttonStyle(.glassProminent)
        .tint(tint)
    }
}

@ViewBuilder
private func settingsLinkButton(tint: Color) -> some View {
    PetSettingsLinkButton(tint: tint)
}

private struct PetContactCallRow: View {
    let contact: QuickContact
    let tint: Color

    var body: some View {
        Button {
            if let url = URL(string: "tel:\(contact.phoneNumber.filter { $0.isNumber || $0 == "+" })"),
               contact.hasPhoneNumber {
                PetHaptics.mediumImpact()
                UIApplication.shared.open(url)
            }
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "phone.fill")
                    .font(.title3)
                    .foregroundStyle(tint)
                VStack(alignment: .leading, spacing: 2) {
                    Text(contact.label)
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                        .foregroundStyle(.primary)
                    Text(contact.hasPhoneNumber ? contact.phoneNumber : "Keine Nummer")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                if contact.hasPhoneNumber {
                    Image(systemName: "phone.arrow.up.right")
                        .foregroundStyle(tint)
                }
            }
            .padding(14)
            .background(tint.opacity(0.08), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .buttonStyle(.plain)
        .disabled(!contact.hasPhoneNumber)
    }
}

#Preview {
    ArcaPetHomeView()
        .environmentObject(PetStore())
}
