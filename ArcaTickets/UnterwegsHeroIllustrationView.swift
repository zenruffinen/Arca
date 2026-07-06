//
//  UnterwegsHeroIllustrationView.swift
//  ArcaTickets
//
//  Entwickler: Hans zen Ruffinen
//

import SwiftUI

// MARK: - View mode preference

enum UnterwegsViewMode: String, CaseIterable, Identifiable {
    case plakatwand
    case ferienGrafik

    var id: String { rawValue }

    var label: String {
        switch self {
        case .plakatwand: return "Glas-Plakatwand"
        case .ferienGrafik: return "Ferien-Grafik"
        }
    }

    var settingsIcon: String {
        switch self {
        case .plakatwand: return "square.grid.3x3.fill"
        case .ferienGrafik: return "photo.artframe"
        }
    }
}

enum UnterwegsViewPreferences {
    static let viewModeKey = "unterwegs.viewMode"
    static let einstiegEnabledKey = "unterwegs.einstiegEnabled"
    static let ferienTapHintDismissedKey = "unterwegs.ferienTapHintDismissed"

    static var viewMode: UnterwegsViewMode {
        get {
            let raw = UserDefaults.standard.string(forKey: viewModeKey) ?? UnterwegsViewMode.plakatwand.rawValue
            return UnterwegsViewMode(rawValue: raw) ?? .plakatwand
        }
        set {
            UserDefaults.standard.set(newValue.rawValue, forKey: viewModeKey)
        }
    }

    /// Ferien-Grafik als Einstieg beim Öffnen des Unterwägs-Tabs.
    static var einstiegEnabled: Bool {
        get {
            if UserDefaults.standard.object(forKey: einstiegEnabledKey) == nil { return true }
            return UserDefaults.standard.bool(forKey: einstiegEnabledKey)
        }
        set {
            UserDefaults.standard.set(newValue, forKey: einstiegEnabledKey)
        }
    }

    /// Einmal-Hinweis „Tippe auf Wegweiser & Objekte“ bereits gezeigt.
    static var ferienTapHintDismissed: Bool {
        get { UserDefaults.standard.bool(forKey: ferienTapHintDismissedKey) }
        set { UserDefaults.standard.set(newValue, forKey: ferienTapHintDismissedKey) }
    }
}

// MARK: - Hidden hotspot map (normalized 0…1 on illustration)

private enum UnterwegsHeroHotspotAction {
    case kleck(UnterwegsSceneAnchor)
    case weiter
}

private struct UnterwegsHeroHotspot: Identifiable {
    let id: String
    let action: UnterwegsHeroHotspotAction
    let point: CGPoint
    let size: CGSize
    let accessibilityHint: String

    static let all: [UnterwegsHeroHotspot] = [
        // Signpost arrows
        UnterwegsHeroHotspot(id: "sign-berge", action: .kleck(.visitenkarte), point: CGPoint(x: 0.09, y: 0.33), size: CGSize(width: 0.11, height: 0.07), accessibilityHint: "Berge — Visitenkarte"),
        UnterwegsHeroHotspot(id: "sign-golf", action: .kleck(.golf), point: CGPoint(x: 0.10, y: 0.41), size: CGSize(width: 0.11, height: 0.07), accessibilityHint: "Golf"),
        UnterwegsHeroHotspot(id: "sign-genuss", action: .kleck(.souvenirs), point: CGPoint(x: 0.08, y: 0.49), size: CGSize(width: 0.11, height: 0.07), accessibilityHint: "Genuss — Souvenirs"),
        UnterwegsHeroHotspot(id: "sign-meer", action: .kleck(.notizen), point: CGPoint(x: 0.07, y: 0.57), size: CGSize(width: 0.11, height: 0.07), accessibilityHint: "Meer — Notizen"),
        UnterwegsHeroHotspot(id: "sign-abenteuer", action: .kleck(.taxi), point: CGPoint(x: 0.08, y: 0.65), size: CGSize(width: 0.11, height: 0.07), accessibilityHint: "Abenteuer — Taxi"),
        UnterwegsHeroHotspot(id: "sign-entspannung", action: .kleck(.kofferPIN), point: CGPoint(x: 0.09, y: 0.73), size: CGSize(width: 0.11, height: 0.07), accessibilityHint: "Entspannung — Koffer-PIN"),

        // Scene objects
        UnterwegsHeroHotspot(id: "man-suitcase", action: .kleck(.visitenkarte), point: CGPoint(x: 0.24, y: 0.60), size: CGSize(width: 0.18, height: 0.24), accessibilityHint: "Reisender mit Koffer — Visitenkarte"),
        UnterwegsHeroHotspot(id: "marmot", action: .kleck(.souvenirs), point: CGPoint(x: 0.14, y: 0.74), size: CGSize(width: 0.10, height: 0.12), accessibilityHint: "Murmeltier — Souvenirs für Opa"),
        UnterwegsHeroHotspot(id: "magazine", action: .kleck(.notizen), point: CGPoint(x: 0.43, y: 0.87), size: CGSize(width: 0.14, height: 0.11), accessibilityHint: "Unterwägs-Magazin — Notizen"),
        UnterwegsHeroHotspot(id: "tablet-arca", action: .weiter, point: CGPoint(x: 0.72, y: 0.90), size: CGSize(width: 0.13, height: 0.12), accessibilityHint: "ARCA-Tablet — Weiter zu Tickets"),
        UnterwegsHeroHotspot(id: "suitcase-stickers", action: .kleck(.kofferPIN), point: CGPoint(x: 0.10, y: 0.82), size: CGSize(width: 0.14, height: 0.14), accessibilityHint: "Koffer mit Stickern — Koffer-PIN"),
        UnterwegsHeroHotspot(id: "train", action: .kleck(.taxi), point: CGPoint(x: 0.48, y: 0.50), size: CGSize(width: 0.16, height: 0.11), accessibilityHint: "SBB-Zug — Taxi"),
        UnterwegsHeroHotspot(id: "golf-bag", action: .kleck(.golf), point: CGPoint(x: 0.66, y: 0.56), size: CGSize(width: 0.15, height: 0.20), accessibilityHint: "ARCA Golf — Golfschläger"),
    ]
}

// MARK: - Inline scene (settings: Ferien-Grafik in scroll)

struct UnterwegsHeroIllustrationScene: View {
    private let aspectRatio: CGFloat = 1024.0 / 682.0

    var body: some View {
        GlasPlakatwandFrame(cornerRadius: 14) {
            UnterwegsHeroHotspotLayer(onContinue: nil)
        }
        .aspectRatio(aspectRatio, contentMode: .fit)
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Ferie-Grafik mit versteckte Schnellzuegriff")
    }
}

// MARK: - Ferien-Szene opener (toolbar)

struct FerienSzeneOpenButton: View {
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 5) {
                Image(systemName: "photo.artframe")
                    .font(.system(size: 12, weight: .semibold))
                Text("Zeerscht")
                    .font(.system(size: 13, weight: .heavy, design: .rounded))
            }
            .foregroundStyle(ArcaTicketsDesign.travelOcean)
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(.ultraThinMaterial, in: Capsule())
            .overlay {
                Capsule()
                    .strokeBorder(
                        LinearGradient(
                            colors: [.white.opacity(0.55), ArcaTicketsDesign.travelGlassCyan.opacity(0.45)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
            }
            .shadow(color: ArcaTicketsDesign.travelOcean.opacity(0.18), radius: 6, y: 2)
        }
        .buttonStyle(UnterwegsKlecksButtonStyle())
        .accessibilityLabel(ArcaTicketsStrings.voZeerschtOpen)
    }
}

// MARK: - Full-screen Ferien-Einstieg

struct UnterwegsFerienEinstiegView: View {
    var onContinue: () -> Void

    @AppStorage(UnterwegsViewPreferences.ferienTapHintDismissedKey) private var tapHintDismissed = false
    @State private var tapHintVisible = false
    @State private var swipeHintVisible = true
    @State private var dragOffset: CGFloat = 0

    private let dismissThreshold: CGFloat = 90

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            GeometryReader { geo in
                UnterwegsHeroHotspotLayer(
                    containerSize: geo.size,
                    onContinue: onContinue
                )
            }
            .ignoresSafeArea()

            VStack {
                HStack {
                    Spacer()
                    weiterGlassButton
                        .padding(.top, 8)
                        .padding(.trailing, 16)
                }
                Spacer()
                VStack(spacing: 10) {
                    if tapHintVisible {
                        ferienTapHint
                            .transition(.opacity.combined(with: .move(edge: .bottom)))
                    }
                    if swipeHintVisible {
                        swipeHint
                            .transition(.opacity.combined(with: .move(edge: .bottom)))
                    }
                }
                .padding(.bottom, 12)
            }
            .padding(.horizontal, 12)
            .safeAreaPadding(.top, 4)
            .safeAreaPadding(.bottom, 4)
        }
        .offset(y: max(0, dragOffset))
        .gesture(swipeDownGesture)
        .statusBarHidden(true)
        .persistentSystemOverlays(.hidden)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Zeerscht — tipp uf d'Szene oder s'ARCA-Tablet")
        .onAppear {
            presentTapHintIfNeeded()
            DispatchQueue.main.asyncAfter(deadline: .now() + 4) {
                withAnimation(.easeOut(duration: 0.5)) {
                    swipeHintVisible = false
                }
            }
        }
    }

    private func presentTapHintIfNeeded() {
        guard !tapHintDismissed else { return }
        tapHintVisible = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
            withAnimation(.easeOut(duration: 0.55)) {
                tapHintVisible = false
            }
            tapHintDismissed = true
        }
    }

    private var ferienTapHint: some View {
        HStack(spacing: 8) {
            Image(systemName: "hand.tap.fill")
                .font(.caption.weight(.bold))
            Text("Tipp uf Wegweiser & Objekt")
                .font(.caption.weight(.semibold))
        }
        .foregroundStyle(.white.opacity(0.88))
        .padding(.horizontal, 16)
        .padding(.vertical, 9)
        .background(.ultraThinMaterial.opacity(0.65), in: Capsule())
        .overlay {
            Capsule()
                .strokeBorder(
                    LinearGradient(
                        colors: [.white.opacity(0.5), ArcaTicketsDesign.travelGlassCyan.opacity(0.45)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
        }
        .shadow(color: ArcaTicketsDesign.travelOcean.opacity(0.22), radius: 8, y: 3)
        .accessibilityLabel("Tipp: Tipp uf Wegweiser und Objekt in dr Szene")
    }

    private var weiterGlassButton: some View {
        Button {
            TicketsHaptics.lightImpact()
            onContinue()
        } label: {
            HStack(spacing: 6) {
                Text(ArcaTicketsStrings.continue)
                    .font(.system(size: 15, weight: .heavy, design: .rounded))
                Image(systemName: "arrow.right.circle.fill")
                    .font(.system(size: 16, weight: .semibold))
            }
            .foregroundStyle(.white.opacity(0.95))
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(.ultraThinMaterial, in: Capsule())
            .overlay {
                Capsule()
                    .strokeBorder(
                        LinearGradient(
                            colors: [.white.opacity(0.55), ArcaTicketsDesign.travelGlassCyan.opacity(0.45)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1.2
                    )
            }
            .shadow(color: ArcaTicketsDesign.travelOcean.opacity(0.28), radius: 10, y: 4)
        }
        .buttonStyle(UnterwegsKlecksButtonStyle())
        .accessibilityLabel(ArcaTicketsStrings.voContinueTickets)
    }

    private var swipeHint: some View {
        HStack(spacing: 6) {
            Image(systemName: "chevron.compact.down")
                .font(.caption.weight(.bold))
            Text("Nach unte wische")
                .font(.caption.weight(.semibold))
        }
        .foregroundStyle(.white.opacity(0.72))
        .padding(.horizontal, 14)
        .padding(.vertical, 7)
        .background(.ultraThinMaterial.opacity(0.55), in: Capsule())
    }

    private var swipeDownGesture: some Gesture {
        DragGesture(minimumDistance: 24, coordinateSpace: .local)
            .onChanged { value in
                guard value.translation.height > 0 else { return }
                dragOffset = value.translation.height
            }
            .onEnded { value in
                if value.translation.height > dismissThreshold {
                    TicketsHaptics.lightImpact()
                    onContinue()
                } else {
                    withAnimation(.spring(response: 0.32, dampingFraction: 0.78)) {
                        dragOffset = 0
                    }
                }
            }
    }
}

// MARK: - Shared hotspot layer

private struct UnterwegsHeroHotspotLayer: View {
    var containerSize: CGSize? = nil
    var onContinue: (() -> Void)?

    var body: some View {
        GeometryReader { geo in
            let size = LayoutSafety.size(containerSize ?? geo.size)
            ZStack {
                Image("UnterwegsHeroIllustration")
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: size.width, height: size.height)
                    .clipped()
                    .accessibilityHidden(true)

                if size.width > 1, size.height > 1 {
                    ForEach(UnterwegsHeroHotspot.all) { hotspot in
                        UnterwegsHeroHiddenHotspot(
                            hotspot: hotspot,
                            containerSize: size,
                            onContinue: onContinue
                        )
                    }
                }
            }
            .frame(width: size.width, height: size.height)
        }
    }
}

/// Invisible tap region — reuses existing kleck actions (sheet, call, toggle).
private struct UnterwegsHeroHiddenHotspot: View {
    let hotspot: UnterwegsHeroHotspot
    let containerSize: CGSize
    var onContinue: (() -> Void)?

    private var hitWidth: CGFloat {
        LayoutSafety.dimension(hotspot.size.width * containerSize.width, minimum: 44)
    }
    private var hitHeight: CGFloat {
        LayoutSafety.dimension(hotspot.size.height * containerSize.height, minimum: 44)
    }
    private var positionX: CGFloat {
        LayoutSafety.dimension(hotspot.point.x * containerSize.width, minimum: 0)
    }
    private var positionY: CGFloat {
        LayoutSafety.dimension(hotspot.point.y * containerSize.height, minimum: 0)
    }

    var body: some View {
        Group {
            switch hotspot.action {
            case .weiter:
                weiterHotspot
            case .kleck:
                kleckHotspot
            }
        }
        .frame(width: hitWidth, height: hitHeight)
        .contentShape(Rectangle())
        .position(x: positionX, y: positionY)
        .accessibilityLabel(hotspot.accessibilityHint)
        .accessibilityAddTraits(.isButton)
    }

    @ViewBuilder
    private var weiterHotspot: some View {
        if let onContinue {
            Button {
                TicketsHaptics.mediumImpact()
                onContinue()
            } label: {
                Color.clear
            }
            .buttonStyle(UnterwegsKlecksButtonStyle())
        }
    }

    @ViewBuilder
    private var kleckHotspot: some View {
        kleckContent
            .opacity(0.01)
            .allowsHitTesting(true)
    }

    @ViewBuilder
    private var kleckContent: some View {
        if case .kleck(let anchor) = hotspot.action {
            switch anchor {
            case .visitenkarte: VisitenkarteFloatingDecoration()
            case .notizen:      NotizenFloatingDecoration()
            case .souvenirs:    SouvenirsFloatingDecoration()
            case .kofferPIN:    KofferPINFloatingDecoration()
            case .taxi:         TaxiButtonView()
            case .golf:         GolfButtonView()
            }
        }
    }
}
