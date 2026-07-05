//
//  TravelSceneGraphic.swift
//  ArcaTickets
//
//  Entwickler: Hans zen Ruffinen
//

import SwiftUI

// MARK: - Anchor map (normalized 0…1 on scene)

enum UnterwegsSceneAnchor: CaseIterable {
    case visitenkarte
    case notizen
    case souvenirs
    case kofferPIN
    case taxi
    case golf

    var point: CGPoint {
        switch self {
        case .visitenkarte: CGPoint(x: 0.13, y: 0.64)
        case .notizen:      CGPoint(x: 0.87, y: 0.40)
        case .souvenirs:    CGPoint(x: 0.26, y: 0.50)
        case .kofferPIN:    CGPoint(x: 0.74, y: 0.56)
        case .taxi:         CGPoint(x: 0.17, y: 0.84)
        case .golf:         CGPoint(x: 0.86, y: 0.80)
        }
    }

    var zoneLabel: String {
        switch self {
        case .visitenkarte: "Pass"
        case .notizen:      "Notizen"
        case .souvenirs:    "Souvenirs"
        case .kofferPIN:    "Hotel"
        case .taxi:         "Taxi"
        case .golf:         "Golf"
        }
    }
}

// MARK: - Scene + Klecks

struct TravelSceneWithKlecks: View {
    var body: some View {
        GeometryReader { geo in
            let size = geo.size
            ZStack {
                TravelSceneGraphic()

                ForEach(UnterwegsSceneAnchor.allCases, id: \.self) { anchor in
                    SceneAnchorMarker(label: anchor.zoneLabel)
                        .position(anchorPosition(anchor, in: size))
                        .allowsHitTesting(false)
                }

                sceneKlecks(at: .visitenkarte, in: size) { VisitenkarteFloatingDecoration() }
                sceneKlecks(at: .notizen, in: size) { NotizenFloatingDecoration() }
                sceneKlecks(at: .souvenirs, in: size) { SouvenirsFloatingDecoration() }
                sceneKlecks(at: .kofferPIN, in: size) { KofferPINFloatingDecoration() }
                sceneKlecks(at: .taxi, in: size) { TaxiButtonView() }
                sceneKlecks(at: .golf, in: size) { GolfButtonView() }
            }
        }
        .aspectRatio(UnterwegsKlecksMetrics.sceneAspectRatio, contentMode: .fit)
        .frame(maxWidth: .infinity)
    }

    private func anchorPosition(_ anchor: UnterwegsSceneAnchor, in size: CGSize) -> CGPoint {
        CGPoint(x: anchor.point.x * size.width, y: anchor.point.y * size.height)
    }

    @ViewBuilder
    private func sceneKlecks<Content: View>(
        at anchor: UnterwegsSceneAnchor,
        in size: CGSize,
        @ViewBuilder content: () -> Content
    ) -> some View {
        content()
            .unterwegsSceneKlecks()
            .position(anchorPosition(anchor, in: size))
    }
}

private struct SceneAnchorMarker: View {
    let label: String

    var body: some View {
        VStack(spacing: 3) {
            Circle()
                .fill(.ultraThinMaterial)
                .frame(width: 10, height: 10)
                .overlay {
                    Circle()
                        .strokeBorder(Color.white.opacity(0.55), lineWidth: 0.75)
                }
                .shadow(color: ArcaTicketsDesign.travelOcean.opacity(0.15), radius: 2, y: 1)

            Text(label)
                .font(.system(size: 6.5, weight: .bold, design: .rounded))
                .foregroundStyle(.secondary.opacity(0.85))
                .lineLimit(1)
        }
        .offset(y: 14)
        .accessibilityHidden(true)
    }
}

// MARK: - Illustrated travel scene

struct TravelSceneGraphic: View {
    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height

            ZStack {
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(.ultraThinMaterial)
                    .overlay {
                        RoundedRectangle(cornerRadius: 22, style: .continuous)
                            .strokeBorder(
                                LinearGradient(
                                    colors: [
                                        .white.opacity(0.55),
                                        ArcaTicketsDesign.travelGlassCyan.opacity(0.25),
                                        ArcaTicketsDesign.travelGlassPurple.opacity(0.18)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 1.25
                            )
                    }
                    .shadow(color: ArcaTicketsDesign.travelOcean.opacity(0.12), radius: 14, y: 6)

                skyLayer(width: w, height: h)
                    .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))

                mountainsLayer(width: w, height: h)
                airportLayer(width: w, height: h)
                golfLayer(width: w, height: h)
                hotelLayer(width: w, height: h)
                giftShopLayer(width: w, height: h)
                roadLayer(width: w, height: h)

                SwissGlassFlag(size: h * 0.17, style: .decoration)
                    .position(x: w * 0.11, y: h * 0.14)
                    .allowsHitTesting(false)

                TravelSunDecoration()
                    .scaleEffect(0.55)
                    .position(x: w * 0.90, y: h * 0.13)
                    .allowsHitTesting(false)

                cloud(at: CGPoint(x: w * 0.38, y: h * 0.11), scale: 1.0)
                cloud(at: CGPoint(x: w * 0.62, y: h * 0.08), scale: 0.75)
                cloud(at: CGPoint(x: w * 0.48, y: h * 0.18), scale: 0.6)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Reise-Karte mit Schnellzugriffen")
    }

    // MARK: Layers

    private func skyLayer(width w: CGFloat, height h: CGFloat) -> some View {
        LinearGradient(
            colors: [
                ArcaTicketsDesign.travelSky.opacity(0.72),
                ArcaTicketsDesign.travelSky.opacity(0.38),
                ArcaTicketsDesign.travelSand.opacity(0.55),
                ArcaTicketsDesign.travelSand.opacity(0.35)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
        .frame(width: w, height: h * 0.72)
        .frame(maxHeight: .infinity, alignment: .top)
    }

    private func mountainsLayer(width w: CGFloat, height h: CGFloat) -> some View {
        TravelMountainSilhouette()
            .fill(
                LinearGradient(
                    colors: [
                        ArcaTicketsDesign.travelOcean.opacity(0.28),
                        ArcaTicketsDesign.travelOcean.opacity(0.14)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .frame(width: w * 1.05, height: h * 0.28)
            .position(x: w * 0.5, y: h * 0.44)
            .allowsHitTesting(false)
    }

    private func airportLayer(width w: CGFloat, height h: CGFloat) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 4, style: .continuous)
                .fill(.ultraThinMaterial.opacity(0.65))
                .frame(width: w * 0.22, height: h * 0.09)
                .overlay {
                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                        .strokeBorder(Color.white.opacity(0.4), lineWidth: 0.75)
                }

            Image(systemName: "airplane")
                .font(.system(size: h * 0.09, weight: .semibold))
                .foregroundStyle(ArcaTicketsDesign.travelOcean.opacity(0.55))
                .rotationEffect(.degrees(-18))
                .offset(x: w * 0.06, y: -h * 0.05)
        }
        .position(x: w * 0.54, y: h * 0.30)
        .allowsHitTesting(false)
    }

    private func golfLayer(width w: CGFloat, height h: CGFloat) -> some View {
        ZStack {
            Ellipse()
                .fill(
                    LinearGradient(
                        colors: [
                            ArcaTicketsDesign.golfFairway.opacity(0.55),
                            ArcaTicketsDesign.golfFairwayDeep.opacity(0.35)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: w * 0.24, height: h * 0.14)

            Image(systemName: "flag.fill")
                .font(.system(size: h * 0.045, weight: .bold))
                .foregroundStyle(.white.opacity(0.85))
                .offset(x: -w * 0.04, y: -h * 0.03)
        }
        .position(x: w * 0.84, y: h * 0.70)
        .allowsHitTesting(false)
    }

    private func hotelLayer(width w: CGFloat, height h: CGFloat) -> some View {
        ZStack(alignment: .bottom) {
            RoundedRectangle(cornerRadius: 3, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            ArcaTicketsDesign.travelGlassPurple.opacity(0.35),
                            ArcaTicketsDesign.travelOcean.opacity(0.28)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(width: w * 0.14, height: h * 0.16)

            RoundedRectangle(cornerRadius: 2, style: .continuous)
                .fill(ArcaTicketsDesign.travelSunset.opacity(0.45))
                .frame(width: w * 0.05, height: h * 0.04)
                .offset(y: -h * 0.16)

            Image(systemName: "suitcase.fill")
                .font(.system(size: h * 0.05, weight: .medium))
                .foregroundStyle(.white.opacity(0.7))
                .offset(y: -h * 0.09)
        }
        .position(x: w * 0.68, y: h * 0.62)
        .allowsHitTesting(false)
    }

    private func giftShopLayer(width w: CGFloat, height h: CGFloat) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 5, style: .continuous)
                .fill(.ultraThinMaterial.opacity(0.55))
                .frame(width: w * 0.12, height: h * 0.10)
                .overlay {
                    RoundedRectangle(cornerRadius: 5, style: .continuous)
                        .strokeBorder(ArcaTicketsDesign.travelSunset.opacity(0.35), lineWidth: 0.75)
                }

            Image(systemName: "gift.fill")
                .font(.system(size: h * 0.04, weight: .semibold))
                .foregroundStyle(ArcaTicketsDesign.travelSunset.opacity(0.6))
        }
        .position(x: w * 0.22, y: h * 0.38)
        .allowsHitTesting(false)
    }

    private func roadLayer(width w: CGFloat, height h: CGFloat) -> some View {
        TravelRoadShape()
            .fill(
                LinearGradient(
                    colors: [
                        Color(white: 0.55).opacity(0.45),
                        Color(white: 0.42).opacity(0.35)
                    ],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .frame(width: w, height: h * 0.22)
            .position(x: w * 0.5, y: h * 0.88)
            .allowsHitTesting(false)
    }

    private func cloud(at point: CGPoint, scale: CGFloat) -> some View {
        HStack(spacing: -6) {
            Circle().frame(width: 14, height: 14)
            Circle().frame(width: 20, height: 20)
            Circle().frame(width: 16, height: 16)
        }
        .foregroundStyle(.white.opacity(0.75))
        .scaleEffect(scale)
        .position(point)
        .allowsHitTesting(false)
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
