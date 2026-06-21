//
//  ArcaDesign.swift
//  Arca
//
//  Entwickler: Hans zen Ruffinen
//  iOS 26 Liquid Glass — Design-Tokens und wiederverwendbare Bausteine
//

import SwiftUI

// MARK: - Design Tokens

enum ArcaDesign {
    static let cornerRadius: CGFloat = 20
    static let chipRadius: CGFloat = 14
    static let iconTileSize: CGFloat = 44

    static let documentBlue = Color.blue
    static let documentTeal = Color.teal
    static let documentOrange = Color.orange
    static let documentIndigo = Color.indigo

    static func hubStyle(for category: String) -> ArcaHubStyle {
        switch category {
        case "Reise":
            return ArcaHubStyle(icon: "airplane", tint: documentBlue, title: "Reise", subtitle: "Pass, Tickets, Hotel")
        case "Papiere":
            return ArcaHubStyle(icon: "person.text.rectangle", tint: documentTeal, title: "Papiere", subtitle: "Ausweis, Führerschein")
        case "Gesundheit":
            return ArcaHubStyle(icon: "cross.case.fill", tint: .pink, title: "Gesundheit", subtitle: "Karten, Befunde")
        case "Rechnungen":
            return ArcaHubStyle(icon: "eurosign.circle.fill", tint: documentOrange, title: "Rechnungen", subtitle: "Belege & Quittungen")
        case "Verträge":
            return ArcaHubStyle(icon: "signature", tint: documentIndigo, title: "Verträge", subtitle: "Wichtige Verträge")
        default:
            return ArcaHubStyle(icon: "folder.fill", tint: .secondary, title: category, subtitle: "Dokumente")
        }
    }

    static let homeHubCategories = ["Reise", "Papiere", "Rechnungen", "Verträge"]
}

struct ArcaHubStyle {
    let icon: String
    let tint: Color
    let title: String
    let subtitle: String
}

/// Eine der vier Arca-Säulen auf der Startseite.
struct ArcaPillarSpec: Identifiable {
    let id: String
    let section: ArcaSection
    let title: String
    let subtitle: String
    let icon: String
    let tint: Color
    let count: Int
    let detail: String
}

struct ArcaQuickAction: Identifiable {
    let id: String
    let title: String
    let icon: String
    let tint: Color
}

// MARK: - Glass Helpers

extension View {
    /// Ein Glas-Layer pro Element — keine Verschachtelung (iOS 26 Rendering).
    @ViewBuilder
    func arcaGlass(
        tint: Color? = nil,
        interactive: Bool = false,
        in shape: some Shape = RoundedRectangle(cornerRadius: ArcaDesign.cornerRadius, style: .continuous)
    ) -> some View {
        let glass: Glass = {
            var base = Glass.regular
            if let tint { base = base.tint(tint) }
            if interactive { base = base.interactive() }
            return base
        }()
        self.glassEffect(glass, in: shape)
    }

    @ViewBuilder
    func arcaGlassCapsule(tint: Color? = nil, interactive: Bool = false) -> some View {
        arcaGlass(tint: tint, interactive: interactive, in: Capsule())
    }

    /// Solide Kartenfläche — zuverlässig lesbar, Glas-Optik nur dezent am Rand.
    func arcaCardBackground(tint: Color = .blue, cornerRadius: CGFloat = ArcaDesign.cornerRadius) -> some View {
        background {
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(Color(.secondarySystemGroupedBackground))
                .overlay {
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .fill(tint.opacity(0.08))
                }
        }
    }

    func arcaIconTile(tint: Color, size: CGFloat = ArcaDesign.iconTileSize) -> some View {
        frame(width: size, height: size)
            .background(tint.opacity(0.14), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

// MARK: - Home Header

struct ArcaHomeHeader: View {
    var vault: Int
    var documents: Int
    var tasks: Int
    var notes: Int
    var onLogoTap: () -> Void

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            Button(action: onLogoTap) {
                ArcaGlassIcon(size: 40)
            }
            .buttonStyle(.plain)

            Text("Arca")
                .font(.system(size: 22, weight: .bold, design: .rounded))

            Spacer()

            HeaderStatPills(vault: vault, documents: documents, tasks: tasks, notes: notes)
        }
    }
}

// MARK: - Pillar Card (Dokumente · Tasks · Passwörter · Notizen)

struct ArcaPillarCard: View {
    let pillar: ArcaPillarSpec
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .center) {
                    Image(systemName: pillar.icon)
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(pillar.tint)
                        .arcaIconTile(tint: pillar.tint, size: 36)
                    Spacer()
                    Text("\(pillar.count)")
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundStyle(pillar.tint)
                }

                Text(pillar.title)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(.primary)

                Text(pillar.subtitle)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)

                Text(pillar.detail)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(pillar.tint)
                    .lineLimit(1)
            }
            .padding(12)
            .frame(maxWidth: .infinity, minHeight: 108, alignment: .leading)
            .arcaCardBackground(tint: pillar.tint, cornerRadius: 16)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Quick Action Chip

struct ArcaQuickActionChip: View {
    let action: ArcaQuickAction
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 5) {
                Image(systemName: action.icon)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(action.tint)
                    .arcaIconTile(tint: action.tint, size: 34)
                Text(action.title)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.primary)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .minimumScaleFactor(0.85)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .padding(.horizontal, 4)
            .arcaCardBackground(tint: action.tint, cornerRadius: 12)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Ordner-Schnellzugriff (wie in der Dokumentenliste)

struct ArcaFolderQuickCard: View {
    let name: String
    let icon: String
    let tint: Color
    let bg: Color
    let count: Int
    var action: (() -> Void)? = nil

    var body: some View {
        let content = HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(tint)
                .frame(width: 34, height: 34)
                .background(bg.opacity(0.85), in: RoundedRectangle(cornerRadius: 8, style: .continuous))

            Text(name)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.primary)
                .lineLimit(2)
                .multilineTextAlignment(.leading)

            Spacer(minLength: 4)

            Text(count > 99 ? "99+" : "\(count)")
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .foregroundStyle(tint)
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(bg.opacity(0.7), in: Capsule())
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .arcaCardBackground(tint: tint, cornerRadius: ArcaDesign.chipRadius)

        if let action {
            Button(action: action) { content }.buttonStyle(.plain)
        } else {
            content
        }
    }
}

// MARK: - Recent Document Chip

struct ArcaRecentDocumentCard: View {
    let title: String
    let typeLabel: String
    let tint: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 5) {
                Image(systemName: "doc.fill")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(tint)
                Text(title)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                Text(typeLabel)
                    .font(.system(size: 9))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            .padding(10)
            .frame(width: 96, alignment: .leading)
            .arcaCardBackground(tint: tint, cornerRadius: 12)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - More Areas Chip (Passwörter, Notizen, Tasks)

struct ArcaMoreAreaChip: View {
    let icon: String
    let title: String
    let count: Int
    let tint: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(tint)
                    .arcaIconTile(tint: tint, size: 36)
                VStack(alignment: .leading, spacing: 1) {
                    Text(title)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.primary)
                    Text(count == 0 ? "Leer" : "\(count) Einträge")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .arcaCardBackground(tint: tint, cornerRadius: ArcaDesign.chipRadius)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Primary CTA

struct ArcaPrimaryButton: View {
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
                .background(Color.accentColor, in: RoundedRectangle(cornerRadius: ArcaDesign.cornerRadius, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Section Label

struct ArcaSectionTitle: View {
    let title: String

    var body: some View {
        Text(title)
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(.secondary)
            .textCase(.uppercase)
            .tracking(0.6)
    }
}

/// Aufklappbare Sektionsüberschrift (Chevron + optional Zähler).
struct ArcaCollapsibleSectionHeader: View {
    let title: String
    var count: Int? = nil
    let isCollapsed: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: "chevron.right")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(.secondary)
                    .rotationEffect(.degrees(isCollapsed ? 0 : 90))
                Text(title)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)
                    .tracking(0.5)
                Spacer()
                if let count {
                    Text("\(count)")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color(.tertiarySystemFill), in: Capsule())
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
