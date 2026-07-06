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

    /// Center point on the vertical hero (paint-splatter klecks, 473×1024).
    var point: CGPoint {
        switch self {
        case .golf:         CGPoint(x: 0.22, y: 0.22)
        case .taxi:         CGPoint(x: 0.76, y: 0.22)
        case .koffer:       CGPoint(x: 0.20, y: 0.77)
        case .pass:         CGPoint(x: 0.50, y: 0.77)
        case .notizen:      CGPoint(x: 0.80, y: 0.77)
        case .boardingCard: CGPoint(x: 0.50, y: 0.92)
        }
    }

    var hitSize: CGSize {
        switch self {
        case .golf, .taxi:      CGSize(width: 0.15, height: 0.085)
        case .koffer, .notizen: CGSize(width: 0.16, height: 0.09)
        case .pass:             CGSize(width: 0.15, height: 0.09)
        case .boardingCard:     CGSize(width: 0.22, height: 0.075)
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
    @Namespace private var glassNamespace

    @State private var activeSheet: ArcaHolidaySheet?
    @State private var tapHintVisible = false
    @State private var kleckWiggle = false
    @State private var flightChipTap = 0
    @State private var originKleck: ArcaHolidayKleck?

    private let heroAspect: CGFloat = 473.0 / 1024.0

    var body: some View {
        ZStack {
            GeometryReader { geo in
                let size = LayoutSafety.size(geo.size)

                ZStack {
                    Color.black.ignoresSafeArea()

                    heroImage(in: size)

                    if size.width > 1, size.height > 1 {
                        ForEach(ArcaHolidayKleck.allCases) { kleck in
                            ArcaHolidayKleckHotspot(
                                kleck: kleck,
                                containerSize: size
                            ) {
                                open(kleck)
                            }
                        }

                        if let ticket = store.flightTodayTicket {
                            flightTodayGlassChip(ticket: ticket, containerSize: size)
                        }
                    }
                }
            }
            .ignoresSafeArea()

            overlayChrome
        }
        .statusBarHidden(true)
        .sheet(item: $activeSheet, onDismiss: { originKleck = nil }) { sheet in
            holidaySheet(for: sheet)
                .presentationBackground(.ultraThinMaterial)
                .presentationDragIndicator(.visible)
        }
        .onAppear {
            presentTapHintIfNeeded()
            withAnimation(.easeInOut(duration: 1.4).repeatForever(autoreverses: true)) {
                kleckWiggle = true
            }
            if let sheet = store.pendingHolidaySheet {
                activeSheet = sheet
                store.pendingHolidaySheet = nil
            }
            FlightDayActivityManager.sync(with: store.flightTodayTicket)
        }
        .onChange(of: tapHintDismissed) { _, dismissed in
            if !dismissed {
                presentTapHintIfNeeded()
            } else {
                tapHintVisible = false
            }
        }
        .onChange(of: store.pendingHolidaySheet) { _, sheet in
            guard let sheet else { return }
            activeSheet = sheet
            store.pendingHolidaySheet = nil
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
            GlassEffectContainer(spacing: 16) {
                HStack(alignment: .top) {
                    grueeziBadge

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
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .ticketsGlass(
            tint: ArcaTicketsDesign.travelOcean.opacity(0.45),
            interactive: true,
            in: Capsule()
        )
        .shadow(color: .black.opacity(0.25), radius: 6, y: 2)
        .accessibilityLabel("Grüezi — willkomme i dr Ferie")
    }

    private var settingsButton: some View {
        Button {
            TicketsHaptics.lightImpact()
            activeSheet = .settings
        } label: {
            Image(systemName: "gearshape.fill")
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(.white.opacity(0.9))
                .frame(width: 40, height: 40)
                .ticketsGlass(
                    tint: ArcaTicketsDesign.travelGlassPurple.opacity(0.4),
                    interactive: true,
                    in: Circle()
                )
        }
        .buttonStyle(.glass)
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
        .foregroundStyle(.white.opacity(0.92))
        .padding(.horizontal, 18)
        .padding(.vertical, 10)
        .ticketsGlass(
            tint: ArcaTicketsDesign.travelSunset.opacity(0.35),
            interactive: false,
            in: Capsule()
        )
        .shadow(color: ArcaTicketsDesign.travelOcean.opacity(0.2), radius: 8, y: 3)
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
        withAnimation(.spring(response: 0.42, dampingFraction: 0.82)) {
            originKleck = kleck
        }
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
    private func flightTodayGlassChip(ticket: TicketEntry, containerSize: CGSize) -> some View {
        let kleck = ArcaHolidayKleck.boardingCard
        let chipX = LayoutSafety.dimension(kleck.point.x * containerSize.width, minimum: 0)
        let chipY = LayoutSafety.dimension((kleck.point.y - 0.11) * containerSize.height, minimum: 60)

        Button {
            flightChipTap += 1
            TicketsHaptics.lightImpact()
            withAnimation(.spring(response: 0.42, dampingFraction: 0.82)) {
                originKleck = .boardingCard
                activeSheet = .boarding
            }
        } label: {
            VStack(alignment: .leading, spacing: 5) {
                Text(ticket.flightTodayLine)
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                Text("🛂 Boarding Card")
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(.secondary)
                Text(ticket.gateLine)
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                Text(ticket.baggageLine)
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundStyle(.secondary)
            }
            .foregroundStyle(.primary)
            .padding(.horizontal, 14)
            .padding(.vertical, 11)
            .frame(maxWidth: min(containerSize.width * 0.72, 280), alignment: .leading)
            .ticketsGlass(
                tint: ArcaTicketsDesign.travelGlassCyan.opacity(0.38),
                interactive: true,
                in: RoundedRectangle(cornerRadius: 18, style: .continuous)
            )
            .shadow(color: ArcaTicketsDesign.travelOcean.opacity(0.22), radius: 14, y: 6)
        }
        .buttonStyle(.plain)
        .glassEffectID("flight-chip", in: glassNamespace)
        .sensoryFeedback(.selection, trigger: flightChipTap)
        .position(x: chipX, y: chipY)
        .transition(.scale(scale: 0.92).combined(with: .opacity))
        .accessibilityLabel("Flug hüt — \(ticket.title), \(ticket.gateLine)")
        .accessibilityHint("Tipp zum Öffne vo dr Boarding Card")
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
    @State private var tapCount = 0

    private var hitWidth: CGFloat {
        LayoutSafety.dimension(kleck.hitSize.width * containerSize.width, minimum: 44)
    }
    private var hitHeight: CGFloat {
        LayoutSafety.dimension(kleck.hitSize.height * containerSize.height, minimum: 44)
    }
    private var positionX: CGFloat {
        LayoutSafety.dimension(kleck.point.x * containerSize.width, minimum: 0)
    }
    private var positionY: CGFloat {
        LayoutSafety.dimension(kleck.point.y * containerSize.height, minimum: 0)
    }

    var body: some View {
        Button {
            tapCount += 1
            playRipple()
            onTap()
        } label: {
            ZStack {
                Circle()
                    .fill(kleck.rippleTint.opacity(rippleOpacity * 0.28))
                    .frame(width: hitWidth * 1.05, height: hitWidth * 1.05)
                    .scaleEffect(rippleScale)

                Circle()
                    .stroke(kleck.rippleTint.opacity(rippleOpacity), lineWidth: 2.5)
                    .frame(width: hitWidth * 1.1, height: hitWidth * 1.1)
                    .scaleEffect(rippleScale)

                Color.clear
                    .frame(width: hitWidth, height: hitHeight)
            }
            .frame(width: hitWidth, height: hitHeight)
            .contentShape(Circle())
        }
        .buttonStyle(HolidayKleckHotspotButtonStyle(tint: kleck.rippleTint))
        .sensoryFeedback(.impact(weight: .medium, intensity: 0.85), trigger: tapCount)
        .position(x: positionX, y: positionY)
        .accessibilityLabel(kleck.label)
        .accessibilityHint(kleck.accessibilityHint)
    }

    private func playRipple() {
        rippleScale = 0.7
        rippleOpacity = 0.9
        withAnimation(.easeOut(duration: 0.5)) {
            rippleScale = 1.4
            rippleOpacity = 0
        }
    }
}

/// Press-only feedback — no permanent glass lid on the hero klecks.
private struct HolidayKleckHotspotButtonStyle: ButtonStyle {
    let tint: Color

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .overlay {
                if configuration.isPressed {
                    Circle()
                        .fill(tint.opacity(0.18))
                }
            }
            .scaleEffect(configuration.isPressed ? 0.94 : 1)
            .animation(.spring(response: 0.2, dampingFraction: 0.68), value: configuration.isPressed)
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
                    .ticketsGlass(
                        tint: ArcaTicketsDesign.travelGlassPurple.opacity(0.25),
                        in: RoundedRectangle(cornerRadius: 14, style: .continuous)
                    )

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
        .ticketsGlass(
            tint: ArcaTicketsDesign.golfFairway.opacity(0.2),
            in: RoundedRectangle(cornerRadius: 16, style: .continuous)
        )
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
        .ticketsGlass(
            tint: ArcaTicketsDesign.travelOcean.opacity(0.2),
            in: RoundedRectangle(cornerRadius: 16, style: .continuous)
        )
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
        .ticketsGlass(
            tint: ArcaTicketsDesign.travelSunset.opacity(0.25),
            in: RoundedRectangle(cornerRadius: 16, style: .continuous)
        )
    }
}

struct HolidayTaxiSheet: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var store: TicketStore
    @State private var editingSlot: TaxiContactSlot?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    holidaySheetIntro(
                        emoji: "🚕",
                        title: "Taxi — Urlaub & diheime",
                        subtitle: "Zwei Nummerä, zwei Orte — tipp zum Aarufe, Stift zum Ändere."
                    )

                    vacationTaxiCard
                    homeTaxiCard
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
            }
            .sheet(item: $editingSlot) { slot in
                TaxiContactEditorView(slot: slot)
            }
        }
        .presentationDetents([.medium, .large])
    }

    private var vacationTaxiCard: some View {
        taxiSectionCard(
            slot: .vacation,
            contact: store.taxiContact,
            icon: "sun.max.fill",
            sectionTitle: "Taxi im Urlaub",
            tint: ArcaTicketsDesign.taxiYellowDeep,
            glassTint: ArcaTicketsDesign.taxiYellow.opacity(0.3)
        )
    }

    private var homeTaxiCard: some View {
        taxiSectionCard(
            slot: .home,
            contact: store.homeTaxiContact,
            icon: "house.fill",
            sectionTitle: "Taxi diheime",
            tint: ArcaTicketsDesign.travelOcean,
            glassTint: ArcaTicketsDesign.travelOcean.opacity(0.2)
        )
    }

    private func taxiSectionCard(
        slot: TaxiContactSlot,
        contact: TaxiContact,
        icon: String,
        sectionTitle: String,
        tint: Color,
        glassTint: Color
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label(sectionTitle, systemImage: icon)
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundStyle(tint)
                Spacer()
                Button {
                    editingSlot = slot
                } label: {
                    Image(systemName: "pencil.circle.fill")
                        .font(.title3)
                        .symbolRenderingMode(.hierarchical)
                        .foregroundStyle(tint)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("\(sectionTitle) bearbeite")
            }

            if contact.hasPhoneNumber {
                taxiCallRow(
                    title: contactDisplayName(contact, slot: slot),
                    phone: contact.displayPhoneNumber,
                    tint: tint
                ) {
                    if let url = contact.telURL {
                        TicketsHaptics.mediumImpact()
                        UIApplication.shared.open(url)
                    }
                }
                .contextMenu {
                    Button {
                        editingSlot = slot
                    } label: {
                        Label("Nummer ändere", systemImage: "pencil")
                    }
                }
            } else {
                Button {
                    editingSlot = slot
                } label: {
                    Label(slot.emptyCallLabel, systemImage: "plus.circle.fill")
                        .font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .foregroundStyle(tint)
                        .background(tint.opacity(0.12), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(16)
        .ticketsGlass(
            tint: glassTint,
            in: RoundedRectangle(cornerRadius: 16, style: .continuous)
        )
    }

    private func contactDisplayName(_ contact: TaxiContact, slot: TaxiContactSlot) -> String {
        let trimmed = contact.companyName.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? slot.defaultDisplayName : trimmed
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
    @State private var showAddTicket = false
    @State private var ticketToDelete: TicketEntry?
    @State private var showDeleteConfirm = false

    private var boardingTickets: [TicketEntry] {
        store.tickets
            .filter(\.isValid)
            .sorted { lhs, rhs in
                if lhs.isPinned != rhs.isPinned { return lhs.isPinned }
                return lhs.unterwegsSortDate < rhs.unterwegsSortDate
            }
    }

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        holidaySheetIntro(
                            emoji: "🎫",
                            title: "Boarding Card",
                            subtitle: "Flug, Zug, Schiff — alles zum Zeige am Schalter. Tipp uf 🗑️ zum Lösche."
                        )

                        if boardingTickets.isEmpty {
                            boardingEmptyState
                        } else {
                            ForEach(boardingTickets) { ticket in
                                BoardingPassCard(ticket: ticket) {
                                    deleteTicket(ticket)
                                }
                            }
                        }
                    }
                    .padding(16)
                    .padding(.bottom, boardingTickets.isEmpty ? 24 : 88)
                }

                if !boardingTickets.isEmpty {
                    TicketsFAB(
                        title: ArcaTicketsStrings.addBoardingPass,
                        useTravelGradient: true
                    ) {
                        showAddTicket = true
                    }
                    .padding(.bottom, 24)
                }
            }
            .background(holidaySheetBackground)
            .navigationTitle("Boarding Card")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(ArcaTicketsStrings.done) { dismiss() }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showAddTicket = true
                    } label: {
                        Image(systemName: "plus")
                    }
                    .accessibilityLabel(ArcaTicketsStrings.addBoardingPass)
                }
            }
            .sheet(isPresented: $showAddTicket) {
                AddTicketView(forHolidayBoarding: true)
            }
            .alert(ArcaTicketsStrings.deleteTicketTitle, isPresented: $showDeleteConfirm) {
                Button(ArcaTicketsStrings.cancel, role: .cancel) { ticketToDelete = nil }
                Button(ArcaTicketsStrings.delete, role: .destructive) {
                    if let ticket = ticketToDelete {
                        TicketsHaptics.delete()
                        store.deleteTicket(ticket)
                        store.showToast("Ticket isch weg 🗑️")
                    }
                    ticketToDelete = nil
                }
            } message: {
                if let ticket = ticketToDelete {
                    Text("\u{201E}\(ticket.title)\u{201C} würklich lösche? Das gaht nöd rückgängig.")
                }
            }
        }
        .presentationDetents([.large])
    }

    private func deleteTicket(_ ticket: TicketEntry) {
        if ticket.needsDeleteConfirmation {
            ticketToDelete = ticket
            showDeleteConfirm = true
        } else {
            TicketsHaptics.delete()
            store.deleteTicket(ticket)
            store.showToast("Ticket isch weg 🗑️")
        }
    }

    private var boardingEmptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "airplane.departure")
                .font(.system(size: 44))
                .foregroundStyle(ArcaTicketsDesign.travelGlassCyan)
                .symbolEffect(.pulse, options: .repeating)

            Text("No kei Boarding Pass debii")
                .font(.system(size: 17, weight: .bold, design: .rounded))

            Text("Importier dis Ticket als PDF, Foto oder mit dr Kamera — denn zeigsch de QR-Code am Schalter.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            Button {
                showAddTicket = true
            } label: {
                Label(ArcaTicketsStrings.addBoardingPass, systemImage: "plus.circle.fill")
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.glassProminent)
            .tint(ArcaTicketsDesign.travelOcean)
            .controlSize(.large)
        }
        .frame(maxWidth: .infinity)
        .padding(24)
        .ticketsGlass(
            tint: ArcaTicketsDesign.travelGlassCyan.opacity(0.3),
            in: RoundedRectangle(cornerRadius: 16, style: .continuous)
        )
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
