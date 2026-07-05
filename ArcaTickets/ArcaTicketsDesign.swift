//
//  ArcaTicketsDesign.swift
//  ArcaTickets
//
//  Entwickler: Hans zen Ruffinen
//

import SwiftUI
import UIKit

/// Guards against SwiftUI runtime warnings for negative / non-finite frame dimensions.
enum LayoutSafety {
    static func dimension(_ value: CGFloat, minimum: CGFloat = 1) -> CGFloat {
        guard value.isFinite, value >= 0 else { return minimum }
        return value > 0 ? value : minimum
    }

    static func size(_ size: CGSize, minimum: CGFloat = 1) -> CGSize {
        CGSize(
            width: dimension(size.width, minimum: minimum),
            height: dimension(size.height, minimum: minimum)
        )
    }
}

enum ArcaTicketsDesign {
    static let cornerRadius: CGFloat = 20
    static let chipRadius: CGFloat = 14
    static let iconTileSize: CGFloat = 44

    static let travelSky = Color(red: 0.35, green: 0.72, blue: 0.98)
    static let travelSand = Color(red: 0.98, green: 0.94, blue: 0.86)
    static let travelOcean = Color(red: 0.10, green: 0.38, blue: 0.72)
    static let travelSunset = Color(red: 1.0, green: 0.62, blue: 0.38)
    static let travelGlassCyan = Color(red: 0.20, green: 0.85, blue: 0.95)
    static let travelGlassPurple = Color(red: 0.55, green: 0.35, blue: 0.95)
    static let travelSunYellow = Color(red: 1.0, green: 0.82, blue: 0.25)
    static let travelSunOrange = Color(red: 1.0, green: 0.55, blue: 0.20)
    static let taxiYellow = Color(red: 1.0, green: 0.84, blue: 0.08)
    static let taxiYellowDeep = Color(red: 0.92, green: 0.72, blue: 0.0)
    static let golfFairway = Color(red: 0.22, green: 0.72, blue: 0.42)
    static let golfFairwayDeep = Color(red: 0.12, green: 0.52, blue: 0.32)
    static let golfCyan = Color(red: 0.18, green: 0.82, blue: 0.75)

    // Wandtafel / Post-it palette
    static let wandtafelWood = Color(red: 0.52, green: 0.36, blue: 0.22)
    static let wandtafelWoodDeep = Color(red: 0.38, green: 0.24, blue: 0.12)
    static let wandtafelCork = Color(red: 0.78, green: 0.62, blue: 0.42)
    static let wandtafelCorkDeep = Color(red: 0.62, green: 0.46, blue: 0.30)
    static let postItYellow = Color(red: 1.0, green: 0.96, blue: 0.62)
    static let postItPink = Color(red: 1.0, green: 0.82, blue: 0.86)
    static let postItGreen = Color(red: 0.78, green: 0.94, blue: 0.72)
    static let postItBlue = Color(red: 0.72, green: 0.88, blue: 0.98)
    static let postItOrange = Color(red: 1.0, green: 0.88, blue: 0.68)
    static let postItLavender = Color(red: 0.86, green: 0.80, blue: 0.98)
    static let pushPinRed = Color(red: 0.88, green: 0.18, blue: 0.16)
    static let pushPinMetal = Color(red: 0.72, green: 0.72, blue: 0.74)

    static var travelGradient: LinearGradient {
        LinearGradient(
            colors: [travelSky.opacity(0.35), travelSand.opacity(0.5)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    static var boardingPassGradient: LinearGradient {
        LinearGradient(
            colors: [
                Color(.secondarySystemGroupedBackground),
                travelSky.opacity(0.12),
                travelSand.opacity(0.18)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    static func tint(for name: String) -> Color {
        switch name {
        case "blue": return .blue
        case "teal": return .teal
        case "purple": return .purple
        case "orange": return .orange
        case "indigo": return .indigo
        case "green": return .green
        case "red": return .red
        default: return .secondary
        }
    }

    static var tabBarSelectedTint: Color { travelGlassCyan }
    static var tabBarUnselectedTint: Color { Color(.secondaryLabel) }

    static var tabBarGlassTint: Color {
        Color(
            red: (travelGlassCyan.components.red + travelGlassPurple.components.red) / 2,
            green: (travelGlassCyan.components.green + travelGlassPurple.components.green) / 2,
            blue: (travelGlassCyan.components.blue + travelGlassPurple.components.blue) / 2
        )
    }
}

private extension Color {
    var components: (red: CGFloat, green: CGFloat, blue: CGFloat) {
        var r: CGFloat = 0
        var g: CGFloat = 0
        var b: CGFloat = 0
        var a: CGFloat = 0
        UIColor(self).getRed(&r, green: &g, blue: &b, alpha: &a)
        return (r, g, b)
    }
}

enum ArcaTicketsTabBar {
    static func configure() {
        let appearance = UITabBarAppearance()
        appearance.configureWithTransparentBackground()
        appearance.backgroundEffect = UIBlurEffect(style: .systemUltraThinMaterial)
        appearance.backgroundColor = UIColor(ArcaTicketsDesign.tabBarGlassTint).withAlphaComponent(0.10)
        appearance.shadowColor = .clear
        appearance.shadowImage = UIImage()

        let selectedUIColor = UIColor(ArcaTicketsDesign.tabBarSelectedTint)
        let normalUIColor = UIColor(ArcaTicketsDesign.tabBarUnselectedTint)

        func styleItems(_ item: UITabBarItemAppearance) {
            item.normal.iconColor = normalUIColor
            item.normal.titleTextAttributes = [
                .foregroundColor: normalUIColor,
                .font: SwissDialectComicStyle.uiFont(size: 10, weight: .semibold)
            ]
            item.selected.iconColor = selectedUIColor
            item.selected.titleTextAttributes = [
                .foregroundColor: selectedUIColor,
                .font: SwissDialectComicStyle.uiFont(size: 10, weight: .black),
                .shadow: {
                    let shadow = NSShadow()
                    shadow.shadowColor = UIColor(ArcaTicketsDesign.travelGlassPurple).withAlphaComponent(0.35)
                    shadow.shadowBlurRadius = 6
                    shadow.shadowOffset = .zero
                    return shadow
                }()
            ]
        }

        styleItems(appearance.stackedLayoutAppearance)
        styleItems(appearance.inlineLayoutAppearance)
        styleItems(appearance.compactInlineLayoutAppearance)

        let tabBar = UITabBar.appearance()
        tabBar.standardAppearance = appearance
        tabBar.scrollEdgeAppearance = appearance
        tabBar.isTranslucent = true
    }
}

extension View {
    func ticketsCardBackground(tint: Color = .blue, cornerRadius: CGFloat = ArcaTicketsDesign.cornerRadius) -> some View {
        background {
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(Color(.secondarySystemGroupedBackground))
                .overlay {
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .fill(tint.opacity(0.08))
                }
        }
    }

    func boardingPassCard(tint: Color = ArcaTicketsDesign.travelOcean) -> some View {
        background {
            RoundedRectangle(cornerRadius: ArcaTicketsDesign.cornerRadius, style: .continuous)
                .fill(ArcaTicketsDesign.boardingPassGradient)
                .overlay {
                    RoundedRectangle(cornerRadius: ArcaTicketsDesign.cornerRadius, style: .continuous)
                        .strokeBorder(tint.opacity(0.15), lineWidth: 1)
                }
                .shadow(color: tint.opacity(0.12), radius: 12, y: 6)
        }
    }

    func travelScreenBackground() -> some View {
        background { TravelGlassBackground() }
    }

    @ViewBuilder
    func ticketsGlass(
        tint: Color? = nil,
        interactive: Bool = false,
        in shape: some Shape = RoundedRectangle(cornerRadius: ArcaTicketsDesign.cornerRadius, style: .continuous)
    ) -> some View {
        let glass: Glass = {
            var base = Glass.regular
            if let tint { base = base.tint(tint) }
            if interactive { base = base.interactive() }
            return base
        }()
        glassEffect(glass, in: shape)
    }

    func ticketsIconTile(tint: Color, size: CGFloat = ArcaTicketsDesign.iconTileSize) -> some View {
        frame(width: size, height: size)
            .background(tint.opacity(0.14), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

struct TicketsFolderCard: View {
    let name: String
    let count: Int
    var isShared: Bool = false
    var action: (() -> Void)? = nil

    private var style: TicketFolderStyle { .style(for: name, isShared: isShared) }
    private var tint: Color { ArcaTicketsDesign.tint(for: style.tintName) }

    var body: some View {
        let content = HStack(spacing: 12) {
            Image(systemName: style.icon)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(tint)
                .ticketsIconTile(tint: tint, size: 40)

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 4) {
                    Text(name)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.primary)
                    if isShared {
                        Image(systemName: "person.2.fill")
                            .font(.caption2)
                            .foregroundStyle(ArcaTicketsDesign.tint(for: "teal"))
                    }
                }
                Text(count == 1 ? "1 Ticket" : "\(count) Tickets")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 0)

            Text(count > 99 ? "99+" : "\(count)")
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .foregroundStyle(tint)
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(tint.opacity(0.12), in: Capsule())

            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.tertiary)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .ticketsCardBackground(tint: tint, cornerRadius: ArcaTicketsDesign.chipRadius)

        if let action {
            Button(action: action) { content }.buttonStyle(.plain)
        } else {
            content
        }
    }
}

struct TicketsPrimaryButton: View {
    let title: String
    let icon: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Label(title, systemImage: icon)
                .font(.system(size: 16, weight: .semibold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .foregroundStyle(.white)
                .background(Color.accentColor, in: RoundedRectangle(cornerRadius: ArcaTicketsDesign.cornerRadius, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Toast

struct TicketsToastBanner: View {
    let message: String

    var body: some View {
        Text(message)
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(.primary)
            .multilineTextAlignment(.center)
            .padding(.horizontal, 20)
            .padding(.vertical, 14)
            .frame(maxWidth: .infinity)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(Color.primary.opacity(0.08), lineWidth: 1)
            }
            .shadow(color: .black.opacity(0.12), radius: 12, y: 6)
            .padding(.horizontal, 20)
            .accessibilityAddTraits(.isStaticText)
    }
}

private struct TicketsToastOverlayModifier: ViewModifier {
    @EnvironmentObject private var store: TicketStore

    func body(content: Content) -> some View {
        content
            .overlay(alignment: .top) {
                if let message = store.toastMessage {
                    TicketsToastBanner(message: message)
                        .padding(.top, 8)
                        .transition(.move(edge: .top).combined(with: .opacity))
                        .zIndex(100)
                }
            }
            .animation(.spring(response: 0.35, dampingFraction: 0.82), value: store.toastMessage)
    }
}

extension View {
    func ticketsToastOverlay() -> some View {
        modifier(TicketsToastOverlayModifier())
    }

    func ticketsMinTapTarget() -> some View {
        frame(minWidth: 44, minHeight: 44, alignment: .center)
            .contentShape(Rectangle())
    }

    func ticketsGlassTabBar() -> some View {
        self
            .toolbarBackground(.ultraThinMaterial, for: .tabBar)
            .toolbarBackground(.visible, for: .tabBar)
            .tint(ArcaTicketsDesign.tabBarSelectedTint)
    }
}

// MARK: - FAB

struct TicketsFAB: View {
    let title: String
    var useTravelGradient: Bool = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: "plus")
                    .font(.title3.bold())
                Text(title)
                    .font(.system(size: 17, weight: .semibold))
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 24)
            .padding(.vertical, 16)
            .background {
                if useTravelGradient {
                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [ArcaTicketsDesign.travelOcean, ArcaTicketsDesign.travelSky],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                } else {
                    Capsule()
                        .fill(Color.accentColor)
                }
            }
            .shadow(
                color: (useTravelGradient ? ArcaTicketsDesign.travelOcean : .black).opacity(useTravelGradient ? 0.3 : 0.18),
                radius: 10,
                y: 4
            )
        }
        .buttonStyle(.plain)
        .ticketsMinTapTarget()
        .accessibilityLabel("\(title) — neues Ticket")
    }
}

// MARK: - Folder share guide

struct FolderShareGuideView: View {
    let folderName: String
    var onContinue: () -> Void

    @State private var shareConsent = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Reise teile")
                            .font(.title2.bold())
                        Text("Einisch teile — jede/r het Flug, Hotel und Iitritt griffbereit.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }

                    VStack(spacing: 14) {
                        shareStep(
                            icon: "folder.fill",
                            number: "1",
                            title: "Ordner wählen",
                            subtitle: "\u{201E}\(folderName)\u{201C} mit allne Ticket wird verpackt.",
                            tintName: "blue"
                        )
                        shareStep(
                            icon: "square.and.arrow.up",
                            number: "2",
                            title: "Teilen",
                            subtitle: "Per AirDrop oder Nachrichte a Familie sende.",
                            tintName: "teal"
                        )
                        shareStep(
                            icon: "hand.tap.fill",
                            number: "3",
                            title: "Öffnen",
                            subtitle: "Empfänger tippt d'Datei — Ticket erschined in dr App.",
                            tintName: "purple"
                        )
                    }

                    LegalFootnote(text: LegalCopy.familyShareWarning, icon: "lock.open.trianglebadge.exclamationmark")

                    Toggle(isOn: $shareConsent) {
                        Text(LegalCopy.familyShareConsent)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .tint(ArcaTicketsDesign.travelOcean)

                    TicketsPrimaryButton(title: "Jetzt teile", icon: "person.2.fill", action: onContinue)
                        .disabled(!shareConsent)
                        .opacity(shareConsent ? 1 : 0.55)
                }
                .padding(20)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Familie einladen")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private func shareStep(icon: String, number: String, title: String, subtitle: String, tintName: String) -> some View {
        let tint = ArcaTicketsDesign.tint(for: tintName)
        return HStack(alignment: .top, spacing: 14) {
            ZStack {
                Circle()
                    .fill(tint.opacity(0.14))
                    .frame(width: 48, height: 48)
                Image(systemName: icon)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(tint)
            }
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text("Schritt \(number)")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(tint)
                    Text(title)
                        .font(.headline)
                }
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .ticketsCardBackground(tint: tint, cornerRadius: ArcaTicketsDesign.chipRadius)
    }
}

// MARK: - Travel glass scenery

struct TravelGlassBackground: View {
    var body: some View {
        ZStack {
            Color(.systemGroupedBackground)

            LinearGradient(
                colors: [
                    ArcaTicketsDesign.travelGlassCyan.opacity(0.28),
                    ArcaTicketsDesign.travelGlassPurple.opacity(0.22),
                    ArcaTicketsDesign.travelSand.opacity(0.45),
                    ArcaTicketsDesign.travelSunset.opacity(0.12)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            Circle()
                .fill(ArcaTicketsDesign.travelGlassCyan.opacity(0.20))
                .frame(width: 280, height: 280)
                .blur(radius: 48)
                .offset(x: -90, y: -140)

            Circle()
                .fill(ArcaTicketsDesign.travelGlassPurple.opacity(0.18))
                .frame(width: 240, height: 240)
                .blur(radius: 40)
                .offset(x: 110, y: 60)

            Circle()
                .fill(ArcaTicketsDesign.travelSunset.opacity(0.14))
                .frame(width: 180, height: 180)
                .blur(radius: 36)
                .offset(x: -40, y: 180)

            RoundedRectangle(cornerRadius: 36, style: .continuous)
                .fill(.ultraThinMaterial.opacity(0.35))
                .frame(width: 180, height: 120)
                .rotationEffect(.degrees(-14))
                .offset(x: -70, y: 280)
                .blur(radius: 1)

            Image(systemName: "suitcase.fill")
                .font(.system(size: 190, weight: .ultraLight))
                .foregroundStyle(
                    LinearGradient(
                        colors: [
                            ArcaTicketsDesign.travelOcean.opacity(0.10),
                            ArcaTicketsDesign.travelGlassPurple.opacity(0.08)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .offset(x: 70, y: 200)
                .rotationEffect(.degrees(-10))
                .accessibilityHidden(true)

            Image(systemName: "suitcase.fill")
                .font(.system(size: 110, weight: .ultraLight))
                .foregroundStyle(ArcaTicketsDesign.travelSky.opacity(0.06))
                .offset(x: -110, y: 340)
                .rotationEffect(.degrees(12))
                .accessibilityHidden(true)
        }
        .ignoresSafeArea()
    }
}

enum UnterwegsKlecksMetrics {
    static let sceneAspectRatio: CGFloat = 1.05
    static let sceneKlecksScale: CGFloat = 1.0
    static let contentHorizontalPadding: CGFloat = 16
    /// Minimum tappable area around each kleck graphic (Apple HIG: 44 pt).
    static let tapTargetSize: CGFloat = 96
    static let pressScale: CGFloat = 0.88

    /// Light label on colorful glass blobs — readable on all kleck tints.
    static let labelForeground = Color.white.opacity(0.95)
    static let labelShadow = Color.black.opacity(0.38)
}

// MARK: - Glas-Plakatwand / glass klecks

struct GlasPlakatwandFrame<Content: View>: View {
    let cornerRadius: CGFloat
    @ViewBuilder var content: () -> Content

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: cornerRadius + 4, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay {
                    RoundedRectangle(cornerRadius: cornerRadius + 4, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [
                                    ArcaTicketsDesign.travelGlassCyan.opacity(0.24),
                                    ArcaTicketsDesign.travelGlassPurple.opacity(0.20),
                                    ArcaTicketsDesign.travelSunset.opacity(0.14),
                                    ArcaTicketsDesign.travelSand.opacity(0.18)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                }
                .overlay {
                    RoundedRectangle(cornerRadius: cornerRadius + 4, style: .continuous)
                        .strokeBorder(
                            LinearGradient(
                                colors: [
                                    .white.opacity(0.50),
                                    ArcaTicketsDesign.travelGlassCyan.opacity(0.40),
                                    ArcaTicketsDesign.travelGlassPurple.opacity(0.28)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1.5
                        )
                }
                .shadow(color: ArcaTicketsDesign.travelOcean.opacity(0.20), radius: 14, y: 6)

            SwissCrossPajamaPattern(crossSize: 11, spacing: 34)
                .opacity(0.05)
                .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
                .padding(4)
                .allowsHitTesting(false)

            content()
                .padding(12)
        }
    }
}

/// Frosted glass panel for plakatwand interior.
struct GlasPlakatwandBackdrop: View {
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(.thinMaterial.opacity(0.65))

            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            ArcaTicketsDesign.travelSky.opacity(0.18),
                            ArcaTicketsDesign.travelGlassCyan.opacity(0.12),
                            ArcaTicketsDesign.travelSand.opacity(0.15)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            Circle()
                .fill(ArcaTicketsDesign.travelSunYellow.opacity(0.12))
                .frame(width: 120, height: 120)
                .blur(radius: 30)
                .offset(x: 60, y: -40)
                .allowsHitTesting(false)
        }
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

/// Glass orb “pin” for pinned elements on the plakatwand.
struct GlasPlakatPin: View {
    var size: CGFloat = 10

    var body: some View {
        ZStack {
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            ArcaTicketsDesign.travelGlassCyan.opacity(0.55),
                            ArcaTicketsDesign.travelOcean.opacity(0.25),
                            Color.clear
                        ],
                        center: .center,
                        startRadius: 0,
                        endRadius: size
                    )
                )
                .frame(width: size * 2.2, height: size * 2.2)
                .blur(radius: 3)

            Circle()
                .fill(.ultraThinMaterial)
                .frame(width: size, height: size)
                .overlay {
                    Circle()
                        .strokeBorder(.white.opacity(0.55), lineWidth: 1)
                }
                .shadow(color: ArcaTicketsDesign.travelOcean.opacity(0.25), radius: 3, y: 1)
        }
        .accessibilityHidden(true)
    }
}

/// Cozy pajama-style Swiss cross grid — subtle background on select Post-its.
struct SwissCrossPajamaPattern: View {
    var crossSize: CGFloat = 10
    var spacing: CGFloat = 18

    var body: some View {
        Canvas { context, size in
            let cols = Int(size.width / spacing) + 2
            let rows = Int(size.height / spacing) + 2
            for row in 0..<rows {
                for col in 0..<cols {
                    let x = CGFloat(col) * spacing + (row.isMultiple(of: 2) ? spacing * 0.5 : 0)
                    let y = CGFloat(row) * spacing
                    let rect = CGRect(x: x - crossSize / 2, y: y - crossSize / 2, width: crossSize, height: crossSize)
                    context.fill(SwissCrossShape().path(in: rect), with: .color(Color(red: 0.91, green: 0.11, blue: 0.15).opacity(0.55)))
                }
            }
        }
        .allowsHitTesting(false)
    }
}

/// Tiny Swiss cross stamp sticker for Post-its and wall decorations.
struct SwissCrossStamp: View {
    var size: CGFloat = 12

    var body: some View {
        ZStack {
            Circle()
                .fill(Color.white.opacity(0.92))
                .frame(width: size * 1.35, height: size * 1.35)
                .shadow(color: .black.opacity(0.10), radius: 1, y: 0.5)
            SwissCrossShape()
                .fill(Color(red: 0.91, green: 0.11, blue: 0.15))
                .padding(size * 0.28)
                .frame(width: size, height: size)
        }
        .accessibilityHidden(true)
    }
}

private extension Color {
    func blend(with other: Color) -> Color {
        Color(
            red: (components.red + other.components.red) / 2,
            green: (components.green + other.components.green) / 2,
            blue: (components.blue + other.components.blue) / 2
        )
    }
}

// VB pattern: Image on PictureBox + Click event → action (sheet, call, toggle).
struct UnterwegsKlecksButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? UnterwegsKlecksMetrics.pressScale : 1.0)
            .brightness(configuration.isPressed ? -0.06 : 0)
            .animation(.spring(response: 0.22, dampingFraction: 0.65), value: configuration.isPressed)
    }
}

extension View {
    func unterwegsSceneKlecks() -> some View {
        scaleEffect(UnterwegsKlecksMetrics.sceneKlecksScale)
    }

    func unterwegsKlecksTapTarget() -> some View {
        frame(
            width: UnterwegsKlecksMetrics.tapTargetSize,
            height: UnterwegsKlecksMetrics.tapTargetSize
        )
        .contentShape(Rectangle())
    }

    func unterwegsKlecksLabel(size: CGFloat = 10.5, minScale: CGFloat = 0.7) -> some View {
        font(.system(size: size, weight: .black, design: .rounded))
            .foregroundStyle(UnterwegsKlecksMetrics.labelForeground)
            .shadow(color: UnterwegsKlecksMetrics.labelShadow, radius: 1.5, y: 0.5)
            .lineLimit(1)
            .minimumScaleFactor(minScale)
    }

    func unterwegsKlecksCurvedLabel() -> some View {
        shadow(color: UnterwegsKlecksMetrics.labelShadow, radius: 1.5, y: 0.5)
    }
}

/// Glass blob kleck — reads anchor tint/size from Ferien-Plakatwand placement.
struct UnterwegsKlecksGlass<Content: View>: View {
    @Environment(\.unterwegsAnchor) private var anchor
    var crossPattern: Bool = false
    @ViewBuilder var content: () -> Content

    private var size: (width: CGFloat, height: CGFloat) {
        anchor?.noteSize ?? (width: 74, height: 70)
    }

    private var tint: Color {
        anchor?.glassTint ?? ArcaTicketsDesign.travelGlassCyan
    }

    var body: some View {
        let blobW = size.width + 8
        let blobH = size.height + 8
        let showCross = crossPattern || anchor == .visitenkarte

        ZStack {
            KlecksBlobShape()
                .fill(
                    RadialGradient(
                        colors: [tint.opacity(0.34), tint.opacity(0.18), Color.clear],
                        center: .center,
                        startRadius: 4,
                        endRadius: 46
                    )
                )
                .frame(width: blobW, height: blobH)
                .blur(radius: 4)

            KlecksBlobShape()
                .fill(.ultraThinMaterial)
                .frame(width: size.width, height: size.height)
                .overlay {
                    KlecksBlobShape()
                        .stroke(
                            LinearGradient(
                                colors: [tint.opacity(0.70), tint.opacity(0.35)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1.5
                        )
                }
                .overlay {
                    if showCross {
                        SwissCrossPajamaPattern(crossSize: 7, spacing: 16)
                            .opacity(0.10)
                            .clipShape(KlecksBlobShape())
                    }
                }
                .shadow(color: tint.opacity(0.24), radius: 8, y: 3)

            content()
        }
        .frame(width: blobW, height: blobH)
        .accessibilityHidden(true)
    }
}

/// Backward-compatible alias — all klecks use glass blobs.
typealias UnterwegsKlecksPostIt = UnterwegsKlecksGlass

/// Ticket card pinned below the Glas-Plakatwand.
struct PinnedTicketPreview<Content: View>: View {
    var label: String = "Gepinnte Vorschau"
    var tilt: Double = -1.3
    @ViewBuilder var content: () -> Content

    var body: some View {
        VStack(spacing: 8) {
            HStack(spacing: 6) {
                GlasPlakatPin(size: 9)
                Text(label)
                    .font(.system(size: 12, weight: .heavy, design: .rounded))
                    .foregroundStyle(ArcaTicketsDesign.travelGlassCyan)
                Spacer(minLength: 0)
                SwissCrossStamp(size: 14)
                    .rotationEffect(.degrees(8))
            }
            .padding(.horizontal, 2)

            content()
                .shadow(color: ArcaTicketsDesign.travelOcean.opacity(0.16), radius: 12, y: 5)
                .rotationEffect(.degrees(tilt))
        }
        .padding(.top, 2)
    }
}

/// Playful glass placeholder when nothing is pinned yet.
struct UnterwegsHolidayEmptyState: View {
    var body: some View {
        ZStack(alignment: .top) {
            GlasPlakatPin(size: 10)
                .offset(y: 4)

            VStack(spacing: 14) {
                HStack(spacing: 10) {
                    Image(systemName: "pin.fill")
                        .font(.system(size: 28, weight: .semibold))
                        .foregroundStyle(ArcaTicketsDesign.travelSunset)
                        .symbolEffect(.pulse, options: .repeating)
                    Image(systemName: "suitcase.rolling.fill")
                        .font(.system(size: 24))
                        .foregroundStyle(ArcaTicketsDesign.travelGlassCyan)
                        .rotationEffect(.degrees(-12))
                    SwissGlassFlag(size: 28, style: .decoration)
                        .rotationEffect(.degrees(6))
                }

                Text(ArcaTicketsStrings.noPinnedOnUnterwegs)
                    .font(.system(size: 17, weight: .bold, design: .rounded))
                    .foregroundStyle(.primary)

                Text("Heft es Ticket under \u{201E}Alli Tickets\u{201C} a oder tipp unte uf \u{201E}Ersti Reise hinzuefüege\u{201C} — denn hängt dini Bordcharte da under dr Plakatwand.")
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(24)
            .frame(maxWidth: .infinity)
            .ticketsGlass(
                tint: ArcaTicketsDesign.travelGlassCyan.opacity(0.35),
                in: RoundedRectangle(cornerRadius: ArcaTicketsDesign.cornerRadius, style: .continuous)
            )
            .padding(.top, 8)
        }
        .rotationEffect(.degrees(2.5))
        .padding(.vertical, 4)
    }
}

struct TravelSunDecoration: View {
    var body: some View {
        ZStack {
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            ArcaTicketsDesign.travelSunYellow.opacity(0.55),
                            ArcaTicketsDesign.travelSunOrange.opacity(0.22),
                            Color.clear
                        ],
                        center: .center,
                        startRadius: 6,
                        endRadius: 50
                    )
                )
                .frame(width: 92, height: 92)
                .blur(radius: 6)

            Circle()
                .fill(.ultraThinMaterial)
                .frame(width: 58, height: 58)
                .overlay {
                    Circle()
                        .strokeBorder(
                            LinearGradient(
                                colors: [
                                    ArcaTicketsDesign.travelSunYellow.opacity(0.7),
                                    ArcaTicketsDesign.travelSunOrange.opacity(0.45)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1.5
                        )
                }
                .shadow(color: ArcaTicketsDesign.travelSunOrange.opacity(0.25), radius: 10, y: 3)

            Image(systemName: "sun.max.fill")
                .font(.system(size: 30, weight: .semibold))
                .foregroundStyle(
                    LinearGradient(
                        colors: [ArcaTicketsDesign.travelSunYellow, ArcaTicketsDesign.travelSunOrange],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .symbolRenderingMode(.multicolor)
        }
        .accessibilityHidden(true)
    }
}

struct TravelTaxiDecoration: View {
    private let tilt: Double = -10

    var body: some View {
        ZStack {
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            ArcaTicketsDesign.taxiYellow.opacity(0.5),
                            ArcaTicketsDesign.taxiYellowDeep.opacity(0.2),
                            Color.clear
                        ],
                        center: .center,
                        startRadius: 6,
                        endRadius: 48
                    )
                )
                .frame(width: 88, height: 88)
                .blur(radius: 6)

            VStack(spacing: 2) {
                Text("Taxi")
                    .font(.system(size: 11, weight: .black, design: .rounded))
                    .foregroundStyle(ArcaTicketsDesign.taxiYellowDeep)
                    .shadow(color: .white.opacity(0.55), radius: 0, y: 1)

                Image(systemName: "car.side.fill")
                    .font(.system(size: 26, weight: .bold))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [ArcaTicketsDesign.taxiYellow, ArcaTicketsDesign.taxiYellowDeep],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .shadow(color: .black.opacity(0.14), radius: 2, y: 2)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(.ultraThinMaterial)
                    .overlay {
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .strokeBorder(
                                LinearGradient(
                                    colors: [
                                        ArcaTicketsDesign.taxiYellow.opacity(0.7),
                                        ArcaTicketsDesign.taxiYellowDeep.opacity(0.4)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 1.5
                            )
                    }
                    .shadow(color: ArcaTicketsDesign.taxiYellowDeep.opacity(0.25), radius: 10, y: 3)
            }
            .rotationEffect(.degrees(tilt))
        }
        .frame(width: 84, height: 78)
        .accessibilityHidden(true)
    }
}

struct TravelGolfDecoration: View {
    private let tilt: Double = 8

    var body: some View {
        ZStack {
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            ArcaTicketsDesign.golfCyan.opacity(0.45),
                            ArcaTicketsDesign.golfFairway.opacity(0.2),
                            Color.clear
                        ],
                        center: .center,
                        startRadius: 6,
                        endRadius: 48
                    )
                )
                .frame(width: 88, height: 88)
                .blur(radius: 6)

            VStack(spacing: 2) {
                Text("Golf")
                    .font(.system(size: 11, weight: .black, design: .rounded))
                    .foregroundStyle(ArcaTicketsDesign.golfFairwayDeep)
                    .shadow(color: .white.opacity(0.55), radius: 0, y: 1)

                Image(systemName: "figure.golf")
                    .font(.system(size: 26, weight: .bold))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [ArcaTicketsDesign.golfCyan, ArcaTicketsDesign.golfFairwayDeep],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .shadow(color: .black.opacity(0.14), radius: 2, y: 2)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background {
                Circle()
                    .fill(.ultraThinMaterial)
                    .overlay {
                        Circle()
                            .strokeBorder(
                                LinearGradient(
                                    colors: [
                                        ArcaTicketsDesign.golfCyan.opacity(0.65),
                                        ArcaTicketsDesign.golfFairwayDeep.opacity(0.4)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 1.5
                            )
                    }
                    .shadow(color: ArcaTicketsDesign.golfFairwayDeep.opacity(0.22), radius: 10, y: 3)
            }
            .rotationEffect(.degrees(tilt))
        }
        .frame(width: 78, height: 78)
        .accessibilityHidden(true)
    }
}

// MARK: - Swiss glass flag

struct SwissCrossShape: Shape {
    func path(in rect: CGRect) -> Path {
        let side = min(rect.width, rect.height)
        let arm = side / 5
        let origin = CGPoint(x: rect.midX - side / 2, y: rect.midY - side / 2)
        var path = Path()
        path.addRect(CGRect(x: origin.x, y: origin.y + (side - arm) / 2, width: side, height: arm))
        path.addRect(CGRect(x: origin.x + (side - arm) / 2, y: origin.y, width: arm, height: side))
        return path
    }
}

struct SwissGlassFlag: View {
    enum Style {
        case decoration
        case badge
    }

    var size: CGFloat = 40
    var style: Style = .decoration

    private var swissRed: Color { Color(red: 0.91, green: 0.11, blue: 0.15) }
    private var swissRedDeep: Color { Color(red: 0.74, green: 0.07, blue: 0.11) }

    var body: some View {
        let corner = size * 0.18
        ZStack {
            RoundedRectangle(cornerRadius: corner, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [swissRed.opacity(0.78), swissRedDeep.opacity(0.9)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            RoundedRectangle(cornerRadius: corner, style: .continuous)
                .fill(.ultraThinMaterial.opacity(style == .badge ? 0.35 : 0.5))

            SwissCrossShape()
                .fill(
                    LinearGradient(
                        colors: [.white.opacity(0.96), .white.opacity(0.8)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .padding(size * 0.1)
                .shadow(color: .white.opacity(0.25), radius: 1, y: -0.5)

            RoundedRectangle(cornerRadius: corner, style: .continuous)
                .strokeBorder(
                    LinearGradient(
                        colors: [.white.opacity(0.5), .white.opacity(0.12)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: style == .badge ? 0.75 : 1
                )
        }
        .frame(width: size, height: size)
        .shadow(color: swissRed.opacity(style == .badge ? 0.15 : 0.2), radius: style == .badge ? 3 : 7, y: style == .badge ? 1 : 3)
        .accessibilityLabel("Schweizer Flagge")
        .accessibilityHidden(style == .decoration)
    }
}

// MARK: - Wusstest du?

struct TicketsTip: Identifiable {
    let id: String
    let icon: String
    let text: String
    let tint: Color

    init(id: String = UUID().uuidString, icon: String, text: String, tint: Color) {
        self.id = id
        self.icon = icon
        self.text = text
        self.tint = tint
    }
}

enum TicketsTravelTips {
    static let swissKnifeDismissKey = "travelTip.swissKnife.dismissed"
    private static let unterwegsTipIndexKey = "travelTip.unterwegs.index"

    static let swissKnife = TicketsTip(
        id: "swissKnife",
        icon: "airplane.departure",
        text: "Schwiizer Messer im Flieger verboten",
        tint: ArcaTicketsDesign.travelGlassCyan
    )

    static let unterwegsGlass: [TicketsTip] = [
        swissKnife,
        TicketsTip(
            id: "handLuggage",
            icon: "drop.fill",
            text: "Flüssigkeiten: max. 100 ml",
            tint: ArcaTicketsDesign.travelOcean
        ),
        TicketsTip(
            id: "boardingPin",
            icon: "pin.fill",
            text: "Bordcharte agheftet? Am Gate parat",
            tint: ArcaTicketsDesign.travelSunset
        ),
    ]

    static var unterwegsGlassTip: TicketsTip {
        let tips = unterwegsGlass
        guard tips.count > 1 else { return tips[0] }
        let stored = UserDefaults.standard.integer(forKey: unterwegsTipIndexKey)
        let index = tips.indices.contains(stored) ? stored : 0
        return tips[index]
    }

    static func advanceUnterwegsGlassTip() {
        let tips = unterwegsGlass
        guard tips.count > 1 else { return }
        let next = (UserDefaults.standard.integer(forKey: unterwegsTipIndexKey) + 1) % tips.count
        UserDefaults.standard.set(next, forKey: unterwegsTipIndexKey)
    }

    static let all: [TicketsTip] = [
        TicketsTip(
            icon: "airplane.departure",
            text: "Schwiizer Messer dörfed nöd ins Handgepäck — lieber im ufgege Gepäck oder diheime lah.",
            tint: ArcaTicketsDesign.travelGlassCyan
        ),
        TicketsTip(icon: "pin.fill", text: "Heft Ticket uf „Unterwägs“ a, damit Bordcharte und Hotelbestätigung bim Reise obe bliibed.", tint: ArcaTicketsDesign.travelOcean),
        TicketsTip(icon: "person.2.fill", text: "Teil en Reiseordner per AirDrop — d'ganz Familie het Flug, Hotel und Iitritt uf em Natel.", tint: .teal),
        TicketsTip(icon: "folder.badge.plus", text: "Leg Ordner wie „Reise Zermatt“ a und sammle alli Ticket vo dr Reise a eim Ort.", tint: .purple),
        TicketsTip(icon: "bell.badge.fill", text: "Abo und Saisoncharte erinnered dich 30 Tag vor Ablauf — normali Ticket ein Tag vorher.", tint: .orange),
        TicketsTip(icon: "phone.circle.fill", text: "Under Notfall findsch wichtigi Nummerä und dini Usweisdate — au offline.", tint: .red),
        TicketsTip(icon: "square.and.arrow.up.fill", text: "Sicher alli Ticket regelmässig — so behaltsch sie au bi eme Gerätewechsel.", tint: .indigo),
        TicketsTip(icon: "icloud.fill", text: "Mit iCloud synchronisiered sich Ticket automatisch zwüsche iPhone und iPad.", tint: .cyan),
        TicketsTip(icon: "qrcode", text: "QR-Code und PDF chasch direkt als Ticket importiere — eifach teile und öffne.", tint: ArcaTicketsDesign.travelSky),
        TicketsTip(icon: "airplane.departure", text: "Sortier d'Tab in de Istellige — Unterwägs oder Alli Tickets als Startsite.", tint: ArcaTicketsDesign.travelSunset),
        TicketsTip(icon: "lock.shield.fill", text: "PIN und Face ID schütze dini Ticket — am Gate zeigsch nur das Nötige.", tint: .green),
    ]
}

struct TravelGlassTipBanner: View {
    let tip: TicketsTip
    var title: String = ArcaTicketsStrings.reiseTip
    var useComicText: Bool = true
    var onDismiss: (() -> Void)?
    var onAdvance: (() -> Void)?

    private let boardTilt: Double = -3.5

    var body: some View {
        ZStack(alignment: .top) {
            GlasPlakatPin(size: 10)
                .offset(y: 2)
                .zIndex(2)

            HStack(alignment: .center, spacing: 12) {
                Image(systemName: tip.icon)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 36, height: 36)
                    .background(
                        LinearGradient(
                            colors: [tip.tint, tip.tint.opacity(0.72)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        in: RoundedRectangle(cornerRadius: 10, style: .continuous)
                    )
                    .shadow(color: tip.tint.opacity(0.35), radius: 4, y: 2)

                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 4) {
                        Text(title)
                            .font(.system(size: 12, weight: .heavy, design: .rounded))
                            .foregroundStyle(tip.tint)
                        SwissCrossStamp(size: 10)
                    }

                    if useComicText {
                        Text(tip.text)
                            .font(.system(size: 13, weight: .medium, design: .rounded))
                            .foregroundStyle(.primary)
                            .minimumScaleFactor(0.8)
                            .lineLimit(2)
                    } else {
                        Text(tip.text)
                            .font(.system(size: 13))
                            .foregroundStyle(.primary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
                .onTapGesture { onAdvance?() }

                if let onDismiss {
                    Button {
                        TicketsHaptics.lightImpact()
                        onDismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(.secondary)
                            .frame(width: 28, height: 28)
                            .background(Color(.tertiarySystemFill), in: Circle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Hinweis schliesse")
                }
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .ticketsGlass(tint: tip.tint.opacity(0.38), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(
                        LinearGradient(
                            colors: [tip.tint.opacity(0.55), tip.tint.opacity(0.22)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1.25
                    )
            }
            .shadow(color: tip.tint.opacity(0.16), radius: 10, y: 4)
            .padding(.top, 6)
        }
        .rotationEffect(.degrees(boardTilt))
        .padding(.vertical, 6)
        .accessibilityElement(children: .combine)
    }
}

struct TicketsDidYouKnowCard: View {
    @State private var index = Int.random(in: 0..<TicketsTravelTips.all.count)

    private var tip: TicketsTip { TicketsTravelTips.all[index] }

    var body: some View {
        Button {
            withAnimation(.easeInOut(duration: 0.25)) {
                var next = index
                while next == index && TicketsTravelTips.all.count > 1 {
                    next = Int.random(in: 0..<TicketsTravelTips.all.count)
                }
                index = next
            }
            TicketsHaptics.lightImpact()
        } label: {
            HStack(alignment: .top, spacing: 14) {
                Image(systemName: tip.icon)
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(tip.tint)
                    .frame(width: 44, height: 44)
                    .background(tip.tint.opacity(0.15), in: RoundedRectangle(cornerRadius: 12, style: .continuous))

                VStack(alignment: .leading, spacing: 4) {
                    ComicCurvedText(text: ArcaTicketsStrings.wusstestDu, style: .compact, foreground: tip.tint)
                    Text(tip.text)
                        .font(.system(size: 14))
                        .foregroundStyle(.primary)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .ticketsGlass(tint: tip.tint.opacity(0.35), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(alignment: .bottomTrailing) {
                Image(systemName: "arrow.triangle.2.circlepath")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .padding(10)
            }
        }
        .buttonStyle(.plain)
    }
}

struct TicketsAppIcon: View {
    var size: CGFloat = 96

    private var corner: CGFloat { size * 0.2237 }

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: corner, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [Color(red: 0.22, green: 0.55, blue: 1.0), Color(red: 0.10, green: 0.28, blue: 0.72)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
            Image(systemName: "ticket.fill")
                .font(.system(size: size * 0.42, weight: .semibold))
                .foregroundStyle(.white)
        }
        .frame(width: size, height: size)
        .shadow(color: Color.blue.opacity(0.2), radius: size * 0.08, y: size * 0.04)
    }
}
