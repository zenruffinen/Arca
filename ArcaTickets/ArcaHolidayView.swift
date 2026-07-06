//
//  ArcaHolidayView.swift
//  ArcaTickets
//
//  Entwickler: Hans zen Ruffinen
//

import SwiftUI

// MARK: - Kleck map (normalized 0…1 on vertical hero)

enum ArcaHolidayKleck: String, CaseIterable, Identifiable {
    case golf
    case taxi
    case koffer
    case pass
    case notizen
    case boardingCard

    var id: String { rawValue }

    var label: String {
        switch self {
        case .golf: return "GOLF"
        case .taxi: return "TAXI"
        case .koffer: return "KOFFER"
        case .pass: return "PASS"
        case .notizen: return "NOTIZEN"
        case .boardingCard: return "BOARDING CARD"
        }
    }

    var accessibilityHint: String {
        switch self {
        case .golf: return "Golf — Schläger & Baggage-Tag"
        case .taxi: return "Taxi — Urlaub und diheime"
        case .koffer: return "Koffer — Reiseunterlage und Versicherig"
        case .pass: return "Pass — Passnummer und Visitenkarte"
        case .notizen: return "Notize und Telefonnummerä"
        case .boardingCard: return "Boarding Card — Tickets und Reisedokument"
        }
    }

    /// Center point on the vertical hero (paint-splatter klecks).
    var point: CGPoint {
        switch self {
        case .golf:         CGPoint(x: 0.22, y: 0.30)
        case .taxi:         CGPoint(x: 0.78, y: 0.30)
        case .koffer:       CGPoint(x: 0.15, y: 0.76)
        case .pass:         CGPoint(x: 0.38, y: 0.82)
        case .notizen:      CGPoint(x: 0.62, y: 0.82)
        case .boardingCard: CGPoint(x: 0.50, y: 0.93)
        }
    }

    var hitSize: CGSize {
        switch self {
        case .golf, .taxi:           CGSize(width: 0.22, height: 0.11)
        case .koffer:                CGSize(width: 0.20, height: 0.12)
        case .pass, .notizen:        CGSize(width: 0.18, height: 0.11)
        case .boardingCard:          CGSize(width: 0.26, height: 0.09)
        }
    }

    var rippleTint: Color {
        switch self {
        case .golf:         ArcaTicketsDesign.golfFairway
        case .taxi:         ArcaTicketsDesign.taxiYellow
        case .koffer:       ArcaTicketsDesign.travelOcean
        case .pass:         Color(red: 0.95, green: 0.25, blue: 0.30)
        case .notizen:      ArcaTicketsDesign.travelGlassPurple
        case .boardingCard: ArcaTicketsDesign.travelGlassCyan
        }
    }
}

enum ArcaHolidaySheet: Identifiable {
    case pass, notizen, koffer, taxi, golf, boarding, settings

    var id: String {
        switch self {
        case .pass: return "pass"
        case .notizen: return "notizen"
        case .koffer: return "koffer"
        case .taxi: return "taxi"
        case .golf: return "golf"
        case .boarding: return "boarding"
        case .settings: return "settings"
        }
    }
}

// MARK: - Main screen

struct ArcaHolidayView: View {
    @EnvironmentObject private var store: TicketStore
    @AppStorage("arcaHoliday.tapHintDismissed") private var tapHintDismissed = false

    @State private var activeSheet: ArcaHolidaySheet?
    @State private var tapHintVisible = false
    @State private var kleckWiggle = false

    private let heroAspect: CGFloat = 473.0 / 1024.0

    var body: some View {
        GeometryReader { geo in
            let size = LayoutSafety.size(geo.size)

            ZStack {
                Color.black.ignoresSafeArea()

                heroImage(in: size)

                if size.width > 1, size.height > 1 {
                    ForEach(ArcaHolidayKleck.allCases) { kleck in
                        ArcaHolidayKleckHotspot(kleck: kleck, containerSize: size) {
                            open(kleck)
                        }
                    }
                }

                overlayChrome
            }
        }
        .ignoresSafeArea()
        .statusBarHidden(true)
        .persistentSystemOverlays(.hidden)
        .sheet(item: $activeSheet) { sheet in
            holidaySheet(for: sheet)
        }
        .onAppear {
            presentTapHintIfNeeded()
            withAnimation(.easeInOut(duration: 1.4).repeatForever(autoreverses: true)) {
                kleckWiggle = true
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Arca Holiday — tipp uf d'Klecks")
    }

    @ViewBuilder
    private func heroImage(in size: CGSize) -> some View {
        Image("ArcaHolidayHero")
            .resizable()
            .aspectRatio(heroAspect, contentMode: .fill)
            .frame(width: size.width, height: size.height)
            .clipped()
            .accessibilityHidden(true)
    }

    private var overlayChrome: some View {
        VStack {
            HStack(alignment: .top) {
                grueeziBadge
                    .padding(.leading, 14)
                    .padding(.top, 6)

                Spacer()

                settingsButton
                    .padding(.trailing, 14)
                    .padding(.top, 6)
            }

            Spacer()

            if tapHintVisible {
                tapHintBanner
                    .padding(.horizontal, 20)
                    .padding(.bottom, 16)
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
            }
        }
        .safeAreaPadding(.top, 4)
        .safeAreaPadding(.bottom, 4)
    }

    private var grueeziBadge: some View {
        HStack(spacing: 4) {
            Text("grüezi")
                .font(.system(size: 22, weight: .bold, design: .serif))
                .italic()
            Text("♥")
                .font(.system(size: 14))
                .foregroundStyle(Color(red: 0.95, green: 0.22, blue: 0.28))
        }
        .foregroundStyle(.white.opacity(0.92))
        .shadow(color: .black.opacity(0.35), radius: 4, y: 2)
        .accessibilityLabel("Grüezi — willkomme i dr Ferie")
    }

    private var settingsButton: some View {
        Button {
            TicketsHaptics.lightImpact()
            activeSheet = .settings
        } label: {
            Image(systemName: "gearshape.fill")
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(.white.opacity(0.88))
                .padding(10)
                .background(.ultraThinMaterial.opacity(0.55), in: Circle())
                .overlay {
                    Circle()
                        .strokeBorder(.white.opacity(0.35), lineWidth: 1)
                }
                .shadow(color: ArcaTicketsDesign.travelOcean.opacity(0.25), radius: 6, y: 2)
        }
        .buttonStyle(UnterwegsKlecksButtonStyle())
        .accessibilityLabel(ArcaTicketsStrings.tabSettings)
    }

    private var tapHintBanner: some View {
        HStack(spacing: 8) {
            Image(systemName: "hand.tap.fill")
                .font(.caption.weight(.bold))
                .symbolEffect(.bounce, value: kleckWiggle)
            Text("Tipp uf d'Klecks — alles debii! ✈️")
                .font(.caption.weight(.semibold))
        }
        .foregroundStyle(.white.opacity(0.9))
        .padding(.horizontal, 18)
        .padding(.vertical, 10)
        .background(.ultraThinMaterial.opacity(0.65), in: Capsule())
        .overlay {
            Capsule()
                .strokeBorder(
                    LinearGradient(
                        colors: [.white.opacity(0.5), ArcaTicketsDesign.travelSunset.opacity(0.45)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
        }
        .shadow(color: ArcaTicketsDesign.travelOcean.opacity(0.22), radius: 8, y: 3)
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

    private func open(_ kleck: ArcaHolidayKleck) {
        TicketsHaptics.mediumImpact()
        switch kleck {
        case .pass: activeSheet = .pass
        case .notizen: activeSheet = .notizen
        case .koffer: activeSheet = .koffer
        case .taxi: activeSheet = .taxi
        case .golf: activeSheet = .golf
        case .boardingCard: activeSheet = .boarding
        }
    }

    @ViewBuilder
    private func holidaySheet(for sheet: ArcaHolidaySheet) -> some View {
        switch sheet {
        case .pass:
            PersonalIDCardDetailSheet()
        case .notizen:
            HolidayNotizenSheet()
        case .koffer:
            HolidayKofferSheet()
        case .taxi:
            HolidayTaxiSheet()
        case .golf:
            GolfschlaegerSheet()
        case .boarding:
            HolidayBoardingSheet()
        case .settings:
            NavigationStack {
                SettingsView()
            }
        }
    }
}

// MARK: - Kleck hotspot (invisible tap + ripple)

private struct ArcaHolidayKleckHotspot: View {
    let kleck: ArcaHolidayKleck
    let containerSize: CGSize
    var onTap: () -> Void

    @State private var rippleScale: CGFloat = 0.6
    @State private var rippleOpacity: Double = 0

    private var hitWidth: CGFloat {
        LayoutSafety.dimension(kleck.hitSize.width * containerSize.width, minimum: 52)
    }
    private var hitHeight: CGFloat {
        LayoutSafety.dimension(kleck.hitSize.height * containerSize.height, minimum: 52)
    }
    private var positionX: CGFloat {
        LayoutSafety.dimension(kleck.point.x * containerSize.width, minimum: 0)
    }
    private var positionY: CGFloat {
        LayoutSafety.dimension(kleck.point.y * containerSize.height, minimum: 0)
    }

    var body: some View {
        Button {
            playRipple()
            onTap()
        } label: {
            ZStack {
                Circle()
                    .stroke(kleck.rippleTint.opacity(rippleOpacity), lineWidth: 3)
                    .frame(width: hitWidth * 1.1, height: hitWidth * 1.1)
                    .scaleEffect(rippleScale)

                Color.clear
            }
            .frame(width: hitWidth, height: hitHeight)
            .contentShape(Rectangle())
        }
        .buttonStyle(UnterwegsKlecksButtonStyle())
        .position(x: positionX, y: positionY)
        .accessibilityLabel(kleck.label)
        .accessibilityHint(kleck.accessibilityHint)
    }

    private func playRipple() {
        rippleScale = 0.65
        rippleOpacity = 0.85
        withAnimation(.easeOut(duration: 0.55)) {
            rippleScale = 1.35
            rippleOpacity = 0
        }
    }
}

// MARK: - Holiday sheets

struct HolidayNotizenSheet: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var store: TicketStore
    @FocusState private var isFocused: Bool
    @State private var draftText = ""

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    holidaySheetIntro(
                        emoji: "📝",
                        title: "Notize & Nummerä",
                        subtitle: "Packliste, Gate-Hinwiis, Hotel — und d'wichtigste Telefon."
                    )

                    notesEditor

                    CollapsibleContactCategoriesView(
                        title: "Telefonnummerä",
                        defaultExpanded: [.notfall, .hotel, .familie]
                    )
                }
                .padding(16)
                .padding(.bottom, 24)
            }
            .background(holidaySheetBackground)
            .navigationTitle("Notizen")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(ArcaTicketsStrings.done) {
                        saveNotes()
                        dismiss()
                    }
                }
            }
            .onAppear {
                draftText = store.travelNotes.text
            }
            .onDisappear { saveNotes() }
        }
        .presentationDetents([.large])
    }

    private var notesEditor: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Mini Notize", systemImage: "note.text")
                .font(.system(size: 15, weight: .bold, design: .rounded))
                .foregroundStyle(ArcaTicketsDesign.travelGlassPurple)

            ZStack(alignment: .topLeading) {
                TextEditor(text: $draftText)
                    .font(.system(.body, design: .rounded))
                    .frame(minHeight: 120)
                    .focused($isFocused)
                    .scrollContentBackground(.hidden)
                    .padding(10)
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .strokeBorder(ArcaTicketsDesign.travelGlassPurple.opacity(0.35), lineWidth: 1)
                    }

                if draftText.isEmpty && !isFocused {
                    Text("z.B. Gate B12, Zimmerschlüssel, Restaurant-Tipp…")
                        .font(.subheadline)
                        .foregroundStyle(.tertiary)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 18)
                        .allowsHitTesting(false)
                }
            }
        }
    }

    private func saveNotes() {
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

struct HolidayKofferSheet: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var store: TicketStore

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    holidaySheetIntro(
                        emoji: "🧳",
                        title: "Koffer & Unterlage",
                        subtitle: "Versicherig, Policen-Nummere und Reisedokument — alles am eim Ort."
                    )

                    insuranceSection

                    kofferPINSection

                    reiseunterlagenPlaceholder
                }
                .padding(16)
                .padding(.bottom, 24)
            }
            .background(holidaySheetBackground)
            .navigationTitle("Koffer")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(ArcaTicketsStrings.done) { dismiss() }
                }
            }
        }
        .presentationDetents([.large])
    }

    @State private var showKofferPIN = false

    private var insuranceContacts: [QuickContact] {
        store.quickContacts.filter { $0.category == .versicherung }
    }

    private var insuranceSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Versicherig", systemImage: "shield.lefthalf.filled")
                .font(.system(size: 15, weight: .bold, design: .rounded))
                .foregroundStyle(ArcaTicketsDesign.golfFairway)

            if insuranceContacts.isEmpty {
                Text("Reiseversicherig & Auslandskranken — Nummer und Police-Nr. hie parat.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(insuranceContacts) { contact in
                    HolidayContactCallRow(contact: contact, tint: ArcaTicketsDesign.golfFairway)
                }
            }
        }
        .padding(16)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(ArcaTicketsDesign.golfFairway.opacity(0.3), lineWidth: 1)
        }
    }

    private var kofferPINSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Koffer-PIN", systemImage: "lock.fill")
                .font(.system(size: 15, weight: .bold, design: .rounded))
                .foregroundStyle(ArcaTicketsDesign.travelOcean)

            Text("S'Zahlencode vom Koffer — schnell parat am Schalter.")
                .font(.caption)
                .foregroundStyle(.secondary)

            Button {
                showKofferPIN = true
            } label: {
                HStack {
                    Image(systemName: store.kofferPIN != nil ? "suitcase.fill" : "plus.circle.fill")
                        .foregroundStyle(ArcaTicketsDesign.travelOcean)
                    Text(store.kofferPIN != nil ? "Koffer-Code azeige" : "Koffer-Code iträge")
                        .font(.subheadline.weight(.semibold))
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.tertiary)
                }
                .padding(14)
                .background(ArcaTicketsDesign.travelOcean.opacity(0.08), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
            .buttonStyle(UnterwegsKlecksButtonStyle())
        }
        .padding(16)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(ArcaTicketsDesign.travelOcean.opacity(0.25), lineWidth: 1)
        }
        .sheet(isPresented: $showKofferPIN) {
            KofferPINSheet()
        }
    }

    private var reiseunterlagenPlaceholder: some View {
        VStack(spacing: 12) {
            Image(systemName: "doc.richtext.fill")
                .font(.system(size: 36))
                .foregroundStyle(ArcaTicketsDesign.travelSunset)
                .symbolRenderingMode(.hierarchical)

            Text("Reiseunterlage")
                .font(.system(size: 17, weight: .bold, design: .rounded))

            Text("Hotel-Bestätigung, Mietwagen, Eintritt — in dr volle Arca Tickets App chunnt bald en Ordner defür. Bis dänn: Notize oder Pass debii!")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(20)
        .background(
            LinearGradient(
                colors: [
                    ArcaTicketsDesign.travelSand.opacity(0.35),
                    ArcaTicketsDesign.travelSunset.opacity(0.12)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ),
            in: RoundedRectangle(cornerRadius: 16, style: .continuous)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(ArcaTicketsDesign.travelSunset.opacity(0.25), lineWidth: 1)
        }
    }
}

struct HolidayTaxiSheet: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var store: TicketStore
    @State private var showEditor = false

    private var homeTaxiContacts: [QuickContact] {
        store.quickContacts.filter {
            let label = $0.label.lowercased()
            return label.contains("taxi") || label.contains("tax")
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    holidaySheetIntro(
                        emoji: "🚕",
                        title: "Taxi — Urlaub & diheime",
                        subtitle: "Ein Tap zum Aarufe. Lang drucke zum Bearbeite."
                    )

                    vacationTaxiCard

                    if !homeTaxiContacts.isEmpty {
                        homeTaxiSection
                    }

                    addTaxiHint
                }
                .padding(16)
                .padding(.bottom, 24)
            }
            .background(holidaySheetBackground)
            .navigationTitle("Taxi")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(ArcaTicketsStrings.done) { dismiss() }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button(ArcaTicketsStrings.edit) { showEditor = true }
                }
            }
            .sheet(isPresented: $showEditor) {
                TaxiContactEditorView()
            }
        }
        .presentationDetents([.medium, .large])
    }

    private var vacationTaxiCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Taxi im Urlaub", systemImage: "sun.max.fill")
                .font(.system(size: 15, weight: .bold, design: .rounded))
                .foregroundStyle(ArcaTicketsDesign.taxiYellowDeep)

            let contact = store.taxiContact
            if contact.hasPhoneNumber {
                taxiCallRow(
                    title: contact.displayCompanyName.isEmpty ? "Taxi" : contact.displayCompanyName,
                    phone: contact.displayPhoneNumber,
                    tint: ArcaTicketsDesign.taxiYellowDeep
                ) {
                    if let url = contact.telURL {
                        TicketsHaptics.mediumImpact()
                        UIApplication.shared.open(url)
                    }
                }
            } else {
                Button {
                    showEditor = true
                } label: {
                    Label("Taxinummer iträge", systemImage: "plus.circle.fill")
                        .font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .foregroundStyle(ArcaTicketsDesign.taxiYellowDeep)
                        .background(ArcaTicketsDesign.taxiYellow.opacity(0.2), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(16)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(ArcaTicketsDesign.taxiYellow.opacity(0.4), lineWidth: 1)
        }
    }

    private var homeTaxiSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Taxi diheime", systemImage: "house.fill")
                .font(.system(size: 15, weight: .bold, design: .rounded))
                .foregroundStyle(ArcaTicketsDesign.travelOcean)

            ForEach(homeTaxiContacts) { contact in
                taxiCallRow(
                    title: contact.label,
                    phone: contact.displayPhoneNumber,
                    tint: ArcaTicketsDesign.travelOcean
                ) {
                    if let url = contact.telURL {
                        TicketsHaptics.mediumImpact()
                        UIApplication.shared.open(url)
                    }
                }
            }
        }
    }

    private var addTaxiHint: some View {
        Text("Tipp: Trag d'Taxi diheime under Nummerä → Sonstiges oder Familie ii.")
            .font(.caption)
            .foregroundStyle(.secondary)
            .padding(.horizontal, 4)
    }

    private func taxiCallRow(title: String, phone: String, tint: Color, action: @escaping () -> Void) -> some View {
        HolidayTaxiCallRow(title: title, phone: phone, tint: tint, action: action)
    }
}

private struct HolidayTaxiCallRow: View {
    let title: String
    let phone: String
    let tint: Color
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: "car.side.fill")
                    .font(.title3)
                    .foregroundStyle(tint)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                        .foregroundStyle(.primary)
                    Text(phone)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: "phone.fill")
                    .foregroundStyle(tint)
            }
            .padding(14)
            .background(tint.opacity(0.08), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .buttonStyle(UnterwegsKlecksButtonStyle())
    }
}

private struct HolidayContactCallRow: View {
    let contact: QuickContact
    let tint: Color

    var body: some View {
        Button {
            if let url = contact.telURL {
                TicketsHaptics.mediumImpact()
                UIApplication.shared.open(url)
            }
        } label: {
            HStack(spacing: 12) {
                Image(systemName: contact.category.icon)
                    .font(.title3)
                    .foregroundStyle(tint)
                VStack(alignment: .leading, spacing: 2) {
                    Text(contact.label)
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                        .foregroundStyle(.primary)
                    Text(contact.displayPhoneNumber)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    if let policy = contact.policyNumber, !policy.isEmpty {
                        Text("Police: \(policy)")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                }
                Spacer()
                if contact.hasPhoneNumber {
                    Image(systemName: "phone.fill")
                        .foregroundStyle(tint)
                }
            }
            .padding(14)
            .background(tint.opacity(0.08), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .buttonStyle(UnterwegsKlecksButtonStyle())
    }
}

struct HolidayBoardingSheet: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var store: TicketStore

    private var pinnedTickets: [TicketEntry] {
        store.unterwegsTickets()
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    holidaySheetIntro(
                        emoji: "🎫",
                        title: "Boarding Card",
                        subtitle: "Flug, Zug, Schiff — alles zum Zeige am Schalter."
                    )

                    if pinnedTickets.isEmpty {
                        boardingPlaceholder
                    } else {
                        ForEach(pinnedTickets) { ticket in
                            BoardingPassCard(ticket: ticket)
                        }
                    }
                }
                .padding(16)
                .padding(.bottom, 24)
            }
            .background(holidaySheetBackground)
            .navigationTitle("Boarding Card")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(ArcaTicketsStrings.done) { dismiss() }
                }
            }
        }
        .presentationDetents([.large])
    }

    private var boardingPlaceholder: some View {
        VStack(spacing: 14) {
            Image(systemName: "airplane.departure")
                .font(.system(size: 44))
                .foregroundStyle(ArcaTicketsDesign.travelGlassCyan)
                .symbolEffect(.pulse, options: .repeating)

            Text("No kei Ticket agheftet")
                .font(.system(size: 17, weight: .bold, design: .rounded))

            Text("In dr volle Arca Tickets App chunnt bald alles mit QR-Code und Ordner. Bis dänn: Pass und Notize debii — und gueti Reis! ✈️")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(24)
        .background(
            LinearGradient(
                colors: [
                    ArcaTicketsDesign.travelSky.opacity(0.25),
                    ArcaTicketsDesign.travelGlassCyan.opacity(0.12)
                ],
                startPoint: .top,
                endPoint: .bottom
            ),
            in: RoundedRectangle(cornerRadius: 16, style: .continuous)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(ArcaTicketsDesign.travelGlassCyan.opacity(0.3), lineWidth: 1)
        }
    }
}

// MARK: - Shared sheet chrome

@ViewBuilder
private func holidaySheetIntro(emoji: String, title: String, subtitle: String) -> some View {
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

private var holidaySheetBackground: some View {
    ZStack {
        Color(.systemGroupedBackground)
        LinearGradient(
            colors: [
                ArcaTicketsDesign.travelSand.opacity(0.18),
                ArcaTicketsDesign.travelSky.opacity(0.08),
                Color(.systemGroupedBackground)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()
    }
}

#Preview {
    ArcaHolidayView()
        .environmentObject(TicketStore())
}
