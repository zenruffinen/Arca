//
//  UnderwegsView.swift
//  ArcaTickets
//
//  Entwickler: Hans zen Ruffinen
//

import SwiftUI

struct UnderwegsView: View {
    @EnvironmentObject private var store: TicketStore
    @Binding var showAddTicket: Bool
    var isTabActive: Bool = true
    @AppStorage(TicketsTravelTips.swissKnifeDismissKey) private var swissKnifeTipDismissed = false
    @AppStorage(UnterwegsViewPreferences.viewModeKey) private var unterwegsViewModeRaw = UnterwegsViewMode.plakatwand.rawValue
    @AppStorage(UnterwegsViewPreferences.einstiegEnabledKey) private var ferienEinstiegEnabled = true
    @State private var glassTip = TicketsTravelTips.unterwegsGlassTip
    @State private var showFerienEinstieg = false
    @State private var einstiegDismissedThisVisit = false

    private var unterwegsViewMode: UnterwegsViewMode {
        UnterwegsViewMode(rawValue: unterwegsViewModeRaw) ?? .plakatwand
    }

    private var unterwegsTickets: [TicketEntry] {
        store.unterwegsTickets()
    }

    private var showGlassTip: Bool {
        !swissKnifeTipDismissed
    }

    var body: some View {
        ZStack {
            TravelGlassBackground()

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Group {
                        switch unterwegsViewMode {
                        case .plakatwand:
                            TravelSceneWithKlecks()
                        case .ferienGrafik:
                            UnterwegsHeroIllustrationScene()
                        }
                    }
                    .animation(.easeInOut(duration: 0.28), value: unterwegsViewModeRaw)

                    if unterwegsTickets.isEmpty {
                        UnterwegsHolidayEmptyState()
                    } else {
                        PinnedTicketPreview {
                            BoardingPassCard(ticket: unterwegsTickets[0])
                        }
                        .transition(.asymmetric(
                            insertion: .move(edge: .bottom).combined(with: .opacity),
                            removal: .opacity
                        ))

                        if unterwegsTickets.count > 1 {
                            Text(ArcaTicketsStrings.moreTickets)
                                .font(.system(size: 13, weight: .heavy, design: .rounded))
                                .foregroundStyle(ArcaTicketsDesign.travelGlassCyan)
                                .padding(.top, 4)

                            ForEach(Array(unterwegsTickets.dropFirst())) { ticket in
                                BoardingPassCard(ticket: ticket)
                                    .transition(.asymmetric(
                                        insertion: .move(edge: .bottom).combined(with: .opacity),
                                        removal: .opacity
                                    ))
                            }
                        }
                    }

                    if showGlassTip {
                        TravelGlassTipBanner(
                            tip: glassTip,
                            title: ArcaTicketsStrings.travelTip,
                            onDismiss: {
                                withAnimation(.easeOut(duration: 0.25)) {
                                    swissKnifeTipDismissed = true
                                }
                            },
                            onAdvance: {
                                withAnimation(.easeInOut(duration: 0.22)) {
                                    TicketsTravelTips.advanceUnterwegsGlassTip()
                                    glassTip = TicketsTravelTips.unterwegsGlassTip
                                }
                                TicketsHaptics.lightImpact()
                            }
                        )
                        .transition(.move(edge: .top).combined(with: .opacity))
                        .onAppear {
                            glassTip = TicketsTravelTips.unterwegsGlassTip
                        }
                    }

                    if store.isCloudSyncPending {
                        HStack(spacing: 8) {
                            ProgressView()
                            Text(store.iCloudStatus.rawValue)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.horizontal, 4)
                    }
                }
                .padding(.horizontal, UnterwegsKlecksMetrics.contentHorizontalPadding)
                .padding(.top, 4)
                .padding(.bottom, 100)
                .animation(.spring(response: 0.4, dampingFraction: 0.82), value: unterwegsTickets.map(\.id))
            }
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                ComicCurvedText(
                    text: SwissDialectPhrases.tabLabel,
                    style: .navTitle,
                    foreground: ArcaTicketsDesign.travelOcean
                )
                .padding(.vertical, 2)
            }
            ToolbarItem(placement: .topBarTrailing) {
                FerienSzeneOpenButton {
                    TicketsHaptics.lightImpact()
                    openFerienSzene()
                }
            }
        }
        .overlay(alignment: .bottom) {
            TicketsFAB(
                title: unterwegsTickets.isEmpty ? ArcaTicketsStrings.addFirstTrip : ArcaTicketsStrings.add,
                useTravelGradient: true
            ) {
                showAddTicket = true
            }
            .padding(.bottom, 24)
        }
        .fullScreenCover(isPresented: $showFerienEinstieg) {
            UnterwegsFerienEinstiegView {
                dismissFerienEinstieg()
            }
        }
        .onAppear {
            presentFerienEinstiegIfNeeded()
        }
        .onChange(of: isTabActive) { _, active in
            if active {
                einstiegDismissedThisVisit = false
                presentFerienEinstiegIfNeeded()
            }
        }
        .onChange(of: ferienEinstiegEnabled) { _, enabled in
            if !enabled {
                showFerienEinstieg = false
            }
        }
    }

    private func presentFerienEinstiegIfNeeded() {
        guard ferienEinstiegEnabled, isTabActive, !einstiegDismissedThisVisit else { return }
        guard !showFerienEinstieg else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            guard ferienEinstiegEnabled, isTabActive, !einstiegDismissedThisVisit else { return }
            showFerienEinstieg = true
        }
    }

    private func openFerienSzene() {
        guard !showFerienEinstieg else { return }
        showFerienEinstieg = true
    }

    private func dismissFerienEinstieg() {
        einstiegDismissedThisVisit = true
        showFerienEinstieg = false
    }
}

struct BoardingPassCard: View {
    @EnvironmentObject private var store: TicketStore
    let ticket: TicketEntry

    @State private var localTicket: TicketEntry
    @State private var showQRFullscreen = false
    @State private var editingField: TravelField?
    @State private var editText = ""
    @State private var editBoardingTime = Date()

    init(ticket: TicketEntry) {
        self.ticket = ticket
        _localTicket = State(initialValue: ticket)
    }

    private var style: TicketFolderStyle { .style(for: localTicket.folder) }
    private var tint: Color { ArcaTicketsDesign.tint(for: style.tintName) }
    private var fileURL: URL { store.fileURL(for: localTicket.fileName) }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            cardHeader
            perforatedDivider
            thumbnailSection
            perforatedDivider
            travelFieldsSection
            showAtCounterButton
        }
        .boardingPassCard(tint: tint)
        .fullScreenCover(isPresented: $showQRFullscreen) {
            QRFullscreenView(imageURL: fileURL)
        }
        .sheet(item: $editingField) { field in
            travelFieldEditor(for: field)
        }
        .onChange(of: store.tickets) { _, _ in
            if let current = store.tickets.first(where: { $0.id == ticket.id }) {
                localTicket = current
            }
        }
        .onChange(of: localTicket) { _, updated in
            store.updateTicket(updated)
        }
    }

    private var cardHeader: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 4) {
                Text(localTicket.folder.uppercased())
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(tint)
                    .tracking(1.2)

                Button {
                    editingField = .title
                    editText = localTicket.title
                } label: {
                    Text(localTicket.title)
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                        .foregroundStyle(.primary)
                        .multilineTextAlignment(.leading)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .buttonStyle(.plain)

                if let countdown = localTicket.expiryCountdownText {
                    Text(countdown)
                        .font(.caption.weight(.medium))
                        .foregroundStyle(localTicket.isExpired ? .red : .secondary)
                }
            }

            Spacer(minLength: 8)

            Button {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) {
                    store.togglePin(for: localTicket)
                    localTicket.isPinned.toggle()
                }
            } label: {
                Image(systemName: localTicket.isPinned ? "pin.fill" : "pin")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(localTicket.isPinned ? ArcaTicketsDesign.travelSunset : .secondary)
                    .symbolEffect(.bounce, value: localTicket.isPinned)
            }
            .buttonStyle(.plain)
            .ticketsMinTapTarget()
            .accessibilityLabel(localTicket.isPinned ? ArcaTicketsStrings.unpinFromUnterwegs : ArcaTicketsStrings.pinOnUnterwegs)
        }
        .padding(16)
    }

    @ViewBuilder
    private var thumbnailSection: some View {
        NavigationLink(value: localTicket) {
            Group {
                if localTicket.fileKind == .pdf {
                    HStack {
                        Image(systemName: "doc.richtext.fill")
                            .font(.largeTitle)
                            .foregroundStyle(tint)
                        Text("PDF-Ticket")
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 120)
                    .background(tint.opacity(0.06))
                } else if let uiImage = UIImage(contentsOfFile: fileURL.path) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFill()
                        .frame(maxWidth: .infinity)
                        .frame(height: 160)
                        .clipped()
                } else {
                    ContentUnavailableView("Vorschau lädt", systemImage: "photo")
                        .frame(height: 120)
                }
            }
        }
        .buttonStyle(.plain)
    }

    private var travelFieldsSection: some View {
        HStack(spacing: 0) {
            travelFieldCell(.flightNumber, label: "Flug", value: localTicket.flightNumber, placeholder: "—")
            fieldDivider
            travelFieldCell(.seatNumber, label: "Sitz", value: localTicket.seatNumber, placeholder: "—")
            fieldDivider
            boardingTimeCell
            if localTicket.gate != nil || editingField == .gate {
                fieldDivider
                travelFieldCell(.gate, label: "Gate", value: localTicket.gate, placeholder: "—")
            } else {
                fieldDivider
                Button {
                    editingField = .gate
                    editText = ""
                } label: {
                    VStack(spacing: 4) {
                        Text("Gate")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(.secondary)
                        Image(systemName: "plus")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(ArcaTicketsDesign.travelOcean)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.vertical, 4)
    }

    private func travelFieldCell(_ field: TravelField, label: String, value: String?, placeholder: String) -> some View {
        Button {
            editingField = field
            editText = value ?? ""
        } label: {
            VStack(spacing: 4) {
                Text(label)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.secondary)
                Text(value?.isEmpty == false ? value! : placeholder)
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundStyle(value?.isEmpty == false ? .primary : .tertiary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
        }
        .buttonStyle(.plain)
    }

    private var boardingTimeCell: some View {
        Button {
            editingField = .boardingTime
            editBoardingTime = localTicket.boardingTime ?? Date()
        } label: {
            VStack(spacing: 4) {
                Text("Boarding")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.secondary)
                if let text = localTicket.boardingTimeText {
                    Text(text)
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundStyle(.primary)
                } else {
                    Text("—")
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundStyle(.tertiary)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private var showAtCounterButton: some View {
        if localTicket.fileKind == .image {
            Button {
                TicketsHaptics.mediumImpact()
                showQRFullscreen = true
            } label: {
                Label(ArcaTicketsStrings.showAtCounter, systemImage: "qrcode.viewfinder")
                    .font(.system(size: 16, weight: .semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .foregroundStyle(.white)
                    .background(
                        LinearGradient(
                            colors: [tint, tint.opacity(0.75)],
                            startPoint: .leading,
                            endPoint: .trailing
                        ),
                        in: RoundedRectangle(cornerRadius: 0, style: .continuous)
                    )
            }
            .buttonStyle(.plain)
            .clipShape(
                UnevenRoundedRectangle(
                    bottomLeadingRadius: ArcaTicketsDesign.cornerRadius,
                    bottomTrailingRadius: ArcaTicketsDesign.cornerRadius
                )
            )
        }
    }

    private var perforatedDivider: some View {
        HStack(spacing: 6) {
            ForEach(0..<24, id: \.self) { _ in
                Circle()
                    .fill(Color(.separator).opacity(0.5))
                    .frame(width: 4, height: 4)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 6)
        .background(Color(.separator).opacity(0.08))
    }

    private var fieldDivider: some View {
        Rectangle()
            .fill(Color(.separator).opacity(0.3))
            .frame(width: 1)
            .padding(.vertical, 8)
    }

    @ViewBuilder
    private func travelFieldEditor(for field: TravelField) -> some View {
        NavigationStack {
            Form {
                switch field {
                case .title:
                    TextField("Titel", text: $editText)
                case .flightNumber:
                    TextField("Flugnummer", text: $editText)
                        .textInputAutocapitalization(.characters)
                case .seatNumber:
                    TextField("Sitzplatz", text: $editText)
                        .textInputAutocapitalization(.characters)
                case .gate:
                    TextField("Gate", text: $editText)
                        .textInputAutocapitalization(.characters)
                case .boardingTime:
                    DatePicker("Boarding-Zeit", selection: $editBoardingTime, displayedComponents: [.date, .hourAndMinute])
                }
            }
            .navigationTitle(field.label)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(ArcaTicketsStrings.cancel) { editingField = nil }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(ArcaTicketsStrings.done) {
                        applyFieldEdit(field)
                        editingField = nil
                    }
                }
            }
        }
        .presentationDetents([.medium])
    }

    private func applyFieldEdit(_ field: TravelField) {
        let trimmed = editText.trimmingCharacters(in: .whitespacesAndNewlines)
        switch field {
        case .title:
            localTicket.title = trimmed.isEmpty ? localTicket.title : trimmed
        case .flightNumber:
            localTicket.flightNumber = trimmed.isEmpty ? nil : trimmed
        case .seatNumber:
            localTicket.seatNumber = trimmed.isEmpty ? nil : trimmed
        case .gate:
            localTicket.gate = trimmed.isEmpty ? nil : trimmed
        case .boardingTime:
            localTicket.boardingTime = editBoardingTime
        }
        TicketsHaptics.lightImpact()
    }
}

enum TravelField: String, Identifiable {
    case title
    case flightNumber
    case seatNumber
    case boardingTime
    case gate

    var id: String { rawValue }

    var label: String {
        switch self {
        case .title: return "Titel"
        case .flightNumber: return "Flugnummer"
        case .seatNumber: return "Sitzplatz"
        case .boardingTime: return "Boarding-Zeit"
        case .gate: return "Gate"
        }
    }
}

#Preview {
    UnderwegsView(showAddTicket: .constant(false))
        .environmentObject(TicketStore())
}
