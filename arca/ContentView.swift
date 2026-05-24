//
//
//  ARCA 2.2
//  Autor: Hans Zen Ruffinen
//  Ein lokaler Mini-Tresor für Passwörter, Dokumente und Notizen.
//  Erstellt mit SwiftUI.
//

import SwiftUI
import UniformTypeIdentifiers
import QuickLook
import VisionKit

struct ContentView: View {
    @EnvironmentObject var store: AppStore
    var isUnlocked: Bool = true
    @State private var selectedSection: ArcaSection = .home
    @State private var screenHeight: CGFloat = 852   // vernünftiger Fallback, wird sofort überschrieben

    // Reihenfolge der wischbaren Tabs (settings bleibt ausgenommen — öffnet sich per Icon)
    private let swipeSections: [ArcaSection] = [.home, .vault, .documents, .notes, .lists, .settings]

    var body: some View {
        ZStack(alignment: .bottom) {
            Group {
                switch selectedSection {
                case .home:      HomeView(selectedSection: $selectedSection)
                case .vault:     VaultView()
                case .documents: DocumentsView(isUnlocked: isUnlocked)
                case .notes:     NotesView()
                case .lists:     ListsView()
                case .settings:  SettingsView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .safeAreaInset(edge: .bottom) { Color.clear.frame(height: 80) }

            ArcaTabBar(selected: $selectedSection)
        }
        .ignoresSafeArea(edges: .bottom)
        .background(
            GeometryReader { geo in
                Color.clear.onAppear { screenHeight = geo.size.height }
                    .onChange(of: geo.size.height) { _, newHeight in screenHeight = newHeight }
            }
        )
        .onChange(of: store.pendingSharedURL) { _, url in
            if url != nil { selectedSection = .documents }
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
        }
        .onChange(of: selectedSection) { _, section in
            if section != .documents { store.pendingScrollCategory = nil }
        }
        .sheet(isPresented: $store.pendingQuickCapture) {
            QuickCaptureSheet { title, text in
                store.addQuickIdea(title: title, text: text)
                UINotificationFeedbackGenerator().notificationOccurred(.success)
            }
        }
        .gesture(
            DragGesture(minimumDistance: 20, coordinateSpace: .global)
                .onEnded { value in
                    // Nur reagieren wenn Wisch im unteren Bereich startete
                    guard value.startLocation.y > screenHeight - 140 else { return }
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
    @Environment(\.colorScheme) private var colorScheme

    private let items: [ArcaTabItem] = [
        ArcaTabItem(section: .home,      icon: "house",          label: "Start",        color: .primary),
        ArcaTabItem(section: .vault,     icon: "key",            label: "Passwörter",   color: .primary),
        ArcaTabItem(section: .documents, icon: "doc.text",       label: "Dokumente",    color: .primary),
        ArcaTabItem(section: .notes,     icon: "note.text",      label: "Notizen",      color: .primary),
        ArcaTabItem(section: .lists,     icon: "checklist",      label: "Tasks",        color: .primary),
        ArcaTabItem(section: .settings,  icon: "gearshape",      label: "Einstellungen", color: .primary),
    ]

    // Nicht alle SF Symbols haben ein .fill — manuelle Ausnahmen
    private func filledIcon(_ icon: String, selected: Bool) -> String {
        guard selected else { return icon }
        let noFill = ["note.text", "checklist", "gearshape"]
        return noFill.contains(icon) ? icon : icon + ".fill"
    }

    var body: some View {
        HStack(spacing: 0) {
            ForEach(items, id: \.section) { item in
                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        selected = item.section
                    }
                } label: {
                    let isSelected = selected == item.section
                    VStack(spacing: 5) {
                        // Icon mit dezenter Pill-Highlight
                        Image(systemName: filledIcon(item.icon, selected: isSelected))
                            .font(.system(size: 19, weight: isSelected ? .semibold : .light))
                            .foregroundStyle(isSelected ? Color.primary : Color.primary.opacity(0.35))
                            .frame(width: 44, height: 28)
                            .background(
                                RoundedRectangle(cornerRadius: 10)
                                    .fill(Color.primary.opacity(isSelected ? 0.08 : 0))
                            )
                            .scaleEffect(isSelected ? 1.04 : 1.0)
                            .animation(.spring(response: 0.25, dampingFraction: 0.7), value: isSelected)

                        Text(item.label)
                            .font(.system(size: 9, weight: isSelected ? .medium : .regular))
                            .foregroundStyle(isSelected ? Color.primary : Color.primary.opacity(0.35))
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.top, 8)
                    .padding(.bottom, 2)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.bottom, 28)
        .background(.regularMaterial)
        .overlay(alignment: .top) {
            Rectangle()
                .fill(Color.primary.opacity(0.06))
                .frame(height: 0.5)
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
            case .task:     return "Tasks"
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
    @State private var showSettings = false
    @FocusState private var isSearchFocused: Bool

    // Schnellzugriff (Quick Access)
    @AppStorage("quickAccessKind") private var quickAccessKind: String = ""
    @AppStorage("quickAccessId") private var quickAccessId: String = ""
    @AppStorage("quickAccessTitle") private var quickAccessTitle: String = ""

    // Einblend-Animation — nur beim allerersten Erscheinen
    private static var hasAppeared = false
    @State private var appeared = Self.hasAppeared

    private func enterAnimation(delay: Double) -> Animation {
        .spring(response: 0.55, dampingFraction: 0.82).delay(delay)
    }

    private var isSearching: Bool {
        !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var hasQuickAccess: Bool { !quickAccessKind.isEmpty }

    private func handleQuickAccessTap() {
        if quickAccessKind == "doc" {
            if let uuid = UUID(uuidString: quickAccessId),
               let doc = store.documents.first(where: { $0.id == uuid }) {
                quickAccessPreviewURL = store.documentURL(for: doc.filename)
            } else {
                store.unpinQuickAccess()
            }
        } else if quickAccessKind == "category" {
            if store.documentCategories.contains(quickAccessId) {
                store.pendingScrollCategory = quickAccessId
                selectedSection = .documents
            } else {
                store.unpinQuickAccess()
            }
        } else if quickAccessKind == "note" {
            if let uuid = UUID(uuidString: quickAccessId),
               let note = store.notes.first(where: { $0.id == uuid }) {
                quickAccessNote = note
            } else {
                store.unpinQuickAccess()
            }
        }
    }

    // 4 Hauptkacheln in fester Reihenfolge (kein Reorder mehr)
    private let tiles: [HomeTileSpec] = [
        HomeTileSpec(id: "vault",     section: .vault,     title: "Passwörter", subtitle: "Deine Zugangsdaten\nsicher gespeichert", actionLabel: "Passwort hinzufügen", icon: "lock.fill",      colorTag: 2),
        HomeTileSpec(id: "documents", section: .documents, title: "Dokumente",  subtitle: "Ausweispapiere,\nDokumente und mehr",    actionLabel: "Dokument hinzufügen", icon: "doc.fill",       colorTag: 5),
        HomeTileSpec(id: "lists",     section: .lists,     title: "Tasks",      subtitle: "Aufgaben und\nChecklisten",              actionLabel: "Neue Aufgabe",        icon: "checklist",      colorTag: 3),
        HomeTileSpec(id: "notes",     section: .notes,     title: "Notizen",    subtitle: "Ideen, Texte und\nErinnerungen",         actionLabel: "Neue Notiz",          icon: "note.text",      colorTag: 4),
    ]

    private func count(for id: String) -> Int {
        switch id {
        case "vault":     return store.vaultItems.count
        case "documents": return store.documents.count
        case "notes":     return store.notes.count
        case "lists":     return store.lists.count
        default:          return 0
        }
    }

    private var recentActivities: [HomeActivityItem] {
        var all: [HomeActivityItem] = []
        for v in store.vaultItems {
            all.append(HomeActivityItem(id: v.id, title: v.title, kind: .password, date: v.dateCreated))
        }
        for d in store.documents {
            all.append(HomeActivityItem(id: d.id, title: d.title, kind: .document, date: d.dateAdded))
        }
        for n in store.notes {
            all.append(HomeActivityItem(id: n.id, title: n.title, kind: .note, date: n.dateCreated))
        }
        for l in store.lists {
            all.append(HomeActivityItem(id: l.id, title: l.title, kind: .task, date: l.dateCreated))
        }
        return Array(all.sorted(by: { $0.date > $1.date }).prefix(2))
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {

                    // Header
                    HStack(alignment: .center, spacing: 12) {
                        PlayfulHomeMark()
                        Text("Arca")
                            .font(.system(size: 22, weight: .bold, design: .rounded))
                            .onTapGesture {
                                logoTapCount += 1
                                if logoTapCount >= 5 {
                                    logoTapCount = 0
                                    UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
                                    showSpiderGame = true
                                }
                            }
                        Spacer()
                        HeaderStatPills(
                            vault: store.vaultItems.count,
                            documents: store.documents.count,
                            tasks: store.lists.count,
                            notes: store.notes.count
                        )
                        if store.notes.contains(where: \.isQuickIdea) {
                            Button {
                                selectedSection = .notes
                            } label: {
                                Text("Z")
                                    .font(.system(size: 12, weight: .bold))
                                    .foregroundStyle(.white)
                                    .frame(width: 24, height: 24)
                                    .background(Color.red)
                                    .clipShape(RoundedRectangle(cornerRadius: 7))
                            }
                            .buttonStyle(.plain)
                            .transition(.scale.combined(with: .opacity))
                        }
                        Button {
                            showSettings = true
                        } label: {
                            Image(systemName: "gearshape")
                                .font(.system(size: 17, weight: .light))
                                .foregroundStyle(.secondary)
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 14)
                    .padding(.bottom, 16)
                    .opacity(appeared ? 1 : 0)
                    .offset(y: appeared ? 0 : -16)
                    .animation(enterAnimation(delay: 0.0), value: appeared)

                    // Globale Suchleiste
                    HomeSearchBar(text: $searchText, focused: $isSearchFocused)
                        .padding(.horizontal, 20)
                        .padding(.bottom, 20)
                        .opacity(appeared ? 1 : 0)
                        .offset(y: appeared ? 0 : 12)
                        .animation(enterAnimation(delay: 0.07), value: appeared)

                    if isSearching {
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
                    } else {

                    // Schnellzugriff (nur wenn etwas angepinnt ist)
                    if hasQuickAccess {
                        QuickAccessTile(
                            title: quickAccessTitle,
                            kind: quickAccessKind,
                            onTap: handleQuickAccessTap,
                            onUnpin: { store.unpinQuickAccess() }
                        )
                        .padding(.horizontal, 20)
                        .padding(.bottom, 12)
                        .transition(.scale.combined(with: .opacity))
                    }

                    // 2x2 Grid der Hauptkacheln
                    LazyVGrid(
                        columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)],
                        spacing: 12
                    ) {
                        ForEach(Array(tiles.enumerated()), id: \.element.id) { idx, tile in
                            SoftHomeTile(tile: tile, count: count(for: tile.id)) {
                                selectedSection = tile.section
                            }
                            .opacity(appeared ? 1 : 0)
                            .offset(y: appeared ? 0 : 24)
                            .animation(enterAnimation(delay: 0.13 + Double(idx) * 0.07), value: appeared)
                        }
                    }
                    .padding(.horizontal, 20)

                    // QR-Code horizontale Kachel
                    QRBigTile {
                        showQRScanner = true
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 12)
                    .opacity(appeared ? 1 : 0)
                    .offset(y: appeared ? 0 : 24)
                    .animation(enterAnimation(delay: 0.41), value: appeared)

                    // Letzte Aktivitäten
                    if !recentActivities.isEmpty {
                        VStack(spacing: 0) {
                            ForEach(Array(recentActivities.enumerated()), id: \.element.id) { idx, item in
                                ActivityRow(item: item) {
                                    selectedSection = item.kind.section
                                }
                                if idx < recentActivities.count - 1 {
                                    Divider()
                                        .padding(.leading, 56)
                                }
                            }
                        }
                        .background(Color(.secondarySystemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                        .padding(.horizontal, 20)
                        .padding(.top, 12)
                        .opacity(appeared ? 1 : 0)
                        .offset(y: appeared ? 0 : 24)
                        .animation(enterAnimation(delay: 0.48), value: appeared)
                    }

                    // Status-Banner: Daten sicher
                    StatusBanner()
                        .padding(.horizontal, 20)
                        .padding(.top, 20)
                        .opacity(appeared ? 1 : 0)
                        .offset(y: appeared ? 0 : 24)
                        .animation(enterAnimation(delay: 0.54), value: appeared)

                    } // Ende des isSearching else-Blocks
                }
                .padding(.bottom, 16)
            }
            .navigationBarHidden(true)
            .onAppear {
                guard !appeared else { return }
                Self.hasAppeared = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                    appeared = true
                }
            }
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
            .animation(.spring(response: 0.4, dampingFraction: 0.75), value: hasQuickAccess)
            .animation(.easeInOut(duration: 0.2), value: isSearching)
            .sheet(isPresented: $showSettings) {
                SettingsView()
                    .environmentObject(store)
            }
        }
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
            TextField("In allen Bereichen suchen…", text: $text)
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
        .padding(.horizontal, 11)
        .padding(.vertical, 7)
        .background(Color(.secondarySystemBackground), in: Capsule())
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
                        title: "Tasks",
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

struct QuickAccessTile: View {
    let title: String
    let kind: String
    let onTap: () -> Void
    let onUnpin: () -> Void

    private var icon: String {
        switch kind {
        case "doc":      return "doc.fill"
        case "category": return "folder.fill"
        case "note":     return "note.text"
        default:         return "star.fill"
        }
    }

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                ZStack(alignment: .topTrailing) {
                    Image(systemName: icon)
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(width: 44, height: 44)
                        .background(.white.opacity(0.22), in: RoundedRectangle(cornerRadius: 11))
                    Image(systemName: "star.fill")
                        .font(.system(size: 9, weight: .black))
                        .foregroundStyle(Color(red: 1.0, green: 0.85, blue: 0.0))
                        .padding(3)
                        .background(.white, in: Circle())
                        .offset(x: 5, y: -5)
                }
                VStack(alignment: .leading, spacing: 1) {
                    Text("SCHNELLZUGRIFF")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(.white.opacity(0.9))
                        .tracking(1.0)
                    Text(title)
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                }
                Spacer()
                Image(systemName: "arrow.right.circle.fill")
                    .font(.system(size: 24))
                    .foregroundStyle(.white)
            }
            .padding(12)
            .background(
                LinearGradient(
                    colors: [
                        Color(red: 1.00, green: 0.55, blue: 0.10),  // bright orange
                        Color(red: 0.95, green: 0.25, blue: 0.30)   // red-orange
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .clipShape(RoundedRectangle(cornerRadius: 18))
            .shadow(color: Color.orange.opacity(0.45), radius: 10, x: 0, y: 5)
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button(role: .destructive, action: onUnpin) {
                Label("Lösen", systemImage: "pin.slash")
            }
        }
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
        // Einfache monochrome Zahlen — dezent, kein Farb-Overload im Header
        HStack(spacing: 8) {
            ForEach([formatted(vault), formatted(documents), formatted(tasks), formatted(notes)], id: \.self) { val in
                Text(val)
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundStyle(Color.primary.opacity(0.4))
            }
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
        NavigationStack {
            VStack(spacing: 0) {

                // "Neues Passwort" Trigger — immer sichtbar, kompakt
                Button {
                    showNewEntry = true
                } label: {
                    HStack(spacing: 12) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 9)
                                .fill(Color.blue.opacity(0.12))
                                .frame(width: 34, height: 34)
                            Image(systemName: "plus")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(.blue)
                        }
                        VStack(alignment: .leading, spacing: 1) {
                            Text("Neues Passwort")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(.primary)
                            Text("Kategorie · Zugangsdaten · Passwort")
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
                .padding(.horizontal, 20)
                .padding(.top, 14)
                .padding(.bottom, 10)

                // Liste — voller Raum
                vaultList
            }
            .navigationTitle("Passwörter")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    let weakCount = store.vaultItems.filter { $0.password.count < 8 }.count
                    let passwords = store.vaultItems.map { $0.password }
                    let dupeCount = passwords.count - Set(passwords).count
                    let total = weakCount + dupeCount
                    if total > 0 {
                        Button {
                            showSecurityAlert = true
                        } label: {
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
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    sortFilterMenu
                }
            }
            .sheet(isPresented: $showNewEntry) {
                NewVaultEntrySheet { title, username, password, url, color in
                    store.addVaultEntry(title: title, username: username,
                                       password: password, url: url, colorTag: color)
                    UINotificationFeedbackGenerator().notificationOccurred(.success)
                    showNewEntry = false
                }
            }
            .sheet(item: $selectedItem) { item in
                VaultDetailView(item: item)
            }
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
                        .swipeActions(edge: .leading) {
                            Button {
                                if let idx = store.vaultItems.firstIndex(where: { $0.id == item.id }) {
                                    store.vaultItems[idx].isFavorite.toggle()
                                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                }
                            } label: {
                                Label(item.isFavorite ? "Lösen" : "Anpinnen",
                                      systemImage: item.isFavorite ? "pin.slash" : "pin.fill")
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
            TextField("Neuer Titel", text: $renameItemText)
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
    let onSave: (String, String, String, String, Int) -> Void

    @Environment(\.dismiss) var dismiss
    @State private var title = ""
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

            // Angepinnt
            if item.isFavorite {
                Image(systemName: "pin.fill")
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
                            let updated = VaultEntry(
                                id: item.id,
                                title: editTitle.trimmingCharacters(in: .whitespacesAndNewlines),
                                username: editUsername.trimmingCharacters(in: .whitespacesAndNewlines),
                                password: editPassword.trimmingCharacters(in: .whitespacesAndNewlines),
                                url: editURL.trimmingCharacters(in: .whitespacesAndNewlines),
                                isFavorite: item.isFavorite,
                                dateCreated: item.dateCreated,
                                colorTag: editColor
                            )
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
    }
}

// Deterministische Farbe pro Kategorie-Name (gleicher Name → gleiche Farbe)
func categoryColor(_ name: String, overrides: [String: Int] = [:]) -> NoteColor {
    if let idx = overrides[name] { return NoteColor.for_(idx) }
    let hash = abs(name.hashValue)
    return NoteColor.for_(hash % NoteColor.palette.count)
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
        DocSource(id: "scan",  icon: "doc.viewfinder", label: "Scannen", colorTag: 4, action: .scan),  // Lila
        DocSource(id: "pdf",   icon: "doc.fill",       label: "PDF",     colorTag: 1, action: .pdf),   // Rosa
        DocSource(id: "image", icon: "photo.fill",     label: "Bild",    colorTag: 2, action: .image), // Blau
        DocSource(id: "text",  icon: "doc.text.fill",  label: "Text",    colorTag: 3, action: .text),  // Grün
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
    @State private var textCategory: String = "Sonstiges"
    @State private var searchText = ""

    // Zwischenspeicher für Kategorie-Auswahl nach Datei-Import
    @State private var pendingTitle = ""
    @State private var pendingFilename = ""
    @State private var pendingType: DocumentType = .pdf
    @State private var pendingCategory: String = "Sonstiges"
    @State private var showCategoryPicker = false
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
        case .pdf:   showFilePicker = true
        case .image: showImagePicker = true
        case .text:  showTextInput = true
        }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Trigger
                AddTriggerButton(label: "Neues Dokument", subtitle: "Scan · PDF · Foto · Text", icon: "doc.badge.plus") {
                    showAddMenu = true
                }
                .padding(.horizontal, 20)
                .padding(.top, 14)
                .padding(.bottom, 10)

                documentsList
            }
            .navigationTitle("Dokumente")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
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
            .fileImporter(isPresented: $showFilePicker, allowedContentTypes: [.pdf]) { result in
                handleFileImport(result: result, type: .pdf)
            }
            .sheet(isPresented: $showImagePicker) {
                ImagePickerView { image in prepareImage(image) }
            }
            .sheet(isPresented: $showScanner) {
                DocumentScannerView { pdfURL in
                    let filename = "\(UUID().uuidString).pdf"
                    let destination = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0].appendingPathComponent(filename)
                    try? FileManager.default.copyItem(at: pdfURL, to: destination)
                    pendingTitle = "Scan \(Date().formatted(date: .abbreviated, time: .omitted))"
                    pendingFilename = filename
                    pendingType = .pdf
                    pendingCategory = store.documentCategories.last ?? "Sonstiges"
                    showScanner = false
                    showCategoryPicker = true
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
                    let dest = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0].appendingPathComponent(pendingFilename)
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
                                        Text(category)
                                            .font(.system(size: 15, weight: .semibold))
                                            .foregroundStyle(.primary)
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
                                        store.pinCategoryForQuickAccess(category)
                                        UINotificationFeedbackGenerator().notificationOccurred(.success)
                                    } label: {
                                        Label("Auf Start anpinnen", systemImage: "pin.fill")
                                    }

                                    Button {
                                        colorPickerCategory = category
                                    } label: {
                                        Label("Farbe ändern", systemImage: "paintpalette")
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
                            .listRowBackground(Color(.secondarySystemBackground))
                            .listRowSeparator(isCollapsed ? .hidden : .visible)
                            .listRowSeparatorTint(Color.primary.opacity(0.06))
                            .listRowInsets(EdgeInsets(top: 0, leading: 14, bottom: 0, trailing: 12))
                            .id(category)

                            // ── Dokument-Zeilen (nur wenn aufgeklappt) ──
                            if !isCollapsed {
                                ForEach(docs) { doc in
                                    Button {
                                        if doc.type == .image {
                                            previewImageURL = store.documentURL(for: doc.filename)
                                        } else {
                                            previewURL = store.documentURL(for: doc.filename)
                                        }
                                    } label: {
                                        HStack(spacing: 12) {
                                            Circle()
                                                .fill(docTypeColor(doc.type))
                                                .frame(width: 8, height: 8)
                                            if doc.type == .image {
                                                DocThumbnail(url: store.documentURL(for: doc.filename))
                                            } else {
                                                Image(systemName: doc.type == .pdf ? "doc.fill" : "doc.text.fill")
                                                    .font(.system(size: 12, weight: .semibold))
                                                    .foregroundStyle(docTypeColor(doc.type))
                                            }
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
                                    .listRowInsets(EdgeInsets(top: 0, leading: 16, bottom: 0, trailing: 12))
                                    .contextMenu {
                                        Button {
                                            renameText = doc.title
                                            renamingDoc = doc
                                        } label: {
                                            Label("Umbenennen", systemImage: "pencil")
                                        }
                                        Menu {
                                            ForEach(store.documentCategories.filter { $0 != doc.category }, id: \.self) { targetCategory in
                                                Button {
                                                    var updated = doc
                                                    updated.category = targetCategory
                                                    if let idx = store.documents.firstIndex(where: { $0.id == doc.id }) {
                                                        store.documents[idx] = updated
                                                    }
                                                } label: {
                                                    Label(targetCategory, systemImage: categoryIcon(targetCategory))
                                                }
                                            }
                                        } label: {
                                            Label("Verschieben nach…", systemImage: "folder.fill")
                                        }
                                        Divider()
                                        Button {
                                            store.pinDocumentForQuickAccess(doc)
                                            UINotificationFeedbackGenerator().notificationOccurred(.success)
                                        } label: {
                                            Label("Auf Start anpinnen", systemImage: "pin.fill")
                                        }
                                        Divider()
                                        Button(role: .destructive) {
                                            store.deleteDocument(doc)
                                        } label: {
                                            Label("Löschen", systemImage: "trash")
                                        }
                                    }
                                }
                                .onDelete { indexSet in
                                    let toDelete = indexSet.map { docs[$0] }
                                    toDelete.forEach { store.deleteDocument($0) }
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
            .alert("Umbenennen", isPresented: Binding(
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
            .alert("Ordner umbenennen", isPresented: $showCategoryRename) {
                TextField("Neuer Name", text: $categoryRenameText)
                Button("Speichern") {
                    if let old = renamingCategory {
                        store.renameCategory(from: old, to: categoryRenameText)
                    }
                    renamingCategory = nil
                }
                Button("Abbrechen", role: .cancel) { renamingCategory = nil }
            }
            // Eingehende Datei aus Mail / Dateien-App verarbeiten
            .onAppear {
                if isUnlocked, let url = store.pendingSharedURL {
                    handleSharedURL(url)
                    store.pendingSharedURL = nil
                }
            }
            .onChange(of: store.pendingSharedURL) { _, url in
                guard let url, isUnlocked else { return }
                handleSharedURL(url)
                store.pendingSharedURL = nil
            }
            // URL verarbeiten sobald App entsperrt wird (war beim Empfang noch gesperrt)
            .onChange(of: isUnlocked) { _, unlocked in
                guard unlocked, let url = store.pendingSharedURL else { return }
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

        // Arca Backup → Passwort-Sheet im Settings-View öffnen
        if ext == "arcabackup" {
            store.pendingBackupURL = url
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
            }
            return
        }
        // Arca Aufgabenliste Import
        if ext == "arcalist" {
            if store.importList(from: url) {
                UINotificationFeedbackGenerator().notificationOccurred(.success)
            }
            return
        }

        let type: DocumentType
        switch ext {
        case "pdf":        type = .pdf
        case "jpg", "jpeg", "png", "heic", "tiff": type = .image
        default:           type = .pdf   // Fallback
        }
        let filename = "\(UUID().uuidString).\(ext.isEmpty ? "pdf" : ext)"
        let destination = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0].appendingPathComponent(filename)
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
        let destination = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0].appendingPathComponent(filename)
        try? FileManager.default.copyItem(at: url, to: destination)
        pendingTitle = url.deletingPathExtension().lastPathComponent
        pendingFilename = filename
        pendingType = type
        pendingCategory = store.documentCategories.last ?? "Sonstiges"
        showCategoryPicker = true
    }

    private func prepareImage(_ image: UIImage) {
        let filename = "\(UUID().uuidString).jpg"
        let destination = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0].appendingPathComponent(filename)
        if let data = image.jpegData(compressionQuality: 0.8) {
            try? data.write(to: destination)
            pendingTitle = "Bild \(Date().formatted(date: .abbreviated, time: .omitted))"
            pendingFilename = filename
            pendingType = .image
            pendingCategory = store.documentCategories.last ?? "Sonstiges"
            showCategoryPicker = true
        }
    }

    private func saveTextDocument() {
        let filename = "\(UUID().uuidString).txt"
        let destination = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0].appendingPathComponent(filename)
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

struct DocThumbnail: View {
    let url: URL
    @State private var image: UIImage? = nil

    var body: some View {
        Group {
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 36, height: 36)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
            } else {
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color(.tertiarySystemFill))
                    .frame(width: 36, height: 36)
                    .overlay {
                        Image(systemName: "photo")
                            .font(.system(size: 14))
                            .foregroundStyle(.secondary)
                    }
            }
        }
        .onAppear {
            if let cached = ThumbnailCache.shared.image(for: url) {
                image = cached
                return
            }
            DispatchQueue.global(qos: .utility).async {
                guard let img = UIImage(contentsOfFile: url.path) else { return }
                ThumbnailCache.shared.store(img, for: url)
                DispatchQueue.main.async { image = img }
            }
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

struct ImagePickerView: UIViewControllerRepresentable {
    let onImageSelected: (UIImage) -> Void
    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.delegate = context.coordinator
        picker.sourceType = .photoLibrary
        return picker
    }
    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}
    func makeCoordinator() -> Coordinator { Coordinator(onImageSelected: onImageSelected) }
    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let onImageSelected: (UIImage) -> Void
        init(onImageSelected: @escaping (UIImage) -> Void) { self.onImageSelected = onImageSelected }
        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            if let image = info[.originalImage] as? UIImage { onImageSelected(image) }
            picker.dismiss(animated: true)
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
        NavigationStack {
            VStack(spacing: 0) {
                // Trigger
                AddTriggerButton(label: "Neue Notiz", subtitle: "Titel · Text · Farbe", icon: "square.and.pencil") {
                    showNewNote = true
                }
                .padding(.horizontal, 20)
                .padding(.top, 14)
                .padding(.bottom, 10)

                notesList
            }
            .navigationTitle("Notizen")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) { sortFilterMenu }
            }
            .sheet(isPresented: $showNewNote) {
                NewNoteSheet { title, text, color in
                    store.addNote(title: title, text: text, colorTag: color)
                    UINotificationFeedbackGenerator().notificationOccurred(.success)
                    showNewNote = false
                }
            }
            .sheet(item: $selectedNote) { note in NoteDetailView(note: note) }
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
                            Button {
                                store.pinNoteForQuickAccess(note)
                                UINotificationFeedbackGenerator().notificationOccurred(.success)
                            } label: {
                                Label("Auf Start anpinnen", systemImage: "pin.fill")
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
            TextField("Neuer Titel", text: $renameNoteText)
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
    @FocusState private var isRenameFocused: Bool

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
        NavigationStack {
            VStack(spacing: 0) {
                // Trigger
                AddTriggerButton(label: "Neue Taskliste", subtitle: "Name · Vorlage · Farbe", icon: "checklist") {
                    showNewList = true
                }
                .padding(.horizontal, 20)
                .padding(.top, 14)
                .padding(.bottom, 10)

                listsList
            }
            .navigationTitle("Tasks")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    sortFilterMenu
                }
            }
            .sheet(isPresented: $showNewList) {
                NewListSheet { title, color in
                    store.addList(title: title, colorTag: color)
                    UINotificationFeedbackGenerator().notificationOccurred(.success)
                    showNewList = false
                }
            }
            .sheet(item: $selectedList) { list in
                ListDetailView(list: list)
            }
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
                    if renamingList?.id == list.id {
                        HStack(spacing: 12) {
                            RoundedRectangle(cornerRadius: 3)
                                .fill(NoteColor.for_(list.colorTag).accent)
                                .frame(width: 4, height: 44)
                            TextField("Name", text: $renameText)
                                .focused($isRenameFocused)
                                .font(.headline)
                                .onSubmit { commitRename() }
                            Spacer()
                            Button { commitRename() } label: {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(NoteColor.for_(list.colorTag).accent).font(.title3)
                            }
                            .buttonStyle(.plain)
                            Button { renamingList = nil } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundStyle(.secondary).font(.title3)
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.vertical, 6)
                        .listRowBackground(NoteColor.for_(list.colorTag).bg.opacity(0.45))
                        .listRowSeparator(.hidden)
                    } else {
                        ListRow(list: list)
                            .contentShape(Rectangle())
                            .onTapGesture { selectedList = list }
                            .listRowBackground(Color(.secondarySystemBackground))
                            .listRowSeparator(.visible)
                            .listRowSeparatorTint(Color.primary.opacity(0.06))
                            .listRowInsets(EdgeInsets(top: 0, leading: 16, bottom: 0, trailing: 12))
                            .swipeActions(edge: .trailing) {
                                Button(role: .destructive) {
                                    store.lists.removeAll { $0.id == list.id }
                                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                                } label: { Label("Löschen", systemImage: "trash") }
                            }
                            .swipeActions(edge: .leading) {
                                Button {
                                    if let idx = store.lists.firstIndex(where: { $0.id == list.id }) {
                                        store.lists[idx].isFavorite.toggle()
                                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                    }
                                } label: {
                                    Label(list.isFavorite ? "Lösen" : "Anpinnen",
                                          systemImage: list.isFavorite ? "pin.slash" : "pin.fill")
                                }
                                .tint(.orange)
                                Button {
                                    renameText = list.title
                                    renamingList = list
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { isRenameFocused = true }
                                } label: { Label("Umbenennen", systemImage: "pencil") }
                                .tint(.blue)
                            }
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .searchable(text: $searchText, prompt: "Suchen…")
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
                Image(systemName: "pin.fill")
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
            .navigationTitle("Neue Taskliste")
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

    private var listColor: NoteColor { NoteColor.for_(currentList.colorTag) }

    private var itemInputBar: some View {
        HStack(spacing: 12) {
            TextField("Neuer Eintrag", text: $newItemText)
                .padding(12)
                .background(listColor.bg.opacity(0.5))
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .onSubmit { addItem() }
            Button { addItem() } label: {
                Image(systemName: "plus.circle.fill")
                    .foregroundStyle(newItemText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? Color.secondary : listColor.accent)
                    .font(.system(size: 32))
            }
            .disabled(newItemText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
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
                TextField("Titel", text: $editTitle)
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
}

// MARK: - Share Sheet
struct ShareSheet: UIViewControllerRepresentable {
    let activityItems: [Any]
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
    }
    func updateUIViewController(_ uvc: UIActivityViewController, context: Context) {}
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

struct SettingsView: View {
    @EnvironmentObject var store: AppStore

    // Export flow
    @State private var showExportPasswordSheet = false
    @State private var exportPassword = ""
    @State private var exportPasswordConfirm = ""
    @State private var exportPasswordError = ""
    @State private var showExportPassword = false
    @State private var showImportPasswordReveal = false
    @State private var importMerge = true
    @State private var pendingImportURLLocal: URL? = nil  // aus "Öffnen mit" via AppStore
    @State private var showExportFailure = false
    @State private var showExportShare = false
    @State private var exportURL: URL? = nil

    // Import flow
    @State private var showImportPicker = false
    @State private var pendingImportURL: URL? = nil
    @State private var showImportPasswordSheet = false
    @State private var importPassword = ""
    @State private var showImportSuccess = false
    @State private var showImportError = false
    @State private var importErrorMessage = ""

    private var totalTasks: Int { store.lists.reduce(0) { $0 + $1.items.count } }
    private var doneTasks: Int { store.lists.reduce(0) { $0 + $1.items.filter(\.isDone).count } }

    var body: some View {
        NavigationStack {
            List {
                Section("Über ARCA") {
                    Label("Version \(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "2.2")", systemImage: "app.badge")
                    Label("© 2026 Hans Zen Ruffinen", systemImage: "c.circle")
                }

                // Statistik
                Section {
                    StatRow(icon: "key.fill",      color: NoteColor.for_(2).accent, label: "Passwörter",     value: "\(store.vaultItems.count)")
                    StatRow(icon: "doc.fill",      color: NoteColor.for_(5).accent, label: "Dokumente",      value: "\(store.documents.count)", subValue: "\(store.documentCategories.count) \(store.documentCategories.count == 1 ? "Gruppe" : "Gruppen")")
                    StatRow(icon: "note.text",     color: NoteColor.for_(4).accent, label: "Notizen",        value: "\(store.notes.count)", subValue: store.notes.contains(where: \.isPinned) ? "\(store.notes.filter(\.isPinned).count) angepinnt" : nil)
                    StatRow(icon: "checklist",     color: NoteColor.for_(3).accent, label: "Tasklisten",     value: "\(store.lists.count)", subValue: totalTasks > 0 ? "\(doneTasks) von \(totalTasks) erledigt" : nil)
                } header: {
                    Text("Deine Daten in Zahlen")
                }

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
                        showImportPicker = true
                    } label: {
                        Label("Daten wiederherstellen", systemImage: "square.and.arrow.down.fill")
                            .foregroundStyle(.green)
                    }
                } header: {
                    Text("Sichern und wiederherstellen")
                } footer: {
                    Text("Das Backup wird verschlüsselt gespeichert. Du kannst es in iCloud Drive, per Mail oder lokal sichern. Falls du deinen PIN vergisst und die App zurücksetzen musst, kannst du alle Daten daraus wiederherstellen.")
                }
            }
            .navigationTitle("Einstellungen")

            // --- Export: password input sheet ---
            .sheet(isPresented: $showExportPasswordSheet, onDismiss: {
                // Wenn Export erfolgreich war (URL gesetzt), öffne ShareSheet
                if exportURL != nil {
                    showExportShare = true
                }
            }) {
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
                                .autocorrectionDisabled()
                                .textInputAutocapitalization(.never)
                                .font(.system(.body, design: .monospaced))
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
                            }
                        } header: {
                            Text("Backup-Passwort festlegen")
                        } footer: {
                            Text("Das Backup wird verschlüsselt. Ohne dieses Passwort kann es nicht wiederhergestellt werden.")
                        }
                        if !exportPasswordError.isEmpty {
                            Section {
                                Text(exportPasswordError)
                                    .foregroundStyle(.red)
                            }
                        }
                    }
                    .navigationTitle("Daten sichern")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Abbrechen") {
                                exportURL = nil      // verhindert, dass danach das ShareSheet aufgeht
                                showExportPasswordSheet = false
                            }
                        }
                        ToolbarItem(placement: .confirmationAction) {
                            Button("Sichern") {
                                guard exportPassword.count >= 4 else {
                                    exportPasswordError = "Mindestens 4 Zeichen erforderlich."
                                    return
                                }
                                guard exportPassword == exportPasswordConfirm else {
                                    exportPasswordError = "Passwörter stimmen nicht überein."
                                    return
                                }
                                if let url = store.exportData(password: exportPassword) {
                                    exportURL = url
                                    showExportPasswordSheet = false   // onDismiss öffnet dann ShareSheet
                                } else {
                                    exportPasswordError = "Sicherung fehlgeschlagen. Bitte erneut versuchen."
                                }
                            }
                            .disabled(exportPassword.isEmpty)
                        }
                    }
                }
            }

            // --- Export: share sheet ---
            .sheet(isPresented: $showExportShare, onDismiss: {
                exportURL = nil  // aufräumen
            }) {
                if let url = exportURL {
                    ShareSheet(activityItems: [url])
                } else {
                    // Fallback falls URL doch nil ist — zeigt Fehler statt weißem Sheet
                    VStack(spacing: 16) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 40))
                            .foregroundStyle(.orange)
                        Text("Sicherung fehlgeschlagen")
                            .font(.headline)
                        Text("Bitte versuche es erneut.")
                            .foregroundStyle(.secondary)
                        Button("Schließen") { showExportShare = false }
                            .buttonStyle(.borderedProminent)
                            .padding(.top, 8)
                    }
                    .padding()
                }
            }

            // --- Import: file picker ---
            .fileImporter(
                isPresented: $showImportPicker,
                allowedContentTypes: [.data]
            ) { result in
                if case .success(let url) = result {
                    pendingImportURL = url
                    importPassword = ""
                    showImportPasswordSheet = true
                }
            }

            // "Öffnen mit .arcabackup" von aussen → Passwort-Sheet öffnen
            .onChange(of: store.pendingBackupURL) { _, url in
                guard let url else { return }
                pendingImportURL = url
                importPassword = ""
                store.pendingBackupURL = nil
                showImportPasswordSheet = true
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
                                showImportPasswordSheet = false
                                pendingImportURL = nil
                                showImportPasswordReveal = false
                            }
                        }
                        ToolbarItem(placement: .confirmationAction) {
                            Button(importMerge ? "Zusammenführen" : "Ersetzen") {
                                guard let url = pendingImportURL else { return }
                                showImportPasswordSheet = false
                                showImportPasswordReveal = false
                                let mergeMode = importMerge
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                    if store.importData(from: url, password: importPassword, merge: mergeMode) {
                                        showImportSuccess = true
                                    } else {
                                        importErrorMessage = "Falsches Passwort oder beschädigte Datei."
                                        showImportError = true
                                    }
                                    pendingImportURL = nil
                                }
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
            let pdfData = NSMutableData()
            let pdfConsumer = CGDataConsumer(data: pdfData)!
            var mediaBox = CGRect(origin: .zero, size: CGSize(width: 595, height: 842))
            guard let pdfContext = CGContext(consumer: pdfConsumer, mediaBox: &mediaBox, nil) else { return }

            for i in 0..<scan.pageCount {
                let image = scan.imageOfPage(at: i)
                guard let cgImage = image.cgImage else { continue }
                let imgRect = CGRect(origin: .zero, size: CGSize(width: 595, height: 842))
                pdfContext.beginPage(mediaBox: &mediaBox)
                pdfContext.draw(cgImage, in: imgRect)
                pdfContext.endPage()
            }
            pdfContext.closePDF()

            let url = FileManager.default.temporaryDirectory.appendingPathComponent("\(UUID().uuidString).pdf")
            pdfData.write(to: url, atomically: true)
            onScan(url)
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
    default:           return "folder"
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
                    HStack {
                        Image(systemName: categoryIcon(cat))
                            .foregroundStyle(categoryColor(cat, overrides: store.categoryColors).accent)
                            .frame(width: 28)
                        Text(cat)
                        Spacer()
                        Button {
                            renameTarget = cat
                            renameText = cat
                        } label: {
                            Image(systemName: "pencil")
                                .foregroundStyle(.blue)
                        }
                        .buttonStyle(.plain)
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
    let onSave: (String, String) -> Void

    private let blitzOrange = Color(red: 1.00, green: 0.45, blue: 0.10)

    @Environment(\.dismiss) private var dismiss
    @StateObject private var speech = SpeechManager()
    @State private var transcribedText = ""
    @State private var savedIdeas: [String] = []
    @State private var hasStarted = false
    @State private var justSaved = false
    @State private var closeTimer: Timer? = nil

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

                Spacer()
            }
            .navigationTitle("⚡ Blitzideen")
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
                        saveCurrentIfNeeded()
                        speech.stopRecording()
                        dismiss()
                    } label: {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(canFinish ? blitzOrange : .secondary)
                            .font(.title3)
                    }
                    .disabled(!canFinish)
                }
            }
            // Auto-Speichern wenn Aufnahme stoppt
            .onChange(of: speech.isRecording) { _, recording in
                guard !recording else { return }
                let text = transcribedText.trimmingCharacters(in: .whitespacesAndNewlines)
                if !text.isEmpty {
                    saveCurrentIfNeeded()
                    transcribedText = ""
                    justSaved = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { dismiss() }
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
