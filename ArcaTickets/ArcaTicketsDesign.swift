//
//  ArcaTicketsDesign.swift
//  ArcaTickets
//
//  Entwickler: Hans zen Ruffinen
//

import SwiftUI

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

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Reise teilen")
                            .font(.title2.bold())
                        Text("Einmal teilen — jeder hat Flug, Hotel und Eintritt griffbereit.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }

                    VStack(spacing: 14) {
                        shareStep(
                            icon: "folder.fill",
                            number: "1",
                            title: "Ordner wählen",
                            subtitle: "\u{201E}\(folderName)\u{201C} mit allen Tickets wird verpackt.",
                            tintName: "blue"
                        )
                        shareStep(
                            icon: "square.and.arrow.up",
                            number: "2",
                            title: "Teilen",
                            subtitle: "Per AirDrop oder Nachrichten an Familie senden.",
                            tintName: "teal"
                        )
                        shareStep(
                            icon: "hand.tap.fill",
                            number: "3",
                            title: "Öffnen",
                            subtitle: "Empfänger tippt die Datei — Tickets erscheinen in der App.",
                            tintName: "purple"
                        )
                    }

                    TicketsPrimaryButton(title: "Jetzt teilen", icon: "person.2.fill", action: onContinue)
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
                    ArcaTicketsDesign.travelGlassCyan.opacity(0.22),
                    ArcaTicketsDesign.travelGlassPurple.opacity(0.16),
                    ArcaTicketsDesign.travelSand.opacity(0.38)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            Circle()
                .fill(ArcaTicketsDesign.travelGlassCyan.opacity(0.14))
                .frame(width: 260, height: 260)
                .blur(radius: 48)
                .offset(x: -90, y: -140)

            Circle()
                .fill(ArcaTicketsDesign.travelGlassPurple.opacity(0.12))
                .frame(width: 220, height: 220)
                .blur(radius: 40)
                .offset(x: 110, y: 60)

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

struct TicketsTip {
    let icon: String
    let text: String
    let tint: Color
}

struct TicketsDidYouKnowCard: View {
    private static let tips: [TicketsTip] = [
        TicketsTip(icon: "pin.fill", text: "Pinne Tickets auf „Unterwegs“, damit Bordkarte und Hotelbestätigung beim Reisen oben bleiben.", tint: ArcaTicketsDesign.travelOcean),
        TicketsTip(icon: "person.2.fill", text: "Teile einen Reiseordner per AirDrop — die ganze Familie hat Flug, Hotel und Eintritt auf dem Handy.", tint: .teal),
        TicketsTip(icon: "folder.badge.plus", text: "Lege Ordner wie „Reise Zermatt“ an und sammle alle Tickets der Reise an einem Ort.", tint: .purple),
        TicketsTip(icon: "bell.badge.fill", text: "Abos und Saisonkarten erinnern dich 30 Tage vor Ablauf — normale Tickets einen Tag vorher.", tint: .orange),
        TicketsTip(icon: "phone.circle.fill", text: "Unter Notfall findest du wichtige Nummern und deine Ausweisdaten — auch offline.", tint: .red),
        TicketsTip(icon: "square.and.arrow.up.fill", text: "Sichere alle Tickets regelmäßig — so behältst du sie auch bei Gerätewechsel.", tint: .indigo),
        TicketsTip(icon: "icloud.fill", text: "Mit iCloud synchronisieren sich Tickets automatisch zwischen iPhone und iPad.", tint: .cyan),
        TicketsTip(icon: "qrcode", text: "QR-Codes und PDFs lassen sich direkt als Ticket importieren — einfach teilen und öffnen.", tint: ArcaTicketsDesign.travelSky),
        TicketsTip(icon: "airplane.departure", text: "Sortiere die Tabs in den Einstellungen — Unterwegs oder Alle Tickets als Startseite.", tint: ArcaTicketsDesign.travelSunset),
        TicketsTip(icon: "lock.shield.fill", text: "PIN und Face ID schützen deine Tickets — am Gate zeigst du nur das, was nötig ist.", tint: .green),
    ]

    @State private var index = Int.random(in: 0..<TicketsDidYouKnowCard.tips.count)

    private var tip: TicketsTip { Self.tips[index] }

    var body: some View {
        Button {
            withAnimation(.easeInOut(duration: 0.25)) {
                var next = index
                while next == index && Self.tips.count > 1 {
                    next = Int.random(in: 0..<Self.tips.count)
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
                    Text("Wusstest du?")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(tip.tint)
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
