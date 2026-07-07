//
//  ArcaPetDesign.swift
//  ArcaPet
//

import SwiftUI
import UIKit

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

enum PetHaptics {
    static func lightImpact() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }

    static func mediumImpact() {
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
    }
}

enum ArcaPetDesign {
    static let cornerRadius: CGFloat = 20
    static let chipRadius: CGFloat = 14
    static let cardRadius: CGFloat = 18

    static let navyDeep = Color(red: 0.04, green: 0.10, blue: 0.24)
    static let navyMid = Color(red: 0.06, green: 0.16, blue: 0.36)
    static let navyGlow = Color(red: 0.10, green: 0.28, blue: 0.52)
    static let glassCyan = Color(red: 0.20, green: 0.78, blue: 0.95)
    static let glassCyanBright = Color(red: 0.35, green: 0.88, blue: 1.0)

    static let meadowGreen = Color(red: 0.28, green: 0.62, blue: 0.42)
    static let forestGreen = Color(red: 0.12, green: 0.42, blue: 0.28)
    static let earthBrown = Color(red: 0.52, green: 0.38, blue: 0.24)
    static let warmSand = Color(red: 0.96, green: 0.90, blue: 0.78)
    static let leafGreen = Color(red: 0.45, green: 0.78, blue: 0.38)
    static let glassTeal = Color(red: 0.18, green: 0.72, blue: 0.68)
    static let glassAmber = Color(red: 0.95, green: 0.72, blue: 0.32)
    static let alertRed = Color(red: 0.92, green: 0.28, blue: 0.24)
    static let skyBlue = Color(red: 0.35, green: 0.72, blue: 0.98)

    static var petGradient: LinearGradient {
        LinearGradient(
            colors: [navyMid.opacity(0.95), navyDeep],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    static var tabBarSelectedTint: Color { glassCyanBright }
    static var tabBarUnselectedTint: Color { Color.white.opacity(0.55) }

    static func tint(for category: ArcaPetHomeCategory) -> Color {
        switch category {
        case .gesundheit: return glassTeal
        case .dokumente: return skyBlue
        case .termine: return glassAmber
        case .futter: return meadowGreen
        case .notfall: return alertRed
        case .fotos: return glassCyan
        }
    }

    static func tint(for kleck: PetDocumentCategory) -> Color {
        switch kleck {
        case .impfung: return glassTeal
        case .chip: return skyBlue
        case .tierarzt: return meadowGreen
        case .medikamente: return glassAmber
        case .dokumente: return earthBrown
        case .notfall: return alertRed
        }
    }
}

extension View {
    func petGlass(
        tint: Color? = nil,
        interactive: Bool = false,
        in shape: some Shape = RoundedRectangle(cornerRadius: ArcaPetDesign.cornerRadius, style: .continuous)
    ) -> some View {
        let glass: Glass = {
            var base = Glass.regular
            if let tint { base = base.tint(tint) }
            if interactive { base = base.interactive() }
            return base
        }()
        return glassEffect(glass, in: shape)
    }

    func petScreenBackground() -> some View {
        background { PetGlassBackground() }
    }

    func petMinTapTarget() -> some View {
        frame(minWidth: 44, minHeight: 44, alignment: .center)
            .contentShape(Rectangle())
    }
}

struct PetGlassBackground: View {
    var body: some View {
        ZStack {
            ArcaPetDesign.navyDeep
            LinearGradient(
                colors: [
                    ArcaPetDesign.navyGlow.opacity(0.55),
                    ArcaPetDesign.navyMid.opacity(0.85),
                    ArcaPetDesign.navyDeep
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            Circle()
                .fill(ArcaPetDesign.glassCyan.opacity(0.14))
                .frame(width: 280, height: 280)
                .blur(radius: 50)
                .offset(x: -60, y: -180)
            Circle()
                .fill(ArcaPetDesign.navyGlow.opacity(0.22))
                .frame(width: 220, height: 220)
                .blur(radius: 44)
                .offset(x: 120, y: 320)
        }
        .ignoresSafeArea()
    }
}

enum ArcaPetTabBar {
    static func configure() {
        let appearance = UITabBarAppearance()
        appearance.configureWithTransparentBackground()
        appearance.backgroundEffect = UIBlurEffect(style: .systemUltraThinMaterialDark)
        appearance.backgroundColor = UIColor(ArcaPetDesign.navyDeep).withAlphaComponent(0.35)
        appearance.shadowColor = .clear
        appearance.shadowImage = UIImage()

        let selectedUIColor = UIColor(ArcaPetDesign.tabBarSelectedTint)
        let normalUIColor = UIColor(ArcaPetDesign.tabBarUnselectedTint)

        func styleItems(_ item: UITabBarItemAppearance) {
            item.normal.iconColor = normalUIColor
            item.normal.titleTextAttributes = [
                .foregroundColor: normalUIColor,
                .font: UIFont.systemFont(ofSize: 10, weight: .medium)
            ]
            item.selected.iconColor = selectedUIColor
            item.selected.titleTextAttributes = [
                .foregroundColor: selectedUIColor,
                .font: UIFont.systemFont(ofSize: 10, weight: .semibold)
            ]
        }

        styleItems(appearance.stackedLayoutAppearance)
        styleItems(appearance.inlineLayoutAppearance)
        styleItems(appearance.compactInlineLayoutAppearance)

        let tabBar = UITabBar.appearance()
        tabBar.standardAppearance = appearance
        tabBar.scrollEdgeAppearance = appearance
        tabBar.isTranslucent = true
        tabBar.tintColor = selectedUIColor
        tabBar.unselectedItemTintColor = normalUIColor
    }
}

struct ArcaPetAppIcon: View {
    var size: CGFloat = 96

    private var corner: CGFloat { size * 0.2237 }

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: corner, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 0.08, green: 0.22, blue: 0.42),
                            Color(red: 0.04, green: 0.12, blue: 0.28)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
            VStack(spacing: size * 0.04) {
                HStack(spacing: size * 0.02) {
                    Image(systemName: "dog.fill")
                    Image(systemName: "cat.fill")
                }
                .font(.system(size: size * 0.22, weight: .semibold))
                .foregroundStyle(.white.opacity(0.92))
                Text("PET")
                    .font(.system(size: size * 0.11, weight: .bold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.85))
            }
        }
        .frame(width: size, height: size)
        .shadow(color: ArcaPetDesign.meadowGreen.opacity(0.25), radius: size * 0.06, y: size * 0.03)
        .accessibilityLabel("Arca Pet")
    }
}

struct PetPlaceholderSheet: View {
    let title: String
    let icon: String
    let tint: Color

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Image(systemName: icon)
                    .font(.system(size: 48, weight: .semibold))
                    .foregroundStyle(tint)
                Text("\(title) — bald verfügbar")
                    .font(.title3.bold())
                Text("Dieser Bereich wird im nächsten Schritt mit Inhalten gefüllt.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(24)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .petScreenBackground()
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Fertig") { dismiss() }
                }
            }
        }
    }
}
