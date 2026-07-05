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
        background {
            ZStack {
                Color(.systemGroupedBackground)
                ArcaTicketsDesign.travelGradient
                    .ignoresSafeArea()
            }
        }
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
