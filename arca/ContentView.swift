//
//  ContentView.swift
//  Arca
//
//  ARCA 2.4.1
//  Entwickler: Hans zen Ruffinen
//  Ein lokaler Mini-Tresor für Passwörter, Dokumente und Notizen.
//  Erstellt mit SwiftUI.
//

import SwiftUI
import UniformTypeIdentifiers
import QuickLook
import QuickLookThumbnailing
import VisionKit
import PhotosUI
import StoreKit

struct ContentView: View {
    @EnvironmentObject var store: AppStore
    var isUnlocked: Bool = true
    @State private var selectedSection: ArcaSection = .home
    @State private var screenHeight: CGFloat = 852   // vernünftiger Fallback, wird sofort überschrieben
    @State private var showRecoveryHint = false
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    // Reihenfolge der wischbaren Tabs
    private let swipeSections: [ArcaSection] = [.home, .settings]

    var body: some View {
        Group {
            if horizontalSizeClass == .regular {
                iPadLayout
            } else {
                iPhoneLayout
            }
        }
        .onChange(of: store.pendingSharedURL) { _, url in
            guard let url else { return }
            if store.isBackupCandidateURL(url) {
                store.pendingSharedURL = nil
                store.pendingBackupURL = url
                selectedSection = .settings
            } else {
                selectedSection = .documents
            }
        }
        .onChange(of: store.pendingBackupURL) { _, url in
            if url != nil { selectedSection = .settings }
        }
        .onChange(of: store.pendingSection) { _, section in
            guard let section else { return }
            if isUnlocked {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
                    selectedSection = section
                }
                store.pendingSection = nil
            }
            // Wenn gesperrt: pendingSection bleibt gesetzt und wird nach Entsperren verarbeitet
        }
        .onChange(of: isUnlocked) { _, unlocked in
            if unlocked, let section = store.pendingSection {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
                    selectedSection = section
                }
                store.pendingSection = nil
            }
            if unlocked, let url = store.pendingSharedURL, store.isBackupCandidateURL(url) {
                store.pendingSharedURL = nil
                store.pendingBackupURL = url
                selectedSection = .settings
            }
        }
        .onChange(of: selectedSection) { _, section in
            if section != .documents { store.pendingScrollCategory = nil }
        }
        .sheet(isPresented: $store.pendingQuickCapture, onDismiss: {
            store.quickCaptureAutoRecord = false
        }) {
            QuickCaptureSheet(autoRecord: store.quickCaptureAutoRecord) { title, text in
                store.addQuickIdea(title: title, text: text)
                UINotificationFeedbackGenerator().notificationOccurred(.success)
            }
            // Die schöne Idee-Karte: halbhoch, Glas, runde Ecken
            .presentationDetents([.medium, .large])
            .presentationCornerRadius(28)
            .presentationBackground(.ultraThinMaterial)
        }
        .sheet(isPresented: $store.zeigeNotfall) {
            NotfallView(karten: store.vaultItems.filter { !$0.sperrHotline.isEmpty })
        }
        // ── Tastaturkürzel (Mac & iPad mit Tastatur) ──
        // ⌘1–⌘6 Bereiche · ⌘N Neu (Blitzidee) · ⇧⌘N Diktat · ⌘F Suche
        .background {
            Group {
                Button("") { wechsleZu(.home) }.keyboardShortcut("1", modifiers: .command)
                Button("") { wechsleZu(.vault) }.keyboardShortcut("2", modifiers: .command)
                Button("") { wechsleZu(.documents) }.keyboardShortcut("3", modifiers: .command)
                Button("") { wechsleZu(.notes) }.keyboardShortcut("4", modifiers: .command)
                Button("") { wechsleZu(.lists) }.keyboardShortcut("5", modifiers: .command)
                Button("") { wechsleZu(.settings) }.keyboardShortcut("6", modifiers: .command)
                Button("") { store.pendingQuickCapture = true }
                    .keyboardShortcut("n", modifiers: .command)
                Button("") {
                    store.quickCaptureAutoRecord = true
                    store.pendingQuickCapture = true
                }
                .keyboardShortcut("n", modifiers: [.command, .shift])
                Button("") {
                    wechsleZu(.home)
                    store.sucheFokusSignal += 1
                }
                .keyboardShortcut("f", modifiers: .command)
            }
            .opacity(0)
            .frame(width: 0, height: 0)
            .accessibilityHidden(true)
        }
        .overlay(alignment: .top) {
            if store.isCloudSyncPending {
                CloudSyncBanner()
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .animation(.easeInOut(duration: 0.25), value: store.isCloudSyncPending)
        .onAppear { evaluateRecoveryHint(isFirstLaunch: true) }
        .onChange(of: store.isCloudSyncPending) { _, pending in
            if !pending { evaluateRecoveryHint() }
        }
        .alert("Daten fehlen?", isPresented: $showRecoveryHint) {
            Button("Verstanden") { store.markRecoveryHintShown() }
        } message: {
            Text("Falls Daten fehlen, versuche: (1) ein anderes Gerät, das noch nicht aktualisiert wurde, (2) Wiederherstellung aus einem Backup über Einstellungen → Daten wiederherstellen.")
        }
    }

    private func wechsleZu(_ ziel: ArcaSection) {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
            selectedSection = ziel
        }
    }

    private func evaluateRecoveryHint(isFirstLaunch: Bool = false) {
        guard store.shouldShowRecoveryHint else { return }
        if isFirstLaunch || store.isLikelyEmptyWithPendingCloud {
            showRecoveryHint = true
        }
    }

    // MARK: - iPhone Layout (unverändert)

    private var iPhoneLayout: some View {
        ZStack(alignment: .bottom) {
            Group {
                switch selectedSection {
                case .home:      HomeView(selectedSection: $selectedSection)
                case .spaceHub:  SpaceHubView(selectedSection: $selectedSection)
                case .vault:     VaultView()
                case .documents: DocumentsView(isUnlocked: isUnlocked)
                case .notes:     NotesView()
                case .lists:     ListsView()
                case .settings:  SettingsView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .safeAreaInset(edge: .bottom) { Color.clear.frame(height: 104) }

            ArcaTabBar(selected: $selectedSection)
        }
        .ignoresSafeArea(edges: .bottom)
        .background(
            GeometryReader { geo in
                Color.clear.onAppear { screenHeight = geo.size.height }
                    .onChange(of: geo.size.height) { _, newHeight in screenHeight = newHeight }
            }
        )
        .gesture(
            DragGesture(minimumDistance: 20, coordinateSpace: .global)
                .onEnded { value in
                    // Nur reagieren wenn Wisch auf der Tab-Leiste selbst startete —
                    // sonst frisst die Geste das Wischen auf den untersten Listenzeilen
                    guard value.startLocation.y > screenHeight - 90 else { return }
                    // Klar horizontale Bewegung
                    guard abs(value.translation.width) > abs(value.translation.height) * 1.2 else { return }
                    guard let idx = swipeSections.firstIndex(of: selectedSection) else { return }
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
                        if value.translation.width < -20 {
                            selectedSection = swipeSections[min(idx + 1, swipeSections.count - 1)]
                        } else if value.translation.width > 20 {
                            selectedSection = swipeSections[max(idx - 1, 0)]
                        }
                    }
                }
        )
    }

    // MARK: - iPad Layout

    private var iPadLayout: some View {
        NavigationSplitView {
            ArcaIPadSidebar(selectedSection: $selectedSection)
                .navigationSplitViewColumnWidth(min: 200, ideal: 260, max: 310)
        } detail: {
            switch selectedSection {
            case .home:      HomeView(selectedSection: $selectedSection)
            case .spaceHub:  SpaceHubView(selectedSection: $selectedSection)
            case .vault:     VaultView()
            case .documents: DocumentsView(isUnlocked: isUnlocked)
            case .notes:     NotesView()
            case .lists:     ListsView()
            case .settings:  SettingsView()
            }
        }
        .navigationSplitViewStyle(.balanced)
        // Der Plus fehlt sonst auf iPad und Mac — hier schwebt er unten rechts
        .overlay(alignment: .bottomTrailing) {
            ArcaPlusKnopf(selected: $selectedSection)
                .padding(.trailing, 28)
                .padding(.bottom, 24)
        }
    }
}

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
    /// (Tasks haben ihren eigenen Reiter in der Pille)
    private var spaceActive: Bool {
        [.home, .spaceHub, .vault, .documents, .notes].contains(selected)
    }

    var body: some View {
        // Schwebende Glas-Pille links, Blitzidee-Plus rechts (Craft-Stil)
        HStack(spacing: 12) {
            HStack(spacing: 2) {
                pillButton(icon: "square.grid.2x2", active: spaceActive, label: "Space") {
                    // Schon auf dem Start? Dann nach oben springen.
                    if selected == .home {
                        store.homeSprungNachOben += 1
                    } else {
                        selected = .home
                    }
                }
                pillButton(icon: "checkmark.square", active: selected == .lists, label: "Aufgaben") {
                    selected = .lists
                }
                // Das Zahnrad klappt ein Menü auf (Craft-Stil):
                // Sichern · Wiederherstellen · Einstellungen
                Menu {
                    Button {
                        store.zeigeNotfall = true
                    } label: {
                        Label("Notfall", systemImage: "cross.case.fill")
                    }
                    Divider()
                    Button {
                        store.pendingSettingsAktion = "export"
                        selected = .settings
                    } label: {
                        Label("Daten sichern", systemImage: "square.and.arrow.up")
                    }
                    Button {
                        store.pendingSettingsAktion = "import"
                        selected = .settings
                    } label: {
                        Label("Daten wiederherstellen", systemImage: "square.and.arrow.down")
                    }
                    Divider()
                    Button {
                        selected = .settings
                    } label: {
                        Label("Einstellungen", systemImage: "gearshape")
                    }
                } label: {
                    Image(systemName: selected == .settings ? "gearshape.fill" : "gearshape")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(selected == .settings ? ArcaWarm.terrakotta : Color.primary.opacity(0.65))
                        .symbolRenderingMode(.hierarchical)
                        .frame(width: 54, height: 44)
                        .contentShape(Rectangle())
                        .background(
                            selected == .settings ? Color.primary.opacity(0.06) : Color.clear,
                            in: Capsule()
                        )
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Mehr")
            }
            .padding(5)
            .glassEffect(.regular, in: Capsule())

            Spacer(minLength: 0)

            ArcaPlusKnopf(selected: $selected)
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 34)
    }

    private func pillButton(icon: String, active: Bool, label: String,
                            action: @escaping () -> Void) -> some View {
        Button {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) { action() }
        } label: {
            Image(systemName: active ? icon + ".fill" : icon)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(active ? ArcaWarm.terrakotta : Color.primary.opacity(0.65))
                .symbolRenderingMode(.hierarchical)
                .frame(width: 54, height: 44)
                .contentShape(Rectangle())
                .background(
                    active ? Color.primary.opacity(0.06) : Color.clear,
                    in: Capsule()
                )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }
}


// MARK: - Der Plus-Knopf (iPhone-Leiste UND iPad/Mac-Überlagerung)

/// Der Terrakotta-Plus mit Sprech-Schalter und Sonar — eigenes Bauteil,
/// damit er auf dem iPhone in der Leiste und auf iPad/Mac als
/// schwebender Knopf unten rechts leben kann.
struct ArcaPlusKnopf: View {
    @Binding var selected: ArcaSection
    @EnvironmentObject var store: AppStore

    /// Schalter an der Plus-Ecke: aktiv = Sprechen (Diktat sofort),
    /// inaktiv = der Plus legt das unten Ausgewählte an.
    @AppStorage("plusSprechenAktiv") private var plusSprechenAktiv = true

    /// Das Symbol des Schalters zeigt, was der Plus anlegen würde.
    private var kontextIcon: String {
        switch selected {
        case .documents: return "doc.fill"
        case .lists:     return "checkmark.square.fill"
        case .vault:     return "key.fill"
        case .notes:     return "note.text"
        default:
            switch store.homeStreamFilter {
            case .dokumente:   return "doc.fill"
            case .notizen:     return "note.text"
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
            // Der Plus: Schalter aktiv = Sprechen (Diktat startet sofort),
            // Schalter inaktiv = das gerade Ausgewählte anlegen.
            Button {
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                if plusSprechenAktiv {
                    store.quickCaptureAutoRecord = true
                    store.pendingQuickCapture = true
                } else {
                    legeKontextbezogenAn()
                }
            } label: {
                Image(systemName: "plus")
                    .font(.system(size: 23, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 56, height: 56)
                    .background(ArcaWarm.terrakotta, in: Circle())
                    .shadow(color: ArcaWarm.terrakotta.opacity(0.35), radius: 8, x: 0, y: 4)
            }
            .buttonStyle(.plain)
            // Im Sprach-Modus atmet der Plus Sonar-Wellen aus
            .background {
                if plusSprechenAktiv {
                    ArcaSprechPuls()
                }
            }
            .simultaneousGesture(
                LongPressGesture(minimumDuration: 0.4).onEnded { _ in
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                    store.quickCaptureAutoRecord = true
                    store.pendingQuickCapture = true
                }
            )
            // Der Schalter an der Plus-Ecke: zeigt, was der Plus gerade tut
            .overlay(alignment: .topLeading) {
                Button {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        plusSprechenAktiv.toggle()
                    }
                } label: {
                    Image(systemName: plusSprechenAktiv ? "mic.fill" : kontextIcon)
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(ArcaWarm.terrakotta)
                        .symbolEffect(.pulse, isActive: plusSprechenAktiv)
                        .frame(width: 32, height: 32)
                        .background(ArcaWarm.karte, in: Circle())
                        .overlay(Circle().strokeBorder(ArcaWarm.terrakotta.opacity(0.45), lineWidth: 1.5))
                        .shadow(color: .black.opacity(0.12), radius: 3, x: 0, y: 1)
                }
                .buttonStyle(.plain)
                .offset(x: -12, y: -12)
                .accessibilityLabel(plusSprechenAktiv ? "Plus spricht (Diktat)" : "Plus legt das Ausgewählte an")
            }
            .accessibilityLabel(plusSprechenAktiv ? "Blitzidee diktieren" : "Neu anlegen")
    }
}

// MARK: - iPad Sidebar

struct ArcaIPadSidebar: View {
    @Binding var selectedSection: ArcaSection
    @EnvironmentObject var store: AppStore

    private struct NavItem {
        let section: ArcaSection
        let icon: String
        let color: Color
    }

    private var navItems: [NavItem] {
        [
            NavItem(section: .home,      icon: "house",     color: .primary),
            NavItem(section: .vault,     icon: "key",       color: NoteColor.for_(2).accent),
            NavItem(section: .documents, icon: "doc.text",  color: NoteColor.for_(5).accent),
            NavItem(section: .notes,     icon: "note.text", color: NoteColor.for_(4).accent),
            NavItem(section: .lists,     icon: "checklist", color: NoteColor.for_(3).accent),
            NavItem(section: .settings,  icon: "gearshape", color: .secondary),
        ]
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
                        Image(systemName: item.icon)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(isSelected ? .white : item.color)
                            .frame(width: 30, height: 30)
                            .background(
                                isSelected ? item.color : item.color.opacity(0.12),
                                in: RoundedRectangle(cornerRadius: 8)
                            )
                        Text(item.section.rawValue)
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
        .safeAreaInset(edge: .bottom) {
            VStack(spacing: 10) {
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

// MARK: - Home

// Tile-Definition für die 4 Hauptkacheln
struct HomeTileSpec: Identifiable {
    let id: String
    let section: ArcaSection
    let title: String
    let subtitle: String
    let actionLabel: String
    let icon: String
    let colorTag: Int   // Index in NoteColor.palette
}

// Activity-Item (Variante A: einfach aus dateCreated/dateAdded der bestehenden Items)
struct HomeActivityItem: Identifiable {
    let id: UUID
    let title: String
    let kind: Kind
    let date: Date

    enum Kind {
        case password, document, note, task

        var icon: String {
            switch self {
            case .password: return "lock.fill"
            case .document: return "doc.fill"
            case .note:     return "note.text"
            case .task:     return "checklist"
            }
        }
        var label: String {
            switch self {
            case .password: return "Passwörter"
            case .document: return "Dokumente"
            case .note:     return "Notizen"
            case .task:     return "Aufgaben"
            }
        }
        var colorTag: Int {
            switch self {
            case .password: return 2  // Blau
            case .document: return 5  // Pfirsich
            case .note:     return 4  // Lila
            case .task:     return 3  // Grün
            }
        }
        var section: ArcaSection {
            switch self {
            case .password: return .vault
            case .document: return .documents
            case .note:     return .notes
            case .task:     return .lists
            }
        }
    }
}

// Datums-Formatierung für die Aktivitäten
func formatActivityDate(_ date: Date) -> String {
    let calendar = Calendar.current
    let timeFormatter = DateFormatter()
    timeFormatter.locale = Locale(identifier: "de_DE")
    timeFormatter.dateFormat = "HH:mm"
    let timeStr = timeFormatter.string(from: date)

    if calendar.isDateInToday(date) {
        return "Heute, \(timeStr)"
    } else if calendar.isDateInYesterday(date) {
        return "Gestern, \(timeStr)"
    } else {
        let dateFormatter = DateFormatter()
        dateFormatter.locale = Locale(identifier: "de_DE")
        dateFormatter.dateFormat = "d. MMM"
        return "\(dateFormatter.string(from: date)), \(timeStr)"
    }
}

struct HomeView: View {
    @EnvironmentObject var store: AppStore
    @Binding var selectedSection: ArcaSection
    @State private var showQRScanner = false
    @State private var showSpiderGame = false
    @State private var logoTapCount = 0
    @State private var quickAccessPreviewURL: URL? = nil
    @State private var quickAccessNote: NoteEntry? = nil
    @State private var searchText = ""
    @FocusState private var isSearchFocused: Bool
    @AppStorage("arcaUserName") private var userName: String = ""
    @AppStorage("arcaUserNameAsked") private var userNameAsked: Bool = false
    @State private var showNamePrompt = false
    @State private var namePromptInput = ""
    // Ausgeklappte Ordner und Tasklisten auf dem Start
    @State private var expandedFolders: Set<String> = []
    @State private var expandedLists: Set<UUID> = []
    // Dokument-Verwaltung direkt auf dem Start
    @State private var homeRenameDoc: DocumentEntry? = nil
    @State private var homeRenameText = ""
    @State private var showNeueGruppe = false
    @State private var neueGruppeName = ""
    @State private var docFuerNeueGruppe: DocumentEntry? = nil
    @State private var gruppeZumUmbenennen: String? = nil
    @State private var gruppeUmbenennenText = ""
    @State private var gruppeZumLoeschen: String? = nil
    @State private var sortiereGruppen = false
    @State private var backupSnoozeSignal = 0
    // Notizen/Aufgaben/Passwörter im Strom bearbeiten
    @State private var streamRenameItem: FavoriteItem? = nil
    @State private var streamRenameText = ""
    @State private var vaultZumLoeschen: FavoriteItem? = nil
    @State private var punktFuerListe: UUID? = nil
    @State private var neuerPunktText = ""

    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    // Einblend-Animation
    @State private var appeared = true

    private func enterAnimation(delay: Double) -> Animation {
        .spring(response: 0.55, dampingFraction: 0.82).delay(delay)
    }

    private var isSearching: Bool {
        !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    /// Auf dem iPad (regular) wird der Startinhalt zentriert und in der Breite
    /// begrenzt, damit er auf großen Bildschirmen nicht gestreckt/leer wirkt.
    private var homeContentMaxWidth: CGFloat {
        horizontalSizeClass == .regular ? 700 : .infinity
    }


    /// Ausgeklappter Ordner: seine Dokumente direkt auf dem Start,
    /// mit Mini-Vorschau — ein Tipp öffnet die Vollansicht.
    private func folderDocumentRows(_ category: String) -> some View {
        // „Unsortiert" sammelt seine eigenen Dateien UND alles,
        // was in keiner bekannten Gruppe steckt
        let docs = store.documents
            .filter { doc in
                category == "Unsortiert"
                    ? (doc.category == "Unsortiert" || !store.documentCategories.contains(doc.category))
                    : doc.category == category
            }
            .sorted { $0.dateAdded > $1.dateAdded }
        return VStack(spacing: 6) {
            if docs.isEmpty {
                Text("Dieser Ordner ist noch leer.")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(10)
            } else {
                ForEach(docs) { doc in
                    Button {
                        quickAccessPreviewURL = store.documentURL(for: doc.filename)
                    } label: {
                        HStack(spacing: 10) {
                            DocThumbnail(url: store.documentURL(for: doc.filename), type: doc.type)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(doc.title)
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundStyle(.primary)
                                    .lineLimit(1)
                                Text("\(doc.type.rawValue) · \(doc.dateAdded.formatted(.relative(presentation: .named)))")
                                    .font(.system(size: 11))
                                    .foregroundStyle(.secondary)
                            }
                            Spacer(minLength: 0)
                            Image(systemName: "chevron.right")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(.tertiary)
                        }
                        .padding(8)
                        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 12))
                    }
                    .buttonStyle(.plain)
                    .contentShape(Rectangle())
                    .draggable(doc.id.uuidString)
                    // Verwaltung direkt auf dem Start: verschieben,
                    // umbenennen, favorisieren, löschen
                    .contextMenu {
                        ArcaMenue.favorit(ist: doc.isFavorite) {
                            store.toggleFavorite(kind: .document, id: doc.id)
                            UINotificationFeedbackGenerator().notificationOccurred(.success)
                        }
                        Divider()
                        ArcaMenue.umbenennen {
                            homeRenameText = doc.title
                            homeRenameDoc = doc
                        }
                        Menu {
                            ForEach(store.documentCategories.filter { $0 != doc.category }, id: \.self) { ziel in
                                Button { verschiebeDokument(doc, nach: ziel) } label: {
                                    Label(ziel, systemImage: categoryIcon(ziel))
                                }
                            }
                            Divider()
                            Button {
                                docFuerNeueGruppe = doc
                                neueGruppeName = ""
                                showNeueGruppe = true
                            } label: {
                                Label("Neue Gruppe…", systemImage: "folder.badge.plus")
                            }
                        } label: {
                            Label("In Gruppe verschieben", systemImage: "folder")
                        }
                        ArcaMenue.loeschen {
                            store.deleteDocument(doc)
                            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                        }
                    }
                }
            }
        }
        .padding(.leading, 16)
    }

    /// Aufgeklappte Taskliste im Strom: Punkte direkt abhaken.
    private func toggleTask(listID: UUID, itemID: UUID) {
        guard let li = store.lists.firstIndex(where: { $0.id == listID }),
              let ti = store.lists[li].items.firstIndex(where: { $0.id == itemID }) else { return }
        store.lists[li].items[ti].isDone.toggle()
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }

    private func listeAufgeklappt(_ liste: ListEntry) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            if liste.items.isEmpty {
                Text("Noch keine Aufgaben in dieser Liste.")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .padding(.vertical, 6)
            } else {
                ForEach(liste.items) { punkt in
                    Button {
                        toggleTask(listID: liste.id, itemID: punkt.id)
                    } label: {
                        HStack(spacing: 10) {
                            Image(systemName: punkt.isDone ? "checkmark.circle.fill" : "circle")
                                .font(.system(size: 16))
                                .foregroundStyle(punkt.isDone ? .green : .secondary)
                            Text(punkt.text)
                                .font(.system(size: 13))
                                .strikethrough(punkt.isDone)
                                .foregroundStyle(punkt.isDone ? .secondary : .primary)
                                .lineLimit(1)
                            Spacer(minLength: 0)
                        }
                        .padding(.vertical, 6)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }
            HStack(spacing: 16) {
                Button {
                    neuerPunktText = ""
                    punktFuerListe = liste.id
                } label: {
                    Label("Punkt", systemImage: "plus.circle.fill")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(ArcaWarm.terrakotta)
                }
                .buttonStyle(.plain)

                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
                        selectedSection = .lists
                    }
                } label: {
                    Text("Zur Liste →")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding(.top, 4)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 12))
        .padding(.leading, 16)
    }

    /// Notiz → Aufgabenliste: Titel wird Listenname, jede Textzeile
    /// ein Punkt; die Notiz gilt danach als einsortiert und verschwindet.
    private func wandleNotizInAufgaben(_ item: FavoriteItem) {
        guard let note = store.notes.first(where: { $0.id == item.id }) else { return }
        let titel = note.title.trimmingCharacters(in: .whitespacesAndNewlines)
        let punkte = note.text
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
            .map { ChecklistItem(text: $0) }
        let liste = ListEntry(title: titel.isEmpty ? "Aufgaben" : titel,
                              items: punkte, colorTag: note.colorTag)
        store.lists.insert(liste, at: 0)
        store.notes.removeAll { $0.id == note.id }
        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
            store.homeStreamFilter = .tasks
            _ = expandedLists.insert(liste.id)
        }
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }

    /// Notiz → Passwort: Tresor öffnet das vorbefüllte Neu-Blatt;
    /// gelöscht wird die Notiz erst nach erfolgreichem Speichern.
    private func wandleNotizInPasswort(_ item: FavoriteItem) {
        guard let note = store.notes.first(where: { $0.id == item.id }) else { return }
        let titel = note.title.trimmingCharacters(in: .whitespacesAndNewlines)
        store.vaultVorbefuellung = titel.isEmpty
            ? String(note.text.prefix(30))
            : titel
        store.notizNachTresorUmwandlung = note.id
        store.pendingNewEntry = .vault
        withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
            selectedSection = .vault
        }
    }

    /// Blitzidee → feste Notiz: verliert nur das Blitz-Etikett.
    private func macheZurFestenNotiz(_ item: FavoriteItem) {
        if let i = store.notes.firstIndex(where: { $0.id == item.id }) {
            store.notes[i].isQuickIdea = false
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        }
    }

    /// Notiz/Aufgabenliste/Passwort direkt aus dem Strom löschen.
    private func loescheStreamEintrag(_ item: FavoriteItem) {
        switch item.kind {
        case .note:     store.notes.removeAll { $0.id == item.id }
        case .list:     store.lists.removeAll { $0.id == item.id }
        case .vault:    store.vaultItems.removeAll { $0.id == item.id }
        case .document: break
        }
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
    }

    /// Titel eines Strom-Eintrags ändern (Notiz/Aufgabenliste/Passwort).
    private func benenneStreamEintragUm() {
        guard let item = streamRenameItem else { return }
        let neu = streamRenameText.trimmingCharacters(in: .whitespacesAndNewlines)
        defer { streamRenameItem = nil }
        guard !neu.isEmpty else { return }
        switch item.kind {
        case .note:
            if let i = store.notes.firstIndex(where: { $0.id == item.id }) { store.notes[i].title = neu }
        case .list:
            if let i = store.lists.firstIndex(where: { $0.id == item.id }) { store.lists[i].title = neu }
        case .vault:
            if let i = store.vaultItems.firstIndex(where: { $0.id == item.id }) { store.vaultItems[i].title = neu }
        case .document: break
        }
    }

    /// Backup-Erinnerung: fällig ohne Sicherung oder nach 14 Tagen —
    /// „Später" schiebt sie eine Woche hinaus.
    private var backupErinnerungFaellig: Bool {
        _ = backupSnoozeSignal
        guard totalEntryCount > 0 else { return false }
        if let schlummer = UserDefaults.standard.object(forKey: "arcaBackupSnooze") as? Date,
           schlummer > Date() { return false }
        guard let letzt = store.letztesBackup else { return true }
        return Date().timeIntervalSince(letzt) > 14 * 86400
    }

    private var backupErinnerungText: String {
        guard let letzt = store.letztesBackup else {
            return "Noch keine Sicherung auf diesem Gerät"
        }
        let tage = max(1, Int(Date().timeIntervalSince(letzt) / 86400))
        return "Letzte Sicherung vor \(tage) Tagen"
    }

    /// Farbe des Strom-Eintrags lesen (für das Häkchen im Farb-Menü).
    private func streamFarbe(_ item: FavoriteItem) -> Int? {
        switch item.kind {
        case .note:     return store.notes.first(where: { $0.id == item.id })?.colorTag
        case .list:     return store.lists.first(where: { $0.id == item.id })?.colorTag
        case .vault:    return store.vaultItems.first(where: { $0.id == item.id })?.colorTag
        case .document: return nil
        }
    }

    /// Farbe des Strom-Eintrags setzen.
    private func setzeStreamFarbe(_ item: FavoriteItem, _ idx: Int) {
        switch item.kind {
        case .note:
            if let i = store.notes.firstIndex(where: { $0.id == item.id }) { store.notes[i].colorTag = idx }
        case .list:
            if let i = store.lists.firstIndex(where: { $0.id == item.id }) { store.lists[i].colorTag = idx }
        case .vault:
            if let i = store.vaultItems.firstIndex(where: { $0.id == item.id }) { store.vaultItems[i].colorTag = idx }
        case .document:
            break
        }
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }

    /// Ist der Eintrag hinter einer Strom-Zeile bereits Favorit?
    private func istFavorit(_ item: FavoriteItem) -> Bool {
        switch item.kind {
        case .document: return store.documents.first(where: { $0.id == item.id })?.isFavorite ?? false
        case .note:     return store.notes.first(where: { $0.id == item.id })?.isFavorite ?? false
        case .list:     return store.lists.first(where: { $0.id == item.id })?.isFavorite ?? false
        case .vault:    return store.vaultItems.first(where: { $0.id == item.id })?.isFavorite ?? false
        }
    }

    /// Favorit antippen: Dokument → Vorschau, Notiz → Blatt,
    /// Liste/Passwort → in die jeweilige Sektion (Tresor bleibt verschlossen).
    private func openFavorite(_ fav: FavoriteItem) {
        switch fav.kind {
        case .document:
            if let doc = store.documents.first(where: { $0.id == fav.id }) {
                quickAccessPreviewURL = store.documentURL(for: doc.filename)
            }
        case .note:
            if let note = store.notes.first(where: { $0.id == fav.id }) {
                quickAccessNote = note
            }
        case .list:
            selectedSection = .lists
        case .vault:
            selectedSection = .vault
        }
    }

    private func documentCount(in category: String) -> Int {
        store.documentCount(in: category)
    }

    private var homeQuickViewFolders: [String] {
        store.visibleHomeQuickViewFolders()
    }

    private func openDocuments(category: String) {
        store.pendingScrollCategory = category
        selectedSection = .documents
    }


    // ── Der Strom: ein Typ zur Zeit, jüngste zuerst (kein „Alle" mehr) ──
    private var streamFilter: HomeStreamFilter { store.homeStreamFilter }
    @State private var streamLimit: Int = 25

    private var streamItems: [FavoriteItem] {
        var all: [FavoriteItem] = []
        switch streamFilter {
        case .dokumente:
            break   // Dokumente zeigen ihre Gruppen, keine Einzelzeilen
        case .notizen:
            for n in store.notes {
                all.append(FavoriteItem(id: n.id, kind: .note, title: n.title.isEmpty ? "Notiz" : n.title,
                                        subtitle: n.isQuickIdea ? "Blitzidee" : "Notiz",
                                        pinned: false, date: n.dateCreated))
            }
        case .tasks:
            for l in store.lists {
                let open = l.items.filter { !$0.isDone }.count
                all.append(FavoriteItem(id: l.id, kind: .list, title: l.title,
                                        subtitle: open > 0 ? "\(open) offen" : "Erledigt",
                                        pinned: false, date: l.dateCreated))
            }
        case .passwoerter:
            for v in store.vaultItems {
                all.append(FavoriteItem(id: v.id, kind: .vault, title: v.title,
                                        subtitle: "Mit Face ID öffnen", pinned: false, date: v.dateCreated))
            }
        }
        return all.sorted { $0.date > $1.date }
    }

    /// Dokumente treten im Strom als Gruppen auf — alle Gruppen, auch
    /// leere (sonst wären frisch erstellte unsichtbar). Was in keiner
    /// bekannten Gruppe steckt, sammelt „Unsortiert".
    private var dokumentGruppen: [(name: String, anzahl: Int)] {
        var zaehler: [String: Int] = [:]
        for d in store.documents {
            let schluessel = store.documentCategories.contains(d.category) ? d.category : "Unsortiert"
            zaehler[schluessel, default: 0] += 1
        }
        // Unsortiert steht immer fest an erster Stelle
        let namen = ["Unsortiert"] + store.documentCategories.filter { $0 != "Unsortiert" }
        return namen.map { ($0, zaehler[$0] ?? 0) }
    }

    /// Etwas wurde auf eine Gruppen-Karte gezogen: entweder ein Dokument
    /// (UUID → einsortieren) oder eine andere Gruppe (Name → umsortieren).
    private func verarbeiteAblage(_ eingeworfen: [String], aufGruppe ziel: String) -> Bool {
        guard let wert = eingeworfen.first else { return false }
        if let uuid = UUID(uuidString: wert),
           let doc = store.documents.first(where: { $0.id == uuid }) {
            guard doc.category != ziel else { return false }
            withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                verschiebeDokument(doc, nach: ziel)
            }
            return true
        }
        guard wert != "Unsortiert", wert != ziel,
              store.documentCategories.contains(wert) else { return false }
        verschiebeGruppe(wert, vorGruppe: ziel)
        return true
    }

    /// Gruppe per Drag & Drop vor eine andere setzen — „Unsortiert" bleibt fest vorn.
    private func verschiebeGruppe(_ name: String, vorGruppe ziel: String) {
        var rest = store.documentCategories.filter { $0 != "Unsortiert" }
        guard let von = rest.firstIndex(of: name) else { return }
        rest.remove(at: von)
        let einfuegeIndex = ziel == "Unsortiert" ? 0 : (rest.firstIndex(of: ziel) ?? rest.count)
        rest.insert(name, at: einfuegeIndex)
        let hatUnsortiert = store.documentCategories.contains("Unsortiert")
        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
            store.documentCategories = (hatUnsortiert ? ["Unsortiert"] : []) + rest
        }
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }

    /// Gruppe in der Reihenfolge verschieben — „Unsortiert" bleibt fest vorn.
    private func verschiebeGruppe(_ name: String, nachOben: Bool) {
        var rest = store.documentCategories.filter { $0 != "Unsortiert" }
        guard let i = rest.firstIndex(of: name) else { return }
        let j = nachOben ? i - 1 : i + 1
        guard rest.indices.contains(j) else { return }
        rest.swapAt(i, j)
        let hatUnsortiert = store.documentCategories.contains("Unsortiert")
        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
            store.documentCategories = (hatUnsortiert ? ["Unsortiert"] : []) + rest
        }
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }

    /// Dokument in eine andere Gruppe verschieben (Untergruppe wird geleert).
    private func verschiebeDokument(_ doc: DocumentEntry, nach ziel: String) {
        guard let i = store.documents.firstIndex(where: { $0.id == doc.id }) else { return }
        store.documents[i].category = ziel
        store.documents[i].subcategory = ""
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }

    private var totalEntryCount: Int {
        store.vaultItems.count + store.documents.count + store.notes.count + store.lists.count
    }

    /// Gemessene Breite der Seite (statt des veralteten UIScreen.main —
    /// auf dem Mac ist das Fenster ohnehin nicht der Bildschirm).
    @State private var seitenBreite: CGFloat = 393

    /// Drei Favoriten-Karten passen nebeneinander auf den Schirm
    /// (20+20 Außenrand, 2 × 8 Abstand — der Rest geteilt durch drei).
    private var favoritenKartenBreite: CGFloat {
        let breite = min(seitenBreite, homeContentMaxWidth)
        return max(96, (breite - 56) / 3)
    }

    var body: some View {
        VStack(spacing: 0) {
            // Der feste Kopfbereich hält dieselbe Maximalbreite wie der
            // Strom darunter — auf iPad und Mac sitzt so alles auf einer Achse.
            VStack(spacing: 0) {
            // ── Kopf: Marke + Space-Zeile + QR-Scan ──
            HStack(alignment: .center, spacing: 12) {
                Button {
                    logoTapCount += 1
                    if logoTapCount >= 5 {
                        logoTapCount = 0
                        UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
                        showSpiderGame = true
                    }
                } label: {
                    ArcaGlassIcon(size: 40)
                }
                .buttonStyle(.plain)

                VStack(alignment: .leading, spacing: 1) {
                    Text("Arca")
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                    Text(totalEntryCount == 1 ? "Dein Space · 1 Eintrag" : "Dein Space · \(totalEntryCount) Einträge")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                }

                Spacer()

                // Dokumente erfassen: öffnet das Quellen-Blatt mit allen
                // Möglichkeiten (Scan · PDF · Fotos/Videos · Text)
                Button {
                    store.pendingNewEntry = .documents
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
                        selectedSection = .documents
                    }
                } label: {
                    Image(systemName: "doc.badge.plus")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.orange)
                        .frame(width: 36, height: 36)
                        .glassEffect(.regular, in: Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Dokument erfassen")

                // Passwort hinzufügen: Tresor öffnet direkt den neuen Eintrag
                Button {
                    store.pendingNewEntry = .vault
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
                        selectedSection = .vault
                    }
                } label: {
                    Image(systemName: "key.fill")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.blue)
                        .frame(width: 36, height: 36)
                        .glassEffect(.regular, in: Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Passwort hinzufügen")

                Button { showQRScanner = true } label: {
                    Image(systemName: "qrcode.viewfinder")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(.primary)
                        .frame(width: 36, height: 36)
                        .glassEffect(.regular, in: Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("QR-Code scannen")
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)
            .padding(.bottom, 10)

            // ── Bühne: großer Gruß, darunter der Kalender — beim Suchen
            //    klappen beide weg und machen den Ergebnissen Platz ──
            if !isSearching {
                ArcaHeroCard(name: userName) {
                    store.pendingQuickCapture = true
                } onDictate: {
                    store.quickCaptureAutoRecord = true
                    store.pendingQuickCapture = true
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 10)
                .transition(.opacity.combined(with: .move(edge: .top)))

                HomeCalendarCard()
                    .padding(.horizontal, 20)
                    .padding(.bottom, 10)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }

            // ── Danach die Suche: „Alles durchsuchen" ──
            HomeSearchBar(text: $searchText, focused: $isSearchFocused)
                .padding(.horizontal, 20)
                .padding(.bottom, 12)
            }
            .frame(maxWidth: homeContentMaxWidth)
            .frame(maxWidth: .infinity)

            if isSearching {
                ScrollView {
                    SearchResultsView(
                        query: searchText,
                        store: store,
                        onSelectSection: { section in
                            searchText = ""
                            isSearchFocused = false
                            selectedSection = section
                        },
                        onPreviewDocument: { url in
                            quickAccessPreviewURL = url
                        }
                    )
                    .padding(.horizontal, 20)
                    .padding(.bottom, 16)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .scrollDismissesKeyboard(.interactively)
            } else {
                ScrollViewReader { leseProxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {

                    // ── Backup-Erinnerung: dezent, aber unübersehbar ──
                    if backupErinnerungFaellig {
                        HStack(spacing: 10) {
                            Image(systemName: "shield.lefthalf.filled.badge.checkmark")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundStyle(ArcaWarm.terrakotta)
                            VStack(alignment: .leading, spacing: 1) {
                                Text(backupErinnerungText)
                                    .font(.system(size: 13, weight: .semibold))
                                Text("Ein verschlüsseltes Backup dauert eine Minute.")
                                    .font(.system(size: 11))
                                    .foregroundStyle(.secondary)
                            }
                            Spacer(minLength: 8)
                            Button {
                                store.pendingSettingsAktion = "export"
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
                                    selectedSection = .settings
                                }
                            } label: {
                                Text("Sichern")
                                    .font(.system(size: 13, weight: .bold))
                                    .foregroundStyle(.white)
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 7)
                                    .background(ArcaWarm.terrakotta, in: Capsule())
                            }
                            .buttonStyle(.plain)
                            Button {
                                UserDefaults.standard.set(
                                    Date().addingTimeInterval(7 * 86400), forKey: "arcaBackupSnooze")
                                withAnimation { backupSnoozeSignal += 1 }
                            } label: {
                                Image(systemName: "xmark")
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundStyle(.secondary)
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(12)
                        .glassEffect(.regular.tint(ArcaWarm.terrakotta.opacity(0.08)),
                                     in: RoundedRectangle(cornerRadius: 14))
                        .padding(.horizontal, 20)
                        .transition(.opacity.combined(with: .move(edge: .top)))
                    }

                    // ── Favoriten: alle Typen gemischt, festgepinnte zuerst ──
                    VStack(alignment: .leading, spacing: 10) {
                        ArcaSectionTitle(title: "Favoriten", icon: "star")
                            .padding(.horizontal, 20)
                        if store.favoriteItems.isEmpty {
                            // Leerzustand: zeigen, dass es die Reihe gibt — und wie man sie füllt
                            HStack(spacing: 10) {
                                Image(systemName: "star")
                                    .font(.system(size: 15, weight: .semibold))
                                    .foregroundStyle(ArcaWarm.terrakotta)
                                Text("Halte einen Eintrag gedrückt und wähle „Zu Favoriten“ — er erscheint dann hier.")
                                    .font(.system(size: 12))
                                    .foregroundStyle(.secondary)
                            }
                            .padding(12)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 14))
                            .padding(.horizontal, 20)
                        } else {
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 8) {
                                    ForEach(store.favoriteItems) { fav in
                                        let doc = fav.kind == .document
                                            ? store.documents.first(where: { $0.id == fav.id })
                                            : nil
                                        HomeFavoriteCard(
                                            item: fav,
                                            previewURL: doc.map { store.documentURL(for: $0.filename) },
                                            docType: doc?.type ?? .pdf,
                                            breite: favoritenKartenBreite
                                        ) {
                                            openFavorite(fav)
                                        } onTogglePin: {
                                            store.toggleFavoritePin(kind: fav.kind, id: fav.id)
                                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                        } onRemove: {
                                            store.toggleFavorite(kind: fav.kind, id: fav.id)
                                        }
                                    }
                                }
                                .padding(.horizontal, 20)
                                // Luft nach oben (fest-Plakette) und unten,
                                // damit die Scroll-Kante das Glas nicht anschneidet
                                .padding(.top, 10)
                                .padding(.bottom, 10)
                            }
                        }
                    }
                    .transition(.scale.combined(with: .opacity))
                    .id("seitenAnfang")


                    // ── Der Strom: alle Einträge gemischt, Filter statt Räume ──
                    VStack(alignment: .leading, spacing: 10) {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 6) {
                                ForEach(HomeStreamFilter.allCases, id: \.self) { filter in
                                    Button {
                                        withAnimation(.easeInOut(duration: 0.2)) {
                                            store.homeStreamFilter = filter
                                            streamLimit = 25
                                        }
                                    } label: {
                                        // Liquid-Glass-Blasen (iOS 27): gewählt = dunkel gefüllt,
                                        // die übrigen schweben als Glas über dem Warmweiß
                                        if streamFilter == filter {
                                            Text(filter.label)
                                                .font(.system(size: 13, weight: .semibold))
                                                .foregroundStyle(Color(.systemBackground))
                                                .padding(.horizontal, 13)
                                                .padding(.vertical, 7)
                                                .background(Capsule().fill(Color.primary))
                                        } else {
                                            Text(filter.label)
                                                .font(.system(size: 13))
                                                .foregroundStyle(.primary)
                                                .padding(.horizontal, 13)
                                                .padding(.vertical, 7)
                                                .glassEffect(.regular, in: Capsule())
                                        }
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            .padding(.horizontal, 20)
                        }

                        if streamFilter == .dokumente {
                            // Dokumente als Gruppen — Einzeldateien wohnen darin
                            VStack(spacing: 8) {
                                if dokumentGruppen.isEmpty {
                                    Text("Noch keine Dokumente — oben rechts wartet das Dokument-Plus.")
                                        .font(.system(size: 13))
                                        .foregroundStyle(.secondary)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .padding(.vertical, 8)
                                } else {
                                    // Neue Gruppe anlegen · Reihenfolge sortieren
                                    HStack(spacing: 8) {
                                        Button {
                                            docFuerNeueGruppe = nil
                                            neueGruppeName = ""
                                            showNeueGruppe = true
                                        } label: {
                                            HStack(spacing: 8) {
                                                Image(systemName: "folder.badge.plus")
                                                    .font(.system(size: 14, weight: .semibold))
                                                Text("Neue Gruppe")
                                                    .font(.system(size: 13, weight: .semibold))
                                            }
                                            .foregroundStyle(ArcaWarm.terrakotta)
                                            .frame(maxWidth: .infinity)
                                            .padding(.vertical, 10)
                                            .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 12))
                                        }
                                        .buttonStyle(.plain)

                                        Button {
                                            withAnimation(.easeInOut(duration: 0.2)) {
                                                sortiereGruppen.toggle()
                                            }
                                        } label: {
                                            HStack(spacing: 6) {
                                                Image(systemName: sortiereGruppen ? "checkmark" : "arrow.up.arrow.down")
                                                    .font(.system(size: 13, weight: .semibold))
                                                Text(sortiereGruppen ? "Fertig" : "Sortieren")
                                                    .font(.system(size: 13, weight: .semibold))
                                            }
                                            .foregroundStyle(sortiereGruppen ? .white : ArcaWarm.terrakotta)
                                            .padding(.horizontal, 14)
                                            .padding(.vertical, 10)
                                            .background {
                                                if sortiereGruppen {
                                                    Capsule().fill(ArcaWarm.terrakotta)
                                                }
                                            }
                                            .glassEffect(.regular, in: Capsule())
                                        }
                                        .buttonStyle(.plain)
                                    }

                                    if sortiereGruppen {
                                        // Sortier-Modus: echte Ziehgriffe (List + onMove) —
                                        // funktioniert per Klick-und-Ziehen auf allen Geräten
                                        let sortierbar = dokumentGruppen.map(\.name).filter { $0 != "Unsortiert" }
                                        List {
                                            ForEach(sortierbar, id: \.self) { name in
                                                HStack(spacing: 10) {
                                                    Image(systemName: name == "Unsortiert" ? "tray.fill" : categoryIcon(name))
                                                        .font(.system(size: 13, weight: .semibold))
                                                        .foregroundStyle(categoryColor(name, overrides: store.categoryColors).accent)
                                                    Text(name)
                                                        .font(.system(size: 14, weight: .medium))
                                                }
                                                .listRowBackground(categoryColor(name, overrides: store.categoryColors).bg.opacity(0.5))
                                            }
                                            .onMove { von, nach in
                                                var rest = sortierbar
                                                rest.move(fromOffsets: von, toOffset: nach)
                                                let hatUnsortiert = store.documentCategories.contains("Unsortiert")
                                                store.documentCategories = (hatUnsortiert ? ["Unsortiert"] : []) + rest
                                                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                            }
                                        }
                                        .listStyle(.insetGrouped)
                                        .scrollContentBackground(.hidden)
                                        .scrollDisabled(true)
                                        .frame(height: CGFloat(sortierbar.count) * 52 + 40)
                                        .environment(\.editMode, .constant(.active))
                                        .padding(.horizontal, -20)
                                    } else {
                                    ForEach(dokumentGruppen, id: \.name) { gruppe in
                                        let farben = categoryColor(gruppe.name, overrides: store.categoryColors)
                                        VStack(spacing: 6) {
                                            ArcaFolderQuickCard(
                                                name: gruppe.name,
                                                icon: gruppe.name == "Unsortiert" ? "tray.fill" : categoryIcon(gruppe.name),
                                                tint: farben.accent,
                                                bg: farben.bg,
                                                count: gruppe.anzahl,
                                                action: {
                                                    withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                                                        if expandedFolders.contains(gruppe.name) {
                                                            expandedFolders.remove(gruppe.name)
                                                        } else {
                                                            expandedFolders.insert(gruppe.name)
                                                        }
                                                    }
                                                },
                                                isExpanded: expandedFolders.contains(gruppe.name),
                                                onOpen: { openDocuments(category: gruppe.name) }
                                            )
                                            .contentShape(Rectangle())
                                            // Ziehen: Gruppe umsortieren („Unsortiert" bleibt fest) —
                                            // und Dokumente lassen sich auf Gruppen fallen lassen
                                            .wennDraggable(gruppe.name != "Unsortiert", gruppe.name)
                                            .dropDestination(for: String.self) { eingeworfen, _ in
                                                verarbeiteAblage(eingeworfen, aufGruppe: gruppe.name)
                                            }
                                            // Gedrückt halten: Farbe, Reihenfolge, Name, Löschen —
                                            // alles synct über iCloud auf alle Geräte
                                            .contextMenu {
                                                ArcaMenue.farbe(aktuell: store.categoryColors[gruppe.name]) { idx in
                                                    store.categoryColors[gruppe.name] = idx
                                                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                                }
                                                if gruppe.name != "Unsortiert" {
                                                    ArcaMenue.umbenennen {
                                                        gruppeUmbenennenText = gruppe.name
                                                        gruppeZumUmbenennen = gruppe.name
                                                    }
                                                    ArcaMenue.loeschen("Gruppe löschen") {
                                                        gruppeZumLoeschen = gruppe.name
                                                    }
                                                }
                                            }
                                            if expandedFolders.contains(gruppe.name) {
                                                folderDocumentRows(gruppe.name)
                                                    .transition(.opacity.combined(with: .move(edge: .top)))
                                            }
                                        }
                                    }
                                    }
                                }
                            }
                            .padding(.horizontal, 20)
                        } else if streamItems.isEmpty {
                            Text("Noch nichts hier — wirf Arca eine Blitzidee zu.")
                                .font(.system(size: 13))
                                .foregroundStyle(.secondary)
                                .padding(.horizontal, 20)
                                .padding(.vertical, 8)
                        } else {
                            LazyVStack(spacing: 8) {
                                ForEach(streamItems.prefix(streamLimit)) { item in
                                    let istFav = istFavorit(item)
                                    HomeStreamRow(item: item,
                                                  expanded: item.kind == .list && expandedLists.contains(item.id)) {
                                        if item.kind == .list {
                                            // Tasks klappen auf und lassen sich direkt abhaken
                                            withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                                                if expandedLists.contains(item.id) {
                                                    expandedLists.remove(item.id)
                                                } else {
                                                    expandedLists.insert(item.id)
                                                }
                                            }
                                        } else {
                                            openFavorite(item)
                                        }
                                    }
                                    .contentShape(Rectangle())
                                    // Gedrückt halten → Favorit, direkt im Strom
                                    .contextMenu {
                                        ArcaMenue.favorit(ist: istFav) {
                                            store.toggleFavorite(kind: item.kind, id: item.id)
                                            UINotificationFeedbackGenerator().notificationOccurred(.success)
                                        }
                                        if istFav {
                                            ArcaMenue.fest {
                                                store.toggleFavoritePin(kind: item.kind, id: item.id)
                                                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                            }
                                        }
                                        Divider()
                                        ArcaMenue.umbenennen {
                                            streamRenameText = item.title
                                            streamRenameItem = item
                                        }
                                        ArcaMenue.farbe(aktuell: streamFarbe(item)) { idx in
                                            setzeStreamFarbe(item, idx)
                                        }
                                        if item.kind == .list {
                                            Button {
                                                neuerPunktText = ""
                                                punktFuerListe = item.id
                                            } label: {
                                                Label("Punkt hinzufügen", systemImage: "plus.circle")
                                            }
                                        }
                                        if item.kind == .note {
                                            Menu {
                                                Button { wandleNotizInAufgaben(item) } label: {
                                                    Label("Aufgabenliste", systemImage: "checkmark.square")
                                                }
                                                Button { wandleNotizInPasswort(item) } label: {
                                                    Label("Passwort-Eintrag", systemImage: "key.fill")
                                                }
                                                if store.notes.first(where: { $0.id == item.id })?.isQuickIdea == true {
                                                    Button { macheZurFestenNotiz(item) } label: {
                                                        Label("Feste Notiz", systemImage: "note.text")
                                                    }
                                                }
                                            } label: {
                                                Label("Umwandeln in …", systemImage: "arrow.triangle.2.circlepath")
                                            }
                                        }
                                        ArcaMenue.loeschen {
                                            if item.kind == .vault {
                                                vaultZumLoeschen = item
                                            } else {
                                                loescheStreamEintrag(item)
                                            }
                                        }
                                    }
                                    if item.kind == .list, expandedLists.contains(item.id),
                                       let liste = store.lists.first(where: { $0.id == item.id }) {
                                        listeAufgeklappt(liste)
                                            .transition(.opacity.combined(with: .move(edge: .top)))
                                    }
                                }
                                if streamItems.count > streamLimit {
                                    Button {
                                        withAnimation { streamLimit += 25 }
                                    } label: {
                                        Text("Mehr anzeigen (\(streamItems.count - streamLimit))")
                                            .font(.system(size: 13, weight: .semibold))
                                            .foregroundStyle(.blue)
                                            .padding(.vertical, 6)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            .padding(.horizontal, 20)
                        }
                    }

                    Spacer().frame(height: 24)
                    }
                    .frame(maxWidth: homeContentMaxWidth)
                    .frame(maxWidth: .infinity)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .scrollDismissesKeyboard(.interactively)
                // Space-Tab erneut angetippt → sanft nach oben
                .onChange(of: store.homeSprungNachOben) { _, _ in
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
                        leseProxy.scrollTo("seitenAnfang", anchor: .top)
                    }
                }
                }
            }

        }
        .background(ArcaWarm.hintergrund)
        // Seitenbreite messen (Ersatz für UIScreen.main; Mac-Fenster tauglich)
        .background(
            GeometryReader { geo in
                Color.clear
                    .onAppear { seitenBreite = geo.size.width }
                    .onChange(of: geo.size.width) { _, neu in seitenBreite = neu }
            }
        )
        .sheet(isPresented: $showQRScanner) {
            QRScannerSheet()
                .environmentObject(store)
        }
        .fullScreenCover(isPresented: $showSpiderGame) {
            SpiderGameView()
        }
        .sheet(item: $quickAccessNote) { note in
            NoteDetailView(note: note)
                .environmentObject(store)
        }
        .quickLookPreview($quickAccessPreviewURL)
        // Einmalige Namensfrage für die Begrüßung (iOS gibt den
        // Gerätenamen aus Datenschutzgründen nicht mehr her)
        .onAppear {
            if userName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !userNameAsked {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { showNamePrompt = true }
            }
        }
        .alert("Wie dürfen wir dich begrüßen?", isPresented: $showNamePrompt) {
            TextField("Dein Vorname", text: $namePromptInput)
                .textInputAutocapitalization(.words)
            Button("Speichern") {
                userName = namePromptInput.trimmingCharacters(in: .whitespacesAndNewlines)
                userNameAsked = true
            }
            Button("Später", role: .cancel) {
                userNameAsked = true
            }
        } message: {
            Text("Dein Vorname erscheint in der Begrüßung — du kannst ihn jederzeit unter „Mehr“ ändern.")
        }
        // Notiz/Aufgabenliste/Passwort umbenennen — direkt vom Start
        .alert("Umbenennen", isPresented: Binding(
            get: { streamRenameItem != nil },
            set: { if !$0 { streamRenameItem = nil } }
        )) {
            TextField("Titel", text: $streamRenameText)
            Button("Sichern") { benenneStreamEintragUm() }
            Button("Abbrechen", role: .cancel) { streamRenameItem = nil }
        }
        // Passwort löschen nur mit Rückfrage
        .alert("Passwort löschen?", isPresented: Binding(
            get: { vaultZumLoeschen != nil },
            set: { if !$0 { vaultZumLoeschen = nil } }
        )) {
            Button("Löschen", role: .destructive) {
                if let item = vaultZumLoeschen { loescheStreamEintrag(item) }
                vaultZumLoeschen = nil
            }
            Button("Abbrechen", role: .cancel) { vaultZumLoeschen = nil }
        } message: {
            Text("Der Eintrag wird endgültig aus dem Tresor entfernt.")
        }
        // Neuen Punkt in eine Aufgabenliste legen
        .alert("Neuer Punkt", isPresented: Binding(
            get: { punktFuerListe != nil },
            set: { if !$0 { punktFuerListe = nil } }
        )) {
            TextField("Aufgabe", text: $neuerPunktText)
            Button("Hinzufügen") {
                if let id = punktFuerListe,
                   let i = store.lists.firstIndex(where: { $0.id == id }) {
                    let text = neuerPunktText.trimmingCharacters(in: .whitespacesAndNewlines)
                    if !text.isEmpty {
                        store.lists[i].items.append(ChecklistItem(text: text))
                        withAnimation { _ = expandedLists.insert(id) }
                    }
                }
                punktFuerListe = nil
            }
            Button("Abbrechen", role: .cancel) { punktFuerListe = nil }
        }
        // Gruppe umbenennen — direkt vom Start
        .alert("Gruppe umbenennen", isPresented: Binding(
            get: { gruppeZumUmbenennen != nil },
            set: { if !$0 { gruppeZumUmbenennen = nil } }
        )) {
            TextField("Name", text: $gruppeUmbenennenText)
            Button("Sichern") {
                if let alt = gruppeZumUmbenennen {
                    store.renameCategory(from: alt, to: gruppeUmbenennenText)
                }
                gruppeZumUmbenennen = nil
            }
            Button("Abbrechen", role: .cancel) { gruppeZumUmbenennen = nil }
        }
        // Gruppe löschen — mit Rückfrage, Dokumente wandern nach Unsortiert
        .alert("Gruppe löschen?", isPresented: Binding(
            get: { gruppeZumLoeschen != nil },
            set: { if !$0 { gruppeZumLoeschen = nil } }
        )) {
            Button("Löschen", role: .destructive) {
                if let name = gruppeZumLoeschen {
                    withAnimation { store.deleteCategory(name) }
                }
                gruppeZumLoeschen = nil
            }
            Button("Abbrechen", role: .cancel) { gruppeZumLoeschen = nil }
        } message: {
            Text("Die Dokumente darin gehen nicht verloren — sie wandern nach „Unsortiert“.")
        }
        // Dokument umbenennen — direkt vom Start
        .alert("Dokument umbenennen", isPresented: Binding(
            get: { homeRenameDoc != nil },
            set: { if !$0 { homeRenameDoc = nil } }
        )) {
            TextField("Titel", text: $homeRenameText)
            Button("Sichern") {
                if let doc = homeRenameDoc,
                   let i = store.documents.firstIndex(where: { $0.id == doc.id }) {
                    let neu = homeRenameText.trimmingCharacters(in: .whitespacesAndNewlines)
                    if !neu.isEmpty { store.documents[i].title = neu }
                }
                homeRenameDoc = nil
            }
            Button("Abbrechen", role: .cancel) { homeRenameDoc = nil }
        }
        // Neue Gruppe anlegen (und optional das Dokument gleich hineinlegen)
        .alert("Neue Gruppe", isPresented: $showNeueGruppe) {
            TextField("Name der Gruppe", text: $neueGruppeName)
            Button("Erstellen") {
                let name = neueGruppeName.trimmingCharacters(in: .whitespacesAndNewlines)
                if !name.isEmpty {
                    if !store.documentCategories.contains(name) {
                        store.documentCategories.append(name)
                    }
                    if let doc = docFuerNeueGruppe {
                        verschiebeDokument(doc, nach: name)
                    }
                    withAnimation { _ = expandedFolders.insert(name) }
                }
                docFuerNeueGruppe = nil
            }
            Button("Abbrechen", role: .cancel) { docFuerNeueGruppe = nil }
        }
        // ⌘F vom Mac/iPad: Suchfeld fokussieren
        .onChange(of: store.sucheFokusSignal) { _, _ in
            isSearchFocused = true
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.75), value: store.favoriteItems.count)
        .animation(.easeInOut(duration: 0.2), value: isSearching)
    }
}

// MARK: - Home Search Bar

struct HomeSearchBar: View {
    @Binding var text: String
    var focused: FocusState<Bool>.Binding

    var body: some View {
        HStack(spacing: 7) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
                .font(.system(size: 13, weight: .semibold))
            TextField("Alles durchsuchen", text: $text)
                .font(.system(size: 14))
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .focused(focused)
            if !text.isEmpty {
                Button {
                    text = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                        .font(.system(size: 14))
                }
                .buttonStyle(.borderless)
                .transition(.scale.combined(with: .opacity))
            }
        }
        .padding(.horizontal, 13)
        .padding(.vertical, 10)
        .glassEffect(.regular, in: Capsule())
    }
}

// MARK: - Search Results

struct SearchResultsView: View {
    let query: String
    @ObservedObject var store: AppStore
    let onSelectSection: (ArcaSection) -> Void
    let onPreviewDocument: (URL) -> Void

    private var q: String { query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }

    private var matchingPasswords: [VaultEntry] {
        store.vaultItems.filter {
            $0.title.lowercased().contains(q) ||
            $0.username.lowercased().contains(q) ||
            $0.url.lowercased().contains(q)
        }.prefix(5).map { $0 }
    }

    private var matchingDocs: [DocumentEntry] {
        store.documents.filter {
            $0.title.lowercased().contains(q) ||
            $0.category.lowercased().contains(q)
        }.prefix(5).map { $0 }
    }

    private var matchingNotes: [NoteEntry] {
        store.notes.filter {
            $0.title.lowercased().contains(q) ||
            $0.text.lowercased().contains(q)
        }.prefix(5).map { $0 }
    }

    private var matchingLists: [ListEntry] {
        store.lists.filter { l in
            l.title.lowercased().contains(q) ||
            l.items.contains { $0.text.lowercased().contains(q) }
        }.prefix(5).map { $0 }
    }

    private var totalCount: Int {
        matchingPasswords.count + matchingDocs.count + matchingNotes.count + matchingLists.count
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            if totalCount == 0 {
                VStack(spacing: 12) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 36))
                        .foregroundStyle(.secondary)
                    Text("Keine Treffer für \"\(query)\"")
                        .font(.headline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 40)
            } else {
                Text("\(totalCount) Treffer")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 4)

                if !matchingPasswords.isEmpty {
                    SearchResultGroup(
                        title: "Passwörter",
                        icon: "key.fill",
                        color: NoteColor.for_(2).accent
                    ) {
                        ForEach(matchingPasswords) { item in
                            SearchResultRow(
                                title: item.title,
                                subtitle: item.username.isEmpty ? "Passwort" : item.username,
                                color: NoteColor.for_(item.colorTag).accent
                            ) { onSelectSection(.vault) }
                        }
                    }
                }

                if !matchingDocs.isEmpty {
                    SearchResultGroup(
                        title: "Dokumente",
                        icon: "doc.fill",
                        color: NoteColor.for_(5).accent
                    ) {
                        ForEach(matchingDocs) { doc in
                            SearchResultRow(
                                title: doc.title,
                                subtitle: "\(doc.category) · \(doc.type.rawValue)",
                                color: docTypeColor(doc.type)
                            ) {
                                onPreviewDocument(store.documentURL(for: doc.filename))
                            }
                        }
                    }
                }

                if !matchingNotes.isEmpty {
                    SearchResultGroup(
                        title: "Notizen",
                        icon: "note.text",
                        color: NoteColor.for_(4).accent
                    ) {
                        ForEach(matchingNotes) { note in
                            SearchResultRow(
                                title: note.title.isEmpty ? "Ohne Titel" : note.title,
                                subtitle: note.text.isEmpty ? "Leer" : String(note.text.prefix(60)),
                                color: NoteColor.for_(note.colorTag).accent
                            ) { onSelectSection(.notes) }
                        }
                    }
                }

                if !matchingLists.isEmpty {
                    SearchResultGroup(
                        title: "Aufgaben",
                        icon: "checklist",
                        color: NoteColor.for_(3).accent
                    ) {
                        ForEach(matchingLists) { list in
                            SearchResultRow(
                                title: list.title,
                                subtitle: list.items.isEmpty ? "Leer" : "\(list.items.count) Einträge",
                                color: NoteColor.for_(list.colorTag).accent
                            ) { onSelectSection(.lists) }
                        }
                    }
                }
            }
        }
    }
}

struct SearchResultGroup<Content: View>: View {
    let title: String
    let icon: String
    let color: Color
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(color)
                Text(title)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(color)
            }
            .padding(.horizontal, 4)
            VStack(spacing: 0) {
                content()
            }
            .background(Color(.secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }
}

struct SearchResultRow: View {
    let title: String
    let subtitle: String
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                RoundedRectangle(cornerRadius: 2)
                    .fill(color)
                    .frame(width: 3, height: 28)
                VStack(alignment: .leading, spacing: 1) {
                    Text(title)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                    Text(subtitle)
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.tertiary)
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 12)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Quick Access Tile

struct HomeFavoriteCard: View {
    let item: FavoriteItem
    // Dokumente zeigen eine echte Mini-Vorschau statt des Icons
    var previewURL: URL? = nil
    var docType: DocumentType = .pdf
    /// Kartenbreite — vom Start so berechnet, dass drei auf den Schirm passen
    var breite: CGFloat = 118
    let onTap: () -> Void
    let onTogglePin: () -> Void
    let onRemove: () -> Void

    private var icon: String {
        switch item.kind {
        case .document: return "doc.fill"
        case .note:     return "note.text"
        case .list:     return "checklist"
        case .vault:    return "lock.fill"
        }
    }

    private var tint: Color {
        switch item.kind {
        case .document: return .orange
        case .note:     return .purple
        case .list:     return .green
        case .vault:    return .blue
        }
    }

    var body: some View {
        Button(action: onTap) {
            // Sanft getönte Karten wie in der Skizze — die Typ-Farbe trägt
            // Hintergrund-Hauch, Icon und (bei „fest") Rand + Plakette
            VStack(alignment: .leading, spacing: 6) {
                if let previewURL {
                    DocThumbnail(url: previewURL, type: docType)
                } else {
                    Image(systemName: icon)
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(tint)
                }
                Spacer(minLength: 0)
                Text(item.title)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                Text(item.subtitle)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            .padding(12)
            .frame(width: breite, height: 118, alignment: .leading)
            // Ganz Glas, kein Rahmen — „fest" zeigt allein die Plakette
            .glassEffect(.regular.tint(tint.opacity(0.09)), in: RoundedRectangle(cornerRadius: 14))
            .overlay(alignment: .topTrailing) {
                if item.pinned {
                    // Glastropfen statt Farb-Plakette
                    HStack(spacing: 3) {
                        Image(systemName: "pin.fill")
                            .font(.system(size: 7, weight: .bold))
                        Text("fest")
                            .font(.system(size: 9, weight: .semibold))
                    }
                    .foregroundStyle(tint)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .glassEffect(.regular, in: Capsule())
                    .offset(x: 4, y: -8)
                }
            }
        }
        .buttonStyle(.plain)
        .contentShape(Rectangle())
        .contextMenu {
            ArcaMenue.fest(aktion: onTogglePin)
            Divider()
            ArcaMenue.favorit(ist: true, aktion: onRemove)
        }
    }
}

private extension View {
    /// draggable nur, wenn erlaubt (Unsortiert bleibt unverrückbar)
    @ViewBuilder
    func wennDraggable(_ aktiv: Bool, _ wert: String) -> some View {
        if aktiv { self.draggable(wert) } else { self }
    }
}

// MARK: - Hero („Was willst du dir merken?")

/// Die Bühne des Space: Begrüßung nach Tageszeit (mit Namen und einem
/// kleinen Anstoß), die Frage der App und der Blitz als Antwort.
/// Die Bögen dahinter sind das Arca-Motiv (die Arche).
struct ArcaHeroCard: View {
    let name: String
    let onCapture: () -> Void
    let onDictate: () -> Void

    private var basisGruss: String {
        let base: String
        switch Calendar.current.component(.hour, from: Date()) {
        case 5..<11:  base = "Guten Morgen"
        case 11..<18: base = "Guten Tag"
        default:      base = "Guten Abend"
        }
        let n = name.trimmingCharacters(in: .whitespacesAndNewlines)
        return n.isEmpty ? base : "\(base), \(n)"
    }

    private var anstoss: String {
        switch Calendar.current.component(.hour, from: Date()) {
        case 5..<11:  return "Neue Ideen? Das Plus wartet."
        case 11..<18: return "Was gibt's Neues? Das Plus wartet."
        default:      return "Noch ein Gedanke? Das Plus wartet."
        }
    }

    /// Sonne am Morgen, volle Sonne am Tag, Mond am Abend
    private var tagesSymbol: String {
        switch Calendar.current.component(.hour, from: Date()) {
        case 5..<11:  return "sun.horizon.fill"
        case 11..<18: return "sun.max.fill"
        default:      return "moon.stars.fill"
        }
    }

    var body: some View {
        // Die Bühne des Space: Tageszeit-Symbol, großer Gruß und die
        // vollen Arca-Bögen — das schönste Stück der Seite.
        VStack(alignment: .leading, spacing: 6) {
            Image(systemName: tagesSymbol)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(ArcaWarm.terrakotta)
                .symbolRenderingMode(.hierarchical)
            Text(basisGruss)
                .font(.system(size: 25, weight: .bold, design: .rounded))
                .foregroundStyle(.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(anstoss)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(ArcaWarm.terrakotta)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 18)
        .padding(.vertical, 20)
        .background(alignment: .trailing) {
            // Arca-Bögen (Regenbogen-Motiv): außen zart, innen kräftig
            ZStack {
                ForEach(0..<3, id: \.self) { ring in
                    Circle()
                        .trim(from: 0.5, to: 1.0)
                        .stroke(ArcaWarm.terrakotta.opacity(0.20 + Double(ring) * 0.30),
                                style: StrokeStyle(lineWidth: 13, lineCap: .round))
                        .frame(width: 150 - CGFloat(ring) * 46,
                               height: 150 - CGFloat(ring) * 46)
                }
            }
            .frame(width: 160, height: 160)
            .offset(x: 14, y: 40)
        }
        .glassEffect(.regular.tint(ArcaWarm.creme.opacity(0.55)), in: RoundedRectangle(cornerRadius: 22))
        .clipShape(RoundedRectangle(cornerRadius: 22))
    }
}

// MARK: - Der Strom (gemischte Einträge mit Filter-Chips)

enum HomeStreamFilter: CaseIterable {
    case dokumente, notizen, tasks, passwoerter

    var label: String {
        switch self {
        case .dokumente:   return "Dokumente"
        case .notizen:     return "Notizen"
        case .tasks:       return "Aufgaben"
        case .passwoerter: return "Passwörter"
        }
    }
}

struct HomeStreamRow: View {
    let item: FavoriteItem
    /// Tasklisten: aufgeklappt zeigt der Pfeil nach unten
    var expanded: Bool = false
    let onTap: () -> Void

    private var icon: String {
        switch item.kind {
        case .document: return "doc.fill"
        case .note:     return "note.text"
        case .list:     return "checklist"
        case .vault:    return "lock.fill"
        }
    }

    private var tint: Color {
        switch item.kind {
        case .document: return .orange
        case .note:     return .purple
        case .list:     return .green
        case .vault:    return .blue
        }
    }

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(tint)
                    .frame(width: 34, height: 34)
                    .background(tint.opacity(0.12), in: RoundedRectangle(cornerRadius: 9))

                VStack(alignment: .leading, spacing: 2) {
                    Text(item.title)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                    Text("\(item.subtitle) · \(item.date.formatted(.relative(presentation: .named)))")
                        .font(.system(size: 11))
                        .foregroundStyle(item.kind == .vault ? tint : .secondary)
                        .lineLimit(1)
                }

                Spacer(minLength: 0)

                // Der Tresor bleibt sichtbar verschlossen
                if item.kind == .vault {
                    Image(systemName: "eye.slash")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                } else {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.tertiary)
                        .rotationEffect(.degrees(item.kind == .list && expanded ? 90 : 0))
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .glassEffect(
                item.kind == .vault
                    ? .regular.tint(ArcaWarm.creme.opacity(0.65))
                    : .regular,
                in: RoundedRectangle(cornerRadius: 14)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Space (die vier Bereiche)

/// Der Space-Tab: die vier Bereiche als ruhige Karten — der Ort, an dem
/// man gezielt in ein Zimmer geht, während der Start alles mischt.
struct SpaceHubView: View {
    @EnvironmentObject var store: AppStore
    @Binding var selectedSection: ArcaSection

    private struct Bereich: Identifiable {
        let id: String
        let section: ArcaSection
        let title: String
        let subtitle: String
        let icon: String
        let tint: Color
        let count: Int
    }

    private var bereiche: [Bereich] {
        [
            Bereich(id: "documents", section: .documents, title: "Dokumente",
                    subtitle: "Pass, Tickets, Verträge", icon: "doc.fill", tint: .orange,
                    count: store.documents.count),
            Bereich(id: "notes", section: .notes, title: "Notizen",
                    subtitle: "Ideen, Texte, Blitzideen", icon: "note.text", tint: .purple,
                    count: store.notes.count),
            Bereich(id: "lists", section: .lists, title: "Aufgaben",
                    subtitle: "Aufgaben und Checklisten", icon: "checklist", tint: .green,
                    count: store.lists.count),
            Bereich(id: "vault", section: .vault, title: "Passwörter",
                    subtitle: "Verschlossen, mit Face ID", icon: "lock.fill", tint: .blue,
                    count: store.vaultItems.count),
        ]
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                Text("Space")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .padding(.top, 16)
                Text("Deine vier Bereiche — alles an seinem Platz.")
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
                    .padding(.bottom, 6)

                ForEach(bereiche) { bereich in
                    Button {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
                            selectedSection = bereich.section
                        }
                    } label: {
                        HStack(spacing: 14) {
                            Image(systemName: bereich.icon)
                                .font(.system(size: 17, weight: .semibold))
                                .foregroundStyle(bereich.tint)
                                .frame(width: 40, height: 40)
                                .background(ArcaWarm.creme, in: RoundedRectangle(cornerRadius: 11))
                            VStack(alignment: .leading, spacing: 2) {
                                Text(bereich.title)
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundStyle(.primary)
                                Text(bereich.subtitle)
                                    .font(.system(size: 12))
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            if bereich.count > 0 {
                                Text("\(bereich.count)")
                                    .font(.system(size: 13, weight: .medium, design: .rounded))
                                    .foregroundStyle(.secondary)
                            }
                            Image(systemName: "chevron.right")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(.tertiary)
                        }
                        .padding(14)
                        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 16))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 20)
            .frame(maxWidth: 700)
            .frame(maxWidth: .infinity)
        }
        .background(ArcaWarm.hintergrund)
    }
}

// MARK: - Playful Home Mark

/// Verspielte 4-Punkt-Konstellation als Ersatz fürs App-Icon im Header.
/// Jeder Punkt steht für eine Sektion (Passwörter, Dokumente, Tasks, Notizen).
/// Sanfte Atmungs-Animation mit Versatz pro Punkt — wirkt lebendig.
struct PlayfulHomeMark: View {
    @State private var breathe: Bool = false

    // Position + Farbe pro Punkt — wie ein kleines Vier-Blatt
    private let dots: [(color: Color, offset: CGSize, delay: Double)] = [
        (NoteColor.for_(2).accent, CGSize(width: -10, height: -10), 0.0),  // Blau (Passwörter) oben links
        (NoteColor.for_(5).accent, CGSize(width:  10, height: -10), 0.4),  // Pfirsich (Dokumente) oben rechts
        (NoteColor.for_(3).accent, CGSize(width: -10, height:  10), 0.8),  // Grün (Tasks) unten links
        (NoteColor.for_(4).accent, CGSize(width:  10, height:  10), 1.2),  // Lila (Notizen) unten rechts
    ]

    var body: some View {
        ZStack {
            // 4 farbige Punkte mit überlappendem Effekt
            ForEach(0..<dots.count, id: \.self) { idx in
                Circle()
                    .fill(dots[idx].color.opacity(0.85))
                    .frame(width: 24, height: 24)
                    .offset(dots[idx].offset)
                    .scaleEffect(breathe ? 1.1 : 0.92)
                    .animation(
                        .easeInOut(duration: 1.6)
                        .repeatForever(autoreverses: true)
                        .delay(dots[idx].delay),
                        value: breathe
                    )
            }
            // Kleiner Sparkle in der Mitte
            Image(systemName: "sparkle")
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(
                    LinearGradient(
                        colors: [.white, .white.opacity(0.6)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .shadow(color: .black.opacity(0.15), radius: 1)
                .rotationEffect(.degrees(breathe ? 15 : -15))
                .animation(
                    .easeInOut(duration: 2.4).repeatForever(autoreverses: true),
                    value: breathe
                )
        }
        .frame(width: 52, height: 52)
        .onAppear { breathe = true }
    }
}

// MARK: - Header Stat Pills

/// Vier kleine farbige Pillen mit der Anzahl pro Sektion.
/// Bei mehr als 99 Einträgen wird „99+" angezeigt (Apple-Konvention).
struct HeaderStatPills: View {
    let vault: Int
    let documents: Int
    let tasks: Int
    let notes: Int

    private func formatted(_ n: Int) -> String {
        n > 99 ? "99+" : "\(n)"
    }

    var body: some View {
        HStack(spacing: 6) {
            statItem(icon: "key.fill", value: vault, color: NoteColor.for_(2).accent)
            statItem(icon: "doc.fill", value: documents, color: NoteColor.for_(5).accent)
            statItem(icon: "checklist", value: tasks, color: NoteColor.for_(3).accent)
            statItem(icon: "note.text", value: notes, color: NoteColor.for_(4).accent)
        }
    }

    private func statItem(icon: String, value: Int, color: Color) -> some View {
        HStack(spacing: 3) {
            Image(systemName: icon)
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(color)
            Text(formatted(value))
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .foregroundStyle(Color.primary.opacity(0.55))
        }
    }
}

struct StatPill: View {
    let value: String
    let color: Color

    var body: some View {
        Text(value)
            .font(.system(size: 11, weight: .medium, design: .rounded))
            .foregroundStyle(Color.primary.opacity(0.4))
            .padding(.horizontal, 7)
            .padding(.vertical, 4)
            .frame(minWidth: 26)
            .background(Color.primary.opacity(0.06), in: Capsule())
    }
}

// MARK: - Geschützt Badge

struct ProtectedBadge: View {
    var body: some View {
        VStack(spacing: 1) {
            Image(systemName: "checkmark.shield.fill")
                .font(.system(size: 18))
                .foregroundStyle(.green)
            Text("Geschützt")
                .font(.system(size: 9, weight: .semibold))
                .foregroundStyle(.green)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(width: 56, height: 56)
        .background(Color.green.opacity(0.08), in: Circle())
        .overlay(
            Circle().stroke(Color.green.opacity(0.45), lineWidth: 1.5)
        )
    }
}

// MARK: - Section Label

struct HomeSectionLabel: View {
    let text: String
    init(_ text: String) { self.text = text }

    var body: some View {
        Text(text.uppercased())
            .font(.system(size: 10, weight: .semibold))
            .tracking(1.2)
            .foregroundStyle(Color.primary.opacity(0.4))
    }
}

// MARK: - Soft Home Tile

struct SoftHomeTile: View {
    let tile: HomeTileSpec
    let count: Int
    let action: () -> Void

    @State private var gradientShift = false

    // Vibrantere Gradient-Farben — je eine eigene Farbwelt pro Kachel
    private var gradientColors: [Color] {
        switch tile.id {
        case "vault":
            return [Color(red: 0.20, green: 0.42, blue: 0.95),
                    Color(red: 0.08, green: 0.22, blue: 0.72)]
        case "documents":
            return [Color(red: 0.95, green: 0.48, blue: 0.12),
                    Color(red: 0.78, green: 0.28, blue: 0.04)]
        case "lists":
            return [Color(red: 0.12, green: 0.72, blue: 0.42),
                    Color(red: 0.06, green: 0.50, blue: 0.28)]
        case "notes":
            return [Color(red: 0.58, green: 0.22, blue: 0.92),
                    Color(red: 0.40, green: 0.10, blue: 0.72)]
        default:
            return [Color.blue, Color.blue.opacity(0.7)]
        }
    }

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 0) {

                // Icon + Counter
                HStack(alignment: .top) {
                    Image(systemName: tile.icon)
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(width: 38, height: 38)
                        .background(.ultraThinMaterial.opacity(0.45),
                                    in: RoundedRectangle(cornerRadius: 11))
                        .overlay(
                            RoundedRectangle(cornerRadius: 11)
                                .stroke(.white.opacity(0.35), lineWidth: 1)
                        )
                    Spacer()
                    Text("\(count)")
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.85))
                        .padding(.top, 2)
                }
                .padding(.bottom, 14)

                // Titel
                Text(tile.title)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(.white)
                    .padding(.bottom, 3)

                // Subtitle
                Text(tile.subtitle.replacingOccurrences(of: "\n", with: " "))
                    .font(.system(size: 11.5))
                    .foregroundStyle(.white.opacity(0.72))
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)

                Spacer(minLength: 16)

                // Action-Pille
                HStack(spacing: 3) {
                    Image(systemName: "plus")
                        .font(.system(size: 10, weight: .semibold))
                    Text(tile.actionLabel)
                        .font(.system(size: 11, weight: .medium))
                        .lineLimit(1)
                        .minimumScaleFactor(0.85)
                    Spacer(minLength: 0)
                    Image(systemName: "arrow.right")
                        .font(.system(size: 9, weight: .medium))
                }
                .foregroundStyle(.white.opacity(0.88))
                .padding(.horizontal, 10)
                .padding(.vertical, 7)
                .frame(maxWidth: .infinity)
                .background(.white.opacity(0.18), in: Capsule())
            }
            .padding(14)
            .frame(maxWidth: .infinity, minHeight: 130, alignment: .topLeading)
            .background(
                ZStack {
                    // Haupt-Gradient mit animiertem Start-/Endpunkt
                    LinearGradient(
                        colors: gradientColors,
                        startPoint: gradientShift ? .leading : .topLeading,
                        endPoint:   gradientShift ? .bottomTrailing : .bottomLeading
                    )
                    .animation(
                        .easeInOut(duration: 4).repeatForever(autoreverses: true),
                        value: gradientShift
                    )
                    // Glasschimmer — obere Hälfte deutlich aufgehellt
                    LinearGradient(
                        colors: [.white.opacity(0.42), .white.opacity(0.08), .clear],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    // Radialer Glanzpunkt oben links
                    RadialGradient(
                        colors: [.white.opacity(0.38), .clear],
                        center: UnitPoint(x: 0.18, y: 0.08),
                        startRadius: 0,
                        endRadius: 55
                    )
                }
            )
            .clipShape(RoundedRectangle(cornerRadius: 20))
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(
                        LinearGradient(
                            colors: [.white.opacity(0.65), .white.opacity(0.10)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1.5
                    )
            )
            .shadow(color: gradientColors[0].opacity(0.38), radius: 12, x: 0, y: 6)
        }
        .buttonStyle(TilePressStyle())
        .onAppear { gradientShift = true }
    }
}

// MARK: - QR Big Tile

struct QRBigTile: View {
    let action: () -> Void

    @Environment(\.colorScheme) private var colorScheme
    private var color: NoteColor { NoteColor.for_(1) }  // Rosa
    private var isDark: Bool { colorScheme == .dark }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: "qrcode")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(isDark ? .white : color.accent)
                    .frame(width: 40, height: 40)
                    .background(isDark ? Color.white.opacity(0.15) : color.bg.opacity(0.85),
                                in: RoundedRectangle(cornerRadius: 10))
                VStack(alignment: .leading, spacing: 2) {
                    Text("QR-Code")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(.primary)
                    Text("Scannen und direkt speichern")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(Color.primary.opacity(0.7))
                        .lineLimit(1)
                }
                Spacer()
                HStack(spacing: 5) {
                    Image(systemName: "qrcode.viewfinder")
                        .font(.system(size: 13, weight: .bold))
                    Text("Scannen")
                        .font(.system(size: 13, weight: .semibold))
                    Image(systemName: "chevron.right")
                        .font(.system(size: 9, weight: .bold))
                }
                .foregroundStyle(isDark ? .white : color.accent)
                .padding(.horizontal, 10)
                .padding(.vertical, 7)
                .background(isDark ? Color.white.opacity(0.15) : color.bg.opacity(0.7), in: Capsule())
            }
            .padding(12)
            .frame(maxWidth: .infinity)
            .background(color.bg.opacity(isDark ? 0.6 : 0.4))
            .clipShape(RoundedRectangle(cornerRadius: 18))
        }
        .buttonStyle(TilePressStyle())
    }
}

// MARK: - Activity Row

struct ActivityRow: View {
    let item: HomeActivityItem
    let action: () -> Void

    private var color: NoteColor { NoteColor.for_(item.kind.colorTag) }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: item.kind.icon)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(color.accent)
                    .frame(width: 32, height: 32)
                    .background(color.bg.opacity(0.85), in: RoundedRectangle(cornerRadius: 9))
                VStack(alignment: .leading, spacing: 1) {
                    Text(item.title)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                    Text(item.kind.label)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(Color.primary.opacity(0.7))
                }
                Spacer()
                Text(formatActivityDate(item.date))
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(Color.primary.opacity(0.7))
                Image(systemName: "chevron.right")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(Color.primary.opacity(0.5))
            }
            .padding(.vertical, 7)
            .padding(.horizontal, 12)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Status Banner

struct CloudSyncBanner: View {
    var body: some View {
        HStack(spacing: 10) {
            ProgressView()
                .controlSize(.small)
            Text("Daten werden aus iCloud geladen…")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.primary)
            Spacer()
            Image(systemName: "icloud.and.arrow.down")
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(Color.accentColor)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14))
    }
}

struct StatusBanner: View {
    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "checkmark.shield")
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(Color.primary.opacity(0.45))
            Text("Ende-zu-Ende verschlüsselt")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(Color.primary.opacity(0.4))
            Spacer()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(Color.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: 12))
    }
}

struct TileDropDelegate: DropDelegate {
    let targetID: String
    @Binding var draggingID: String?
    @Binding var tileOrderRaw: String
    let allIDs: [String]

    func performDrop(info: DropInfo) -> Bool {
        draggingID = nil
        return true
    }

    func dropEntered(info: DropInfo) {
        guard let from = draggingID, from != targetID else { return }
        var ids = allIDs
        guard let fromIdx = ids.firstIndex(of: from),
              let toIdx   = ids.firstIndex(of: targetID) else { return }
        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
            ids.move(fromOffsets: IndexSet(integer: fromIdx), toOffset: toIdx > fromIdx ? toIdx + 1 : toIdx)
            tileOrderRaw = ids.joined(separator: ",")
        }
    }

    func dropUpdated(info: DropInfo) -> DropProposal? {
        DropProposal(operation: .move)
    }
}

struct HomePill: View {
    let icon: String
    let text: String

    var body: some View {
        HStack(spacing: 5) {
            Image(systemName: icon).font(.caption2)
            Text(text).font(.caption)
        }
        .foregroundStyle(.secondary)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Color(.secondarySystemBackground))
        .clipShape(Capsule())
    }
}

// MARK: - Subviews

struct HomeTile: View {
    let title: String
    let description: String
    let icon: String
    let color: Color
    var badge: Int = 0
    var editMode: Bool = false
    var isComingSoon: Bool = false
    let action: () -> Void
    @State private var blinkOpacity: Double = 1.0
    @State private var sparkleScale: CGFloat = 1.0

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 0) {
                // Icon + Badge
                HStack(alignment: .top) {
                    Image(systemName: icon)
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(width: 40, height: 40)
                        .background(.ultraThinMaterial.opacity(0.6))
                        .clipShape(RoundedRectangle(cornerRadius: 11))
                        .overlay(
                            RoundedRectangle(cornerRadius: 11)
                                .stroke(.white.opacity(0.3), lineWidth: 1)
                        )
                        .scaleEffect(isComingSoon ? sparkleScale : 1.0)
                    Spacer()
                    if badge > 0 {
                        Text("\(badge)")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(.white.opacity(0.25))
                            .clipShape(Capsule())
                    }
                }

                Spacer(minLength: 6)

                // Text
                Text(title)
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(.white)
                    .padding(.bottom, 2)
                Text(description)
                    .font(.system(size: 10))
                    .foregroundStyle(.white.opacity(0.82))
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(minHeight: 26, alignment: .topLeading)
            }
            .frame(maxWidth: .infinity, minHeight: 110)
            .padding(12)
            .background(
                ZStack {
                    if isComingSoon {
                        // Dezenter, animierter Hintergrund für „Bald da"
                        LinearGradient(
                            colors: [Color.gray.opacity(0.55), Color.gray.opacity(0.35)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    } else {
                        LinearGradient(
                            colors: [color, color.opacity(0.75)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    }
                    // Glasschimmer oben
                    LinearGradient(
                        colors: [.white.opacity(0.28), .clear],
                        startPoint: .top,
                        endPoint: .center
                    )
                    // Glasschimmer links
                    LinearGradient(
                        colors: [.white.opacity(0.12), .clear],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                }
            )
            .clipShape(RoundedRectangle(cornerRadius: 18))
            .overlay(
                RoundedRectangle(cornerRadius: 18)
                    .stroke(editMode ? color : (isComingSoon ? .white.opacity(0.4) : .white.opacity(0.25)),
                            style: StrokeStyle(lineWidth: editMode ? 2.5 : 1, dash: isComingSoon ? [4, 3] : []))
                    .opacity(editMode ? blinkOpacity : 1.0)
            )
            .shadow(color: (isComingSoon ? Color.gray : color).opacity(0.4), radius: 11, x: 0, y: 5)
            .rotationEffect(editMode ? .degrees(-1.5) : .degrees(0))
            .animation(editMode ? .easeInOut(duration: 0.2).repeatForever(autoreverses: true) : .spring(response: 0.3), value: editMode)
        }
        .buttonStyle(TilePressStyle())
        .onAppear {
            withAnimation(.easeInOut(duration: 0.6).repeatForever(autoreverses: true)) {
                blinkOpacity = 0.3
            }
            if isComingSoon {
                withAnimation(.easeInOut(duration: 1.4).repeatForever(autoreverses: true)) {
                    sparkleScale = 1.12
                }
            }
        }
    }
}

struct TilePressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .animation(.spring(response: 0.25, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

struct FeatureRow: View {
    let icon: String
    let color: Color
    let title: String
    let subtitle: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(color)
                .frame(width: 38, height: 38)
                .background(color.opacity(0.13))
                .clipShape(RoundedRectangle(cornerRadius: 11))
            VStack(alignment: .leading, spacing: 1) {
                Text(title).font(.subheadline.bold())
                Text(subtitle).font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(10)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .shadow(color: .black.opacity(0.05), radius: 5, x: 0, y: 2)
    }
}

// MARK: - Vault

// MARK: - Quick-Templates für Passwörter

struct VaultTemplate: Identifiable {
    let id = UUID()
    let emoji: String
    let label: String
    let colorTag: Int

    static let all: [VaultTemplate] = [
        VaultTemplate(emoji: "🌐", label: "Webseite", colorTag: 2),  // Blau
        VaultTemplate(emoji: "📧", label: "E-Mail",   colorTag: 5),  // Pfirsich
        VaultTemplate(emoji: "🏦", label: "Bank",     colorTag: 3),  // Grün
        VaultTemplate(emoji: "📱", label: "App",      colorTag: 4),  // Lila
        VaultTemplate(emoji: "🛒", label: "Shop",     colorTag: 1),  // Rosa
        VaultTemplate(emoji: "🔑", label: "Sonstiges", colorTag: 0), // Gelb
    ]
}

struct VaultView: View {
    @EnvironmentObject var store: AppStore
    @State private var selectedItem: VaultEntry? = nil
    @State private var showNewEntry = false
    @State private var searchText = ""
    @State private var copiedItemID: UUID? = nil
    @State private var renamingItem: VaultEntry? = nil
    @State private var showSecurityAlert = false
    @State private var renameItemText = ""
    @AppStorage("vaultSortOption") private var sortOption: String = "newest"
    @AppStorage("vaultFilterColor") private var filterColor: Int = -1

    private var filteredItems: [VaultEntry] {
        var items = searchText.isEmpty ? store.vaultItems : store.vaultItems.filter {
            $0.title.localizedCaseInsensitiveContains(searchText) ||
            $0.username.localizedCaseInsensitiveContains(searchText)
        }
        if filterColor >= 0 {
            items = items.filter { $0.colorTag == filterColor }
        }
        switch sortOption {
        case "oldest":   items.sort { $0.dateCreated < $1.dateCreated }
        case "az":       items.sort { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
        case "color":    items.sort { $0.colorTag < $1.colorTag }
        case "weak":     items.sort { $0.password.count < $1.password.count }
        default:         items.sort { $0.dateCreated > $1.dateCreated }
        }
        items.sort { $0.isFavorite && !$1.isFavorite }
        return items
    }

    var body: some View {
        vaultBody
    }

    // Einspaltiges Layout — auf iPhone wie iPad (in der Detailspalte der Sidebar-SplitView).
    // Bewusst keine eigene Master-Detail-HStack mehr: die führte auf dem iPad zu einer
    // dritten, zu engen Spalte (Guideline 4 "crowded interface").
    private var vaultBody: some View {
        NavigationStack {
            VStack(spacing: 0) {
                AddTriggerButton(
                    label: "Neues Passwort",
                    subtitle: "Kategorie · Zugangsdaten · Passwort",
                    icon: "plus"
                ) { showNewEntry = true }
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .padding(.bottom, 4)
                vaultList
            }
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Image(systemName: "key.fill")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(.secondary)
                }
                ToolbarItem(placement: .navigationBarTrailing) { vaultTrailingToolbar }
            }
            .sheet(isPresented: $showNewEntry, onDismiss: {
                // Abgebrochen? Dann bleibt die Quell-Notiz unangetastet.
                store.vaultVorbefuellung = nil
                store.notizNachTresorUmwandlung = nil
            }) { vaultNewEntrySheet }
            // Erfassen vom Start: „Neu"-Blatt direkt öffnen
            .onAppear {
                if store.pendingNewEntry == .vault {
                    store.pendingNewEntry = nil
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { showNewEntry = true }
                }
            }
            .onChange(of: store.pendingNewEntry) { _, wert in
                // Plus gedrückt, während der Bereich schon offen ist
                if wert == .vault {
                    store.pendingNewEntry = nil
                    showNewEntry = true
                }
            }
            .sheet(item: $selectedItem) { item in VaultDetailView(item: item) }
        }
    }

    private var vaultTrailingToolbar: some View {
        HStack(spacing: 6) {
            let weakCount = store.vaultItems.filter { $0.password.count < 8 }.count
            let passwords = store.vaultItems.map { $0.password }
            let dupeCount = passwords.count - Set(passwords).count
            let total = weakCount + dupeCount
            if total > 0 {
                Button { showSecurityAlert = true } label: {
                    Label("\(total)", systemImage: "exclamationmark.shield.fill")
                        .font(.caption.bold())
                        .foregroundStyle(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.red)
                        .clipShape(Capsule())
                }
                .alert("Sicherheitshinweis", isPresented: $showSecurityAlert) {
                    Button("OK") {}
                } message: {
                    let weakCount = store.vaultItems.filter { $0.password.count < 8 }.count
                    let passwords = store.vaultItems.map { $0.password }
                    let dupeCount = passwords.count - Set(passwords).count
                    let lines = [
                        weakCount > 0 ? "• \(weakCount) schwache\(weakCount == 1 ? "s" : "") Passwort\(weakCount == 1 ? "" : "wörter") (kürzer als 8 Zeichen)" : nil,
                        dupeCount > 0 ? "• \(dupeCount) mehrfach verwendete\(dupeCount == 1 ? "s" : "") Passwort\(dupeCount == 1 ? "" : "wörter")" : nil
                    ].compactMap { $0 }
                    Text(lines.joined(separator: "\n"))
                }
            }
            sortFilterMenu
        }
    }

    @ViewBuilder
    private var vaultNewEntrySheet: some View {
        NewVaultEntrySheet(startTitel: store.vaultVorbefuellung ?? "") { title, username, password, url, hotline, color in
            store.addVaultEntry(title: title, username: username,
                               password: password, url: url,
                               sperrHotline: hotline, colorTag: color)
            // Blitzidee → Passwort: die Quell-Notiz ist jetzt einsortiert
            if let notizID = store.notizNachTresorUmwandlung {
                store.notes.removeAll { $0.id == notizID }
            }
            store.vaultVorbefuellung = nil
            store.notizNachTresorUmwandlung = nil
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            showNewEntry = false
        }
    }

    // MARK: Vault List

    private var vaultList: some View {
        List {
            if filteredItems.isEmpty {
                Text(store.vaultItems.isEmpty ? "Noch keine Einträge vorhanden." : "Keine Treffer.")
                    .foregroundStyle(.secondary)
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
            } else {
                ForEach(filteredItems) { item in
                    VaultRow(item: item, copiedItemID: $copiedItemID)
                        .contentShape(Rectangle())
                        .onTapGesture { selectedItem = item }
                        .listRowBackground(Color(.secondarySystemBackground))
                        .listRowSeparator(.visible)
                        .listRowSeparatorTint(Color.primary.opacity(0.06))
                        .listRowInsets(EdgeInsets(top: 0, leading: 16, bottom: 0, trailing: 12))
                        .contextMenu {
                            ArcaMenue.favorit(ist: item.isFavorite) {
                                if let idx = store.vaultItems.firstIndex(where: { $0.id == item.id }) {
                                    store.vaultItems[idx].isFavorite.toggle()
                                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                }
                            }
                            Divider()
                            ArcaMenue.umbenennen {
                                renameItemText = item.title
                                renamingItem = item
                            }
                            ArcaMenue.farbe(aktuell: item.colorTag) { idx in
                                if let i = store.vaultItems.firstIndex(where: { $0.id == item.id }) {
                                    store.vaultItems[i].colorTag = idx
                                }
                            }
                            ArcaMenue.loeschen {
                                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                                store.vaultItems.removeAll { $0.id == item.id }
                            }
                        }
                        .swipeActions(edge: .leading) {
                            Button {
                                if let idx = store.vaultItems.firstIndex(where: { $0.id == item.id }) {
                                    store.vaultItems[idx].isFavorite.toggle()
                                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                }
                            } label: {
                                Label(item.isFavorite ? "Aus Favoriten" : "Favorit",
                                      systemImage: item.isFavorite ? "star.slash" : "star.fill")
                            }
                            .tint(.orange)
                            Button {
                                renameItemText = item.title
                                renamingItem = item
                            } label: {
                                Label("Umbenennen", systemImage: "pencil")
                            }
                            .tint(.blue)
                        }
                }
                .onDelete { indexSet in
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                    let toDelete = indexSet.map { filteredItems[$0] }
                    store.vaultItems.removeAll { item in toDelete.contains { $0.id == item.id } }
                }
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .searchable(text: $searchText, prompt: "Suchen…")
        .alert("Eintrag umbenennen", isPresented: Binding(
            get: { renamingItem != nil },
            set: { if !$0 { renamingItem = nil } }
        )) {
            TextField("Neuer Name", text: $renameItemText)
            Button("Speichern") {
                if let item = renamingItem {
                    let trimmed = renameItemText.trimmingCharacters(in: .whitespacesAndNewlines)
                    if !trimmed.isEmpty,
                       let idx = store.vaultItems.firstIndex(where: { $0.id == item.id }) {
                        store.vaultItems[idx].title = trimmed
                    }
                }
                renamingItem = nil
            }
            Button("Abbrechen", role: .cancel) { renamingItem = nil }
        }
    }

    // MARK: Sort & Filter Menu

    private var sortFilterMenu: some View {
        Menu {
            Picker("Sortierung", selection: $sortOption) {
                Label("Neueste zuerst", systemImage: "arrow.down").tag("newest")
                Label("Älteste zuerst", systemImage: "arrow.up").tag("oldest")
                Label("A–Z", systemImage: "textformat").tag("az")
                Label("Nach Farbe", systemImage: "paintpalette.fill").tag("color")
                Label("Schwache zuerst", systemImage: "exclamationmark.shield.fill").tag("weak")
            }
            Divider()
            Menu {
                Button {
                    filterColor = -1
                } label: {
                    Label("Alle Farben", systemImage: filterColor == -1 ? "checkmark" : "circle")
                }
                ForEach(0..<NoteColor.palette.count, id: \.self) { idx in
                    Button {
                        filterColor = idx
                    } label: {
                        Label(NoteColor.palette[idx].name,
                              systemImage: filterColor == idx ? "checkmark" : "circle.fill")
                    }
                }
            } label: {
                Label(filterColor == -1 ? "Filter: Alle" : "Filter: \(NoteColor.for_(filterColor).name)",
                      systemImage: "line.3.horizontal.decrease.circle")
            }
        } label: {
            Image(systemName: filterColor == -1 ? "arrow.up.arrow.down.circle"
                                                : "line.3.horizontal.decrease.circle.fill")
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(filterColor == -1 ? Color.primary : NoteColor.for_(filterColor).accent)
        }
    }
}

// MARK: - New Vault Entry Sheet

struct NewVaultEntrySheet: View {
    let onSave: (String, String, String, String, String, Int) -> Void

    init(startTitel: String = "", onSave: @escaping (String, String, String, String, String, Int) -> Void) {
        self.onSave = onSave
        _title = State(initialValue: startTitel)
    }

    @Environment(\.dismiss) var dismiss
    @State private var title = ""
    @State private var sperrHotline = ""
    @State private var username = ""
    @State private var password = ""
    @State private var url = ""
    @State private var selectedColor = 2
    @State private var showPassword = false
    @State private var showGenerator = false
    @FocusState private var focusedField: VaultField?

    enum VaultField { case title, username, password, url }

    private var canSave: Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !password.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    private var color: NoteColor { NoteColor.for_(selectedColor) }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {

                    // Kategorie / Vorlage
                    VStack(alignment: .leading, spacing: 10) {
                        HomeSectionLabel("Kategorie")
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(VaultTemplate.all) { template in
                                    Button {
                                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                        withAnimation(.spring(response: 0.25)) {
                                            selectedColor = template.colorTag
                                            let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
                                            if !trimmed.hasPrefix(template.emoji) {
                                                title = trimmed.isEmpty ? "\(template.emoji) " : "\(template.emoji) \(trimmed)"
                                            }
                                        }
                                        focusedField = .title
                                    } label: {
                                        HStack(spacing: 5) {
                                            Text(template.emoji)
                                            Text(template.label)
                                                .font(.system(size: 13, weight: .medium))
                                        }
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 7)
                                        .background(NoteColor.for_(template.colorTag).bg.opacity(0.85))
                                        .foregroundStyle(.primary)
                                        .clipShape(Capsule())
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            .padding(.vertical, 2)
                        }
                    }

                    // Felder
                    VStack(spacing: 12) {
                        // Titel
                        VaultFieldRow(label: "Titel", placeholder: "z. B. Gmail, Netflix…") {
                            TextField("z. B. Gmail, Netflix…", text: $title)
                                .focused($focusedField, equals: .title)
                                .autocorrectionDisabled()
                        }

                        // Benutzername
                        VaultFieldRow(label: "Benutzername / E-Mail", placeholder: "") {
                            TextField("Benutzername oder E-Mail", text: $username)
                                .focused($focusedField, equals: .username)
                                .autocorrectionDisabled()
                                .textInputAutocapitalization(.never)
                        }

                        // Passwort
                        VaultFieldRow(label: "Passwort", placeholder: "") {
                            HStack(spacing: 10) {
                                Group {
                                    if showPassword {
                                        TextField("Passwort", text: $password)
                                    } else {
                                        SecureField("Passwort", text: $password)
                                    }
                                }
                                .focused($focusedField, equals: .password)
                                .autocorrectionDisabled()
                                .textInputAutocapitalization(.never)
                                .font(.system(.body, design: .monospaced))

                                Button {
                                    showPassword.toggle()
                                } label: {
                                    Image(systemName: showPassword ? "eye.slash" : "eye")
                                        .font(.system(size: 15))
                                        .foregroundStyle(.secondary)
                                }
                                .buttonStyle(.plain)

                                Button {
                                    showGenerator = true
                                } label: {
                                    Image(systemName: "wand.and.stars")
                                        .font(.system(size: 15))
                                        .foregroundStyle(color.accent)
                                }
                                .buttonStyle(.plain)
                            }
                        }

                        // Passwortstärke
                        if !password.isEmpty {
                            PasswordStrengthBar(password: password)
                                .padding(.horizontal, 2)
                                .transition(.opacity.combined(with: .move(edge: .top)))
                        }

                        // Website
                        VaultFieldRow(label: "Website (optional)", placeholder: "") {
                            TextField("https://…", text: $url)
                                .focused($focusedField, equals: .url)
                                .autocorrectionDisabled()
                                .textInputAutocapitalization(.never)
                                .keyboardType(.URL)
                        }

                        // Sperr-Hotline (Notfall-Bereich)
                        VaultFieldRow(label: "Sperr-Hotline (optional, für Karten)", placeholder: "") {
                            TextField("z.B. +41 44 123 45 67", text: $sperrHotline)
                                .keyboardType(.phonePad)
                        }
                    }

                    // Farbauswahl
                    VStack(alignment: .leading, spacing: 10) {
                        HomeSectionLabel("Farbe")
                        HStack(spacing: 12) {
                            ForEach(0..<NoteColor.palette.count, id: \.self) { idx in
                                Button {
                                    withAnimation(.spring(response: 0.25, dampingFraction: 0.7)) {
                                        selectedColor = idx
                                    }
                                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                } label: {
                                    Circle()
                                        .fill(NoteColor.palette[idx].accent)
                                        .frame(width: 26, height: 26)
                                        .overlay(
                                            Circle()
                                                .stroke(Color.primary.opacity(0.8), lineWidth: selectedColor == idx ? 2.5 : 0)
                                                .padding(2)
                                        )
                                        .scaleEffect(selectedColor == idx ? 1.15 : 1.0)
                                }
                                .buttonStyle(.plain)
                            }
                            Spacer()
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)
                .padding(.bottom, 40)
                .animation(.easeInOut(duration: 0.2), value: password.isEmpty)
            }
            .navigationTitle("Neues Passwort")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Abbrechen") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        onSave(title.trimmingCharacters(in: .whitespacesAndNewlines),
                               username.trimmingCharacters(in: .whitespacesAndNewlines),
                               password.trimmingCharacters(in: .whitespacesAndNewlines),
                               url.trimmingCharacters(in: .whitespacesAndNewlines),
                               sperrHotline.trimmingCharacters(in: .whitespacesAndNewlines),
                               selectedColor)
                    } label: {
                        Text("Sichern")
                            .fontWeight(.semibold)
                    }
                    .disabled(!canSave)
                }
            }
            .sheet(isPresented: $showGenerator) {
                PasswordGeneratorView { generated in
                    password = generated
                    showPassword = true
                }
            }
        }
    }
}

// Einheitliche Feld-Zeile
struct VaultFieldRow<Content: View>: View {
    let label: String
    let placeholder: String
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(Color.primary.opacity(0.45))
                .tracking(0.3)
            content()
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .background(Color(.secondarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }
}

// MARK: - VaultRow

struct VaultRow: View {
    let item: VaultEntry
    @Binding var copiedItemID: UUID?

    private var color: NoteColor { NoteColor.for_(item.colorTag) }
    private var isCopied: Bool { copiedItemID == item.id }

    var body: some View {
        HStack(spacing: 12) {
            // Farbpunkt
            Circle()
                .fill(color.accent)
                .frame(width: 8, height: 8)

            // Nur Titel
            Text(item.title)
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(.primary)
                .lineLimit(1)

            // Favorit
            if item.isFavorite {
                Image(systemName: "star.fill")
                    .font(.system(size: 9))
                    .foregroundStyle(.orange.opacity(0.8))
            }

            Spacer()

            // Kopier-Icon — dezent, kein Label
            Button {
                UIPasteboard.general.string = item.password
                UINotificationFeedbackGenerator().notificationOccurred(.success)
                withAnimation(.spring(response: 0.3)) { copiedItemID = item.id }
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                    withAnimation { if copiedItemID == item.id { copiedItemID = nil } }
                }
            } label: {
                Image(systemName: isCopied ? "checkmark" : "doc.on.doc")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(isCopied ? .green : Color.primary.opacity(0.3))
                    .frame(width: 28, height: 28)
                    .background(
                        isCopied
                            ? Color.green.opacity(0.12)
                            : Color.primary.opacity(0.05),
                        in: RoundedRectangle(cornerRadius: 7)
                    )
                    .animation(.easeInOut(duration: 0.2), value: isCopied)
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 4)
        .padding(.horizontal, 2)
    }
}

struct VaultDetailView: View {
    let item: VaultEntry
    @EnvironmentObject var store: AppStore
    @Environment(\.dismiss) var dismiss

    @State private var isEditing = false
    @State private var editTitle = ""
    @State private var editUsername = ""
    @State private var editPassword = ""
    @State private var editURL = ""
    @State private var editSperrHotline = ""
    @State private var editColor = 0
    @State private var showPassword = false
    @State private var showGenerator = false

    private var displayColor: NoteColor {
        NoteColor.for_(isEditing ? editColor : item.colorTag)
    }

    var body: some View {
        NavigationStack {
            List {
                if isEditing {
                    Section("Titel") {
                        TextField("Titel", text: $editTitle)
                    }
                    Section("Benutzername") {
                        TextField("Benutzername", text: $editUsername)
                            .autocorrectionDisabled()
                            .textInputAutocapitalization(.never)
                    }
                    Section("Passwort") {
                        HStack {
                            if showPassword {
                                TextField("Passwort", text: $editPassword)
                                    .autocorrectionDisabled()
                                    .textInputAutocapitalization(.never)
                                    .font(.system(.body, design: .monospaced))
                            } else {
                                SecureField("Passwort", text: $editPassword)
                                    .font(.system(.body, design: .monospaced))
                            }
                            Button {
                                showPassword.toggle()
                            } label: {
                                Image(systemName: showPassword ? "eye.slash" : "eye")
                                    .foregroundStyle(.blue)
                            }
                            .buttonStyle(.borderless)
                            Button {
                                showGenerator = true
                            } label: {
                                Image(systemName: "wand.and.stars")
                                    .foregroundStyle(.blue)
                            }
                            .buttonStyle(.borderless)
                        }
                        if !editPassword.isEmpty {
                            PasswordStrengthBar(password: editPassword)
                        }
                    }
                    .sheet(isPresented: $showGenerator) {
                        PasswordGeneratorView { generated in
                            editPassword = generated
                            showPassword = true
                        }
                    }
                    Section("Website (optional)") {
                        TextField("https://...", text: $editURL)
                            .autocorrectionDisabled()
                            .textInputAutocapitalization(.never)
                            .keyboardType(.URL)
                    }
                    Section {
                        TextField("z.B. +41 44 123 45 67", text: $editSperrHotline)
                            .keyboardType(.phonePad)
                    } header: {
                        Text("Sperr-Hotline (optional)")
                    } footer: {
                        Text("Für Karten: erscheint mit Anruf-Knopf im Notfall-Bereich (Mehr → Notfall).")
                    }
                } else {
                    Section("Titel") {
                        Text(item.title)
                    }
                    Section("Benutzername") {
                        HStack {
                            Text(item.username.isEmpty ? "–" : item.username)
                            Spacer()
                            if !item.username.isEmpty {
                                Button {
                                    UIPasteboard.general.string = item.username
                                } label: {
                                    Image(systemName: "doc.on.doc").foregroundStyle(.blue)
                                }
                                .buttonStyle(.borderless)
                            }
                        }
                    }
                    Section("Passwort") {
                        HStack {
                            Text(showPassword ? item.password : "••••••••")
                                .font(.system(.body, design: .monospaced))
                            Spacer()
                            Button {
                                showPassword.toggle()
                            } label: {
                                Image(systemName: showPassword ? "eye.slash" : "eye")
                                    .foregroundStyle(.blue)
                            }
                            .buttonStyle(.borderless)
                            Button {
                                UIPasteboard.general.string = item.password
                            } label: {
                                Image(systemName: "doc.on.doc").foregroundStyle(.blue)
                            }
                            .buttonStyle(.borderless)
                        }
                    }
                    if !item.sperrHotline.isEmpty {
                        Section("Sperr-Hotline") {
                            HStack {
                                Text(item.sperrHotline)
                                    .font(.system(.body, design: .rounded))
                                Spacer()
                                Button {
                                    let nummer = item.sperrHotline.filter { "0123456789+".contains($0) }
                                    if let url = URL(string: "tel:\(nummer)") {
                                        UIApplication.shared.open(url)
                                    }
                                } label: {
                                    Image(systemName: "phone.arrow.up.right")
                                        .foregroundStyle(.red)
                                }
                                .buttonStyle(.borderless)
                            }
                        }
                    }
                    if !item.url.isEmpty {
                        Section("Website") {
                            HStack {
                                Text(item.url)
                                    .foregroundStyle(.blue)
                                    .lineLimit(1)
                                Spacer()
                                Button {
                                    var urlStr = item.url
                                    if !urlStr.hasPrefix("http") { urlStr = "https://" + urlStr }
                                    if let u = URL(string: urlStr) { UIApplication.shared.open(u) }
                                } label: {
                                    Image(systemName: "safari").foregroundStyle(.blue)
                                }
                                .buttonStyle(.borderless)
                            }
                        }
                    }
                    Section("Erstellt am") {
                        Text(item.dateCreated.formatted(date: .abbreviated, time: .shortened))
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle(isEditing ? "Bearbeiten" : item.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    if isEditing {
                        Button("Abbrechen") {
                            isEditing = false
                            showPassword = false
                        }
                    } else {
                        Button("Fertig") { dismiss() }
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    if isEditing {
                        Button("Speichern") {
                            UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                            var updated = VaultEntry(
                                id: item.id,
                                title: editTitle.trimmingCharacters(in: .whitespacesAndNewlines),
                                username: editUsername.trimmingCharacters(in: .whitespacesAndNewlines),
                                password: editPassword.trimmingCharacters(in: .whitespacesAndNewlines),
                                url: editURL.trimmingCharacters(in: .whitespacesAndNewlines),
                                sperrHotline: editSperrHotline.trimmingCharacters(in: .whitespacesAndNewlines),
                                isFavorite: item.isFavorite,
                                dateCreated: item.dateCreated,
                                colorTag: editColor
                            )
                            // Die „fest"-Nadel überlebt das Bearbeiten
                            updated.favoritePinned = item.favoritePinned
                            store.updateVaultEntry(updated)
                            isEditing = false
                            showPassword = false
                            dismiss()
                        }
                        .disabled(editTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
                                  editPassword.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    } else {
                        Button("Bearbeiten") {
                            editTitle = item.title
                            editUsername = item.username
                            editPassword = item.password
                            editURL = item.url
                            editSperrHotline = item.sperrHotline
                            editColor = item.colorTag
                            showPassword = false
                            isEditing = true
                        }
                    }
                }
                ToolbarItem(placement: .navigationBarLeading) {
                    if isEditing {
                        Menu {
                            ForEach(0..<NoteColor.palette.count, id: \.self) { idx in
                                Button {
                                    withAnimation(.easeInOut(duration: 0.25)) { editColor = idx }
                                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                } label: {
                                    Label(NoteColor.palette[idx].name,
                                          systemImage: editColor == idx ? "checkmark.circle.fill" : "circle.fill")
                                        .foregroundStyle(NoteColor.palette[idx].accent)
                                }
                            }
                        } label: {
                            Image(systemName: "paintpalette.fill")
                                .foregroundStyle(displayColor.accent)
                        }
                    }
                }
            }
            // Verhindert versehentliches Wegwischen während des Bearbeitens
            .interactiveDismissDisabled(isEditing)
        }
    }
}

// MARK: - Password Generator

struct PasswordGeneratorView: View {
    let onUse: (String) -> Void
    @Environment(\.dismiss) var dismiss

    @State private var length: Double = 16
    @State private var useUppercase = true
    @State private var useNumbers = true
    @State private var useSymbols = true
    @State private var generated = ""

    private let lower = "abcdefghijklmnopqrstuvwxyz"
    private let upper = "ABCDEFGHIJKLMNOPQRSTUVWXYZ"
    private let numbers = "0123456789"
    private let symbols = "!@#$%^&*()-_=+[]{}|;:,.<>?"

    var body: some View {
        NavigationStack {
            Form {
                Section("Generiertes Passwort") {
                    HStack {
                        Text(generated)
                            .font(.system(.body, design: .monospaced))
                            .lineLimit(2)
                            .minimumScaleFactor(0.7)
                            .foregroundStyle(.primary)
                        Spacer()
                        Button {
                            UIPasteboard.general.string = generated
                        } label: {
                            Image(systemName: "doc.on.doc")
                                .foregroundStyle(.blue)
                        }
                    }
                    PasswordStrengthBar(password: generated)
                    Button {
                        generate()
                    } label: {
                        Label("Neu generieren", systemImage: "arrow.clockwise")
                    }
                }

                Section("Optionen") {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text("Länge: \(Int(length)) Zeichen")
                            Spacer()
                        }
                        Slider(value: $length, in: 8...32, step: 1)
                            .onChange(of: length) { _, _ in generate() }
                    }
                    Toggle("Grossbuchstaben (A-Z)", isOn: $useUppercase)
                        .onChange(of: useUppercase) { _, _ in generate() }
                    Toggle("Zahlen (0-9)", isOn: $useNumbers)
                        .onChange(of: useNumbers) { _, _ in generate() }
                    Toggle("Sonderzeichen (!@#...)", isOn: $useSymbols)
                        .onChange(of: useSymbols) { _, _ in generate() }
                }
            }
            .navigationTitle("Passwort-Generator")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Abbrechen") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Übernehmen") {
                        onUse(generated)
                        dismiss()
                    }
                    .bold()
                }
            }
            .onAppear { generate() }
        }
    }

    private func generate() {
        var charset = lower
        if useUppercase { charset += upper }
        if useNumbers   { charset += numbers }
        if useSymbols   { charset += symbols }
        guard !charset.isEmpty else { generated = ""; return }
        generated = String((0..<Int(length)).map { _ in charset.randomElement()! })
    }
}

// MARK: - Password Strength Bar

struct PasswordStrengthBar: View {
    let password: String

    private var strength: (label: String, color: Color, fraction: Double) {
        var score = 0
        if password.count >= 8  { score += 1 }
        if password.count >= 12 { score += 1 }
        if password.count >= 16 { score += 1 }
        if password.rangeOfCharacter(from: .uppercaseLetters) != nil { score += 1 }
        if password.rangeOfCharacter(from: .decimalDigits) != nil    { score += 1 }
        let special = CharacterSet(charactersIn: "!@#$%^&*()-_=+[]{}|;:,.<>?")
        if password.rangeOfCharacter(from: special) != nil { score += 1 }
        switch score {
        case 0...2: return ("Schwach",    .red,    Double(score) / 6.0)
        case 3...4: return ("Mittel",     .orange, Double(score) / 6.0)
        default:    return ("Stark",      .green,  Double(score) / 6.0)
        }
    }

    var body: some View {
        HStack(spacing: 8) {
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color.secondary.opacity(0.2))
                        .frame(height: 6)
                    RoundedRectangle(cornerRadius: 3)
                        .fill(strength.color)
                        .frame(width: geo.size.width * strength.fraction, height: 6)
                        .animation(.easeInOut(duration: 0.3), value: strength.fraction)
                }
            }
            .frame(height: 6)
            Text(strength.label)
                .font(.caption)
                .foregroundStyle(strength.color)
                .frame(width: 50, alignment: .trailing)
        }
        .padding(.vertical, 2)
    }
}

// MARK: - Documents

// Helpers für Dokument-Stil

// Farbe pro Dokument-Typ (für Streifen + Icon)
func docTypeColor(_ type: DocumentType) -> Color {
    switch type {
    case .pdf:   return .red
    case .image: return .blue
    case .text:  return .green
    case .video: return .orange
    }
}

// Deterministische Farbe pro Kategorie-Name (gleicher Name → gleiche Farbe)
func categoryColor(_ name: String, overrides: [String: Int] = [:]) -> NoteColor {
    if let idx = overrides[name] { return NoteColor.for_(idx) }
    let hash = abs(name.hashValue)
    return NoteColor.for_(hash % NoteColor.palette.count)
}

// Helper-Struct für Untergruppen-Operationen (Tuples können nicht direkt als @State verwendet werden)
struct SubcatTarget {
    var category: String
    var name: String
}

// Quick-Action-Quellen für Dokument-Import
struct DocSource: Identifiable {
    let id: String
    let icon: String
    let label: String
    let colorTag: Int
    let action: Action

    enum Action { case scan, pdf, image, text }

    static let all: [DocSource] = [
        DocSource(id: "scan",  icon: "doc.viewfinder",            label: "Scannen",        colorTag: 4, action: .scan),  // Lila
        DocSource(id: "pdf",   icon: "doc.fill",                  label: "PDF",            colorTag: 1, action: .pdf),   // Rosa
        DocSource(id: "image", icon: "photo.fill.on.rectangle.fill", label: "Fotos / Videos", colorTag: 2, action: .image), // Blau
        DocSource(id: "text",  icon: "doc.text.fill",             label: "Text",           colorTag: 3, action: .text),  // Grün
    ]
}

struct DocumentsView: View {
    @EnvironmentObject var store: AppStore
    var isUnlocked: Bool = true
    @State private var showAddMenu = false
    @State private var pendingSource: DocSource.Action? = nil
    @State private var showFilePicker = false
    @State private var showImagePicker = false
    @State private var showScanner = false
    @State private var previewURL: URL? = nil
    @State private var previewImageURL: URL? = nil
    @State private var showTextInput = false
    @State private var textTitle = ""
    @State private var textContent = ""
    @State private var textCategory: String = "Unsortiert"
    @State private var searchText = ""

    // Zwischenspeicher für Kategorie-Auswahl nach Datei-Import
    @State private var pendingTitle = ""
    @State private var pendingFilename = ""
    @State private var pendingType: DocumentType = .pdf
    @State private var pendingCategory: String = "Unsortiert"
    @State private var showCategoryPicker = false
    @State private var scanReady = false
    @State private var downloadingDoc: DocumentEntry? = nil
    @State private var showDownloadError = false
    @State private var filePickerTypes: [UTType] = [.pdf]
    @State private var filePickerDocType: DocumentType = .pdf
    @State private var showCategoryManager = false
    @State private var renamingDoc: DocumentEntry? = nil
    @State private var renameText = ""

    // Ordner Teilen
    @State private var shareItem: ShareURLItem? = nil
    @State private var importedFolderName: String? = nil
    @State private var showImportSuccess = false
    @State private var showImportError = false
    @State private var colorPickerCategory: String? = nil
    @State private var deletingCategory: String? = nil
    @State private var renamingCategory: String? = nil
    @State private var categoryRenameText = ""
    @State private var showCategoryRename = false

    // Untergruppen-Zustand
    @State private var collapsedSubcategories: Set<String> = []
    @State private var addingSubcategoryTo: String? = nil
    @State private var newSubcategoryName = ""
    @State private var renamingSubcat: SubcatTarget? = nil
    @State private var subcatRenameText = ""
    @State private var deletingSubcat: SubcatTarget? = nil

    // Aufgeklappt/Zugeklappt-Zustand pro Kategorie (persistent)
    @State private var collapsedCategories: Set<String> = DocumentsView.loadCollapsed()
    private static let collapsedKey = "collapsedDocCategories"

    private static func loadCollapsed() -> Set<String> {
        if let arr = UserDefaults.standard.stringArray(forKey: collapsedKey) {
            return Set(arr)
        }
        return []
    }

    private func saveCollapsed() {
        UserDefaults.standard.set(Array(collapsedCategories), forKey: DocumentsView.collapsedKey)
    }

    private func toggleCategory(_ category: String) {
        withAnimation(.easeInOut(duration: 0.25)) {
            if collapsedCategories.contains(category) {
                collapsedCategories.remove(category)
            } else {
                collapsedCategories.insert(category)
            }
        }
        saveCollapsed()
    }

    private var filteredDocuments: [DocumentEntry] {
        if searchText.isEmpty { return store.documents }
        return store.documents.filter {
            $0.title.localizedCaseInsensitiveContains(searchText) ||
            $0.category.localizedCaseInsensitiveContains(searchText)
        }
    }

    private func handleImport(_ action: DocSource.Action) {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        switch action {
        case .scan:  showScanner = true
        case .pdf:   filePickerTypes = [.pdf]; filePickerDocType = .pdf; showFilePicker = true
        case .image: showImagePicker = true
        case .text:  textCategory = store.ensureImportCategoryExists(); showTextInput = true
        }
    }

    private func printDocument(_ doc: DocumentEntry) {
        let url = store.documentURL(for: doc.filename)
        let printInfo = UIPrintInfo(dictionary: nil)
        printInfo.jobName = doc.title
        printInfo.outputType = doc.type == .image ? .photo : .general
        let controller = UIPrintInteractionController.shared
        controller.printInfo = printInfo
        if doc.type == .image, let data = try? Data(contentsOf: url), let image = UIImage(data: data) {
            controller.printingItem = image
        } else {
            controller.printingItem = url
        }
        controller.present(animated: true)
    }

    var body: some View {
        Group {
            iPhoneDocumentsBody
        }
        .overlay { downloadHUD }
        .alert("Download fehlgeschlagen", isPresented: $showDownloadError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Das Dokument konnte nicht aus iCloud geladen werden. Prüfe deine Internetverbindung und versuche es erneut.")
        }
    }

    // MARK: - iPhone Layout (unverändert)

    private var iPhoneDocumentsBody: some View {
        NavigationStack {
            VStack(spacing: 0) {
                AddTriggerButton(label: "Neues Dokument", subtitle: "Scan · PDF · Fotos/Videos · Text", icon: "plus") {
                    showAddMenu = true
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .padding(.bottom, 4)

                documentsList
            }
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Image(systemName: "doc.text.fill")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(.secondary)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showCategoryManager = true
                    } label: {
                        Image(systemName: "folder.badge.gearshape")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(.secondary)
                    }
                }
            }
            // Quelle wählen Sheet
            // Erfassen vom Start: Quellen-Blatt direkt öffnen
            .onAppear {
                if store.pendingNewEntry == .documents {
                    store.pendingNewEntry = nil
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { showAddMenu = true }
                }
            }
            .onChange(of: store.pendingNewEntry) { _, wert in
                // Plus gedrückt, während der Bereich schon offen ist
                if wert == .documents {
                    store.pendingNewEntry = nil
                    showAddMenu = true
                }
            }
            .sheet(isPresented: $showAddMenu, onDismiss: {
                if let src = pendingSource {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                        handleImport(src)
                    }
                    pendingSource = nil
                }
            }) {
                NewDocumentSourceSheet { action in
                    pendingSource = action
                    showAddMenu = false
                }
            }
            .fileImporter(isPresented: $showFilePicker, allowedContentTypes: filePickerTypes) { result in
                handleFileImport(result: result, type: filePickerDocType)
            }
            .sheet(isPresented: $showImagePicker) {
                MediaPickerView { images, videos in
                    importPickedMedia(imageURLs: images, videoURLs: videos)
                }
            }
            .sheet(isPresented: $showScanner, onDismiss: {
                if scanReady {
                    scanReady = false
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { showCategoryPicker = true }
                }
            }) {
                DocumentScannerView { pdfURL in
                    let filename = "\(UUID().uuidString).pdf"
                    let destination = store.documentURL(for:filename)
                    try? FileManager.default.copyItem(at: pdfURL, to: destination)
                    pendingTitle = "Scan \(Date().formatted(date: .abbreviated, time: .omitted))"
                    pendingFilename = filename
                    pendingType = .pdf
                    pendingCategory = store.ensureImportCategoryExists()
                    scanReady = true
                    showScanner = false
                }
            }
            .sheet(isPresented: $showTextInput) {
                TextDocumentInputView(title: $textTitle, content: $textContent, category: $textCategory) {
                    saveTextDocument()
                    showTextInput = false
                }
            }
            .sheet(isPresented: $showCategoryPicker) {
                DocumentSaveSheet(
                    title: $pendingTitle,
                    category: $pendingCategory
                ) {
                    store.addDocument(title: pendingTitle, type: pendingType, filename: pendingFilename, category: pendingCategory)
                    showCategoryPicker = false
                } onCancel: {
                    let dest = store.documentURL(for:pendingFilename)
                    try? FileManager.default.removeItem(at: dest)
                    showCategoryPicker = false
                }
            }
            .sheet(isPresented: $showCategoryManager) {
                DocumentCategoryManagerView()
            }
            .quickLookPreview($previewURL)
            .fullScreenCover(isPresented: Binding(
                get: { previewImageURL != nil },
                set: { if !$0 { previewImageURL = nil } }
            )) {
                if let url = previewImageURL {
                    ImagePreviewView(url: url)
                }
            }
            .sheet(isPresented: Binding(
                get: { colorPickerCategory != nil },
                set: { if !$0 { colorPickerCategory = nil } }
            )) {
                if let cat = colorPickerCategory {
                    CategoryColorPickerSheet(
                        categoryName: cat,
                        current: store.categoryColors[cat]
                    ) { idx in
                        if let idx { store.categoryColors[cat] = idx }
                        else       { store.categoryColors.removeValue(forKey: cat) }
                        colorPickerCategory = nil
                    }
                }
            }
            .alert("Gruppe löschen", isPresented: Binding(
                get: { deletingCategory != nil },
                set: { if !$0 { deletingCategory = nil } }
            )) {
                Button("Dokumente behalten") {
                    if let cat = deletingCategory { store.deleteCategory(cat) }
                    deletingCategory = nil
                }
                Button("Dokumente mitlöschen", role: .destructive) {
                    if let cat = deletingCategory {
                        store.documents
                            .filter { $0.category == cat }
                            .forEach { store.deleteDocument($0) }
                        store.documentCategories.removeAll { $0 == cat }
                    }
                    deletingCategory = nil
                }
                Button("Abbrechen", role: .cancel) { deletingCategory = nil }
            } message: {
                if let cat = deletingCategory {
                    let count = store.documents.filter { $0.category == cat }.count
                    let word = count == 1 ? "Dokument" : "Dokumente"
                    Text("\(cat) enthält \(count) \(word).")
                }
            }
            .alert("Import fehlgeschlagen", isPresented: $showImportError) {
                Button("OK", role: .cancel) { }
            } message: {
                Text("Die Datei konnte nicht importiert werden. Bitte prüfe den Speicherplatz und versuche es erneut.")
            }
        }
    }

    // MARK: - Dokument öffnen (mit iCloud-Download falls nötig)

    private func openDocument(_ doc: DocumentEntry) {
        if store.ensureFileDownloaded(doc.filename) {
            presentPreview(doc)
        } else {
            downloadingDoc = doc
            waitForDownload(doc, attempts: 0)
        }
    }

    private func waitForDownload(_ doc: DocumentEntry, attempts: Int) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            guard downloadingDoc?.id == doc.id else { return }   // abgebrochen
            if store.ensureFileDownloaded(doc.filename) {
                downloadingDoc = nil
                presentPreview(doc)
            } else if attempts < 300 {   // max. ~2 Minuten
                waitForDownload(doc, attempts: attempts + 1)
            } else {
                downloadingDoc = nil
                showDownloadError = true
            }
        }
    }

    private func presentPreview(_ doc: DocumentEntry) {
        // Einspaltig auf iPhone wie iPad: Vorschau als QuickLook bzw. Bild-Cover.
        if doc.type == .image {
            previewImageURL = store.documentURL(for: doc.filename)
        } else {
            previewURL = store.documentURL(for: doc.filename)
        }
    }

    @ViewBuilder
    private var downloadHUD: some View {
        if let doc = downloadingDoc {
            VStack(spacing: 14) {
                ProgressView()
                Text("\u{201E}\(doc.title)\u{201C} wird aus iCloud geladen …")
                    .font(.system(size: 14, weight: .medium))
                    .multilineTextAlignment(.center)
                Button("Abbrechen") { downloadingDoc = nil }
                    .font(.system(size: 14))
            }
            .padding(24)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 20))
            .padding(40)
        }
    }

    @ViewBuilder
    private func documentRow(_ doc: DocumentEntry, indented: Bool = false) -> some View {
        Button {
            openDocument(doc)
        } label: {
            HStack(spacing: 12) {
                Circle()
                    .fill(docTypeColor(doc.type))
                    .frame(width: 8, height: 8)
                DocThumbnail(url: store.documentURL(for: doc.filename), type: doc.type)
                Text(doc.title)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                Spacer()
            }
            .padding(.vertical, 4)
        }
        .foregroundStyle(.primary)
        .listRowBackground(Color(.secondarySystemBackground))
        .listRowSeparator(.visible)
        .listRowSeparatorTint(Color.primary.opacity(0.06))
        .listRowInsets(EdgeInsets(top: 0, leading: indented ? 36 : 16, bottom: 0, trailing: 12))
        .swipeActions(edge: .trailing) {
            Button(role: .destructive) {
                store.deleteDocument(doc)
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            } label: { Label("Löschen", systemImage: "trash") }
        }
        .swipeActions(edge: .leading) {
            Button {
                store.toggleFavorite(kind: .document, id: doc.id)
                UINotificationFeedbackGenerator().notificationOccurred(.success)
            } label: {
                Label(doc.isFavorite ? "Entfernen" : "Favorit",
                      systemImage: doc.isFavorite ? "star.slash" : "star.fill")
            }
            .tint(.orange)
            Button {
                renameText = doc.title
                renamingDoc = doc
            } label: { Label("Umbenennen", systemImage: "pencil") }
            .tint(.blue)
        }
        .contextMenu {
            ArcaMenue.favorit(ist: doc.isFavorite) {
                store.toggleFavorite(kind: .document, id: doc.id)
                UINotificationFeedbackGenerator().notificationOccurred(.success)
            }
            Divider()
            ArcaMenue.umbenennen {
                renameText = doc.title
                renamingDoc = doc
            }
            Menu {
                ForEach(store.documentCategories, id: \.self) { targetCategory in
                    let subcats = store.documentSubcategories[targetCategory] ?? []
                    if subcats.isEmpty {
                        Button {
                            if let idx = store.documents.firstIndex(where: { $0.id == doc.id }) {
                                store.documents[idx].category = targetCategory
                                store.documents[idx].subcategory = ""
                            }
                        } label: {
                            Label(targetCategory, systemImage: categoryIcon(targetCategory))
                        }
                    } else {
                        Menu {
                            Button {
                                if let idx = store.documents.firstIndex(where: { $0.id == doc.id }) {
                                    store.documents[idx].category = targetCategory
                                    store.documents[idx].subcategory = ""
                                }
                            } label: {
                                Label("Direkt in \(targetCategory)", systemImage: "folder")
                            }
                            Divider()
                            ForEach(subcats, id: \.self) { subcat in
                                Button {
                                    if let idx = store.documents.firstIndex(where: { $0.id == doc.id }) {
                                        store.documents[idx].category = targetCategory
                                        store.documents[idx].subcategory = subcat
                                    }
                                } label: {
                                    Label(subcat, systemImage: "folder.fill")
                                }
                            }
                        } label: {
                            Label(targetCategory, systemImage: categoryIcon(targetCategory))
                        }
                    }
                }
            } label: {
                Label("Verschieben nach…", systemImage: "folder.fill")
            }
            Divider()
            Button {
                if let url = store.exportDocument(doc) {
                    shareItem = ShareURLItem(url: url)
                }
            } label: {
                Label("An Arca-Nutzer senden", systemImage: "person.2.fill")
            }
            Button {
                shareItem = ShareURLItem(url: store.documentURL(for: doc.filename))
            } label: {
                Label("Als Datei teilen", systemImage: "square.and.arrow.up")
            }
            if doc.type != .video {
                Button {
                    printDocument(doc)
                } label: {
                    Label("Drucken", systemImage: "printer")
                }
            }
            Divider()
            Button(role: .destructive) {
                store.deleteDocument(doc)
            } label: {
                Label("Löschen", systemImage: "trash")
            }
        }
    }

    private var documentsList: some View {
        ScrollViewReader { proxy in
        List {
            let grouped = Dictionary(grouping: filteredDocuments, by: \.category)
            if grouped.isEmpty {
                Text(store.documents.isEmpty ? "Noch keine Dokumente vorhanden." : "Keine Treffer.")
                    .foregroundStyle(.secondary)
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
            } else {
                ForEach(store.documentCategories, id: \.self) { category in
                    let docs = grouped[category] ?? []
                    if !docs.isEmpty {
                        let isCollapsed = collapsedCategories.contains(category)
                        let catColor = categoryColor(category, overrides: store.categoryColors)

                        // ── Kategorie-Header als echte Row (gleiche Card wie Passwörter) ──
                        Section {
                            // Kategorie-Zeile
                            HStack(spacing: 10) {
                                Button {
                                    toggleCategory(category)
                                } label: {
                                    HStack(spacing: 8) {
                                        Image(systemName: "chevron.right")
                                            .font(.system(size: 11, weight: .semibold))
                                            .foregroundStyle(.secondary)
                                            .rotationEffect(.degrees(isCollapsed ? 0 : 90))
                                            .animation(.easeInOut(duration: 0.2), value: isCollapsed)
                                        Image(systemName: categoryIcon(category))
                                            .font(.system(size: 13, weight: .semibold))
                                            .foregroundStyle(catColor.accent)
                                            .frame(width: 28, height: 28)
                                            .background(catColor.bg.opacity(0.9), in: RoundedRectangle(cornerRadius: 8))
                                        Text(category)
                                            .font(.system(size: 15, weight: .semibold))
                                            .foregroundStyle(.primary)
                                        if store.isInHomeFolderQuickView(category) {
                                            Image(systemName: "house.fill")
                                                .font(.system(size: 10, weight: .semibold))
                                                .foregroundStyle(catColor.accent.opacity(0.85))
                                                .accessibilityHidden(true)
                                        }
                                        Text("\(docs.count)")
                                            .font(.caption.weight(.bold))
                                            .foregroundStyle(catColor.accent)
                                            .padding(.horizontal, 7)
                                            .padding(.vertical, 2)
                                            .background(catColor.bg.opacity(0.7), in: Capsule())
                                    }
                                    .contentShape(Rectangle())
                                }
                                .buttonStyle(.plain)
                                .contextMenu {
                                    Button {
                                        colorPickerCategory = category
                                    } label: {
                                        Label("Farbe", systemImage: "paintpalette")
                                    }
                                    ArcaMenue.umbenennen {
                                        categoryRenameText = category
                                        renamingCategory = category
                                        showCategoryRename = true
                                    }
                                    Button {
                                        newSubcategoryName = ""
                                        addingSubcategoryTo = category
                                    } label: {
                                        Label("Untergruppe hinzufügen", systemImage: "folder.badge.plus")
                                    }

                                    Divider()

                                    Button {
                                        store.toggleHomeFolderQuickView(category)
                                        UINotificationFeedbackGenerator().notificationOccurred(.success)
                                    } label: {
                                        if store.isInHomeFolderQuickView(category) {
                                            Label("Aus Schnellansicht entfernen", systemImage: "house.slash")
                                        } else {
                                            Label("In Schnellansicht anzeigen", systemImage: "house")
                                        }
                                    }

                                    Divider()

                                    if let idx = store.documentCategories.firstIndex(of: category), idx > 0 {
                                        Button {
                                            withAnimation {
                                                store.documentCategories.move(
                                                    fromOffsets: IndexSet(integer: idx),
                                                    toOffset: idx - 1)
                                            }
                                        } label: {
                                            Label("Nach oben", systemImage: "arrow.up")
                                        }
                                    }
                                    if let idx = store.documentCategories.firstIndex(of: category),
                                       idx < store.documentCategories.count - 1 {
                                        Button {
                                            withAnimation {
                                                store.documentCategories.move(
                                                    fromOffsets: IndexSet(integer: idx),
                                                    toOffset: idx + 2)
                                            }
                                        } label: {
                                            Label("Nach unten", systemImage: "arrow.down")
                                        }
                                    }

                                    Divider()

                                    Button {
                                        if let url = store.exportFolder(category: category) {
                                            shareItem = ShareURLItem(url: url)
                                        }
                                    } label: {
                                        Label("Gruppe teilen", systemImage: "person.2.fill")
                                    }

                                    Divider()

                                    Button(role: .destructive) {
                                        deletingCategory = category
                                    } label: {
                                        Label("Gruppe löschen", systemImage: "trash")
                                    }
                                }

                                Spacer()

                                Button {
                                    if let url = store.exportFolder(category: category) {
                                        shareItem = ShareURLItem(url: url)
                                    }
                                } label: {
                                    Image(systemName: "person.2.fill")
                                        .font(.system(size: 12))
                                        .foregroundStyle(.blue)
                                }
                                .buttonStyle(.borderless)

                                Button {
                                    categoryRenameText = category
                                    renamingCategory = category
                                    showCategoryRename = true
                                } label: {
                                    Image(systemName: "pencil")
                                        .font(.system(size: 12))
                                        .foregroundStyle(.secondary)
                                }
                                .buttonStyle(.borderless)
                            }
                            .padding(.vertical, 6)
                            // Gleiche Farbwelt wie die Gruppen-Karten auf dem Start
                            .listRowBackground(catColor.bg.opacity(0.55))
                            .listRowSeparator(isCollapsed ? .hidden : .visible)
                            .listRowSeparatorTint(Color.primary.opacity(0.06))
                            .listRowInsets(EdgeInsets(top: 0, leading: 14, bottom: 0, trailing: 12))
                            .id(category)

                            // ── Dokument-Zeilen (nur wenn aufgeklappt) ──
                            if !isCollapsed {
                                let subcats = store.documentSubcategories[category] ?? []
                                let rootDocs = docs.filter { $0.subcategory.isEmpty }

                                // Dokumente direkt in der Kategorie (ohne Untergruppe)
                                ForEach(rootDocs) { doc in
                                    documentRow(doc)
                                }
                                .onDelete { indexSet in
                                    let toDelete = indexSet.map { rootDocs[$0] }
                                    toDelete.forEach { store.deleteDocument($0) }
                                }

                                // Untergruppen-Header + ihre Dokumente
                                ForEach(subcats, id: \.self) { subcat in
                                    let subcatKey = "\(category)/\(subcat)"
                                    let isSubcollapsed = collapsedSubcategories.contains(subcatKey)
                                    let subcatDocs = docs.filter { $0.subcategory == subcat }

                                    // Untergruppen-Header-Zeile
                                    HStack(spacing: 0) {
                                        // Farbiger linker Streifen
                                        Rectangle()
                                            .fill(catColor.accent)
                                            .frame(width: 3)
                                        Button {
                                            withAnimation(.easeInOut(duration: 0.22)) {
                                                if isSubcollapsed { collapsedSubcategories.remove(subcatKey) }
                                                else { collapsedSubcategories.insert(subcatKey) }
                                            }
                                        } label: {
                                            HStack(spacing: 8) {
                                                Image(systemName: "chevron.right")
                                                    .font(.system(size: 10, weight: .bold))
                                                    .foregroundStyle(catColor.accent)
                                                    .rotationEffect(.degrees(isSubcollapsed ? 0 : 90))
                                                    .animation(.easeInOut(duration: 0.22), value: isSubcollapsed)
                                                Image(systemName: "folder.fill")
                                                    .font(.system(size: 13, weight: .semibold))
                                                    .foregroundStyle(catColor.accent)
                                                Text(subcat)
                                                    .font(.system(size: 14, weight: .semibold))
                                                    .foregroundStyle(.primary)
                                                Spacer()
                                                Text("\(subcatDocs.count)")
                                                    .font(.caption.weight(.bold))
                                                    .foregroundStyle(catColor.accent)
                                                    .padding(.horizontal, 7)
                                                    .padding(.vertical, 2)
                                                    .background(catColor.bg.opacity(0.9), in: Capsule())
                                            }
                                            .padding(.horizontal, 12)
                                            .contentShape(Rectangle())
                                        }
                                        .buttonStyle(.plain)
                                        .contextMenu {
                                            Button {
                                                subcatRenameText = subcat
                                                renamingSubcat = SubcatTarget(category: category, name: subcat)
                                            } label: { Label("Umbenennen", systemImage: "pencil") }
                                            Divider()
                                            Button(role: .destructive) {
                                                deletingSubcat = SubcatTarget(category: category, name: subcat)
                                            } label: { Label("Untergruppe löschen", systemImage: "trash") }
                                        }
                                    }
                                    .padding(.vertical, 7)
                                    .listRowBackground(catColor.bg.opacity(0.18))
                                    .listRowSeparator(.hidden)
                                    .listRowInsets(EdgeInsets(top: 4, leading: 24, bottom: 4, trailing: 0))

                                    // Dokumente in dieser Untergruppe
                                    if !isSubcollapsed {
                                        ForEach(subcatDocs) { doc in
                                            documentRow(doc, indented: true)
                                        }
                                        .onDelete { indexSet in
                                            let toDelete = indexSet.map { subcatDocs[$0] }
                                            toDelete.forEach { store.deleteDocument($0) }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .listSectionSpacing(8)
        .scrollContentBackground(.hidden)
        .searchable(text: $searchText, prompt: "Suchen…")
            .alert("Dokument umbenennen", isPresented: Binding(
                get: { renamingDoc != nil },
                set: { if !$0 { renamingDoc = nil } }
            )) {
                TextField("Neuer Name", text: $renameText)
                Button("Speichern") {
                    if let doc = renamingDoc, !renameText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        if let idx = store.documents.firstIndex(where: { $0.id == doc.id }) {
                            store.documents[idx].title = renameText.trimmingCharacters(in: .whitespacesAndNewlines)
                        }
                    }
                    renamingDoc = nil
                }
                Button("Abbrechen", role: .cancel) { renamingDoc = nil }
            }
            // Ordner Teilen Sheet
            .sheet(item: $shareItem) { item in
                if FileManager.default.fileExists(atPath: item.url.path) {
                    ShareSheet(activityItems: [item.url])
                } else {
                    VStack(spacing: 16) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 40))
                            .foregroundStyle(.orange)
                        Text("Teilen fehlgeschlagen")
                            .font(.headline)
                        Text("Die Datei konnte nicht erstellt werden. Bitte versuche es erneut.")
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                        Button("Schließen") { shareItem = nil }
                            .buttonStyle(.borderedProminent)
                            .padding(.top, 8)
                    }
                    .padding()
                }
            }
            // Import Erfolg
            .alert("Ordner importiert!", isPresented: $showImportSuccess) {
                Button("Umbenennen") {
                    if let name = importedFolderName {
                        categoryRenameText = name
                        renamingCategory = name
                        showCategoryRename = true
                    }
                }
                Button("OK", role: .cancel) { importedFolderName = nil }
            } message: {
                Text("Der Ordner \"\(importedFolderName ?? "")\" wurde hinzugefügt.")
            }
            // Ordner Umbenennen Alert
            .alert("Gruppe umbenennen", isPresented: $showCategoryRename) {
                TextField("Neuer Name", text: $categoryRenameText)
                Button("Speichern") {
                    if let old = renamingCategory {
                        store.renameCategory(from: old, to: categoryRenameText)
                    }
                    renamingCategory = nil
                }
                Button("Abbrechen", role: .cancel) { renamingCategory = nil }
            }
            // Untergruppe hinzufügen Alert
            .alert("Untergruppe hinzufügen", isPresented: Binding(
                get: { addingSubcategoryTo != nil },
                set: { if !$0 { addingSubcategoryTo = nil } }
            )) {
                TextField("Name der Untergruppe", text: $newSubcategoryName)
                Button("Hinzufügen") {
                    if let cat = addingSubcategoryTo {
                        store.addSubcategory(to: cat, name: newSubcategoryName)
                    }
                    addingSubcategoryTo = nil
                    newSubcategoryName = ""
                }
                Button("Abbrechen", role: .cancel) { addingSubcategoryTo = nil }
            }
            // Untergruppe umbenennen Alert
            .alert("Untergruppe umbenennen", isPresented: Binding(
                get: { renamingSubcat != nil },
                set: { if !$0 { renamingSubcat = nil } }
            )) {
                TextField("Neuer Name", text: $subcatRenameText)
                Button("Speichern") {
                    if let r = renamingSubcat {
                        store.renameSubcategory(category: r.category, old: r.name, new: subcatRenameText)
                    }
                    renamingSubcat = nil
                }
                Button("Abbrechen", role: .cancel) { renamingSubcat = nil }
            }
            // Untergruppe löschen Alert
            .alert("Untergruppe löschen", isPresented: Binding(
                get: { deletingSubcat != nil },
                set: { if !$0 { deletingSubcat = nil } }
            )) {
                Button("Dokumente behalten") {
                    if let d = deletingSubcat { store.deleteSubcategory(category: d.category, name: d.name) }
                    deletingSubcat = nil
                }
                Button("Löschen", role: .destructive) {
                    if let d = deletingSubcat { store.deleteSubcategory(category: d.category, name: d.name) }
                    deletingSubcat = nil
                }
                Button("Abbrechen", role: .cancel) { deletingSubcat = nil }
            } message: {
                if let d = deletingSubcat {
                    let count = store.documents.filter { $0.category == d.category && $0.subcategory == d.name }.count
                    Text("Die Untergruppe \"\(d.name)\" enthält \(count) Dokument(e). Dokumente werden in die Hauptgruppe verschoben.")
                }
            }
            // Eingehende Datei aus Mail / Dateien-App verarbeiten
            .onAppear {
                if isUnlocked, let url = store.pendingSharedURL, !store.isBackupCandidateURL(url) {
                    handleSharedURL(url)
                    store.pendingSharedURL = nil
                }
            }
            .onChange(of: store.pendingSharedURL) { _, url in
                guard let url, isUnlocked, !store.isBackupCandidateURL(url) else { return }
                handleSharedURL(url)
                store.pendingSharedURL = nil
            }
            // URL verarbeiten sobald App entsperrt wird (war beim Empfang noch gesperrt)
            .onChange(of: isUnlocked) { _, unlocked in
                guard unlocked, let url = store.pendingSharedURL, !store.isBackupCandidateURL(url) else { return }
                handleSharedURL(url)
                store.pendingSharedURL = nil
            }
            .onChange(of: store.pendingScrollCategory) { _, target in
                guard let category = target else { return }
                scrollToCategory(category, proxy: proxy)
            }
            .onAppear {
                if let category = store.pendingScrollCategory {
                    scrollToCategory(category, proxy: proxy)
                }
            }
        }
    }

    private func scrollToCategory(_ category: String, proxy: ScrollViewProxy) {
        collapsedCategories.remove(category)
        saveCollapsed()
        // Erster Tick: SwiftUI rendert die aufgeklappten Rows.
        // Zweiter Tick: Liste hat neues Layout → scrollTo findet die ID.
        DispatchQueue.main.async {
            DispatchQueue.main.async {
                withAnimation { proxy.scrollTo(category, anchor: .top) }
                store.pendingScrollCategory = nil
            }
        }
    }

    private func handleSharedURL(_ url: URL) {
        let ext = url.pathExtension.lowercased()

        // Arca Backup — Extension oder Magic-Bytes (Export ohne Endung in Dateien-App)
        if ext == "arcabackup" || store.isBackupCandidateURL(url) {
            store.pendingBackupURL = url
            store.pendingSection = .settings
            return
        }

        // Arca Ordner Import
        if ext == "arcafolder" {
            if let importedName = store.importFolder(from: url) {
                importedFolderName = importedName
                showImportSuccess = true
            }
            return
        }
        // Arca Notiz Import
        if ext == "arcanote" {
            if store.importNote(from: url) {
                UINotificationFeedbackGenerator().notificationOccurred(.success)
                store.pendingSection = .notes   // direkt zu den Notizen springen
            }
            return
        }
        // Arca Aufgabenliste Import
        if ext == "arcalist" {
            if store.importList(from: url) {
                UINotificationFeedbackGenerator().notificationOccurred(.success)
                store.pendingSection = .lists   // direkt zu den Tasks springen
            }
            return
        }

        let type: DocumentType
        switch ext {
        case "pdf":        type = .pdf
        case "jpg", "jpeg", "png", "heic", "tiff": type = .image
        case "mov", "mp4", "m4v": type = .video
        default:           type = .pdf   // Fallback
        }
        let filename = "\(UUID().uuidString).\(ext.isEmpty ? "pdf" : ext)"
        let destination = store.documentURL(for:filename)
        let accessing = url.startAccessingSecurityScopedResource()
        defer { if accessing { url.stopAccessingSecurityScopedResource() } }
        let importCategory = store.importCategoryName
        do {
            try FileManager.default.copyItem(at: url, to: destination)
            if !store.documentCategories.contains(importCategory) {
                store.documentCategories.insert(importCategory, at: 0)
            }
            let title = url.deletingPathExtension().lastPathComponent
            store.addDocument(title: title, type: type, filename: filename, category: importCategory)
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        } catch {
            try? FileManager.default.removeItem(at: destination)
            showImportError = true
        }
    }

    private func handleFileImport(result: Result<URL, Error>, type: DocumentType) {
        guard case .success(let url) = result else { return }
        guard url.startAccessingSecurityScopedResource() else { return }
        defer { url.stopAccessingSecurityScopedResource() }
        let filename = "\(UUID().uuidString).\(url.pathExtension)"
        let destination = store.documentURL(for:filename)
        try? FileManager.default.copyItem(at: url, to: destination)
        pendingTitle = url.deletingPathExtension().lastPathComponent
        pendingFilename = filename
        pendingType = type
        pendingCategory = store.ensureImportCategoryExists()
        showCategoryPicker = true
    }

    /// Importiert ausgewählte Fotos/Videos direkt in die Import-Gruppe (ohne Einzeldialog).
    private func importPickedMedia(imageURLs: [URL], videoURLs: [URL]) {
        guard !imageURLs.isEmpty || !videoURLs.isEmpty else { return }
        let category = store.ensureImportCategoryExists()
        let dateStr = Date().formatted(date: .abbreviated, time: .omitted)

        func importFiles(_ urls: [URL], titlePrefix: String, type: DocumentType) {
            for (i, src) in urls.enumerated() {
                let ext = src.pathExtension.isEmpty ? "dat" : src.pathExtension
                let filename = "\(UUID().uuidString).\(ext)"
                let dest = store.documentURL(for: filename)
                guard (try? FileManager.default.copyItem(at: src, to: dest)) != nil else { continue }
                try? FileManager.default.removeItem(at: src)
                let suffix = urls.count > 1 ? " (\(i + 1))" : ""
                store.addDocument(title: "\(titlePrefix) \(dateStr)\(suffix)",
                                  type: type, filename: filename, category: category)
            }
        }

        importFiles(imageURLs, titlePrefix: "Bild",  type: .image)
        importFiles(videoURLs, titlePrefix: "Video", type: .video)
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }

    private func saveTextDocument() {
        let filename = "\(UUID().uuidString).txt"
        let destination = store.documentURL(for:filename)
        try? textContent.write(to: destination, atomically: true, encoding: .utf8)
        store.addDocument(title: textTitle.isEmpty ? "Textdokument" : textTitle, type: .text, filename: filename, category: textCategory)
        textTitle = ""
        textContent = ""
        textCategory = store.documentCategories.last ?? "Sonstiges"
    }
}

// MARK: - DocThumbnail

private final class ThumbnailCache {
    static let shared = ThumbnailCache()
    private let cache = NSCache<NSString, UIImage>()
    private init() { cache.countLimit = 200 }

    func image(for url: URL) -> UIImage? {
        cache.object(forKey: url.path as NSString)
    }
    func store(_ image: UIImage, for url: URL) {
        cache.setObject(image, forKey: url.path as NSString)
    }
}

/// Universelle Datei-Vorschau: PDF-Erstseite, Video-Standbild, Foto, Textinhalt.
struct DocThumbnail: View {
    let url: URL
    var type: DocumentType = .image

    @State private var image: UIImage? = nil
    @Environment(\.displayScale) private var displayScale

    private var fallbackIcon: String {
        switch type {
        case .pdf:   return "doc.fill"
        case .image: return "photo"
        case .text:  return "doc.text.fill"
        case .video: return "video.fill"
        }
    }

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 6)
                .fill(Color(.tertiarySystemFill))
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                Image(systemName: fallbackIcon)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(docTypeColor(type).opacity(0.7))
            }
            if type == .video, image != nil {
                Image(systemName: "play.circle.fill")
                    .font(.system(size: 16))
                    .foregroundStyle(.white)
                    .shadow(radius: 2)
            }
        }
        .frame(width: 42, height: 50)
        .clipShape(RoundedRectangle(cornerRadius: 6))
        .overlay {
            RoundedRectangle(cornerRadius: 6)
                .strokeBorder(Color.primary.opacity(0.08), lineWidth: 0.5)
        }
        .onAppear { loadThumbnail() }
    }

    private func loadThumbnail() {
        if let cached = ThumbnailCache.shared.image(for: url) {
            image = cached
            return
        }
        guard FileManager.default.fileExists(atPath: url.path) else { return }
        let request = QLThumbnailGenerator.Request(
            fileAt: url,
            size: CGSize(width: 42, height: 50),
            scale: displayScale,
            representationTypes: .thumbnail
        )
        QLThumbnailGenerator.shared.generateBestRepresentation(for: request) { rep, _ in
            guard let img = rep?.uiImage else { return }
            ThumbnailCache.shared.store(img, for: url)
            DispatchQueue.main.async { image = img }
        }
    }
}

// MARK: - ImagePreviewView

struct ImagePreviewView: View {
    let url: URL
    @Environment(\.dismiss) private var dismiss
    @State private var image: UIImage? = nil
    @State private var scale: CGFloat = 1.0
    @State private var baseScale: CGFloat = 1.0
    @State private var offset: CGSize = .zero
    @State private var baseOffset: CGSize = .zero

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .scaleEffect(scale)
                    .offset(offset)
                    .gesture(
                        MagnificationGesture()
                            .onChanged { value in
                                scale = max(1.0, baseScale * value)
                            }
                            .onEnded { _ in
                                baseScale = scale
                            }
                    )
                    .simultaneousGesture(
                        DragGesture(minimumDistance: 5)
                            .onChanged { value in
                                if scale > 1 {
                                    offset = CGSize(
                                        width: baseOffset.width + value.translation.width,
                                        height: baseOffset.height + value.translation.height
                                    )
                                } else {
                                    offset = CGSize(width: 0, height: value.translation.height)
                                }
                            }
                            .onEnded { value in
                                if scale <= 1 && value.translation.height > 80 {
                                    dismiss()
                                } else if scale > 1 {
                                    baseOffset = offset
                                } else {
                                    withAnimation(.spring(response: 0.3)) { offset = .zero }
                                    baseOffset = .zero
                                }
                            }
                    )
                    .onTapGesture(count: 2) {
                        withAnimation(.spring(response: 0.3)) {
                            if scale > 1 {
                                scale = 1; baseScale = 1
                                offset = .zero; baseOffset = .zero
                            } else {
                                scale = 3; baseScale = 3
                            }
                        }
                    }
            } else {
                ProgressView().tint(.white)
            }

            VStack {
                HStack {
                    Spacer()
                    Button { dismiss() } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 30))
                            .foregroundStyle(.white.opacity(0.85))
                            .shadow(radius: 4)
                    }
                    .padding(.top, 56)
                    .padding(.trailing, 20)
                }
                Spacer()
            }
        }
        .onAppear {
            DispatchQueue.global(qos: .userInitiated).async {
                let img = UIImage(contentsOfFile: url.path)
                DispatchQueue.main.async { image = img }
            }
        }
    }
}

// MARK: - DocumentDetailPanel (iPad inline preview)

struct DocumentDetailPanel: View {
    let doc: DocumentEntry
    @EnvironmentObject var store: AppStore

    var body: some View {
        let url = store.documentURL(for: doc.filename)
        Group {
            if doc.type == .image {
                InlineImageView(url: url)
            } else {
                QuickLookInlineView(url: url)
            }
        }
        .navigationTitle(doc.title)
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct InlineImageView: View {
    let url: URL
    @State private var image: UIImage? = nil

    var body: some View {
        Group {
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .padding()
            } else {
                ProgressView()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemBackground))
        .onAppear {
            DispatchQueue.global(qos: .userInitiated).async {
                let img = UIImage(contentsOfFile: url.path)
                DispatchQueue.main.async { image = img }
            }
        }
    }
}

struct QuickLookInlineView: UIViewControllerRepresentable {
    let url: URL

    func makeUIViewController(context: Context) -> QLPreviewController {
        let vc = QLPreviewController()
        vc.dataSource = context.coordinator
        return vc
    }

    func updateUIViewController(_ vc: QLPreviewController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(url: url) }

    class Coordinator: NSObject, QLPreviewControllerDataSource {
        let url: URL
        init(url: URL) { self.url = url }
        func numberOfPreviewItems(in controller: QLPreviewController) -> Int { 1 }
        func previewController(_ controller: QLPreviewController, previewItemAt index: Int) -> any QLPreviewItem {
            url as NSURL
        }
    }
}

// MARK: - NewDocumentSourceSheet

struct NewDocumentSourceSheet: View {
    let onSelect: (DocSource.Action) -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                Text("Hinzufügen als")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 20)
                    .padding(.top, 8)

                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                    ForEach(DocSource.all) { source in
                        Button {
                            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                            dismiss()
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                                onSelect(source.action)
                            }
                        } label: {
                            VStack(spacing: 10) {
                                Image(systemName: source.icon)
                                    .font(.system(size: 28, weight: .semibold))
                                    .foregroundStyle(NoteColor.for_(source.colorTag).accent)
                                    .frame(width: 56, height: 56)
                                    .background(NoteColor.for_(source.colorTag).bg.opacity(0.7),
                                                in: RoundedRectangle(cornerRadius: 16))
                                Text(source.label)
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundStyle(.primary)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 20)
                            .background(Color(.secondarySystemBackground))
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 20)

                Spacer()
            }
            .padding(.top, 8)
            .navigationTitle("Neues Dokument")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Abbrechen") { dismiss() }
                        .foregroundStyle(.secondary)
                }
            }
        }
        .presentationDetents([.fraction(0.45)])
        .presentationDragIndicator(.visible)
    }
}

// Sheet: Titel bestätigen + Gruppe wählen (für PDF & Bild)
struct DocumentSaveSheet: View {
    @EnvironmentObject var store: AppStore
    @Binding var title: String
    @Binding var category: String
    let onSave: () -> Void
    let onCancel: () -> Void

    var body: some View {
        NavigationStack {
            Form {
                Section("Titel") {
                    TextField("Titel", text: $title)
                }
                Section("Gruppe") {
                    Picker("Gruppe", selection: $category) {
                        ForEach(store.documentCategories, id: \.self) { cat in
                            HStack {
                                Image(systemName: categoryIcon(cat))
                                    .foregroundStyle(categoryColor(cat, overrides: store.categoryColors).accent)
                                Text(cat)
                            }.tag(cat)
                        }
                    }
                    .pickerStyle(.inline)
                    .labelsHidden()
                }
            }
            .navigationTitle("Dokument speichern")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Abbrechen", action: onCancel)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Speichern", action: onSave)
                        .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }
}

/// Gemeinsamer Picker für Fotos und Videos aus der Fotobibliothek (Mehrfachauswahl).
/// Liefert die ausgewählten Medien als temporäre Datei-URLs zurück —
/// speicherschonend, da nichts in den RAM dekodiert wird.
struct MediaPickerView: UIViewControllerRepresentable {
    /// (Bild-URLs, Video-URLs) — wird einmal nach Abschluss aller Ladevorgänge aufgerufen.
    let onPicked: (_ images: [URL], _ videos: [URL]) -> Void

    func makeUIViewController(context: Context) -> PHPickerViewController {
        var config = PHPickerConfiguration()
        config.filter = .any(of: [.images, .videos])
        config.selectionLimit = 0   // 0 = unbegrenzte Mehrfachauswahl
        let picker = PHPickerViewController(configuration: config)
        picker.delegate = context.coordinator
        return picker
    }
    func updateUIViewController(_ uiViewController: PHPickerViewController, context: Context) {}
    func makeCoordinator() -> Coordinator { Coordinator(onPicked: onPicked) }

    class Coordinator: NSObject, PHPickerViewControllerDelegate {
        let onPicked: ([URL], [URL]) -> Void
        init(onPicked: @escaping ([URL], [URL]) -> Void) { self.onPicked = onPicked }

        func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
            picker.dismiss(animated: true)
            guard !results.isEmpty else { return }

            let group = DispatchGroup()
            let lock = NSLock()
            var images: [URL] = []
            var videos: [URL] = []

            for result in results {
                let provider = result.itemProvider
                let isVideo = provider.hasItemConformingToTypeIdentifier(UTType.movie.identifier)
                let typeID = isVideo ? UTType.movie.identifier : UTType.image.identifier
                guard provider.hasItemConformingToTypeIdentifier(typeID) else { continue }
                group.enter()
                // Datei sofort wegkopieren – die gelieferte URL ist nur kurz gültig
                provider.loadFileRepresentation(forTypeIdentifier: typeID) { url, _ in
                    defer { group.leave() }
                    guard let url else { return }
                    let ext = url.pathExtension.isEmpty ? (isVideo ? "mov" : "jpg") : url.pathExtension
                    let tmp = FileManager.default.temporaryDirectory
                        .appendingPathComponent("\(UUID().uuidString).\(ext)")
                    guard (try? FileManager.default.copyItem(at: url, to: tmp)) != nil else { return }
                    lock.lock()
                    if isVideo { videos.append(tmp) } else { images.append(tmp) }
                    lock.unlock()
                }
            }

            group.notify(queue: .main) {
                self.onPicked(images, videos)
            }
        }
    }
}

struct TextDocumentInputView: View {
    @EnvironmentObject var store: AppStore
    @Binding var title: String
    @Binding var content: String
    @Binding var category: String
    let onSave: () -> Void
    @Environment(\.dismiss) var dismiss
    var body: some View {
        NavigationStack {
            Form {
                Section("Titel") {
                    TextField("Titel", text: $title)
                }
                Section("Gruppe") {
                    Picker("Gruppe", selection: $category) {
                        ForEach(store.documentCategories, id: \.self) { cat in
                            HStack {
                                Image(systemName: categoryIcon(cat))
                                    .foregroundStyle(categoryColor(cat, overrides: store.categoryColors).accent)
                                Text(cat)
                            }.tag(cat)
                        }
                    }
                    .pickerStyle(.inline)
                    .labelsHidden()
                }
                Section("Inhalt") {
                    TextEditor(text: $content)
                        .frame(minHeight: 150)
                }
            }
            .navigationTitle("Textdokument")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Abbrechen") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Speichern") { onSave() }
                        .disabled(content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }
}

// MARK: - Passwords

// MARK: - Notes

// MARK: - Notiz-Farben & Quick-Templates

struct NoteColor {
    let bg: Color
    let accent: Color
    let name: String

    // Adaptiver Hintergrund: hell im Light Mode, dunkel im Dark Mode
    private static func adaptiveBg(
        lightR: Double, lightG: Double, lightB: Double,
        darkR:  Double, darkG:  Double, darkB:  Double
    ) -> Color {
        Color(UIColor { trait in
            trait.userInterfaceStyle == .dark
                ? UIColor(red: darkR,  green: darkG,  blue: darkB,  alpha: 1)
                : UIColor(red: lightR, green: lightG, blue: lightB, alpha: 1)
        })
    }

    static let palette: [NoteColor] = [
        NoteColor(bg: adaptiveBg(lightR: 1.00, lightG: 0.94, lightB: 0.65,
                                  darkR:  0.28, darkG:  0.24, darkB:  0.04), accent: .yellow, name: "Gelb"),
        NoteColor(bg: adaptiveBg(lightR: 1.00, lightG: 0.82, lightB: 0.86,
                                  darkR:  0.35, darkG:  0.10, darkB:  0.18), accent: .pink,   name: "Rosa"),
        NoteColor(bg: adaptiveBg(lightR: 0.78, lightG: 0.89, lightB: 1.00,
                                  darkR:  0.08, darkG:  0.18, darkB:  0.38), accent: .blue,   name: "Blau"),
        NoteColor(bg: adaptiveBg(lightR: 0.83, lightG: 0.95, lightB: 0.81,
                                  darkR:  0.10, darkG:  0.28, darkB:  0.10), accent: .green,  name: "Grün"),
        NoteColor(bg: adaptiveBg(lightR: 0.89, lightG: 0.83, lightB: 1.00,
                                  darkR:  0.22, darkG:  0.12, darkB:  0.38), accent: .purple, name: "Lila"),
        NoteColor(bg: adaptiveBg(lightR: 1.00, lightG: 0.86, lightB: 0.73,
                                  darkR:  0.35, darkG:  0.20, darkB:  0.05), accent: .orange, name: "Pfirsich"),
    ]

    static func for_(_ tag: Int) -> NoteColor {
        let idx = ((tag % palette.count) + palette.count) % palette.count
        return palette[idx]
    }
}

// MARK: - Shared Add Trigger Button

struct AddTriggerButton: View {
    let label: String
    let subtitle: String
    let icon: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 9)
                        .fill(Color.blue.opacity(0.12))
                        .frame(width: 34, height: 34)
                    Image(systemName: icon)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.blue)
                }
                VStack(alignment: .leading, spacing: 1) {
                    Text(label)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.primary)
                    Text(subtitle)
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.secondary.opacity(0.6))
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 11)
            .background(Color(.secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 14))
        }
        .buttonStyle(.plain)
    }
}

struct NoteTemplate: Identifiable {
    let id = UUID()
    let emoji: String
    let label: String
    let colorTag: Int

    static let all: [NoteTemplate] = [
        NoteTemplate(emoji: "💡", label: "Idee",       colorTag: 0),  // Gelb
        NoteTemplate(emoji: "⏰", label: "Erinnerung", colorTag: 5),  // Pfirsich
        NoteTemplate(emoji: "📞", label: "Telefon",    colorTag: 2),  // Blau
        NoteTemplate(emoji: "🎯", label: "Ziel",       colorTag: 3),  // Grün
        NoteTemplate(emoji: "❓", label: "Frage",      colorTag: 4),  // Lila
        NoteTemplate(emoji: "🛒", label: "Einkauf",    colorTag: 1),  // Rosa
    ]
}

struct NotesView: View {
    @EnvironmentObject var store: AppStore
    @State private var selectedNote: NoteEntry? = nil
    @State private var showNewNote = false
    @State private var searchText = ""
    @AppStorage("notesSortOption") private var sortOption: String = "newest"
    @AppStorage("notesFilterColor") private var filterColor: Int = -1
    @State private var renamingNote: NoteEntry? = nil
    @State private var renameNoteText = ""
    @State private var shareItem: ShareURLItem? = nil

    private var filteredNotes: [NoteEntry] {
        var notes = searchText.isEmpty ? store.notes : store.notes.filter {
            $0.title.localizedCaseInsensitiveContains(searchText) ||
            $0.text.localizedCaseInsensitiveContains(searchText)
        }
        if filterColor >= 0 { notes = notes.filter { $0.colorTag == filterColor } }
        switch sortOption {
        case "oldest": notes.sort { $0.dateCreated < $1.dateCreated }
        case "az":     notes.sort { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
        case "color":  notes.sort { $0.colorTag < $1.colorTag }
        default:       notes.sort { $0.dateCreated > $1.dateCreated }
        }
        notes.sort { $0.isPinned && !$1.isPinned }
        return notes
    }

    var body: some View {
        iPhoneNotesBody
    }

    private var iPhoneNotesBody: some View {
        NavigationStack {
            VStack(spacing: 0) {
                AddTriggerButton(label: "Neue Notiz", subtitle: "Titel · Text · Farbe", icon: "plus") {
                    showNewNote = true
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .padding(.bottom, 4)
                notesList
            }
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Image(systemName: "note.text")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(.secondary)
                }
                ToolbarItem(placement: .navigationBarTrailing) { sortFilterMenu }
            }
            .sheet(isPresented: $showNewNote) {
                NewNoteSheet { title, text, color in
                    store.addNote(title: title, text: text, colorTag: color)
                    UINotificationFeedbackGenerator().notificationOccurred(.success)
                    showNewNote = false
                }
            }
            // Erfassen vom Start: „Neu"-Blatt direkt öffnen
            .onAppear {
                if store.pendingNewEntry == .notes {
                    store.pendingNewEntry = nil
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { showNewNote = true }
                }
            }
            .onChange(of: store.pendingNewEntry) { _, wert in
                // Plus gedrückt, während der Bereich schon offen ist
                if wert == .notes {
                    store.pendingNewEntry = nil
                    showNewNote = true
                }
            }
            .sheet(item: $selectedNote) { note in NoteDetailView(note: note) }
            .sheet(item: $shareItem) { item in ShareSheet(activityItems: [item.url]) }
        }
    }

    private var sortFilterMenu: some View {
        Menu {
            Picker("Sortierung", selection: $sortOption) {
                Label("Neueste zuerst", systemImage: "arrow.down").tag("newest")
                Label("Älteste zuerst", systemImage: "arrow.up").tag("oldest")
                Label("A–Z", systemImage: "textformat").tag("az")
                Label("Nach Farbe", systemImage: "paintpalette.fill").tag("color")
            }
            Divider()
            Menu {
                Button { filterColor = -1 } label: {
                    Label("Alle Farben", systemImage: filterColor == -1 ? "checkmark" : "circle")
                }
                ForEach(0..<NoteColor.palette.count, id: \.self) { idx in
                    Button { filterColor = idx } label: {
                        Label(NoteColor.palette[idx].name,
                              systemImage: filterColor == idx ? "checkmark" : "circle.fill")
                    }
                }
            } label: {
                Label(filterColor == -1 ? "Filter: Alle" : "Filter: \(NoteColor.for_(filterColor).name)",
                      systemImage: "line.3.horizontal.decrease.circle")
            }
        } label: {
            Image(systemName: filterColor == -1 ? "arrow.up.arrow.down.circle" : "line.3.horizontal.decrease.circle.fill")
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(filterColor == -1 ? Color.primary : NoteColor.for_(filterColor).accent)
        }
    }

    private var notesList: some View {
        List {
            if filteredNotes.isEmpty {
                Text(store.notes.isEmpty ? "Noch keine Notizen." : "Keine Treffer.")
                    .foregroundStyle(.secondary)
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
            } else {
                ForEach(filteredNotes) { note in
                    NoteRow(note: note)
                        .contentShape(Rectangle())
                        .onTapGesture { selectedNote = note }
                        .listRowBackground(Color(.secondarySystemBackground))
                        .listRowSeparator(.visible)
                        .listRowSeparatorTint(Color.primary.opacity(0.06))
                        .listRowInsets(EdgeInsets(top: 0, leading: 16, bottom: 0, trailing: 12))
                        .contextMenu {
                            ArcaMenue.favorit(ist: note.isFavorite) {
                                store.toggleFavorite(kind: .note, id: note.id)
                                UINotificationFeedbackGenerator().notificationOccurred(.success)
                            }
                            Divider()
                            ArcaMenue.umbenennen {
                                renameNoteText = note.title
                                renamingNote = note
                            }
                            ArcaMenue.farbe(aktuell: note.colorTag) { idx in
                                if let i = store.notes.firstIndex(where: { $0.id == note.id }) {
                                    store.notes[i].colorTag = idx
                                }
                            }
                            Button {
                                if let url = store.exportNote(note) {
                                    shareItem = ShareURLItem(url: url)
                                }
                            } label: {
                                Label("An Arca-Nutzer senden", systemImage: "person.2.fill")
                            }
                            ArcaMenue.loeschen {
                                store.notes.removeAll { $0.id == note.id }
                                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                            }
                        }
                        .swipeActions(edge: .leading) {
                            Button {
                                if let idx = store.notes.firstIndex(where: { $0.id == note.id }) {
                                    store.notes[idx].isPinned.toggle()
                                }
                            } label: {
                                Label(note.isPinned ? "Lösen" : "Anpinnen",
                                      systemImage: note.isPinned ? "pin.slash" : "pin.fill")
                            }
                            .tint(.orange)
                            Button {
                                renameNoteText = note.title
                                renamingNote = note
                            } label: {
                                Label("Umbenennen", systemImage: "pencil")
                            }
                            .tint(.blue)
                        }
                }
                .onDelete { indexSet in
                    let toDelete = indexSet.map { filteredNotes[$0] }
                    store.notes.removeAll { n in toDelete.contains { $0.id == n.id } }
                }
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .searchable(text: $searchText, prompt: "Suchen…")
        .alert("Notiz umbenennen", isPresented: Binding(
            get: { renamingNote != nil },
            set: { if !$0 { renamingNote = nil } }
        )) {
            TextField("Neuer Name", text: $renameNoteText)
            Button("Speichern") {
                if let note = renamingNote {
                    let trimmed = renameNoteText.trimmingCharacters(in: .whitespacesAndNewlines)
                    if !trimmed.isEmpty,
                       let idx = store.notes.firstIndex(where: { $0.id == note.id }) {
                        store.notes[idx].title = trimmed
                    }
                }
                renamingNote = nil
            }
            Button("Abbrechen", role: .cancel) { renamingNote = nil }
        }
    }

}

// MARK: - NoteRow

struct NoteRow: View {
    let note: NoteEntry

    var body: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(NoteColor.for_(note.colorTag).accent)
                .frame(width: 8, height: 8)
            Text(note.title.isEmpty ? "Ohne Titel" : note.title)
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(.primary)
                .lineLimit(1)
            if note.isQuickIdea {
                Text("Z")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 18, height: 18)
                    .background(Color.red)
                    .clipShape(RoundedRectangle(cornerRadius: 5))
            }
            if note.isPinned {
                Image(systemName: "pin.fill")
                    .font(.system(size: 10))
                    .foregroundStyle(.orange)
            }
            Spacer()
        }
        .padding(.vertical, 4)
        .overlay(
            note.isQuickIdea ?
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color.red.opacity(0.6), lineWidth: 1.5)
                .padding(.vertical, -2)
            : nil
        )
    }
}

struct NoteDetailView: View {
    let note: NoteEntry
    @EnvironmentObject var store: AppStore
    @Environment(\.dismiss) var dismiss

    @State private var isEditing = false
    @State private var editTitle = ""
    @State private var editText = ""
    @State private var editColor = 0
    @State private var shareItem: ShareURLItem? = nil
    @StateObject private var speech = SpeechManager()
    @State private var isChecking = false

    private var displayColor: NoteColor {
        NoteColor.for_(isEditing ? editColor : note.colorTag)
    }

    var body: some View {
        NavigationStack {
            Group {
                if isEditing {
                    VStack(spacing: 0) {
                        TextField("Überschrift", text: $editTitle)
                            .font(.title2.bold())
                            .padding()
                            .background(displayColor.bg.opacity(0.45))
                        Divider()
                        ZStack(alignment: .bottomTrailing) {
                        TextEditor(text: $editText)
                            .scrollContentBackground(.hidden)
                            .background(displayColor.bg.opacity(0.25))
                            .padding(.horizontal, 4)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                        Button {
                            speech.toggle(appendingTo: editText) { recognized in
                                editText = recognized
                            }
                        } label: {
                            Image(systemName: speech.isRecording ? "stop.circle.fill" : "mic.circle.fill")
                                .font(.system(size: 30))
                                .foregroundStyle(speech.isRecording ? .red : displayColor.accent)
                                .symbolEffect(.pulse, isActive: speech.isRecording)
                        }
                        .buttonStyle(.plain)
                        .padding(12)
                        }

                        // Farbpicker am unteren Rand
                        HStack(spacing: 10) {
                            Image(systemName: "paintpalette.fill")
                                .foregroundStyle(.secondary)
                                .font(.subheadline)
                            ForEach(0..<NoteColor.palette.count, id: \.self) { idx in
                                Button {
                                    withAnimation(.spring(response: 0.25, dampingFraction: 0.7)) {
                                        editColor = idx
                                    }
                                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                } label: {
                                    Circle()
                                        .fill(NoteColor.palette[idx].accent)
                                        .frame(width: 24, height: 24)
                                        .overlay(
                                            Circle()
                                                .stroke(.primary.opacity(0.85), lineWidth: editColor == idx ? 2 : 0)
                                        )
                                        .scaleEffect(editColor == idx ? 1.15 : 1.0)
                                }
                                .buttonStyle(.plain)
                            }
                            Spacer()
                        }
                        .padding()
                        .background(.ultraThinMaterial)
                    }
                    .animation(.easeInOut(duration: 0.25), value: editColor)
                } else {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 16) {
                            HStack(alignment: .top, spacing: 10) {
                                RoundedRectangle(cornerRadius: 3)
                                    .fill(displayColor.accent)
                                    .frame(width: 5, height: 28)
                                Text(note.title.isEmpty ? "Ohne Titel" : note.title)
                                    .font(.title2.bold())
                            }
                            Text(note.dateCreated.formatted(date: .abbreviated, time: .shortened))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Divider()
                            Text(note.text.isEmpty ? "Kein Inhalt" : note.text)
                                .font(.body)
                                .foregroundStyle(note.text.isEmpty ? .secondary : .primary)
                            Spacer()
                        }
                        .padding()
                    }
                    .background(displayColor.bg.opacity(0.18))
                }
            }
            .navigationTitle(isEditing ? "Bearbeiten" : "Notiz")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    if isEditing {
                        Button("Abbrechen") {
                            isEditing = false
                        }
                    } else {
                        Button("Fertig") { dismiss() }
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    if isEditing {
                        Button("Speichern") {
                            UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                            let updated = NoteEntry(
                                id: note.id,
                                title: editTitle,
                                text: editText,
                                isPinned: note.isPinned,
                                isFavorite: note.isFavorite,
                                dateCreated: note.dateCreated,
                                colorTag: editColor,
                                isQuickIdea: false
                            )
                            store.updateNote(updated)
                            isEditing = false
                            dismiss()
                        }
                        .disabled(editTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
                                  editText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    } else {
                        Button("Bearbeiten") {
                            editTitle = note.title
                            editText = note.text
                            editColor = note.colorTag
                            isEditing = true
                        }
                    }
                }
                ToolbarItem(placement: .navigationBarLeading) {
                    if isEditing {
                        Button {
                            isChecking = true
                            DispatchQueue.global(qos: .userInitiated).async {
                                let fixed = spellChecked(editText)
                                DispatchQueue.main.async { editText = fixed; isChecking = false }
                            }
                        } label: {
                            if isChecking {
                                ProgressView().scaleEffect(0.8)
                            } else {
                                Image(systemName: "text.badge.checkmark")
                                    .foregroundStyle(.purple)
                            }
                        }
                        .disabled(editText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isChecking)
                    }
                }
                ToolbarItem(placement: .navigationBarLeading) {
                    if !isEditing {
                        Button {
                            if let url = store.exportNote(note) {
                                shareItem = ShareURLItem(url: url)
                            }
                        } label: {
                            Image(systemName: "square.and.arrow.up")
                        }
                    }
                }
            }
            .sheet(item: $shareItem) { item in
                if FileManager.default.fileExists(atPath: item.url.path) {
                    ShareSheet(activityItems: [item.url])
                } else {
                    VStack(spacing: 16) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 40))
                            .foregroundStyle(.orange)
                        Text("Teilen fehlgeschlagen")
                            .font(.headline)
                        Text("Die Datei konnte nicht erstellt werden.")
                            .foregroundStyle(.secondary)
                        Button("Schließen") { shareItem = nil }
                            .buttonStyle(.borderedProminent)
                    }
                    .padding()
                }
            }
        }
    }

}

// MARK: - Spell Check Helper

private func spellChecked(_ text: String) -> String {
    let checker = UITextChecker()
    let language = Locale.preferredLanguages.first ?? "de"
    var corrections: [(NSRange, String)] = []
    var location = 0
    let nsText = text as NSString
    while location < nsText.length {
        let search = NSRange(location: location, length: nsText.length - location)
        let bad = checker.rangeOfMisspelledWord(in: text, range: search, startingAt: location, wrap: false, language: language)
        if bad.location == NSNotFound { break }
        if let fix = checker.guesses(forWordRange: bad, in: text, language: language)?.first {
            corrections.append((bad, fix))
        }
        location = bad.location + bad.length
    }
    var result = nsText
    for (range, fix) in corrections.reversed() {
        result = result.replacingCharacters(in: range, with: fix) as NSString
    }
    return result as String
}

// MARK: - NewNoteSheet

struct NewNoteSheet: View {
    let onSave: (String, String, Int) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var title = ""
    @State private var text = ""
    @State private var selectedColor = 0
    @FocusState private var titleFocused: Bool
    @StateObject private var speech = SpeechManager()
    @State private var isChecking = false
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {

                    // Template Chips
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(NoteTemplate.all) { template in
                                Button {
                                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                    selectedColor = template.colorTag
                                    if !title.hasPrefix(template.emoji) {
                                        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
                                        title = trimmed.isEmpty ? "\(template.emoji) " : "\(template.emoji) \(trimmed)"
                                    }
                                    titleFocused = true
                                } label: {
                                    HStack(spacing: 5) {
                                        Text(template.emoji)
                                        Text(template.label)
                                            .font(.caption.weight(.medium))
                                    }
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 6)
                                    .background(NoteColor.for_(template.colorTag).bg.opacity(0.8))
                                    .foregroundStyle(.primary)
                                    .clipShape(Capsule())
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.vertical, 2)
                    }
                    .padding(.horizontal, 20)

                    // Titel
                    TextField("Titel", text: $title)
                        .font(.system(size: 17, weight: .semibold))
                        .focused($titleFocused)
                        .padding(12)
                        .background(NoteColor.for_(selectedColor).bg.opacity(0.45))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .padding(.horizontal, 20)
                        .animation(.easeInOut(duration: 0.2), value: selectedColor)

                    // Text
                    ZStack(alignment: .topLeading) {
                        if text.isEmpty {
                            Text("Notiz…")
                                .foregroundStyle(.secondary)
                                .padding(.horizontal, 16)
                                .padding(.top, 12)
                                .allowsHitTesting(false)
                        }
                        TextEditor(text: $text)
                            .frame(minHeight: 140)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                    }
                    .background(Color(.secondarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .padding(.horizontal, 20)

                    // Diktieren + Rechtschreibung
                    HStack(spacing: 10) {
                        Button {
                            speech.toggle(appendingTo: text) { updated in text = updated }
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: speech.isRecording ? "stop.circle.fill" : "mic.fill")
                                    .font(.system(size: 15, weight: .semibold))
                                Text(speech.isRecording ? "Stoppen" : "Diktieren")
                                    .font(.system(size: 14, weight: .medium))
                            }
                            .foregroundStyle(speech.isRecording ? .red : .blue)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 9)
                            .background((speech.isRecording ? Color.red : Color.blue).opacity(0.1))
                            .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)

                        Button {
                            isChecking = true
                            DispatchQueue.global(qos: .userInitiated).async {
                                let fixed = spellChecked(text)
                                DispatchQueue.main.async { text = fixed; isChecking = false }
                            }
                        } label: {
                            HStack(spacing: 6) {
                                if isChecking {
                                    ProgressView().scaleEffect(0.75).tint(.purple)
                                } else {
                                    Image(systemName: "text.badge.checkmark")
                                        .font(.system(size: 14, weight: .semibold))
                                }
                                Text(isChecking ? "Läuft…" : "Rechtschreibung")
                                    .font(.system(size: 14, weight: .medium))
                            }
                            .foregroundStyle(.purple)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 9)
                            .background(Color.purple.opacity(0.10))
                            .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)
                        .disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isChecking)

                        Spacer()
                    }
                    .padding(.horizontal, 20)

                    // Farbauswahl
                    HStack(spacing: 10) {
                        Text("Farbe")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(.secondary)
                        HStack(spacing: 8) {
                            ForEach(0..<NoteColor.palette.count, id: \.self) { idx in
                                Button {
                                    withAnimation(.spring(response: 0.25, dampingFraction: 0.7)) {
                                        selectedColor = idx
                                    }
                                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                } label: {
                                    Circle()
                                        .fill(NoteColor.palette[idx].accent)
                                        .frame(width: 24, height: 24)
                                        .overlay(
                                            Circle()
                                                .stroke(.primary.opacity(0.85), lineWidth: selectedColor == idx ? 2 : 0)
                                        )
                                        .scaleEffect(selectedColor == idx ? 1.15 : 1.0)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        Spacer()
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 20)
                }
                .padding(.top, 16)
            }
            .navigationTitle("Neue Notiz")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Abbrechen") { dismiss() }
                        .foregroundStyle(.secondary)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Sichern") {
                        let t = title.trimmingCharacters(in: .whitespacesAndNewlines)
                        guard !t.isEmpty else { return }
                        onSave(t, text, selectedColor)
                    }
                    .font(.system(size: 15, weight: .semibold))
                    .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        .onAppear { titleFocused = true }
    }
}

// MARK: - Lists

// MARK: - Quick-Templates für Tasks

struct ListTemplate: Identifiable {
    let id = UUID()
    let emoji: String
    let label: String
    let colorTag: Int

    static let all: [ListTemplate] = [
        ListTemplate(emoji: "🛒",  label: "Einkaufen",      colorTag: 1),  // Rosa
        ListTemplate(emoji: "📅",  label: "Termin",         colorTag: 2),  // Blau
        ListTemplate(emoji: "⚠️",  label: "Nicht vergessen", colorTag: 5),  // Pfirsich
        ListTemplate(emoji: "❗",  label: "Wichtig",        colorTag: 0),  // Gelb
        ListTemplate(emoji: "👶",  label: "Kinder",         colorTag: 4),  // Lila
        ListTemplate(emoji: "👨",  label: "Mann",           colorTag: 3),  // Grün
        ListTemplate(emoji: "🚗",  label: "Auto",           colorTag: 2),  // Blau
        ListTemplate(emoji: "🏠",  label: "Haus",           colorTag: 5),  // Pfirsich
        ListTemplate(emoji: "🛍️", label: "Kaufen",         colorTag: 1),  // Rosa
    ]
}

struct ListsView: View {
    @EnvironmentObject var store: AppStore
    @State private var selectedList: ListEntry? = nil
    @State private var showNewList = false
    @State private var renamingList: ListEntry? = nil
    @State private var renameText = ""
    @State private var searchText = ""
    @AppStorage("listsSortOption") private var sortOption: String = "newest"
    @AppStorage("listsFilterColor") private var filterColor: Int = -1
    @AppStorage("listsHideCompleted") private var hideCompleted: Bool = false

    // Schnell-Eintrag über Kontextmenü
    @State private var quickAddList: ListEntry? = nil
    @State private var shareItem: ShareURLItem? = nil

    private var filteredLists: [ListEntry] {
        var lists = searchText.isEmpty ? store.lists : store.lists.filter {
            $0.title.localizedCaseInsensitiveContains(searchText) ||
            $0.items.contains { $0.text.localizedCaseInsensitiveContains(searchText) }
        }
        if filterColor >= 0 {
            lists = lists.filter { $0.colorTag == filterColor }
        }
        if hideCompleted {
            // Listen rausfiltern, die komplett erledigt sind (alle Items done) — leere Listen behalten
            lists = lists.filter { l in l.items.isEmpty || !l.items.allSatisfy(\.isDone) }
        }
        switch sortOption {
        case "oldest":   lists.sort { $0.dateCreated < $1.dateCreated }
        case "az":       lists.sort { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
        case "color":    lists.sort { $0.colorTag < $1.colorTag }
        case "progress": lists.sort {
            let a = $0.items.isEmpty ? 0.0 : Double($0.items.filter(\.isDone).count) / Double($0.items.count)
            let b = $1.items.isEmpty ? 0.0 : Double($1.items.filter(\.isDone).count) / Double($1.items.count)
            return a < b   // wenig erledigt zuerst
        }
        default:         lists.sort { $0.dateCreated > $1.dateCreated }
        }
        return lists
    }

    var body: some View {
        iPhoneListsBody
    }

    // MARK: - iPhone Layout (unverändert)

    private var iPhoneListsBody: some View {
        NavigationStack {
            VStack(spacing: 0) {
                AddTriggerButton(label: "Neue Aufgabenliste", subtitle: "Name · Vorlage · Farbe", icon: "plus") {
                    showNewList = true
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .padding(.bottom, 4)

                listsList
            }
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Image(systemName: "checklist")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(.secondary)
                }
                ToolbarItem(placement: .navigationBarTrailing) { sortFilterMenu }
            }
            .sheet(isPresented: $showNewList) {
                NewListSheet { title, color in
                    store.addList(title: title, colorTag: color)
                    UINotificationFeedbackGenerator().notificationOccurred(.success)
                    showNewList = false
                }
            }
            // Erfassen vom Start: „Neu"-Blatt direkt öffnen
            .onAppear {
                if store.pendingNewEntry == .lists {
                    store.pendingNewEntry = nil
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { showNewList = true }
                }
            }
            .onChange(of: store.pendingNewEntry) { _, wert in
                // Plus gedrückt, während der Bereich schon offen ist
                if wert == .lists {
                    store.pendingNewEntry = nil
                    showNewList = true
                }
            }
            .sheet(item: $selectedList) { list in ListDetailView(list: list) }
        }
    }

    // MARK: Sort & Filter Menu

    private var sortFilterMenu: some View {
        Menu {
            Picker("Sortierung", selection: $sortOption) {
                Label("Neueste zuerst", systemImage: "arrow.down").tag("newest")
                Label("Älteste zuerst", systemImage: "arrow.up").tag("oldest")
                Label("A–Z", systemImage: "textformat").tag("az")
                Label("Nach Farbe", systemImage: "paintpalette.fill").tag("color")
                Label("Nach Fortschritt", systemImage: "chart.bar.fill").tag("progress")
            }
            Divider()
            Toggle(isOn: $hideCompleted) {
                Label("Erledigte ausblenden", systemImage: "eye.slash")
            }
            Divider()
            Menu {
                Button {
                    filterColor = -1
                } label: {
                    Label("Alle Farben", systemImage: filterColor == -1 ? "checkmark" : "circle")
                }
                ForEach(0..<NoteColor.palette.count, id: \.self) { idx in
                    Button {
                        filterColor = idx
                    } label: {
                        Label(NoteColor.palette[idx].name,
                              systemImage: filterColor == idx ? "checkmark" : "circle.fill")
                    }
                }
            } label: {
                Label(filterColor == -1 ? "Filter: Alle" : "Filter: \(NoteColor.for_(filterColor).name)",
                      systemImage: "line.3.horizontal.decrease.circle")
            }
        } label: {
            let isActive = filterColor != -1 || hideCompleted
            Image(systemName: isActive ? "line.3.horizontal.decrease.circle.fill"
                                       : "arrow.up.arrow.down.circle")
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(filterColor == -1 ? Color.primary : NoteColor.for_(filterColor).accent)
        }
    }

    // MARK: Lists List

    private var listsList: some View {
        List {
            if filteredLists.isEmpty {
                Text(store.lists.isEmpty ? "Noch keine Listen." : "Keine Treffer.")
                    .foregroundStyle(.secondary)
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
            } else {
                ForEach(filteredLists) { list in
                    ListRow(list: list)
                            .contentShape(Rectangle())
                            .onTapGesture { selectedList = list }
                            .listRowBackground(Color(.secondarySystemBackground))
                            .listRowSeparator(.visible)
                            .listRowSeparatorTint(Color.primary.opacity(0.06))
                            .listRowInsets(EdgeInsets(top: 0, leading: 16, bottom: 0, trailing: 12))
                            .contextMenu {
                                ArcaMenue.favorit(ist: list.isFavorite) {
                                    if let idx = store.lists.firstIndex(where: { $0.id == list.id }) {
                                        store.lists[idx].isFavorite.toggle()
                                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                    }
                                }
                                Divider()
                                ArcaMenue.umbenennen {
                                    renameText = list.title
                                    renamingList = list
                                }
                                ArcaMenue.farbe(aktuell: list.colorTag) { idx in
                                    if let i = store.lists.firstIndex(where: { $0.id == list.id }) {
                                        store.lists[i].colorTag = idx
                                    }
                                }
                                Button {
                                    quickAddList = list
                                } label: {
                                    Label("Punkt hinzufügen", systemImage: "plus.circle")
                                }
                                Button {
                                    if let url = store.exportList(list) {
                                        shareItem = ShareURLItem(url: url)
                                    }
                                } label: {
                                    Label("An Arca-Nutzer senden", systemImage: "person.2.fill")
                                }
                                ArcaMenue.loeschen {
                                    store.lists.removeAll { $0.id == list.id }
                                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                                }
                            }
                            .swipeActions(edge: .trailing) {
                                Button(role: .destructive) {
                                    store.lists.removeAll { $0.id == list.id }
                                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                                } label: { Label("Löschen", systemImage: "trash") }
                            }
                            .swipeActions(edge: .leading) {
                                Button {
                                    quickAddList = list
                                } label: { Label("Eintrag", systemImage: "plus") }
                                .tint(.green)
                                Button {
                                    if let idx = store.lists.firstIndex(where: { $0.id == list.id }) {
                                        store.lists[idx].isFavorite.toggle()
                                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                    }
                                } label: {
                                    Label(list.isFavorite ? "Aus Favoriten" : "Favorit",
                                          systemImage: list.isFavorite ? "star.slash" : "star.fill")
                                }
                                .tint(.orange)
                                Button {
                                    renameText = list.title
                                    renamingList = list
                                } label: { Label("Umbenennen", systemImage: "pencil") }
                                .tint(.blue)
                            }
                }
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .searchable(text: $searchText, prompt: "Suchen…")
        .alert("Liste umbenennen", isPresented: Binding(
            get: { renamingList != nil },
            set: { if !$0 { renamingList = nil } }
        )) {
            TextField("Neuer Name", text: $renameText)
            Button("Speichern") { commitRename() }
            Button("Abbrechen", role: .cancel) { renamingList = nil }
        }
        .sheet(item: $shareItem) { item in ShareSheet(activityItems: [item.url]) }
        .sheet(item: $quickAddList) { list in
            QuickAddEntrySheet(listTitle: list.title, color: NoteColor.for_(list.colorTag)) { items in
                if let idx = store.lists.firstIndex(where: { $0.id == list.id }) {
                    for t in items {
                        store.lists[idx].items.append(ChecklistItem(text: t))
                    }
                    UINotificationFeedbackGenerator().notificationOccurred(.success)
                }
            }
        }
    }

    // MARK: Actions

    func commitRename() {
        guard let list = renamingList else { return }
        let trimmed = renameText.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty, let idx = store.lists.firstIndex(where: { $0.id == list.id }) {
            store.lists[idx].title = trimmed
        }
        renamingList = nil
    }
}

/// Zerlegt diktierten/eingegebenen Text in einzelne Listeneinträge:
/// "Butter, Käse und Milch" → Butter / Käse / Milch
func splitDictatedItems(_ raw: String) -> [String] {
    raw.replacingOccurrences(of: " und ", with: ",")
        .replacingOccurrences(of: " Und ", with: ",")
        .components(separatedBy: CharacterSet(charactersIn: ",;\n"))
        .map {
            $0.trimmingCharacters(in: .whitespacesAndNewlines)
              .trimmingCharacters(in: CharacterSet(charactersIn: ".!?"))
              .trimmingCharacters(in: .whitespacesAndNewlines)
        }
        .filter { !$0.isEmpty }
        .map { $0.prefix(1).uppercased() + $0.dropFirst() }
}

// MARK: - QuickAddEntrySheet (Schnell-Eintrag mit Diktat)

struct QuickAddEntrySheet: View {
    let listTitle: String
    let color: NoteColor
    let onAdd: ([String]) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var text = ""
    @State private var cancelled = false
    @StateObject private var speech = SpeechManager()
    @FocusState private var focused: Bool

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                HStack(spacing: 12) {
                    TextField(speech.isRecording ? "Sprich jetzt …" : "Was ist zu tun?", text: $text)
                        .focused($focused)
                        .padding(12)
                        .background(color.bg.opacity(speech.isRecording ? 0.8 : 0.5))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .onSubmit { commit() }
                    Button {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        speech.toggle(appendingTo: text) { text = $0 }
                    } label: {
                        Image(systemName: speech.isRecording ? "stop.circle.fill" : "mic.circle.fill")
                            .foregroundStyle(speech.isRecording ? Color.red : color.accent)
                            .font(.system(size: 32))
                    }
                    .buttonStyle(.plain)
                }

                Button { commit() } label: {
                    Text("Hinzufügen")
                        .font(.system(size: 16, weight: .semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(color.accent.opacity(
                            text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? 0.3 : 1))
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .buttonStyle(.plain)
                .disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

                Text("Mehrere Einträge mit Komma oder \u{201E}und\u{201C} trennen — auch beim Sprechen.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)

                Spacer()
            }
            .padding(20)
            .navigationTitle("Neuer Eintrag – \(listTitle)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Abbrechen") {
                        cancelled = true
                        speech.stopRecording()
                        dismiss()
                    }
                }
            }
            .onChange(of: speech.isRecording) { _, recording in
                // Nach dem Diktat (manuell oder per Stille-Timeout) direkt übernehmen
                if !recording, !cancelled,
                   !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    commit()
                }
            }
            .onAppear { focused = true }
            .onDisappear { speech.stopRecording() }
        }
        .presentationDetents([.fraction(0.38)])
        .presentationDragIndicator(.visible)
    }

    private func commit() {
        guard !cancelled else { return }
        let items = splitDictatedItems(text)
        guard !items.isEmpty else { return }
        onAdd(items)
        dismiss()
    }
}

// MARK: - ListRow

struct ListRow: View {
    let list: ListEntry

    var body: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(NoteColor.for_(list.colorTag).accent)
                .frame(width: 8, height: 8)
            Text(list.title)
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(.primary)
                .lineLimit(1)
            if list.isFavorite {
                Image(systemName: "star.fill")
                    .font(.system(size: 10))
                    .foregroundStyle(.orange)
            }
            Spacer()
            let done = list.items.filter(\.isDone).count
            let total = list.items.count
            if total > 0 {
                Text("\(done)/\(total)")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(done == total ? .green : .secondary)
                    .monospacedDigit()
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - NewListSheet

struct NewListSheet: View {
    let onSave: (String, Int) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var title = ""
    @State private var selectedColor = 0
    @FocusState private var titleFocused: Bool

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {

                    // Template Chips
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(ListTemplate.all) { template in
                                Button {
                                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                    selectedColor = template.colorTag
                                    title = "\(template.emoji) \(template.label)"
                                    titleFocused = true
                                } label: {
                                    HStack(spacing: 5) {
                                        Text(template.emoji)
                                        Text(template.label)
                                            .font(.caption.weight(.medium))
                                    }
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 6)
                                    .background(NoteColor.for_(template.colorTag).bg.opacity(0.8))
                                    .foregroundStyle(.primary)
                                    .clipShape(Capsule())
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.vertical, 2)
                    }
                    .padding(.horizontal, 20)

                    // Titel
                    TextField("Listenname…", text: $title)
                        .font(.system(size: 17, weight: .semibold))
                        .focused($titleFocused)
                        .padding(12)
                        .background(NoteColor.for_(selectedColor).bg.opacity(0.45))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .padding(.horizontal, 20)
                        .animation(.easeInOut(duration: 0.2), value: selectedColor)

                    // Farbauswahl
                    HStack(spacing: 10) {
                        Text("Farbe")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(.secondary)
                        HStack(spacing: 8) {
                            ForEach(0..<NoteColor.palette.count, id: \.self) { idx in
                                Button {
                                    withAnimation(.spring(response: 0.25, dampingFraction: 0.7)) {
                                        selectedColor = idx
                                    }
                                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                } label: {
                                    Circle()
                                        .fill(NoteColor.palette[idx].accent)
                                        .frame(width: 24, height: 24)
                                        .overlay(
                                            Circle()
                                                .stroke(.primary.opacity(0.85), lineWidth: selectedColor == idx ? 2 : 0)
                                        )
                                        .scaleEffect(selectedColor == idx ? 1.15 : 1.0)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        Spacer()
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 20)
                }
                .padding(.top, 16)
            }
            .navigationTitle("Neue Aufgabenliste")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Abbrechen") { dismiss() }
                        .foregroundStyle(.secondary)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Sichern") {
                        let t = title.trimmingCharacters(in: .whitespacesAndNewlines)
                        guard !t.isEmpty else { return }
                        onSave(t, selectedColor)
                    }
                    .font(.system(size: 15, weight: .semibold))
                    .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        .onAppear { titleFocused = true }
    }
}

struct CircularProgressView: View {
    let done: Int
    let total: Int
    var progress: Double { total > 0 ? Double(done) / Double(total) : 0 }

    var body: some View {
        ZStack {
            Circle().stroke(Color.secondary.opacity(0.2), lineWidth: 3)
            Circle()
                .trim(from: 0, to: progress)
                .stroke(Color.green, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                .rotationEffect(.degrees(-90))
            Text("\(Int(progress * 100))%")
                .font(.system(size: 8, weight: .bold))
                .foregroundStyle(.secondary)
        }
    }
}

struct TaskItemRow: View {
    @Binding var item: ChecklistItem
    let onToggle: () -> Void
    let onDelete: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 4)
                .fill(item.isDone ? Color.green : Color.red)
                .frame(width: 4, height: 36)

            VStack(alignment: .leading, spacing: 2) {
                Text(item.text)
                    .strikethrough(item.isDone)
                    .foregroundStyle(item.isDone ? .secondary : .primary)
                Text(item.isDone ? "Erledigt" : "Offen")
                    .font(.caption2)
                    .foregroundStyle(item.isDone ? Color.green : Color.red)
            }

            Spacer()

            Button {
                item.isDone.toggle()
                onToggle()
            } label: {
                Text(item.isDone ? "↩︎" : "Erledigt")
                    .font(.caption.bold())
                    .foregroundColor(item.isDone ? .secondary : .white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(item.isDone ? Color.secondary.opacity(0.2) : Color.green)
                    .clipShape(Capsule())
            }
            .buttonStyle(.plain)

            Button(action: onDelete) {
                Image(systemName: "trash")
                    .font(.caption)
                    .foregroundColor(.red.opacity(0.7))
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 4)
    }
}

struct ListDetailView: View {
    let list: ListEntry
    @EnvironmentObject var store: AppStore
    @Environment(\.dismiss) var dismiss
    @State private var currentList: ListEntry
    @State private var newItemText = ""
    @State private var isEditingTitle = false
    @State private var editTitle = ""
    @State private var shareItem: ShareURLItem? = nil
    @StateObject private var speech = SpeechManager()

    init(list: ListEntry) {
        self.list = list
        _currentList = State(initialValue: list)
    }

    private func addItem() {
        let trimmed = newItemText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        currentList.items.append(ChecklistItem(text: trimmed))
        store.updateList(currentList)
        newItemText = ""
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }

    /// Zerlegt diktierten Text in einzelne Einträge:
    /// "Butter, Käse und Milch" → Butter / Käse / Milch
    private func processDictation() {
        let parts = splitDictatedItems(newItemText)
        guard !parts.isEmpty else { return }
        for p in parts {
            currentList.items.append(ChecklistItem(text: p))
        }
        store.updateList(currentList)
        newItemText = ""
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }

    private var listColor: NoteColor { NoteColor.for_(currentList.colorTag) }

    private var itemInputBar: some View {
        HStack(spacing: 12) {
            TextField(speech.isRecording ? "Sprich jetzt …" : "Neuer Eintrag", text: $newItemText)
                .padding(12)
                .background(listColor.bg.opacity(speech.isRecording ? 0.8 : 0.5))
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .onSubmit { addItem() }
            Button {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                speech.toggle(appendingTo: newItemText) { updated in newItemText = updated }
            } label: {
                Image(systemName: speech.isRecording ? "stop.circle.fill" : "mic.circle.fill")
                    .foregroundStyle(speech.isRecording ? Color.red : listColor.accent)
                    .font(.system(size: 32))
            }
            Button { addItem() } label: {
                Image(systemName: "plus.circle.fill")
                    .foregroundStyle(newItemText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? Color.secondary : listColor.accent)
                    .font(.system(size: 32))
            }
            .disabled(newItemText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
        .onChange(of: speech.isRecording) { _, recording in
            if !recording { processDictation() }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(.ultraThinMaterial)
        .overlay(alignment: .top) { Divider() }
        .animation(.easeInOut(duration: 0.25), value: currentList.colorTag)
    }

    var body: some View {
        NavigationStack {
            List {
                // Farbiger Header mit Listen-Titel
                Section {
                    HStack(spacing: 10) {
                        RoundedRectangle(cornerRadius: 3)
                            .fill(listColor.accent)
                            .frame(width: 5, height: 28)
                        Text(currentList.title)
                            .font(.title3.bold())
                        Spacer()
                        if !currentList.items.isEmpty {
                            let done = currentList.items.filter(\.isDone).count
                            let total = currentList.items.count
                            Text("\(done)/\(total)")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(done == total ? .green : .secondary)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(Color.secondary.opacity(0.15), in: Capsule())
                        }
                    }
                    .listRowBackground(listColor.bg.opacity(0.4))
                    .listRowSeparator(.hidden)
                }

                Section {
                    if currentList.items.isEmpty {
                        Text("Noch keine Einträge")
                            .foregroundStyle(.secondary)
                            .listRowBackground(Color.clear)
                            .listRowSeparator(.hidden)
                    } else {
                        ForEach($currentList.items) { $item in
                            TaskItemRow(item: $item, onToggle: {
                                store.updateList(currentList)
                            }, onDelete: {
                                if let idx = currentList.items.firstIndex(where: { $0.id == item.id }) {
                                    currentList.items.remove(at: idx)
                                    store.updateList(currentList)
                                }
                            })
                            .listRowBackground(
                                item.isDone ? Color.green.opacity(0.08) : listColor.bg.opacity(0.25)
                            )
                        }
                        .onMove { from, to in
                            currentList.items.move(fromOffsets: from, toOffset: to)
                            store.updateList(currentList)
                        }
                    }
                }
                Color.clear.frame(height: 8).listRowBackground(Color.clear)
            }
            .scrollContentBackground(.hidden)
            .navigationTitle(currentList.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Fertig") { dismiss() }
                }
                ToolbarItem(placement: .primaryAction) {
                    HStack {
                        // Farbpicker-Menü
                        Menu {
                            ForEach(0..<NoteColor.palette.count, id: \.self) { idx in
                                Button {
                                    withAnimation(.easeInOut(duration: 0.25)) {
                                        currentList.colorTag = idx
                                    }
                                    store.updateList(currentList)
                                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                } label: {
                                    Label(NoteColor.palette[idx].name,
                                          systemImage: currentList.colorTag == idx ? "checkmark.circle.fill" : "circle.fill")
                                        .foregroundStyle(NoteColor.palette[idx].accent)
                                }
                            }
                        } label: {
                            Image(systemName: "paintpalette.fill")
                                .foregroundStyle(listColor.accent)
                        }
                        Button {
                            if let url = store.exportList(currentList) {
                                shareItem = ShareURLItem(url: url)
                            }
                        } label: {
                            Image(systemName: "square.and.arrow.up")
                        }
                        Button {
                            editTitle = currentList.title
                            isEditingTitle = true
                        } label: {
                            Image(systemName: "pencil")
                        }
                        EditButton()
                    }
                }
            }
            .sheet(item: $shareItem) { item in
                if FileManager.default.fileExists(atPath: item.url.path) {
                    ShareSheet(activityItems: [item.url])
                } else {
                    VStack(spacing: 16) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 40))
                            .foregroundStyle(.orange)
                        Text("Teilen fehlgeschlagen")
                            .font(.headline)
                        Text("Die Datei konnte nicht erstellt werden.")
                            .foregroundStyle(.secondary)
                        Button("Schließen") { shareItem = nil }
                            .buttonStyle(.borderedProminent)
                    }
                    .padding()
                }
            }
            .alert("Liste umbenennen", isPresented: $isEditingTitle) {
                TextField("Neuer Name", text: $editTitle)
                Button("Speichern") {
                    let trimmed = editTitle.trimmingCharacters(in: .whitespacesAndNewlines)
                    if !trimmed.isEmpty {
                        currentList.title = trimmed
                        store.updateList(currentList)
                    }
                }
                Button("Abbrechen", role: .cancel) {}
            }
        }
        .safeAreaInset(edge: .bottom) { itemInputBar }
    }
}

// MARK: - Settings

/// MARK: - Share URL Item (Identifiable wrapper — eliminates Bool+URL race condition)

struct ShareURLItem: Identifiable {
    let id = UUID()
    let url: URL
    /// true = Arca-Backup-Export mit erzwungener .arcabackup-Endung im Share-Sheet
    var isArcaBackup: Bool = false
}

#if canImport(UIKit)
import LinkPresentation

/// Share-Item für Backup-Export: erzwingt UTType + Dateiname mit .arcabackup (Speichern in Dateien-App).
final class BackupShareActivityItem: NSObject, UIActivityItemSource {
    let fileURL: URL

    init(fileURL: URL) {
        self.fileURL = fileURL
    }

    func activityViewControllerPlaceholderItem(_ activityViewController: UIActivityViewController) -> Any {
        fileURL
    }

    func activityViewController(
        _ activityViewController: UIActivityViewController,
        itemForActivityType activityType: UIActivity.ActivityType?
    ) -> Any? {
        fileURL
    }

    func activityViewController(
        _ activityViewController: UIActivityViewController,
        subjectForActivityType activityType: UIActivity.ActivityType?
    ) -> String {
        fileURL.lastPathComponent
    }

    func activityViewController(
        _ activityViewController: UIActivityViewController,
        dataTypeIdentifierForActivityType activityType: UIActivity.ActivityType?
    ) -> String {
        AppStore.arcabackupContentType.identifier
    }

    func activityViewControllerLinkMetadata(_ activityViewController: UIActivityViewController) -> LPLinkMetadata? {
        let meta = LPLinkMetadata()
        meta.title = fileURL.lastPathComponent
        meta.originalURL = fileURL
        meta.url = fileURL
        return meta
    }
}
#endif

// MARK: - Share Sheet
struct ShareSheet: UIViewControllerRepresentable {
    let activityItems: [Any]
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
    }
    func updateUIViewController(_ uvc: UIActivityViewController, context: Context) {}
}

// MARK: - Backup Import Document Picker (mit gemerktem Startordner)
struct BackupImportDocumentPicker: UIViewControllerRepresentable {
    var contentType: UTType
    var directoryURL: URL?
    var onPick: (URL) -> Void
    var onCancel: () -> Void

    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: [contentType], asCopy: true)
        picker.directoryURL = directoryURL
        picker.delegate = context.coordinator
        picker.allowsMultipleSelection = false
        return picker
    }

    func updateUIViewController(_ picker: UIDocumentPickerViewController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(onPick: onPick, onCancel: onCancel)
    }

    final class Coordinator: NSObject, UIDocumentPickerDelegate {
        let onPick: (URL) -> Void
        let onCancel: () -> Void

        init(onPick: @escaping (URL) -> Void, onCancel: @escaping () -> Void) {
            self.onPick = onPick
            self.onCancel = onCancel
        }

        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            guard let url = urls.first else {
                onCancel()
                return
            }
            onPick(url)
        }

        func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
            onCancel()
        }
    }
}

// MARK: - Stat Row (für Statistik in Settings)

struct StatRow: View {
    let icon: String
    let color: Color
    let label: String
    let value: String
    var subValue: String? = nil

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 32, height: 32)
                .background(color, in: RoundedRectangle(cornerRadius: 8))
            VStack(alignment: .leading, spacing: 1) {
                Text(label)
                    .font(.body)
                if let sub = subValue {
                    Text(sub)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
            Text(value)
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundStyle(color)
        }
        .padding(.vertical, 2)
    }
}

// MARK: - Wusstest du? Karte

struct ArcaTip {
    let icon: String
    let text: String
    let tint: Color
}

struct DidYouKnowCard: View {
    private static let tips: [ArcaTip] = [
        ArcaTip(icon: "hand.draw.fill", text: "Tippe lange auf einen Ordner, um ihn umzubenennen, einzufärben oder zu teilen.", tint: .orange),
        ArcaTip(icon: "house.fill", text: "Über „In Schnellansicht anzeigen“ legst du fest, welche Ordner auf dem Startbildschirm erscheinen.", tint: .blue),
        ArcaTip(icon: "mic.fill", text: "Notizen kannst du einfach einsprechen – Arca wandelt deine Stimme in Text um.", tint: .purple),
        ArcaTip(icon: "bolt.fill", text: "Mit der Blitzidee hältst du Gedanken in Sekunden fest, bevor sie weg sind.", tint: .yellow),
        ArcaTip(icon: "qrcode.viewfinder", text: "Der QR-Scanner auf dem Start liest Codes blitzschnell ein.", tint: .teal),
        ArcaTip(icon: "lock.shield.fill", text: "Alle Passwörter liegen sicher im iCloud-Schlüsselbund – verschlüsselt und nur für dich.", tint: .green),
        ArcaTip(icon: "icloud.fill", text: "Deine Daten synchronisieren sich automatisch zwischen iPhone und iPad.", tint: .cyan),
        ArcaTip(icon: "square.and.arrow.up.fill", text: "Sichere deinen Tresor regelmäßig über „Daten sichern“ – so bist du auch bei Geräteverlust geschützt.", tint: .indigo),
        ArcaTip(icon: "ticket.fill", text: "Lege deine Fahrkarten und Tickets in einen Ordner und zeig ihn in der Schnellansicht – am Bahnsteig sofort griffbereit.", tint: .pink),
        ArcaTip(icon: "airplane", text: "Reisedokumente wie Pass, Buchungen und Bordkarten an einem Ort – auf Reisen alles schnell zur Hand.", tint: .orange),
        ArcaTip(icon: "car.fill", text: "Führerschein, Fahrzeugschein und Versichertenkarte fotografieren – bei einer Kontrolle in Sekunden gefunden.", tint: .blue),
        ArcaTip(icon: "cross.case.fill", text: "Impfpass, Rezepte und Befunde an einem Ort – beim Arztbesuch alles sofort zur Hand.", tint: .red),
        ArcaTip(icon: "receipt.fill", text: "Kassenbons und Garantiebelege fotografieren – beim Umtausch oder Garantiefall sofort griffbereit.", tint: .green),
        ArcaTip(icon: "wifi", text: "Speichere dein WLAN-Passwort einmal – und zeig es Gästen blitzschnell, ohne langes Suchen.", tint: .cyan),
        ArcaTip(icon: "sparkles", text: "Tippe auf dem Startbildschirm mehrmals auf das Arca-Logo – vielleicht entdeckst du etwas. 🕷️", tint: .pink),
    ]

    @State private var index = Int.random(in: 0..<DidYouKnowCard.tips.count)

    private var tip: ArcaTip { Self.tips[index] }

    var body: some View {
        Button {
            withAnimation(.easeInOut(duration: 0.25)) {
                var next = index
                while next == index && Self.tips.count > 1 {
                    next = Int.random(in: 0..<Self.tips.count)
                }
                index = next
            }
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
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
            .background(tip.tint.opacity(0.08), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
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

struct RateAppRow: View {
    /// Numerische App-Store-ID von Arca. Der Knopf öffnet direkt die Bewertungsseite.
    /// Solange leer, nutzt Arca die System-Bewertungsabfrage von Apple als Fallback.
    private let appStoreID = "6764523136"

    @Environment(\.requestReview) private var requestReview

    var body: some View {
        Button {
            if !appStoreID.isEmpty,
               let url = URL(string: "https://apps.apple.com/app/id\(appStoreID)?action=write-review") {
                UIApplication.shared.open(url)
            } else {
                requestReview()
            }
        } label: {
            HStack {
                Label("Arca bewerten", systemImage: "star.fill")
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .foregroundStyle(.primary)
    }
}

struct FeedbackLinkRow: View {
    let url: URL?
    let email = "kontakt@arcavault.app"

    @State private var showCopiedAlert = false

    private var canOpenMail: Bool {
        guard let url else { return false }
        return UIApplication.shared.canOpenURL(url)
    }

    var body: some View {
        Button {
            if let url, canOpenMail {
                UIApplication.shared.open(url)
            } else {
                UIPasteboard.general.string = email
                showCopiedAlert = true
            }
        } label: {
            HStack {
                Label("Feedback senden", systemImage: "envelope.fill")
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .foregroundStyle(.primary)
        .alert("E-Mail-Adresse kopiert", isPresented: $showCopiedAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Auf diesem Gerät ist keine Mail-App eingerichtet. Schreib uns gern an \(email) – die Adresse wurde in die Zwischenablage kopiert.")
        }
    }
}

struct SettingsView: View {
    @EnvironmentObject var store: AppStore
    @AppStorage("arcaUserName") private var userName: String = ""

    /// Vom Mehr-Menü der Leiste angestoßen: Sichern oder Wiederherstellen
    /// öffnet direkt das passende Blatt.
    private func verarbeiteSettingsAktion() {
        guard let aktion = store.pendingSettingsAktion else { return }
        store.pendingSettingsAktion = nil
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
            switch aktion {
            case "export": showExportPasswordSheet = true
            case "import": showImportConfirm = true
            default: break
            }
        }
    }

    // Export flow
    @State private var showExportPasswordSheet = false
    @State private var exportPassword = ""
    @State private var exportPasswordConfirm = ""
    @State private var exportPasswordError = ""
    @State private var showExportPassword = false
    @FocusState private var exportPasswordFieldFocused: Bool
    @FocusState private var importPasswordFieldFocused: Bool
    @State private var showImportPasswordReveal = false
    @State private var importMerge = true
    @State private var exportShareItem: ShareURLItem? = nil

    // Import flow
    @State private var showImportPicker = false
    @State private var pendingImportURL: URL? = nil
    @State private var showImportPasswordSheet = false
    @State private var importPassword = ""
    @State private var showImportSuccess = false
    @State private var showImportError = false
    @State private var importErrorMessage = ""
    @State private var showReleaseNotes = false
    @State private var showImportConfirm = false
    @State private var importPickerStartFolder: URL? = nil

    private var feedbackURL: URL? {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "2.4.1"
        let subject = "Arca Feedback (Version \(version))"
        var components = URLComponents()
        components.scheme = "mailto"
        components.path = "kontakt@arcavault.app"
        components.queryItems = [URLQueryItem(name: "subject", value: subject)]
        return components.url
    }

    @ViewBuilder
    private var aboutSection: some View {
        Section {
            Button {
                showReleaseNotes = true
            } label: {
                HStack {
                    Label("Version \(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "2.4.1")", systemImage: "app.badge")
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .foregroundStyle(.primary)
            Label("Entwickler: Hans zen Ruffinen", systemImage: "person.fill")
            RateAppRow()
            FeedbackLinkRow(url: feedbackURL)
        } header: {
            Text("Über ARCA")
        } footer: {
            Text("Fragen, Wünsche oder ein Lob? Schreib mir gern – über jedes Feedback freue ich mich.")
        }
    }

    private var arcabackupType: UTType {
        AppStore.arcabackupContentType
    }

    private func backupImportErrorMessage(for url: URL, error: AppStore.BackupImportError) -> String {
        if store.isBlockedDocumentExtension(url) {
            let ext = url.pathExtension.uppercased()
            if ext == "PDF" {
                return "Das ist ein PDF-Dokument, keine Arca-Sicherung (.arcabackup). Bitte die exportierte Datei „ArcaBackup_….arcabackup“ wählen — nicht ein Dokument aus dem Tresor."
            }
            return "Das ist eine \(ext)-Datei, keine Arca-Sicherung (.arcabackup). Bitte die exportierte Backup-Datei wählen."
        }
        switch error {
        case .fileAccessDenied:
            return "Kein Zugriff auf die Datei. Bitte erneut auswählen."
        case .invalidBackupFile:
            return "Keine gültige Arca-Backup-Datei (.arcabackup). Bitte die exportierte Sicherungsdatei wählen — keine PDF oder anderes Dokument."
        case .wrongPasswordOrCorrupt, .manifestInvalid:
            return "Die Datei konnte nicht gelesen werden."
        }
    }

    private func consumePendingBackupURL() {
        guard let url = store.pendingBackupURL else { return }
        store.pendingBackupURL = nil
        beginBackupImport(from: url)
    }

    private func beginBackupImport(from url: URL) {
        store.rememberBackupFolder(containing: url)
        switch store.prepareBackupImport(from: url) {
        case .success(let staged):
            pendingImportURL = staged
            importPassword = ""
            showImportPasswordReveal = false
            // Kurz warten, bis der Dateiwähler wirklich zu ist — sonst
            // verpufft das Passwort-Blatt still (Blatt-auf-Blatt-Rennen,
            // besonders auf iPad/Mac).
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                showImportPasswordSheet = true
            }
        case .failure(let error):
            importErrorMessage = backupImportErrorMessage(for: url, error: error)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                showImportError = true
            }
        }
    }

    private func backupShareActivityItems(for item: ShareURLItem) -> [Any] {
        #if canImport(UIKit)
        if item.isArcaBackup {
            return [BackupShareActivityItem(fileURL: item.url)]
        }
        #endif
        return [item.url]
    }

    private func performBackupExport() {
        exportPasswordFieldFocused = false
        #if canImport(UIKit)
        UIApplication.shared.sendAction(
            #selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
        #endif

        let password = exportPassword
        let passwordConfirm = exportPasswordConfirm

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            guard password.count >= AppStore.minBackupPasswordLength else {
                exportPasswordError = "Das Passwort muss mindestens 4 Zeichen lang sein."
                return
            }
            guard password == passwordConfirm else {
                exportPasswordError = "Passwörter stimmen nicht überein."
                return
            }

            switch store.exportData(password: password) {
            case .success(let url):
                showExportPasswordSheet = false
                // Kurz warten bis Passwort-Sheet zu ist — sonst wird das Share-Sheet
                // von iOS ignoriert (gleiches Muster wie beim Import).
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                    exportShareItem = ShareURLItem(url: url, isArcaBackup: true)
                }
            case .failure(.passwordTooShort):
                exportPasswordError = "Das Passwort muss mindestens 4 Zeichen lang sein."
            case .failure(.archiveFailed):
                exportPasswordError = "Sicherung fehlgeschlagen. Bitte erneut versuchen."
            }
        }
    }

    private func performBackupImport() {
        importPasswordFieldFocused = false
        #if canImport(UIKit)
        UIApplication.shared.sendAction(
            #selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
        #endif

        // SecureField committet den Text erst nach Focus-Verlust — vor async einfrieren
        // (gleiches Muster wie performBackupExport).
        let password = importPassword
        let url = pendingImportURL
        let mergeMode = importMerge

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            guard let url else { return }
            switch store.importData(from: url, password: password, merge: mergeMode) {
            case .success:
                showImportPasswordSheet = false
                showImportPasswordReveal = false
                pendingImportURL = nil
                showImportSuccess = true
            case .failure(.fileAccessDenied):
                importErrorMessage = "Kein Zugriff auf die Datei. Bitte erneut auswählen."
                showImportError = true
            case .failure(.manifestInvalid):
                importErrorMessage = "Backup-Datei beschädigt (manifest.json ungültig)."
                showImportError = true
            case .failure(.wrongPasswordOrCorrupt):
                importErrorMessage = "Falsches Passwort oder beschädigte Datei."
                showImportError = true
            case .failure(.invalidBackupFile):
                importErrorMessage = "Keine gültige Arca-Backup-Datei (.arcabackup)."
                showImportError = true
            }
        }
    }

    var body: some View {
        NavigationStack {
            List {
                aboutSection

                Section {
                    HStack {
                        Label("Dein Name", systemImage: "person.fill")
                        Spacer()
                        TextField("Name", text: $userName)
                            .multilineTextAlignment(.trailing)
                            .textInputAutocapitalization(.words)
                            .frame(maxWidth: 160)
                    }
                } footer: {
                    Text("Für die Begrüßung auf dem Startbildschirm.")
                }

                Section {
                    HStack {
                        Label("iCloud", systemImage: "icloud.fill")
                        Spacer()
                        Text(store.iCloudStatus.rawValue)
                            .font(.subheadline)
                            .foregroundStyle(store.iCloudStatus == .downloading ? .orange : .secondary)
                    }
                } footer: {
                    Text("Deine Daten werden über iCloud zwischen Geräten synchronisiert. Bei „Warte auf Download“ werden Inhalte noch aus der Cloud geladen.")
                }

                // Backup — wichtigste Funktion, direkt oben
                Section {
                    Button {
                        exportPassword = ""
                        exportPasswordConfirm = ""
                        exportPasswordError = ""
                        showExportPassword = false
                        showExportPasswordSheet = true
                    } label: {
                        Label("Daten sichern", systemImage: "square.and.arrow.up.fill")
                            .foregroundStyle(.blue)
                    }

                    Button {
                        showImportConfirm = true
                    } label: {
                        Label("Daten wiederherstellen", systemImage: "square.and.arrow.down.fill")
                            .foregroundStyle(.green)
                    }
                } header: {
                    Text("Sichern und wiederherstellen")
                } footer: {
                    Text("Das Backup wird verschlüsselt gespeichert. Du kannst es in iCloud Drive, per Mail oder lokal sichern. Falls du deinen PIN vergisst und die App zurücksetzen musst, kannst du alle Daten daraus wiederherstellen.")
                }

                // Wusstest du? – wechselnde Tipps & versteckte Funktionen
                Section {
                    DidYouKnowCard()
                        .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                } footer: {
                    Label("Arca ist kostenlos, werbefrei und sammelt keine Daten über dich.", systemImage: "lock.shield.fill")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

            }
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Image(systemName: "gearshape")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(.secondary)
                }
            }

            // --- Release Notes Sheet ---
            .sheet(isPresented: $showReleaseNotes) {
                NavigationStack {
                    List {
                        Section {
                            Label("iCloud: Datenverlust beim App-Update behoben – Downloads werden vollständig abgewartet", systemImage: "icloud.fill")
                            Label("Ladehinweis beim iCloud-Download und Sync-Status in den Einstellungen", systemImage: "icloud.and.arrow.down.fill")
                            Label("Hinweis zur Datenwiederherstellung für von Update betroffene Nutzer", systemImage: "arrow.counterclockwise.icloud.fill")
                            Label("Backup teilen: Freigabe-Dialog erscheint zuverlässig nach Passworteingabe", systemImage: "square.and.arrow.up.fill")
                            Label("Verbesserter Passwortschutz für verschlüsselte Backups (HKDF/AEA)", systemImage: "lock.shield.fill")
                            Label("Import: Passworteingabe und Dateiauswahl zuverlässiger (.arcabackup)", systemImage: "square.and.arrow.down.fill")
                            Label("Falsche Dateitypen beim Import werden klar abgewiesen", systemImage: "doc.badge.gearshape.fill")
                            Label("Letzter Backup-Ordner wird gemerkt", systemImage: "folder.fill")
                            Label("Bestätigung vor dem Datenimport", systemImage: "checkmark.circle.fill")
                            Label("Passwort-Hinweise beim Sichern und Wiederherstellen", systemImage: "info.circle.fill")
                        } header: {
                            Text("Neu in Version 2.4.1")
                        }

                        Section {
                            Label("Neues, modernes App-Icon im Liquid-Glass-Stil – hell und dunkel", systemImage: "app.gift.fill")
                            Label("Frischer Startbildschirm mit wählbarer Ordner-Schnellansicht", systemImage: "square.grid.2x2.fill")
                            Label("Ordner per Drag & Drop sortieren, leere Ordner werden ausgeblendet", systemImage: "arrow.up.arrow.down")
                            Label("„Wusstest du?“-Tipps mit praktischen Anwendungen", systemImage: "lightbulb.fill")
                            Label("Feedback senden und Arca im App Store bewerten", systemImage: "star.fill")
                        } header: {
                            Text("Version 2.4.0")
                        }

                        Section {
                            Label("Videos mit Mehrfachauswahl in Dokumente importieren", systemImage: "film.stack.fill")
                            Label("Diktat-Einträge direkt in Tasklisten", systemImage: "mic.fill")
                            Label("Datei-Vorschauen für Bilder und Dokumente", systemImage: "doc.text.viewfinder")
                            Label("iCloud-Download-Handling – Dateien werden bei Bedarf nachgeladen", systemImage: "icloud.and.arrow.down.fill")
                            Label("Speicherschonendes Backup – große Archive ohne RAM-Überlast", systemImage: "externaldrive.fill.badge.checkmark")
                            Label("Einheitliche Bedienführung auf allen Seiten", systemImage: "hand.tap.fill")
                            Label("Scan-Fix und verbesserte Dokumentenerfassung", systemImage: "doc.viewfinder.fill")
                            Label("iPad-Layout optimiert, App-Store-Compliance (Guideline 4)", systemImage: "ipad")
                            Label("Undurchsichtiger Sperrbildschirm im Hintergrund", systemImage: "lock.shield.fill")
                        } header: {
                            Text("Version 2.3.0")
                        }

                        Section {
                            Label("iCloud Sync – alle Daten automatisch zwischen iPhone und iPad", systemImage: "icloud.fill")
                            Label("Passwörter, Notizen, Tasks und Dokumente auf allen Geräten synchron", systemImage: "arrow.triangle.2.circlepath")
                            Label("Offline voll nutzbar – Sync im Hintergrund sobald Verbindung besteht", systemImage: "wifi.slash")
                            Label("Bestehende Daten werden automatisch migriert – kein Datenverlust", systemImage: "checkmark.shield.fill")
                        } header: {
                            Text("Version 2.2.4")
                        }

                        Section {
                            Label("iPad: Dokumente – Master-Detail-Ansicht mit direkter Vorschau", systemImage: "doc.text.magnifyingglass")
                            Label("iPad: Tasks – Master-Detail-Ansicht, Liste und Detail nebeneinander", systemImage: "checklist")
                            Label("iPad: Alle vier Bereiche (Passwörter, Notizen, Dokumente, Tasks) als Master-Detail", systemImage: "rectangle.split.2x1")
                        } header: {
                            Text("Version 2.2.3")
                        }

                        Section {
                            Label("Einzelne Dokumente teilen, drucken & an Arca-Nutzer senden", systemImage: "square.and.arrow.up.fill")
                            Label("Untergruppen für Dokumente – volle Hierarchie (Gruppe → Untergruppe → Dokument)", systemImage: "folder.fill.badge.plus")
                            Label("Kontextmenüs auf allen Seiten komplett modernisiert", systemImage: "contextualmenu.and.cursorarrow")
                            Label("Farben für Passwörter, Notizen und Listen einzeln änderbar", systemImage: "paintpalette.fill")
                            Label("Startseite: Header mit Logo und Statistiken fixiert", systemImage: "pin.fill")
                            Label("Suchleiste ergonomisch unten auf der Startseite", systemImage: "magnifyingglass")
                            Label("Ende-zu-Ende verschlüsselt – Hinweis über Schnellzugriff", systemImage: "checkmark.shield.fill")
                            Label("Sicherheitshinweis-Badge auf Passwörter-Seite rechts neben Sortierung", systemImage: "exclamationmark.shield.fill")
                            Label("Einheitlicher + Button auf allen Seiten", systemImage: "plus.circle.fill")
                            Label("Seiten-Icons in der Navigationsleiste", systemImage: "rectangle.grid.1x2.fill")
                            Label("Release Notes hinter dem Versions-Eintrag versteckt", systemImage: "doc.text.magnifyingglass")
                            Label("Abstände kompakter – mehr Platz für Inhalte", systemImage: "arrow.up.and.down.square")
                        } header: {
                            Text("Version 2.2.2")
                        }

                        Section {
                            Label("Öffnen mit – Arca-Dateien erscheinen zuverlässig in der Auswahl", systemImage: "square.and.arrow.down.fill")
                            Label("Backup importieren – Zusammenführen oder Ersetzen wählbar", systemImage: "arrow.triangle.merge")
                            Label("Siri: Kurznotiz in Arca speichert ohne App zu öffnen", systemImage: "mic.fill")
                            Label("Siri: Ich habe eine Idee für Arca – neuer Befehl", systemImage: "lightbulb.fill")
                            Label("Bestätigung beim Speichern per Vibration & Meldung", systemImage: "checkmark.circle.fill")
                        } header: {
                            Text("Version 2.2.1")
                        }
                    }
                    .navigationTitle("Release Notes")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .confirmationAction) {
                            Button("Fertig") { showReleaseNotes = false }
                        }
                    }
                }
            }

            // --- Export: password input sheet ---
            .sheet(isPresented: $showExportPasswordSheet) {
                NavigationStack {
                    Form {
                        Section {
                            HStack {
                                Group {
                                    if showExportPassword {
                                        TextField("Passwort", text: $exportPassword)
                                    } else {
                                        SecureField("Passwort", text: $exportPassword)
                                    }
                                }
                                .focused($exportPasswordFieldFocused)
                                .autocorrectionDisabled()
                                .textInputAutocapitalization(.never)
                                .font(.system(.body, design: .monospaced))
                                .onChange(of: exportPassword) { _, _ in exportPasswordError = "" }
                                Button {
                                    showExportPassword.toggle()
                                } label: {
                                    Image(systemName: showExportPassword ? "eye.slash" : "eye")
                                        .foregroundStyle(.blue)
                                }
                                .buttonStyle(.borderless)
                            }
                            HStack {
                                Group {
                                    if showExportPassword {
                                        TextField("Passwort bestätigen", text: $exportPasswordConfirm)
                                    } else {
                                        SecureField("Passwort bestätigen", text: $exportPasswordConfirm)
                                    }
                                }
                                .autocorrectionDisabled()
                                .textInputAutocapitalization(.never)
                                .font(.system(.body, design: .monospaced))
                                .onChange(of: exportPasswordConfirm) { _, _ in exportPasswordError = "" }
                            }
                        } header: {
                            Text("Backup-Passwort festlegen")
                        } footer: {
                            VStack(alignment: .leading, spacing: 6) {
                                Text("Das Passwort muss mindestens 4 Zeichen lang sein.")
                                Text("Das Backup wird verschlüsselt. Ohne dieses Passwort kann es nicht wiederhergestellt werden.")
                            }
                        }
                        if !exportPasswordError.isEmpty {
                            Section {
                                Label(exportPasswordError, systemImage: "exclamationmark.triangle.fill")
                                    .foregroundStyle(.red)
                                    .font(.subheadline)
                            }
                        }
                    }
                    .navigationTitle("Daten sichern")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Abbrechen") {
                                exportPasswordFieldFocused = false
                                showExportPasswordSheet = false
                            }
                        }
                        ToolbarItem(placement: .confirmationAction) {
                            Button("Sichern") {
                                performBackupExport()
                            }
                            .disabled(exportPassword.isEmpty)
                        }
                    }
                }
            }

            // --- Export: share sheet ---
            .sheet(item: $exportShareItem) { item in
                if FileManager.default.fileExists(atPath: item.url.path) {
                    ShareSheet(activityItems: backupShareActivityItems(for: item))
                } else {
                    VStack(spacing: 16) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 40))
                            .foregroundStyle(.orange)
                        Text("Sicherung fehlgeschlagen")
                            .font(.headline)
                        Text("Die Backup-Datei konnte nicht erstellt werden. Bitte versuche es erneut.")
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                        Button("Schließen") { exportShareItem = nil }
                            .buttonStyle(.borderedProminent)
                            .padding(.top, 8)
                    }
                    .padding()
                }
            }

            // --- Import: file picker ---
            .alert("Daten wiederherstellen", isPresented: $showImportConfirm) {
                Button("Abbrechen", role: .cancel) {}
                Button("Fortfahren") {
                    importPickerStartFolder = store.beginAccessingRememberedBackupFolder()
                    showImportPicker = true
                }
            } message: {
                Text("Bestehende Daten werden ersetzt. Möchtest du fortfahren?")
            }
            .sheet(isPresented: $showImportPicker, onDismiss: {
                store.releaseRememberedBackupFolderAccess()
                importPickerStartFolder = nil
            }) {
                BackupImportDocumentPicker(
                    contentType: arcabackupType,
                    directoryURL: importPickerStartFolder
                ) { url in
                    showImportPicker = false
                    beginBackupImport(from: url)
                } onCancel: {
                    showImportPicker = false
                }
            }
            // Mehr-Menü in der Leiste: Sichern/Wiederherstellen direkt anspringen
            .onAppear { verarbeiteSettingsAktion() }
            .onChange(of: store.pendingSettingsAktion) { _, _ in verarbeiteSettingsAktion() }

            // "Öffnen mit .arcabackup" von aussen → Passwort-Sheet öffnen
            .onAppear { consumePendingBackupURL() }
            .onChange(of: store.pendingBackupURL) { _, url in
                guard url != nil else { return }
                consumePendingBackupURL()
            }

            // --- Import: password input sheet ---
            .sheet(isPresented: $showImportPasswordSheet) {
                NavigationStack {
                    Form {
                        Section {
                            HStack {
                                Group {
                                    if showImportPasswordReveal {
                                        TextField("Passwort", text: $importPassword)
                                    } else {
                                        SecureField("Passwort", text: $importPassword)
                                    }
                                }
                                .focused($importPasswordFieldFocused)
                                .autocorrectionDisabled()
                                .textInputAutocapitalization(.never)
                                .font(.system(.body, design: .monospaced))
                                Button {
                                    showImportPasswordReveal.toggle()
                                } label: {
                                    Image(systemName: showImportPasswordReveal ? "eye.slash" : "eye")
                                        .foregroundStyle(.blue)
                                }
                                .buttonStyle(.borderless)
                            }
                        } header: {
                            Text("Backup-Passwort eingeben")
                        } footer: {
                            Text("Gib das Passwort ein, das beim Export vergeben wurde.")
                        }

                        Section {
                            Toggle(isOn: $importMerge) {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Zusammenführen")
                                        .font(.body)
                                    Text("Bestehende Daten bleiben erhalten — nur neue Einträge werden hinzugefügt.")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        } footer: {
                            Text(importMerge
                                 ? "✓ Sicher: Vorhandene Notizen, Dokumente und Listen bleiben."
                                 : "⚠️ Alles wird durch den Backup-Stand ersetzt.")
                                .foregroundStyle(importMerge ? .green : .orange)
                        }
                    }
                    .navigationTitle("Wiederherstellen")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Abbrechen") {
                                importPasswordFieldFocused = false
                                showImportPasswordSheet = false
                                pendingImportURL = nil
                                showImportPasswordReveal = false
                            }
                        }
                        ToolbarItem(placement: .confirmationAction) {
                            Button(importMerge ? "Zusammenführen" : "Ersetzen") {
                                performBackupImport()
                            }
                            .disabled(importPassword.isEmpty)
                        }
                    }
                }
            }

            .alert("Import erfolgreich! ✅", isPresented: $showImportSuccess) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("Alle Daten wurden erfolgreich wiederhergestellt.")
            }
            .alert("Import fehlgeschlagen ❌", isPresented: $showImportError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(importErrorMessage)
            }
        }
    }
}

// MARK: - Scanner

struct DocumentScannerView: UIViewControllerRepresentable {
    let onScan: (URL) -> Void

    func makeUIViewController(context: Context) -> VNDocumentCameraViewController {
        let scanner = VNDocumentCameraViewController()
        scanner.delegate = context.coordinator
        return scanner
    }

    func updateUIViewController(_ uiViewController: VNDocumentCameraViewController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(onScan: onScan)
    }

    class Coordinator: NSObject, VNDocumentCameraViewControllerDelegate {
        let onScan: (URL) -> Void

        init(onScan: @escaping (URL) -> Void) {
            self.onScan = onScan
        }

        func documentCameraViewController(_ controller: VNDocumentCameraViewController, didFinishWith scan: VNDocumentCameraScan) {
            guard scan.pageCount > 0 else {
                controller.dismiss(animated: true)
                return
            }

            // A4-Seiten, Bild proportional eingepasst (UIGraphicsPDFRenderer
            // berücksichtigt die Bildausrichtung korrekt)
            let pageRect = CGRect(x: 0, y: 0, width: 595, height: 842)
            let renderer = UIGraphicsPDFRenderer(bounds: pageRect)
            let pdfData = renderer.pdfData { ctx in
                for i in 0..<scan.pageCount {
                    let image = scan.imageOfPage(at: i)
                    guard image.size.width > 0, image.size.height > 0 else { continue }
                    ctx.beginPage()
                    let scale = min(pageRect.width / image.size.width, pageRect.height / image.size.height)
                    let drawSize = CGSize(width: image.size.width * scale, height: image.size.height * scale)
                    let origin = CGPoint(x: (pageRect.width - drawSize.width) / 2,
                                         y: (pageRect.height - drawSize.height) / 2)
                    image.draw(in: CGRect(origin: origin, size: drawSize))
                }
            }

            let url = FileManager.default.temporaryDirectory.appendingPathComponent("\(UUID().uuidString).pdf")
            do {
                try pdfData.write(to: url, options: .atomic)
                onScan(url)
            } catch {
                controller.dismiss(animated: true)
            }
        }

        func documentCameraViewControllerDidCancel(_ controller: VNDocumentCameraViewController) {
            controller.dismiss(animated: true)
        }

        func documentCameraViewController(_ controller: VNDocumentCameraViewController, didFailWithError error: Error) {
            controller.dismiss(animated: true)
        }
    }
}

// MARK: - Farb-Picker für Gruppen

struct CategoryColorPickerSheet: View {
    let categoryName: String
    let current: Int?
    let onSelect: (Int?) -> Void

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 16), count: 3)

    var body: some View {
        VStack(spacing: 0) {
            Text("Farbe für \"\(categoryName)\"")
                .font(.headline)
                .padding(.top, 20)
                .padding(.bottom, 16)

            LazyVGrid(columns: columns, spacing: 16) {
                ForEach(0..<NoteColor.palette.count, id: \.self) { idx in
                    let nc = NoteColor.for_(idx)
                    let isSelected = current == idx
                    Button { onSelect(idx) } label: {
                        VStack(spacing: 8) {
                            Circle()
                                .fill(nc.accent)
                                .frame(width: 48, height: 48)
                                .overlay {
                                    if isSelected {
                                        Image(systemName: "checkmark")
                                            .font(.system(size: 18, weight: .bold))
                                            .foregroundStyle(.white)
                                    }
                                }
                                .overlay {
                                    Circle()
                                        .strokeBorder(nc.accent, lineWidth: isSelected ? 3 : 0)
                                        .padding(-4)
                                }
                            Text(nc.name)
                                .font(.caption.weight(isSelected ? .semibold : .regular))
                                .foregroundStyle(isSelected ? nc.accent : .secondary)
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 24)

            if current != nil {
                Button(role: .destructive) { onSelect(nil) } label: {
                    Label("Farbe zurücksetzen", systemImage: "arrow.uturn.backward")
                        .font(.subheadline)
                }
                .padding(.top, 20)
            }

            Spacer()
        }
        .presentationDetents([.fraction(0.42)])
        .presentationDragIndicator(.visible)
    }
}

// MARK: - Gruppen-Manager

func categoryIcon(_ name: String) -> String {
    switch name {
    case "Reise":      return "airplane"
    case "Papiere":    return "doc.plaintext"
    case "Rechnungen": return "eurosign.circle"
    case "Verträge":   return "signature"
    case "Gesundheit": return "heart.text.square"
    case "Unsortiert":    return "tray.fill"
    default:           return "folder"
    }
}

struct DocumentCategoryManagerRow: View {
    @EnvironmentObject var store: AppStore
    let category: String
    let onRename: () -> Void

    private var docCount: Int { store.documentCount(in: category) }
    private var inQuickView: Bool { store.isInHomeFolderQuickView(category) }

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: categoryIcon(category))
                .foregroundStyle(categoryColor(category, overrides: store.categoryColors).accent)
                .frame(width: 28)
            VStack(alignment: .leading, spacing: 2) {
                Text(category)
                if docCount > 0 {
                    Text("\(docCount) Dokument\(docCount == 1 ? "" : "e")")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    Text("Leer")
                        .font(.caption)
                        .foregroundStyle(.secondary.opacity(0.6))
                }
            }
            Spacer()
            Button { store.toggleHomeFolderQuickView(category) } label: {
                Image(systemName: inQuickView ? "house.fill" : "house")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(inQuickView ? Color.blue : (docCount > 0 ? Color.secondary : Color.secondary.opacity(0.5)))
                    .frame(width: 36, height: 36)
                    .background(Color(.secondarySystemFill), in: Circle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(inQuickView ? "Aus Start-Schnellansicht entfernen" : "In Start-Schnellansicht anzeigen")
            Button(action: onRename) {
                Image(systemName: "pencil")
                    .foregroundStyle(.blue)
            }
            .buttonStyle(.plain)
        }
    }
}

struct DocumentCategoryManagerView: View {
    @EnvironmentObject var store: AppStore
    @Environment(\.dismiss) var dismiss
    @State private var showAddAlert = false
    @State private var newCategoryName = ""
    @State private var renameTarget: String? = nil
    @State private var renameText = ""

    var body: some View {
        NavigationStack {
            List {
                ForEach(store.documentCategories, id: \.self) { cat in
                    DocumentCategoryManagerRow(category: cat) {
                        renameTarget = cat
                        renameText = cat
                    }
                }
                .onDelete { indexSet in
                    indexSet.forEach { store.deleteCategory(store.documentCategories[$0]) }
                }
                .onMove { from, to in
                    store.documentCategories.move(fromOffsets: from, toOffset: to)
                }
            }
            .navigationTitle("Gruppen verwalten")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { EditButton() }
                ToolbarItem(placement: .primaryAction) {
                    Button { showAddAlert = true } label: { Image(systemName: "plus") }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Fertig") { dismiss() }
                }
            }
            .alert("Neue Gruppe", isPresented: $showAddAlert) {
                TextField("Name", text: $newCategoryName)
                Button("Hinzufügen") {
                    let trimmed = newCategoryName.trimmingCharacters(in: .whitespacesAndNewlines)
                    if !trimmed.isEmpty && !store.documentCategories.contains(trimmed) {
                        store.documentCategories.append(trimmed)
                    }
                    newCategoryName = ""
                }
                Button("Abbrechen", role: .cancel) { newCategoryName = "" }
            }
            .alert("Gruppe umbenennen", isPresented: Binding(
                get: { renameTarget != nil },
                set: { if !$0 { renameTarget = nil } }
            )) {
                TextField("Name", text: $renameText)
                Button("Speichern") {
                    if let old = renameTarget { store.renameCategory(from: old, to: renameText) }
                    renameTarget = nil
                }
                Button("Abbrechen", role: .cancel) { renameTarget = nil }
            }
        }
    }
}

// MARK: - QuickCaptureSheet

struct QuickCaptureSheet: View {
    var autoRecord: Bool = false
    let onSave: (String, String) -> Void
    @EnvironmentObject var store: AppStore

    /// Wohin mit dem Gesprochenen? Schlüsselwörter schlagen vor,
    /// die drei Knöpfe entscheiden — Stufe 1 der schlauen Spracheingabe.
    enum ErfassungsZiel { case notiz, aufgabe, passwort }

    private let blitzOrange = Color(red: 1.00, green: 0.45, blue: 0.10)

    @Environment(\.dismiss) private var dismiss
    @StateObject private var speech = SpeechManager()
    @State private var transcribedText = ""
    @State private var savedIdeas: [String] = []
    @State private var hasStarted = false
    @State private var justSaved = false
    @State private var closeTimer: Timer? = nil
    @State private var erkanntesZiel: ErfassungsZiel = .notiz
    @State private var wartetAufZiel = false
    @State private var zielTimer: Timer? = nil

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {

                // Gespeicherte Ideen
                if !savedIdeas.isEmpty {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 8) {
                            ForEach(Array(savedIdeas.enumerated()), id: \.offset) { idx, idea in
                                HStack(alignment: .top, spacing: 10) {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundStyle(.green)
                                        .font(.callout)
                                    Text(idea)
                                        .font(.callout)
                                        .foregroundStyle(.primary)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                }
                                .padding(.horizontal)
                                .padding(.vertical, 4)
                            }
                        }
                        .padding(.vertical, 12)
                    }
                    .frame(maxHeight: 180)
                    .background(Color(.secondarySystemBackground))
                    Divider()
                }

                Spacer()

                // Mic-Button
                ZStack {
                    Circle()
                        .fill(speech.isRecording ? blitzOrange.opacity(0.12) : Color.secondary.opacity(0.07))
                        .frame(width: 130, height: 130)
                        .scaleEffect(speech.isRecording ? 1.08 : 1.0)
                        .animation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true), value: speech.isRecording)

                    Image(systemName: speech.isRecording ? "waveform" : "mic.fill")
                        .font(.system(size: 54, weight: .medium))
                        .foregroundStyle(speech.isRecording ? blitzOrange : .secondary)
                        .contentTransition(.symbolEffect(.replace))
                }
                .onTapGesture {
                    zielTimer?.invalidate()
                    zielTimer = nil
                    wartetAufZiel = false
                    if speech.isRecording {
                        speech.stopRecording()
                    } else {
                        beginRecording()
                    }
                    closeTimer?.invalidate()
                    closeTimer = nil
                }
                .padding(.bottom, 16)

                // Status
                Group {
                    if justSaved {
                        Label("Gespeichert", systemImage: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                    } else if speech.isRecording {
                        Text("Sprich deine Idee…")
                            .foregroundStyle(blitzOrange)
                    } else if transcribedText.isEmpty {
                        Text(savedIdeas.isEmpty ? "Tippen zum Starten" : "Tippen für eine weitere Idee")
                            .foregroundStyle(.secondary)
                    } else if wartetAufZiel {
                        Text(zielHinweis)
                            .foregroundStyle(blitzOrange)
                    } else {
                        Text("Tippen zum erneuten Aufnehmen")
                            .foregroundStyle(.secondary)
                    }
                }
                .font(.subheadline)
                .multilineTextAlignment(.center)
                .padding(.bottom, 12)

                // Aktueller Text
                if !transcribedText.isEmpty {
                    Text(transcribedText)
                        .font(.body)
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(blitzOrange.opacity(0.07))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .padding(.horizontal)
                        .padding(.bottom, 8)
                }

                // Wohin damit? Drei Ziele, das erkannte ist vorgewählt
                if wartetAufZiel && !transcribedText.isEmpty {
                    HStack(spacing: 8) {
                        zielKnopf(.notiz,    titel: "Notiz",    symbol: "bolt.fill")
                        zielKnopf(.aufgabe,  titel: "Aufgabe",  symbol: "checkmark.square")
                        zielKnopf(.passwort, titel: "Passwort", symbol: "key.fill")
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 8)
                }

                Spacer()
            }
            .onAppear {
                // „Halten = Diktat": Aufnahme startet sofort
                if autoRecord && !speech.isRecording { beginRecording() }
            }
            .navigationTitle("Idee?")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button {
                        speech.stopRecording()
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                            .font(.title3)
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        zielTimer?.invalidate()
                        if wartetAufZiel {
                            fuehreAus(erkanntesZiel)
                        } else {
                            saveCurrentIfNeeded()
                            speech.stopRecording()
                            dismiss()
                        }
                    } label: {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(canFinish ? blitzOrange : .secondary)
                            .font(.title3)
                    }
                    .disabled(!canFinish)
                }
            }
            // Aufnahme stoppt → Ziel erkennen; Notiz/Aufgabe speichern
            // nach kurzer Einspruchsfrist von selbst, Passwort nur per Tipp
            .onChange(of: speech.isRecording) { _, recording in
                guard !recording else { return }
                let text = transcribedText.trimmingCharacters(in: .whitespacesAndNewlines)
                if !text.isEmpty {
                    erkanntesZiel = analysiereZiel(text)
                    wartetAufZiel = true
                    if erkanntesZiel != .passwort {
                        zielTimer?.invalidate()
                        zielTimer = Timer.scheduledTimer(withTimeInterval: 2.5, repeats: false) { _ in
                            fuehreAus(erkanntesZiel)
                        }
                    }
                } else {
                    startCloseTimer()
                }
            }
            .onAppear { startIfReady() }
            .onChange(of: speech.permissionGranted) { _, granted in
                guard granted else { return }
                startIfReady()
            }
        }
    }

    private var canFinish: Bool {
        !savedIdeas.isEmpty || !transcribedText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private func startIfReady() {
        guard speech.permissionGranted, !hasStarted else { return }
        hasStarted = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { beginRecording() }
    }

    private func beginRecording() {
        closeTimer?.invalidate()
        closeTimer = nil
        transcribedText = ""
        justSaved = false
        speech.toggle(appendingTo: "") { updated in transcribedText = updated }
    }

    private func startCloseTimer() {
        closeTimer?.invalidate()
        closeTimer = Timer.scheduledTimer(withTimeInterval: 5, repeats: false) { _ in
            DispatchQueue.main.async { dismiss() }
        }
    }

    private var zielHinweis: String {
        switch erkanntesZiel {
        case .notiz:    return "Wird gleich als Notiz gespeichert — oder wähle ein Ziel"
        case .aufgabe:  return "Klingt nach Aufgaben — wird gleich zur Liste"
        case .passwort: return "Klingt nach einem Passwort — Tipp öffnet den Tresor"
        }
    }

    /// Schlüsselwort-Erkennung (Stufe 1, ohne KI, offline):
    /// „Aufgabe/Liste/Einkauf …" → Aufgabenliste, „Passwort …" → Tresor.
    private func analysiereZiel(_ text: String) -> ErfassungsZiel {
        let anfang = text.lowercased().prefix(30)
        if anfang.hasPrefix("passwort") || anfang.hasPrefix("zugang") { return .passwort }
        for wort in ["aufgabe", "aufgaben", "liste", "einkauf", "todo", "to do", "besorgen"] {
            if anfang.hasPrefix(wort) { return .aufgabe }
        }
        return .notiz
    }

    /// Führendes Schlüsselwort samt Trennzeichen entfernen.
    private func ohneSchluesselwort(_ text: String) -> String {
        var rest = text
        let woerter = ["aufgabenliste", "aufgaben", "aufgabe", "liste", "einkaufsliste",
                       "passwort", "zugang", "todo", "to do"]
        let klein = rest.lowercased()
        for wort in woerter where klein.hasPrefix(wort) {
            rest = String(rest.dropFirst(wort.count))
            break
        }
        return rest.trimmingCharacters(in: CharacterSet(charactersIn: " :,.–-"))
    }

    @ViewBuilder
    private func zielKnopf(_ ziel: ErfassungsZiel, titel: String, symbol: String) -> some View {
        let gewaehlt = erkanntesZiel == ziel
        Button {
            zielTimer?.invalidate()
            fuehreAus(ziel)
        } label: {
            HStack(spacing: 6) {
                Image(systemName: symbol)
                    .font(.system(size: 12, weight: .semibold))
                Text(titel)
                    .font(.system(size: 13, weight: .semibold))
            }
            .foregroundStyle(gewaehlt ? .white : .primary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 9)
            .background(gewaehlt ? blitzOrange : Color.secondary.opacity(0.12), in: Capsule())
        }
        .buttonStyle(.plain)
    }

    private func fuehreAus(_ ziel: ErfassungsZiel) {
        zielTimer?.invalidate()
        zielTimer = nil
        let text = transcribedText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        wartetAufZiel = false
        switch ziel {
        case .notiz:
            saveCurrentIfNeeded()
            transcribedText = ""
            justSaved = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { dismiss() }
        case .aufgabe:
            let inhalt = ohneSchluesselwort(text)
            var zeilen = inhalt
                .components(separatedBy: .newlines)
                .map { $0.trimmingCharacters(in: .whitespaces) }
                .filter { !$0.isEmpty }
            if zeilen.count <= 1 {
                // Eine gesprochene Zeile: an Kommas und „und" auftrennen
                zeilen = inhalt
                    .replacingOccurrences(of: " und ", with: ",")
                    .components(separatedBy: ",")
                    .map { $0.trimmingCharacters(in: .whitespaces) }
                    .filter { !$0.isEmpty }
            }
            let titel = zeilen.count == 1 ? "Aufgaben" : "Aufgaben \(Date().formatted(date: .abbreviated, time: .omitted))"
            let punkte = zeilen.map { ChecklistItem(text: $0.prefix(1).uppercased() + $0.dropFirst()) }
            store.lists.insert(ListEntry(title: titel, items: punkte, colorTag: 3), at: 0)
            store.homeStreamFilter = .tasks
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            transcribedText = ""
            savedIdeas.append("☑︎ \(inhalt)")
            justSaved = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { dismiss() }
        case .passwort:
            let titel = ohneSchluesselwort(text)
            store.vaultVorbefuellung = titel.isEmpty ? nil : String(titel.prefix(40))
            store.pendingNewEntry = .vault
            store.pendingSection = .vault
            speech.stopRecording()
            dismiss()
        }
    }

    private func saveCurrentIfNeeded() {
        let text = transcribedText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        onSave(String(text.prefix(50)), text)
        savedIdeas.append(text)
        // Haptisches Feedback: kurze Erfolgs-Vibration
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }
}

#Preview {
    ContentView()
        .environmentObject(AppStore())
}
