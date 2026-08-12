//
//  ArcaLeiste.swift
//  Arca
//
//  Tab-Leiste, Blitzidee-Mikro + Plus und die iPad-Seitenleiste.
//  (Aus ContentView.swift herausgelöst — Code unverändert.)
//
//  Entwickler: Hans zen Ruffinen
//

import SwiftUI

// MARK: - Custom Tab Bar

struct ArcaTabItem {
    let section: ArcaSection
    let icon: String
    let label: String
    let color: Color
}

struct ArcaTabBar: View {
    @Binding var selected: ArcaSection
    @EnvironmentObject var store: AppStore

    /// Space gilt auch als aktiv, wenn man in einem seiner Bereiche steckt
    private var spaceActive: Bool {
        [.home, .spaceHub, .vault, .documents, .notes, .lists].contains(selected)
    }

    /// „Unsortiert" zählt eigene Dateien PLUS Waisen (wie der Aufräum-Balken).
    private var unsortiertAnzahl: Int {
        let bekannte = Set(store.documentCategories)
        return store.documents.filter {
            $0.category == "Unsortiert" || !bekannte.contains($0.category)
        }.count
    }

    var body: some View {
        HStack(spacing: 11) {
            unsortiertKorb

            Spacer(minLength: 2)

            // Space · Home
            barKreis(icon: "ArcaHome", titel: "Space", unter: "Home", aktiv: spaceActive) {
                if selected == .home {
                    store.homeSprungNachOben += 1
                } else {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) { selected = .home }
                }
            }

            // Einstellungen · Settings (Menü: Notfall · Sichern · Wiederherstellen)
            Menu {
                Button { store.zeigeNotfall = true } label: {
                    Label("Notfall", systemImage: "cross.case.fill")
                }
                Divider()
                Button {
                    store.pendingSettingsAktion = "export"; selected = .settings
                } label: { Label("Daten sichern", systemImage: "square.and.arrow.up") }
                Button {
                    store.pendingSettingsAktion = "import"; selected = .settings
                } label: { Label("Daten wiederherstellen", systemImage: "square.and.arrow.down") }
                Divider()
                Button { selected = .settings } label: {
                    Label("Einstellungen", systemImage: "gearshape")
                }
            } label: {
                kreisInhalt(icon: "ArcaSettings", titel: "Einstellungen", unter: "Settings",
                            aktiv: selected == .settings)
            }
            .buttonStyle(.plain)

            // Trennlinie
            Rectangle()
                .fill(Color.primary.opacity(0.12))
                .frame(width: 1, height: 28)

            // Mikrofon · Aufnahme
            barKreis(icon: "ArcaMic", titel: "Mikrofon", unter: "Aufnahme",
                     aktiv: false, iconFarbe: ArcaWarm.terrakotta) {
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                store.quickCaptureAutoRecord = true
                store.pendingQuickCapture = true
            }

            plusGross
        }
        .padding(.horizontal, 10)
        .padding(.bottom, 34)
    }

    // MARK: Eingangskorb links

    private var unsortiertKorb: some View {
        Button {
            store.fokusKategorie = "Unsortiert"
            store.pendingScrollCategory = "Unsortiert"
            withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) { selected = .documents }
        } label: {
            HStack(spacing: 7) {
                ArcaIcon(name: "ArcaArchive", groesse: 19)
                    .foregroundStyle(ArcaWarm.terrakotta)
                VStack(alignment: .leading, spacing: 1) {
                    HStack(spacing: 5) {
                        Text("Unsortiert")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(.primary)
                        if unsortiertAnzahl > 0 {
                            Text("\(unsortiertAnzahl)")
                                .font(.system(size: 9.5, weight: .bold))
                                .foregroundStyle(.white)
                                .frame(minWidth: 15, minHeight: 15)
                                .padding(.horizontal, 2)
                                .background(ArcaWarm.terrakotta, in: Capsule())
                        }
                    }
                    Text("Alles hier landet zuerst")
                        .font(.system(size: 8))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            .padding(.horizontal, 11)
            .padding(.vertical, 8)
            .glassEffect(.regular, in: Capsule())
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
    }

    // MARK: Kreis-Knopf (nur Icon, schwebend — ohne Label)

    private func barKreis(icon: String, titel: String, unter: String, aktiv: Bool,
                          iconFarbe: Color? = nil,
                          action: @escaping () -> Void) -> some View {
        Button { action() } label: {
            kreisInhalt(icon: icon, titel: titel, unter: unter, aktiv: aktiv, iconFarbe: iconFarbe)
        }
        .buttonStyle(.plain)
    }

    private func kreisInhalt(icon: String, titel: String, unter: String, aktiv: Bool,
                             iconFarbe: Color? = nil) -> some View {
        ArcaIcon(name: icon, groesse: 21)
            .foregroundStyle(iconFarbe ?? (aktiv ? ArcaWarm.terrakotta : Color.primary.opacity(0.72)))
            .symbolRenderingMode(.hierarchical)
            .frame(width: 48, height: 48)
            .glassEffect(.regular, in: Circle())
            .overlay {
                if aktiv { Circle().strokeBorder(ArcaWarm.terrakotta.opacity(0.5), lineWidth: 1.5) }
            }
            .contentShape(Circle())
            .accessibilityLabel(titel)
    }

    // MARK: Großer Plus mit Schlüssel-Badge

    private var plusGross: some View {
        Button {
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            legeKontextbezogenAn()
        } label: {
            Image(systemName: "plus")
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 54, height: 54)
                .background(ArcaWarm.terrakotta, in: Circle())
                .shadow(color: ArcaWarm.terrakotta.opacity(0.35), radius: 7, x: 0, y: 3)
        }
        .buttonStyle(.plain)
        .overlay(alignment: .topTrailing) {
            ZStack {
                Circle().fill(ArcaWarm.karte)
                    .overlay(Circle().strokeBorder(ArcaWarm.terrakotta.opacity(0.4), lineWidth: 1.2))
                ArcaIcon(name: "ArcaKey", groesse: 11)
                    .foregroundStyle(ArcaWarm.terrakotta)
            }
            .frame(width: 23, height: 23)
            .shadow(color: .black.opacity(0.12), radius: 3, x: 0, y: 1)
            .offset(x: 7, y: -7)
            .allowsHitTesting(false)
        }
        .accessibilityLabel("Neu anlegen")
    }

    /// Was der Plus anlegt, hängt vom Ort ab (wie bisher im ArcaPlusKnopf).
    private func legeKontextbezogenAn() {
        switch selected {
        case .home, .spaceHub:
            switch store.homeStreamFilter {
            case .dokumente:
                store.pendingNewEntry = .documents
                withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) { selected = .documents }
            case .notizen:
                store.pendingQuickCapture = true
            case .tasks:
                store.pendingNewEntry = .lists
                withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) { selected = .lists }
            case .passwoerter:
                store.pendingNewEntry = .vault
                withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) { selected = .vault }
            }
        case .documents: store.pendingNewEntry = .documents
        case .lists:     store.pendingNewEntry = .lists
        case .vault:     store.pendingNewEntry = .vault
        case .notes:     store.pendingQuickCapture = true
        case .settings:  store.pendingQuickCapture = true
        }
    }
}


// MARK: - Der Plus-Knopf (iPhone-Leiste UND iPad/Mac-Überlagerung)

/// Der Terrakotta-Plus mit Sprech-Schalter und Sonar — eigenes Bauteil,
/// damit er auf dem iPhone in der Leiste und auf iPad/Mac als
/// schwebender Knopf unten rechts leben kann.
struct ArcaPlusKnopf: View {
    @Binding var selected: ArcaSection
    @EnvironmentObject var store: AppStore
    @Environment(\.horizontalSizeClass) private var groessenKlasse
    @State private var zeigeStiftNotiz = false

    /// Das Symbol der Plakette zeigt, was der Plus anlegen würde.
    private var kontextIcon: String {
        switch selected {
        case .documents: return "doc.fill"
        case .lists:     return "checkmark.square.fill"
        case .vault:     return "key.fill"
        case .notes:     return "lightbulb.fill"
        default:
            switch store.homeStreamFilter {
            case .dokumente:   return "doc.fill"
            case .notizen:     return "lightbulb.fill"
            case .tasks:       return "checkmark.square.fill"
            case .passwoerter: return "key.fill"
            }
        }
    }

    /// Was der Plus anlegt, hängt vom Ort ab: auf dem Start entscheidet
    /// der aktive Filter-Chip, in den Bereichen der Bereich selbst.
    /// Notizen = Blitzidee (das ist Arcas Notiz-Erfassung).
    private func legeKontextbezogenAn() {
        switch selected {
        case .home, .spaceHub:
            switch store.homeStreamFilter {
            case .dokumente:
                store.pendingNewEntry = .documents
                withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) { selected = .documents }
            case .notizen:
                store.pendingQuickCapture = true
            case .tasks:
                store.pendingNewEntry = .lists
                withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) { selected = .lists }
            case .passwoerter:
                store.pendingNewEntry = .vault
                withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) { selected = .vault }
            }
        case .documents: store.pendingNewEntry = .documents
        case .lists:     store.pendingNewEntry = .lists
        case .vault:     store.pendingNewEntry = .vault
        case .notes:     store.pendingQuickCapture = true
        case .settings:  store.pendingQuickCapture = true
        }
    }

    /// Sonar-Wellen hinter dem Plus, solange der Sprach-Modus an ist —
    /// ruhig und langsam, Premium statt verspielt.
    private struct ArcaSprechPuls: View {
        @State private var schwingt = false

        var body: some View {
            ZStack {
                ForEach(0..<2, id: \.self) { welle in
                    Circle()
                        .stroke(ArcaWarm.terrakotta.opacity(schwingt ? 0.0 : 0.35),
                                lineWidth: schwingt ? 1 : 6)
                        .frame(width: 56, height: 56)
                        .scaleEffect(schwingt ? 1.6 : 1.0)
                        .animation(
                            .easeOut(duration: 2.2)
                                .repeatForever(autoreverses: false)
                                .delay(Double(welle) * 1.1),
                            value: schwingt
                        )
                }
            }
            .allowsHitTesting(false)
            .onAppear { schwingt = true }
        }
    }

    var body: some View {
        // Zwei Freunde nebeneinander: links das Blitzidee-Mikro,
        // rechts der Plus für die vier Eingaben (Plakette = Gruppe).
        HStack(spacing: 14) {
            // Die Schreibtisch-Uhr: ganz links in der Werkzeug-Reihe
            if groessenKlasse == .regular {
                ArcaDeskUhr()
            }

            // Arca Pen: immer griffbereit, auch bei eingeklappter
            // Seitenleiste (nur iPad/Mac)
            if groessenKlasse == .regular {
                Button {
                    zeigeStiftNotiz = true
                } label: {
                    Image(systemName: "pencil.and.scribble")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(width: 52, height: 52)
                        .background(
                            LinearGradient(
                                colors: [Color(red: 0.85, green: 0.62, blue: 0.30),
                                         ArcaWarm.terrakotta],
                                startPoint: .topLeading, endPoint: .bottomTrailing),
                            in: Circle())
                        .shadow(color: ArcaWarm.terrakotta.opacity(0.3), radius: 6, x: 0, y: 3)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Arca Pen — Stift-Notiz")
            }

            // Das Blitzidee-Mikro: Glas-Tropfen mit Terrakotta-Mikro
            // und kleinem Blitz — ein Tipp, sprechen, fertig.
            Button {
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                store.quickCaptureAutoRecord = true
                store.pendingQuickCapture = true
            } label: {
                Image(systemName: "mic.fill")
                    .font(.system(size: 23, weight: .semibold))
                    .foregroundStyle(ArcaWarm.terrakotta)
                    .frame(width: 56, height: 56)
                    .background(ArcaWarm.karte, in: Circle())
                    .overlay(Circle().strokeBorder(ArcaWarm.terrakotta.opacity(0.5), lineWidth: 2))
                    .shadow(color: .black.opacity(0.18), radius: 7, x: 0, y: 3)
                    .contentShape(Circle().inset(by: -8))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Blitzidee diktieren")

            // Der Plus: legt immer das gerade Angewählte an
            Button {
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                legeKontextbezogenAn()
            } label: {
                Image(systemName: "plus")
                    .font(.system(size: 23, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 56, height: 56)
                    .background(ArcaWarm.terrakotta, in: Circle())
                    .shadow(color: ArcaWarm.terrakotta.opacity(0.35), radius: 8, x: 0, y: 4)
            }
            .buttonStyle(.plain)
            // Die Plakette zeigt immer die angewählte Gruppe —
            // rechts oben am Plus, weg vom Mikro
            .overlay(alignment: .topTrailing) {
                Image(systemName: kontextIcon)
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(ArcaWarm.terrakotta)
                    .contentTransition(.symbolEffect(.replace))
                    .frame(width: 28, height: 28)
                    .background(ArcaWarm.karte, in: Circle())
                    .overlay(Circle().strokeBorder(ArcaWarm.terrakotta.opacity(0.45), lineWidth: 1.5))
                    .shadow(color: .black.opacity(0.12), radius: 3, x: 0, y: 1)
                    .offset(x: 10, y: -10)
                    .allowsHitTesting(false)
            }
            .accessibilityLabel("Neu anlegen")
        }
        .sheet(isPresented: $zeigeStiftNotiz) {
            ArcaStiftNotiz()
                .environmentObject(store)
        }
    }
}

// MARK: - iPad Sidebar

struct ArcaIPadSidebar: View {
    @Binding var selectedSection: ArcaSection
    @EnvironmentObject var store: AppStore
    @State private var zeigeStiftNotiz = false

    private struct NavItem {
        let section: ArcaSection
        let icon: String
        let color: Color
    }

    /// Start oben, Einstellungen unten — dazwischen die Bereiche in der
    /// Reihenfolge, die auf dem Start zusammengezogen wurde.
    private var navItems: [NavItem] {
        var items = [NavItem(section: .home, icon: "house", color: .primary)]
        for bereich in store.bereichsOrdnung {
            switch bereich {
            case .passwoerter:
                items.append(NavItem(section: .vault,     icon: "ArcaKey",       color: NoteColor.for_(2).accent))
            case .dokumente:
                items.append(NavItem(section: .documents, icon: "ArcaDocument",  color: NoteColor.for_(5).accent))
            case .notizen:
                items.append(NavItem(section: .notes,     icon: "ArcaIdee", color: ArcaWarm.ideenGelb))
            case .tasks:
                items.append(NavItem(section: .lists,     icon: "ArcaChecklist", color: NoteColor.for_(3).accent))
            }
        }
        items.append(NavItem(section: .settings, icon: "ArcaSettings", color: .secondary))
        return items
    }

    private func count(for section: ArcaSection) -> Int? {
        switch section {
        case .vault:     return store.vaultItems.isEmpty ? nil : store.vaultItems.count
        case .documents: return store.documents.isEmpty  ? nil : store.documents.count
        case .notes:     return store.notes.isEmpty      ? nil : store.notes.count
        case .lists:     return store.lists.isEmpty      ? nil : store.lists.count
        default:         return nil
        }
    }

    var body: some View {
        List {
            ForEach(navItems, id: \.section) { item in
                let isSelected = selectedSection == item.section
                Button {
                    selectedSection = item.section
                } label: {
                    HStack(spacing: 12) {
                        ArcaIcon(name: item.icon, groesse: 16)
                            .foregroundStyle(isSelected ? .white : item.color)
                            .frame(width: 30, height: 30)
                            .background(
                                isSelected ? item.color : item.color.opacity(0.12),
                                in: RoundedRectangle(cornerRadius: 8)
                            )
                        Text(item.section.displayName)
                            .font(.system(size: 15, weight: isSelected ? .semibold : .regular))
                            .foregroundStyle(Color.primary)
                        Spacer()
                        if let n = count(for: item.section) {
                            Text(n > 99 ? "99+" : "\(n)")
                                .font(.system(size: 12, weight: .medium, design: .rounded))
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.vertical, 2)
                }
                .buttonStyle(.plain)
                .listRowBackground(isSelected ? Color.primary.opacity(0.07) : Color.clear)
            }
        }
        .listStyle(.sidebar)
        .scrollContentBackground(.hidden)
        .background(ArcaWarm.hintergrund)
        .navigationTitle("Arca")
        // Notfall immer griffbereit + die Kürzel als leiser Hinweis
        .sheet(isPresented: $zeigeStiftNotiz) {
            ArcaStiftNotiz()
                .environmentObject(store)
        }
        .safeAreaInset(edge: .bottom) {
            VStack(spacing: 10) {
                // Arca Pen: schräges Pergament-Blatt mit Stift —
                // der Knopf macht Lust, von Hand zu schreiben
                Button {
                    zeigeStiftNotiz = true
                } label: {
                    HStack(spacing: 9) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 3)
                                .fill(LinearGradient(
                                    colors: [Color(red: 0.97, green: 0.92, blue: 0.80),
                                             Color(red: 0.89, green: 0.80, blue: 0.63)],
                                    startPoint: .top, endPoint: .bottom))
                                .frame(width: 16, height: 20)
                                .overlay(
                                    VStack(spacing: 2.5) {
                                        ForEach(0..<3, id: \.self) { _ in
                                            Capsule()
                                                .fill(Color(red: 0.55, green: 0.42, blue: 0.25).opacity(0.5))
                                                .frame(height: 1.4)
                                        }
                                    }
                                    .padding(.horizontal, 3)
                                )
                                .overlay(RoundedRectangle(cornerRadius: 3)
                                    .strokeBorder(Color(red: 0.55, green: 0.42, blue: 0.25).opacity(0.4),
                                                  lineWidth: 0.7))
                                .rotationEffect(.degrees(-9))
                                .shadow(color: .black.opacity(0.25), radius: 1, x: 0, y: 1)
                            Image(systemName: "pencil")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundStyle(.white)
                                .shadow(color: .black.opacity(0.45), radius: 0.6)
                                .rotationEffect(.degrees(-42))
                                .offset(x: 5, y: 4)
                        }
                        Text("Arca Pen")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(.white)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 9)
                    .background(
                        LinearGradient(
                            colors: [Color(red: 0.85, green: 0.62, blue: 0.30),
                                     ArcaWarm.terrakotta],
                            startPoint: .topLeading, endPoint: .bottomTrailing),
                        in: Capsule())
                    .shadow(color: ArcaWarm.terrakotta.opacity(0.35), radius: 5, x: 0, y: 2)
                }
                .buttonStyle(.plain)

                Button {
                    store.zeigeNotfall = true
                } label: {
                    Label("Notfall", systemImage: "cross.case.fill")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.red)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 9)
                        .glassEffect(.regular, in: Capsule())
                }
                .buttonStyle(.plain)
                Text("⌘1–6 Bereiche · ⌘N Neu · ⌘F Suche")
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 14)
            .padding(.bottom, 10)
            .background(ArcaWarm.hintergrund)
        }
    }
}

