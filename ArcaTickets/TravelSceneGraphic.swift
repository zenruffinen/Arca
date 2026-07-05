//
//  TravelSceneGraphic.swift
//  ArcaTickets
//
//  Entwickler: Hans zen Ruffinen
//

import SwiftUI

// MARK: - Anchor map (organic placement on Ferien-Plakatwand)

enum UnterwegsSceneAnchor: CaseIterable {
    case visitenkarte
    case notizen
    case souvenirs
    case kofferPIN
    case taxi
    case golf

    /// Normalized 0…1 — deliberately off-grid, not row/column aligned.
    var point: CGPoint {
        switch self {
        case .visitenkarte: CGPoint(x: 0.19, y: 0.26)
        case .notizen:      CGPoint(x: 0.76, y: 0.14)
        case .souvenirs:    CGPoint(x: 0.47, y: 0.40)
        case .kofferPIN:    CGPoint(x: 0.84, y: 0.54)
        case .taxi:         CGPoint(x: 0.14, y: 0.70)
        case .golf:         CGPoint(x: 0.61, y: 0.80)
        }
    }

    /// Extra nudge in points — breaks any residual alignment.
    var placementOffset: CGSize {
        switch self {
        case .visitenkarte: CGSize(width: 5, height: -7)
        case .notizen:      CGSize(width: -9, height: 6)
        case .souvenirs:    CGSize(width: 11, height: -5)
        case .kofferPIN:    CGSize(width: -6, height: 9)
        case .taxi:         CGSize(width: 7, height: 4)
        case .golf:         CGSize(width: -11, height: -6)
        }
    }

    /// Unique tilt per note — Ferien-Plakatwand, not iOS grid.
    var placementRotation: Double {
        switch self {
        case .visitenkarte: 8.5
        case .notizen:     -11.0
        case .souvenirs:    5.5
        case .kofferPIN:   -7.5
        case .taxi:        12.0
        case .golf:        -9.5
        }
    }

    var noteScale: CGFloat {
        switch self {
        case .visitenkarte: 1.06
        case .notizen:      0.93
        case .souvenirs:    1.02
        case .kofferPIN:    1.00
        case .taxi:         0.95
        case .golf:         1.05
        }
    }

    /// Overlap layering — higher = on top.
    var zLayer: Double {
        switch self {
        case .visitenkarte: 3
        case .notizen:      5
        case .souvenirs:    2
        case .kofferPIN:    6
        case .taxi:         4
        case .golf:         1
        }
    }

    var glassTint: Color {
        switch self {
        case .visitenkarte: ArcaTicketsDesign.travelOcean
        case .notizen:      ArcaTicketsDesign.travelGlassPurple
        case .souvenirs:    ArcaTicketsDesign.travelSunset
        case .kofferPIN:    ArcaTicketsDesign.travelGlassCyan
        case .taxi:         ArcaTicketsDesign.taxiYellowDeep
        case .golf:         ArcaTicketsDesign.golfFairwayDeep
        }
    }

    /// Legacy alias
    var postItColor: Color { glassTint }

    var noteSize: (width: CGFloat, height: CGFloat) {
        switch self {
        case .visitenkarte: (72, 68)
        case .notizen:      (68, 64)
        case .souvenirs:    (70, 66)
        case .kofferPIN:    (76, 72)
        case .taxi:         (70, 68)
        case .golf:         (74, 70)
        }
    }
}

// MARK: - Ferien-Plakatwand + Klecks
// VB: PictureBox + freely placed Image, Click → action.

struct TravelSceneWithKlecks: View {
    private let anchors: [UnterwegsSceneAnchor] = UnterwegsSceneAnchor.allCases
        .sorted { $0.zLayer < $1.zLayer }

    var body: some View {
        GlasPlakatwandFrame(cornerRadius: 14) {
            GeometryReader { geo in
                let size = LayoutSafety.size(geo.size)
                ZStack {
                    FerienPlakatwandBackdrop(width: size.width, height: size.height)

                    TravelPosterLayer()
                        .opacity(0.38)
                        .scaleEffect(0.90)
                        .rotationEffect(.degrees(-2.8))
                        .allowsHitTesting(false)

                    FerienPlakatDecorations(width: size.width, height: size.height)

                    ForEach(anchors, id: \.self) { anchor in
                        sceneKlecks(at: anchor, in: size) {
                            kleckContent(for: anchor)
                        }
                        .zIndex(anchor.zLayer)
                    }
                }
            }
        }
        .aspectRatio(UnterwegsKlecksMetrics.sceneAspectRatio, contentMode: .fit)
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Schweizer Glas-Plakatwand mit Schnellzugriffen")
    }

    @ViewBuilder
    private func kleckContent(for anchor: UnterwegsSceneAnchor) -> some View {
        switch anchor {
        case .visitenkarte: VisitenkarteFloatingDecoration()
        case .notizen:      NotizenFloatingDecoration()
        case .souvenirs:    SouvenirsFloatingDecoration()
        case .kofferPIN:    KofferPINFloatingDecoration()
        case .taxi:         TaxiButtonView()
        case .golf:         GolfButtonView()
        }
    }

    private func anchorPosition(_ anchor: UnterwegsSceneAnchor, in size: CGSize) -> CGPoint {
        let safe = LayoutSafety.size(size)
        return CGPoint(
            x: LayoutSafety.dimension(anchor.point.x * safe.width, minimum: 0),
            y: LayoutSafety.dimension(anchor.point.y * safe.height, minimum: 0)
        )
    }

    @ViewBuilder
    private func sceneKlecks<Content: View>(
        at anchor: UnterwegsSceneAnchor,
        in size: CGSize,
        @ViewBuilder content: () -> Content
    ) -> some View {
        content()
            .environment(\.unterwegsAnchor, anchor)
            .scaleEffect(anchor.noteScale)
            .rotationEffect(.degrees(anchor.placementRotation))
            .offset(x: anchor.placementOffset.width, y: anchor.placementOffset.height)
            .position(anchorPosition(anchor, in: size))
    }
}

// MARK: - Cork backdrop + vacation scraps

private struct FerienPlakatwandBackdrop: View {
    let width: CGFloat
    let height: CGFloat

    var body: some View {
        GlasPlakatwandBackdrop()
    }
}

private struct FerienPlakatDecorations: View {
    let width: CGFloat
    let height: CGFloat

    var body: some View {
        ZStack {
            // Matterhorn-style peak poster
            MatterhornSilhouette()
                .fill(
                    LinearGradient(
                        colors: [
                            ArcaTicketsDesign.travelOcean.opacity(0.55),
                            ArcaTicketsDesign.travelGlassPurple.opacity(0.35)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(width: width * 0.22, height: height * 0.20)
                .overlay(alignment: .bottom) {
                    Text("Wallis")
                        .font(.system(size: height * 0.038, weight: .black, design: .rounded))
                        .foregroundStyle(.white.opacity(0.85))
                        .padding(.bottom, 4)
                }
                .shadow(color: .black.opacity(0.14), radius: 4, y: 2)
                .rotationEffect(.degrees(7))
                .position(x: width * 0.30, y: height * 0.58)
                .allowsHitTesting(false)

            // SBB train glass sticker
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(.ultraThinMaterial)
                .frame(width: width * 0.24, height: height * 0.09)
                .overlay {
                    HStack(spacing: 4) {
                        Image(systemName: "tram.fill")
                            .font(.system(size: height * 0.045, weight: .bold))
                            .foregroundStyle(ArcaTicketsDesign.travelGlassCyan)
                        Text("SBB")
                            .font(.system(size: height * 0.042, weight: .black, design: .rounded))
                            .foregroundStyle(ArcaTicketsDesign.travelOcean)
                    }
                }
                .overlay {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .strokeBorder(ArcaTicketsDesign.travelGlassCyan.opacity(0.45), lineWidth: 1)
                }
                .shadow(color: ArcaTicketsDesign.travelOcean.opacity(0.14), radius: 6, y: 2)
                .rotationEffect(.degrees(-8))
                .position(x: width * 0.68, y: height * 0.68)
                .allowsHitTesting(false)

            // Cow + cheese glass chip
            VStack(spacing: 2) {
                Image(systemName: "leaf.fill")
                    .font(.system(size: height * 0.035))
                    .foregroundStyle(ArcaTicketsDesign.golfFairway)
                Text("🐄")
                    .font(.system(size: height * 0.06))
            }
            .padding(6)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .strokeBorder(ArcaTicketsDesign.golfFairway.opacity(0.4), lineWidth: 1)
            }
            .shadow(color: ArcaTicketsDesign.golfFairway.opacity(0.12), radius: 4, y: 2)
            .rotationEffect(.degrees(16))
            .position(x: width * 0.90, y: height * 0.18)
            .allowsHitTesting(false)

            // Lake Geneva postcard
            RoundedRectangle(cornerRadius: 3, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [ArcaTicketsDesign.travelSky.opacity(0.7), ArcaTicketsDesign.travelGlassCyan.opacity(0.5)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(width: width * 0.20, height: height * 0.11)
                .overlay {
                    Image(systemName: "sailboat.fill")
                        .font(.system(size: height * 0.04))
                        .foregroundStyle(.white.opacity(0.9))
                }
                .shadow(color: .black.opacity(0.10), radius: 3, y: 1)
                .rotationEffect(.degrees(-12))
                .position(x: width * 0.42, y: height * 0.16)
                .allowsHitTesting(false)

            // "FERIEN in der CH" postcard
            RoundedRectangle(cornerRadius: 3, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [ArcaTicketsDesign.travelSand, ArcaTicketsDesign.travelSunset.opacity(0.55)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: width * 0.30, height: height * 0.13)
                .overlay {
                    VStack(spacing: 2) {
                        Text("FERIEN")
                            .font(.system(size: height * 0.048, weight: .black, design: .rounded))
                        Text("in der CH 🇨🇭")
                            .font(.system(size: height * 0.032, weight: .bold, design: .rounded))
                    }
                    .foregroundStyle(ArcaTicketsDesign.travelOcean.opacity(0.75))
                    .rotationEffect(.degrees(-3))
                }
                .shadow(color: .black.opacity(0.15), radius: 4, y: 2)
                .rotationEffect(.degrees(-14))
                .position(x: width * 0.55, y: height * 0.38)
                .allowsHitTesting(false)

            // Pajama-cross glass sticker (Nachthemd-Vibe)
            ZStack {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(.ultraThinMaterial)
                    .frame(width: width * 0.16, height: height * 0.14)
                SwissCrossPajamaPattern(crossSize: 7, spacing: 14)
                    .frame(width: width * 0.14, height: height * 0.12)
                    .opacity(0.18)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                SwissCrossStamp(size: height * 0.055)
                    .offset(x: width * 0.05, y: -height * 0.04)
            }
            .overlay {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .strokeBorder(.white.opacity(0.35), lineWidth: 1)
            }
            .shadow(color: ArcaTicketsDesign.travelOcean.opacity(0.12), radius: 5, y: 2)
            .rotationEffect(.degrees(11))
            .position(x: width * 0.72, y: height * 0.28)
            .allowsHitTesting(false)

            // Swiss glass flag
            ZStack(alignment: .top) {
                GlasPlakatPin(size: 8)
                    .offset(y: -4)
                SwissGlassFlag(size: height * 0.10, style: .decoration)
                    .padding(.top, 4)
            }
            .rotationEffect(.degrees(6))
            .shadow(color: ArcaTicketsDesign.travelOcean.opacity(0.12), radius: 4, y: 2)
            .position(x: width * 0.08, y: height * 0.12)
            .allowsHitTesting(false)

            // Edelweiss glass orb
            Image(systemName: "snowflake")
                .font(.system(size: height * 0.065, weight: .semibold))
                .foregroundStyle(.white.opacity(0.95))
                .padding(5)
                .background(.ultraThinMaterial, in: Circle())
                .overlay { Circle().strokeBorder(ArcaTicketsDesign.travelGlassCyan.opacity(0.5), lineWidth: 1) }
                .shadow(color: ArcaTicketsDesign.travelGlassCyan.opacity(0.15), radius: 4, y: 2)
                .rotationEffect(.degrees(-18))
                .position(x: width * 0.06, y: height * 0.48)
                .allowsHitTesting(false)

            // Sun + cross combo sticker
            ZStack {
                Image(systemName: "sun.max.fill")
                    .font(.system(size: height * 0.07, weight: .semibold))
                    .foregroundStyle(ArcaTicketsDesign.travelSunYellow.opacity(0.55))
                SwissCrossStamp(size: height * 0.035)
                    .offset(x: width * 0.04, y: height * 0.03)
            }
            .rotationEffect(.degrees(18))
            .position(x: width * 0.93, y: height * 0.42)
            .allowsHitTesting(false)

            // Glass tape strips
            RoundedRectangle(cornerRadius: 1)
                .fill(.white.opacity(0.35))
                .frame(width: width * 0.18, height: 10)
                .rotationEffect(.degrees(-32))
                .shadow(color: .white.opacity(0.2), radius: 1, y: 1)
                .position(x: width * 0.22, y: height * 0.08)
                .allowsHitTesting(false)

            RoundedRectangle(cornerRadius: 1)
                .fill(.white.opacity(0.28))
                .frame(width: width * 0.12, height: 8)
                .rotationEffect(.degrees(22))
                .position(x: width * 0.50, y: height * 0.88)
                .allowsHitTesting(false)
        }
    }
}

private struct MatterhornSilhouette: Shape {
    func path(in rect: CGRect) -> Path {
        let w = rect.width
        let h = rect.height
        var path = Path()
        path.move(to: CGPoint(x: w * 0.5, y: 0))
        path.addLine(to: CGPoint(x: w * 0.72, y: h * 0.55))
        path.addLine(to: CGPoint(x: w * 0.82, y: h))
        path.addLine(to: CGPoint(x: w * 0.18, y: h))
        path.addLine(to: CGPoint(x: w * 0.28, y: h * 0.55))
        path.closeSubpath()
        return path
    }
}

// MARK: - Travel illustration (faded poster on the wall)

private struct TravelPosterLayer: View {
    var body: some View {
        TravelSceneGraphic()
    }
}

struct TravelSceneGraphic: View {
    var body: some View {
        GeometryReader { geo in
            let w = LayoutSafety.dimension(geo.size.width)
            let h = LayoutSafety.dimension(geo.size.height)

            ZStack {
                skyLayer(width: w, height: h)
                mountainsLayer(width: w, height: h)
                airportLayer(width: w, height: h)
                golfLayer(width: w, height: h)
                hotelLayer(width: w, height: h)
                giftShopLayer(width: w, height: h)
                roadLayer(width: w, height: h)

                cloud(at: CGPoint(x: w * 0.38, y: h * 0.11), scale: 1.0, tint: .white)
                cloud(at: CGPoint(x: w * 0.62, y: h * 0.08), scale: 0.75, tint: ArcaTicketsDesign.travelSky.opacity(0.95))
                cloud(at: CGPoint(x: w * 0.48, y: h * 0.18), scale: 0.6, tint: ArcaTicketsDesign.travelSand.opacity(0.92))
            }
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
        .accessibilityHidden(true)
    }

    private func skyLayer(width w: CGFloat, height h: CGFloat) -> some View {
        ZStack {
            LinearGradient(
                colors: [
                    ArcaTicketsDesign.travelSky.opacity(0.92),
                    ArcaTicketsDesign.travelGlassCyan.opacity(0.55),
                    ArcaTicketsDesign.travelSand.opacity(0.72),
                    ArcaTicketsDesign.travelSunset.opacity(0.22)
                ],
                startPoint: .top,
                endPoint: .bottom
            )

            Circle()
                .fill(ArcaTicketsDesign.travelSunYellow.opacity(0.18))
                .frame(width: w * 0.35, height: w * 0.35)
                .blur(radius: 18)
                .offset(x: w * 0.28, y: -h * 0.04)
        }
        .frame(width: w, height: h * 0.72)
        .frame(maxHeight: .infinity, alignment: .top)
    }

    private func mountainsLayer(width w: CGFloat, height h: CGFloat) -> some View {
        TravelMountainSilhouette()
            .fill(
                LinearGradient(
                    colors: [
                        ArcaTicketsDesign.travelGlassPurple.opacity(0.48),
                        ArcaTicketsDesign.travelOcean.opacity(0.42),
                        ArcaTicketsDesign.golfFairwayDeep.opacity(0.32)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .overlay(alignment: .top) {
                TravelMountainSilhouette()
                    .fill(
                        LinearGradient(
                            colors: [.white.opacity(0.75), .clear],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .frame(height: h * 0.09)
            }
            .frame(width: w * 1.05, height: h * 0.28)
            .position(x: w * 0.5, y: h * 0.44)
    }

    private func airportLayer(width w: CGFloat, height h: CGFloat) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 4, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            ArcaTicketsDesign.travelGlassCyan.opacity(0.45),
                            ArcaTicketsDesign.travelSky.opacity(0.35)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: w * 0.22, height: h * 0.09)

            Image(systemName: "airplane")
                .font(.system(size: h * 0.09, weight: .semibold))
                .foregroundStyle(ArcaTicketsDesign.travelOcean)
                .rotationEffect(.degrees(-18))
                .offset(x: w * 0.06, y: -h * 0.05)
        }
        .position(x: w * 0.54, y: h * 0.30)
    }

    private func golfLayer(width w: CGFloat, height h: CGFloat) -> some View {
        Ellipse()
            .fill(ArcaTicketsDesign.golfFairway.opacity(0.78))
            .frame(width: w * 0.24, height: h * 0.14)
            .position(x: w * 0.84, y: h * 0.70)
    }

    private func hotelLayer(width w: CGFloat, height h: CGFloat) -> some View {
        RoundedRectangle(cornerRadius: 3, style: .continuous)
            .fill(ArcaTicketsDesign.travelGlassPurple.opacity(0.55))
            .frame(width: w * 0.14, height: h * 0.16)
            .position(x: w * 0.68, y: h * 0.62)
    }

    private func giftShopLayer(width w: CGFloat, height h: CGFloat) -> some View {
        RoundedRectangle(cornerRadius: 5, style: .continuous)
            .fill(ArcaTicketsDesign.travelSunset.opacity(0.42))
            .frame(width: w * 0.12, height: h * 0.10)
            .position(x: w * 0.22, y: h * 0.38)
    }

    private func roadLayer(width w: CGFloat, height h: CGFloat) -> some View {
        TravelRoadShape()
            .fill(ArcaTicketsDesign.travelSand.opacity(0.75))
            .frame(width: w, height: h * 0.22)
            .position(x: w * 0.5, y: h * 0.88)
    }

    private func cloud(at point: CGPoint, scale: CGFloat, tint: Color = .white) -> some View {
        HStack(spacing: -6) {
            Circle().frame(width: 14, height: 14)
            Circle().frame(width: 20, height: 20)
            Circle().frame(width: 16, height: 16)
        }
        .foregroundStyle(tint.opacity(0.82))
        .scaleEffect(scale)
        .position(point)
    }
}

// MARK: - Anchor environment (Post-it color/size per kleck)

struct UnterwegsAnchorKey: EnvironmentKey {
    static let defaultValue: UnterwegsSceneAnchor? = nil
}

extension EnvironmentValues {
    var unterwegsAnchor: UnterwegsSceneAnchor? {
        get { self[UnterwegsAnchorKey.self] }
        set { self[UnterwegsAnchorKey.self] = newValue }
    }
}

// MARK: - Shapes

private struct TravelMountainSilhouette: Shape {
    func path(in rect: CGRect) -> Path {
        let w = rect.width
        let h = rect.height
        var path = Path()
        path.move(to: CGPoint(x: 0, y: h))
        path.addLine(to: CGPoint(x: w * 0.12, y: h * 0.55))
        path.addLine(to: CGPoint(x: w * 0.22, y: h * 0.72))
        path.addLine(to: CGPoint(x: w * 0.35, y: h * 0.38))
        path.addLine(to: CGPoint(x: w * 0.48, y: h * 0.58))
        path.addLine(to: CGPoint(x: w * 0.58, y: h * 0.28))
        path.addLine(to: CGPoint(x: w * 0.70, y: h * 0.52))
        path.addLine(to: CGPoint(x: w * 0.82, y: h * 0.35))
        path.addLine(to: CGPoint(x: w * 0.92, y: h * 0.62))
        path.addLine(to: CGPoint(x: w, y: h * 0.48))
        path.addLine(to: CGPoint(x: w, y: h))
        path.closeSubpath()
        return path
    }
}

private struct TravelRoadShape: Shape {
    func path(in rect: CGRect) -> Path {
        let w = rect.width
        let h = rect.height
        var path = Path()
        path.move(to: CGPoint(x: 0, y: h * 0.35))
        path.addQuadCurve(
            to: CGPoint(x: w * 0.45, y: h * 0.55),
            control: CGPoint(x: w * 0.18, y: h * 0.62)
        )
        path.addQuadCurve(
            to: CGPoint(x: w, y: h * 0.42),
            control: CGPoint(x: w * 0.72, y: h * 0.48)
        )
        path.addLine(to: CGPoint(x: w, y: h))
        path.addLine(to: CGPoint(x: 0, y: h))
        path.closeSubpath()
        return path
    }
}

// MARK: - Previews

#Preview("Plakatwand mit Klecks") {
    TravelSceneWithKlecks()
        .padding(16)
        .frame(maxWidth: 400)
        .background { TravelGlassBackground() }
        .environmentObject(TicketStore())
}

#Preview("TravelSceneGraphic") {
    TravelSceneGraphic()
        .frame(width: 320, height: 240)
        .padding(16)
        .background { TravelGlassBackground() }
}
