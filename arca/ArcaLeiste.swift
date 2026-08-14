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

/// Der Rahmen der unteren Leiste mit einem Bogen (Notch) in der Mitte,
/// in dem der erhöhte Plus-/Besen-Knopf sitzt.
struct NotchedBar: Shape {
    var notchRadius: CGFloat = 34
    var corner: CGFloat = 26

    func path(in rect: CGRect) -> Path {
        var p = Path()
        let cx = rect.midX
        let r = notchRadius
        let top = rect.minY

        p.move(to: CGPoint(x: rect.minX, y: top + corner))
        p.addQuadCurve(to: CGPoint(x: rect.minX + corner, y: top),
                       control: CGPoint(x: rect.minX, y: top))
        // hin zum Bogen
        p.addLine(to: CGPoint(x: cx - r, y: top))
        // weicher Bogen nach unten (Bogen im Rahmen)
        p.addQuadCurve(to: CGPoint(x: cx, y: top + r * 0.82),
                       control: CGPoint(x: cx - r * 0.52, y: top + r * 0.92))
        p.addQuadCurve(to: CGPoint(x: cx + r, y: top),
                       control: CGPoint(x: cx + r * 0.52, y: top + r * 0.92))
        // weiter zur rechten Ecke
        p.addLine(to: CGPoint(x: rect.maxX - corner, y: top))
        p.addQuadCurve(to: CGPoint(x: rect.maxX, y: top + corner),
                       control: CGPoint(x: rect.maxX, y: top))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        p.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        p.closeSubpath()
        return p
    }
}

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
            $0.category != "Top Secret" &&
            ($0.category == "Unsortiert" || !bekannte.contains($0.category))
        }.count
    }

    var body: some View {
        ZStack {
            // Rahmen mit Bogen in der Mitte
            NotchedBar(notchRadius: 36, corner: 26)
                .fill(.ultraThinMaterial)
                .overlay(
                    NotchedBar(notchRadius: 36, corner: 26)
                        .stroke(Color.primary.opacity(0.06), lineWidth: 1)
                )
                .frame(height: 60)
                .shadow(color: .black.opacity(0.08), radius: 12, x: 0, y: -2)

            // Seiten-Items: Home + Suche links, Mikro + Mehr rechts, Mitte frei
            HStack(spacing: 0) {
                HStack(spacing: 22) {
                    leistenItem(icon: "ArcaHome", label: "Home", aktiv: spaceActive) {
                        store.fokusKategorie = nil
                        store.zeigeIdeenPinnwand = false
                        if selected == .home {
                            store.homeStreamFilter = .dokumente
                            store.homeSprungNachOben += 1
                        } else {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) { selected = .home }
                        }
                    }
                    leistenItem(icon: "ArcaSearch", label: "Suche", aktiv: false) {
                        UISelectionFeedbackGenerator().selectionChanged()
                        store.fokusKategorie = nil
                        if selected != .home {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) { selected = .home }
                        }
                        store.sucheFokusSignal += 1
                    }
                }
                Spacer(minLength: 0)
                HStack(spacing: 22) {
                    leistenItem(icon: "ArcaMic", label: "Mikro", aktiv: false,
                                farbe: ArcaWarm.terrakotta) {
                        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                        store.quickCaptureAutoRecord = true
                        store.pendingQuickCapture = true
                    }
                    Menu {
                        Button { store.zeigeQRScan = true } label: {
                            Label("QR-Code scannen", systemImage: "qrcode.viewfinder")
                        }
                        Button { store.zeigeNotfall = true } label: {
                            Label("Notfall", systemImage: "cross.case.fill")
                        }
                        Divider()
                        Button { store.pendingSettingsAktion = "export"; selected = .settings } label: {
                            Label("Daten sichern", systemImage: "square.and.arrow.up")
                        }
                        Button { store.pendingSettingsAktion = "import"; selected = .settings } label: {
                            Label("Daten wiederherstellen", systemImage: "square.and.arrow.down")
                        }
                        Divider()
                        Button { selected = .settings } label: {
                            Label("Einstellungen", systemImage: "gearshape")
                        }
                    } label: {
                        leistenLabel(icon: "ArcaSettings", label: "Mehr", aktiv: selected == .settings)
                    }
                    .buttonStyle(.plain)
                }
            }
            .frame(height: 60)
            .padding(.horizontal, 30)

            // Der erhöhte zentrale Knopf sitzt im Bogen
            zentralKnopf
                .offset(y: -14)
        }
        .padding(.horizontal, 12)
        .padding(.bottom, 26)
    }

    // MARK: Zentraler Knopf — Plus, wird zum Besen wenn Unordnung herrscht

    private var zentralKnopf: some View {
        let aufraeumen = unsortiertAnzahl > 0
        return Button {
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            if aufraeumen { store.zeigeAufraeumen = true }
            else { legeKontextbezogenAn() }
        } label: {
            VStack(spacing: 4) {
                ZStack {
                    Circle()
                        .fill(ArcaWarm.terrakotta)
                        .frame(width: 56, height: 56)
                        .shadow(color: ArcaWarm.terrakotta.opacity(0.35), radius: 7, x: 0, y: 3)
                    if aufraeumen {
                        ArcaIcon(name: "ArcaBroom", groesse: 25).foregroundStyle(.white)
                    } else {
                        Image(systemName: "plus")
                            .font(.system(size: 24, weight: .semibold))
                            .foregroundStyle(.white)
                    }
                }
                // Plakette: Aufräum-Zähler ODER Kontext-Symbol des Plus
                .overlay(alignment: .topTrailing) {
                    if aufraeumen {
                        Text("\(unsortiertAnzahl)")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(.white)
                            .frame(minWidth: 18, minHeight: 18)
                            .padding(.horizontal, 2)
                            .background(Color.red, in: Capsule())
                            .offset(x: 6, y: -4)
                    } else {
                        ArcaIcon(name: kontextIcon, groesse: 11)
                            .foregroundStyle(ArcaWarm.terrakotta)
                            .frame(width: 22, height: 22)
                            .background(ArcaWarm.karte, in: Circle())
                            .overlay(Circle().strokeBorder(ArcaWarm.terrakotta.opacity(0.4), lineWidth: 1.2))
                            .offset(x: 7, y: -5)
                            .id(kontextIcon)
                    }
                }
                Text(aufraeumen ? "Aufräumen" : "Neu")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(aufraeumen ? ArcaWarm.terrakotta : Color.secondary)
            }
        }
        .buttonStyle(.plain)
        .animation(.easeInOut(duration: 0.25), value: aufraeumen)
        .accessibilityLabel(aufraeumen ? "Aufräumen — \(unsortiertAnzahl) unsortiert" : "Neu anlegen")
    }

    // MARK: Leisten-Item mit Label (Icon oben, Text unten)

    private func leistenItem(icon: String, label: String, aktiv: Bool,
                             farbe: Color? = nil, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            leistenLabel(icon: icon, label: label, aktiv: aktiv, farbe: farbe)
        }
        .buttonStyle(.plain)
    }

    private func leistenLabel(icon: String, label: String, aktiv: Bool,
                              farbe: Color? = nil) -> some View {
        VStack(spacing: 4) {
            ArcaIcon(name: icon, groesse: 23)
                .foregroundStyle(farbe ?? (aktiv ? ArcaWarm.terrakotta : Color.primary.opacity(0.6)))
                .symbolRenderingMode(.hierarchical)
                .frame(height: 28)
            Text(label)
                .font(.system(size: 10, weight: aktiv ? .semibold : .medium))
                .foregroundStyle(aktiv ? ArcaWarm.terrakotta : Color.secondary)
        }
        .frame(minWidth: 48)
        .contentShape(Rectangle())
        .accessibilityLabel(label)
    }

    /// Die Plakette am Plus zeigt, was gerade angelegt würde — sie wandert
    /// mit den Chips (Dokumente/Ideen/Aufgaben/Tresor) und den Bereichen mit.
    private var kontextIcon: String {
        switch selected {
        case .documents: return "ArcaDocument"
        case .lists:     return "ArcaChecklist"
        case .vault:     return "ArcaKey"
        case .notes:     return "ArcaIdee"
        default:
            switch store.homeStreamFilter {
            case .dokumente:   return "ArcaDocument"
            case .notizen:     return "ArcaIdee"
            case .tasks:       return "ArcaChecklist"
            case .passwoerter: return "ArcaKey"
            }
        }
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

