//
//  Start.swift
//  Arca
//
//  Der Start (Space): Kopf, Hero, Kalender, Suche, Favoriten, Strom.
//  (Aus ContentView.swift herausgelöst — Code unverändert.)
//
//  Entwickler: Hans zen Ruffinen
//

import SwiftUI
import UniformTypeIdentifiers
import QuickLook
import EventKit

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
            case .note:     return "lightbulb.fill"
            case .task:     return "checklist"
            }
        }
        var label: String {
            switch self {
            case .password: return "Passwörter"
            case .document: return "Dokumente"
            case .note:     return "Ideen"
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
    @State private var showAlleFavoriten = false
    @State private var sichtbareDokKarte: String? = nil
    @State private var showSpiderGame = false
    @State private var logoTapCount = 0
    @State private var quickAccessPreviewURL: URL? = nil
    @State private var quickAccessNote: NoteEntry? = nil
    @State private var searchText = ""
    @FocusState private var isSearchFocused: Bool
    @State private var sucheOffen = false
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
    /// Welche Gruppe gerade ein neues Symbol wählt (nil = Wähler zu)
    private struct SymbolZiel: Identifiable { let id = UUID(); let name: String }
    @State private var symbolZiel: SymbolZiel? = nil
    @State private var sortiereGruppen = false

    /// Was aufzuräumen ist: alles in „Unsortiert" PLUS Waisen,
    /// deren Gruppe es nicht mehr gibt — wie der Unsortiert-Balken zählt.
    private var unsortierteAnzahl: Int {
        let bekannte = Set(store.documentCategories)
        return store.documents.filter {
            $0.category == "Unsortiert" || !bekannte.contains($0.category)
        }.count
    }
    @State private var backupSnoozeSignal = 0
    @State private var gezogeneBlase: HomeStreamFilter? = nil
    @State private var ziehZielGruppe: String? = nil
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
                                    Label(ziel, image: store.iconFor(ziel))
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

    /// Der Schreibtisch wohnt rechts: die App rückt nach links, beide
    /// Flächen (Zu erledigen · Schnellzugriff) teilen sich den freien Raum.
    /// Je breiter das Fenster, desto größer die Flächen — sie wachsen
    /// ungedeckelt mit dem Fenster-Zoom.
    private var deskZonenBreite: CGFloat {
        let frei = seitenBreite - homeContentMaxWidth - 44
        return (frei - 16) / 2
    }

    private var deskSichtbar: Bool {
        horizontalSizeClass == .regular && deskZonenBreite >= 165
    }

    @ViewBuilder
    private var homeDeskFlaechen: some View {
        if deskSichtbar {
            HStack(alignment: .top, spacing: 10) {
                ArcaDeskRail(seite: "links",
                             selectedSection: $selectedSection,
                             breite: deskZonenBreite)
                ArcaDeskRail(seite: "rechts",
                             selectedSection: $selectedSection,
                             breite: deskZonenBreite)
            }
            .padding(.top, 6)
        }
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
    @ViewBuilder
    private var dokumentKarussell: some View {
        VStack(alignment: .leading, spacing: 12) {
            if dokumentGruppen.isEmpty {
                Text("Noch keine Dokumente — oben rechts wartet das Dokument-Plus.")
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 8)
            } else {
                if unsortierteAnzahl > 0 {
                    Button {
                        store.zeigeAufraeumen = true
                    } label: {
                        HStack(spacing: 7) {
                            Image(systemName: "sparkles")
                                .font(.system(size: 14, weight: .semibold))
                            Text("Aufräumen")
                                .font(.system(size: 13, weight: .bold))
                            Text("\(unsortierteAnzahl)")
                                .font(.system(size: 11, weight: .bold))
                                .padding(.horizontal, 7)
                                .padding(.vertical, 2)
                                .background(Color.white.opacity(0.25), in: Capsule())
                            Spacer()
                            Image(systemName: "arrow.right")
                                .font(.system(size: 12, weight: .bold))
                        }
                        .foregroundStyle(.white)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 11)
                        .background(
                            LinearGradient(
                                colors: [Color(red: 0.85, green: 0.62, blue: 0.30), ArcaWarm.terrakotta],
                                startPoint: .topLeading, endPoint: .bottomTrailing),
                            in: RoundedRectangle(cornerRadius: 12))
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal, 20)
                }

                // Eine Reihe, läuft nach rechts durch (kein Titel — der Chip sagt schon „Dokumente")
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(dokumentGruppen, id: \.name) { gruppe in
                            ArcaKategorieKarte(
                                name: gruppe.name,
                                icon: store.iconFor(gruppe.name),
                                farben: categoryColor(gruppe.name, overrides: store.categoryColors),
                                anzahl: gruppe.anzahl)
                            .id(gruppe.name)
                            .contentShape(RoundedRectangle(cornerRadius: 15))
                            .onTapGesture { openDocuments(category: gruppe.name) }
                            .wennDraggable(gruppe.name != "Unsortiert", gruppe.name)
                            .dropDestination(for: String.self) { eingeworfen, _ in
                                verarbeiteAblage(eingeworfen, aufGruppe: gruppe.name)
                            }
                            .contextMenu {
                                Button {
                                    symbolZiel = SymbolZiel(name: gruppe.name)
                                } label: {
                                    Label("Symbol ändern", systemImage: "square.grid.2x2")
                                }
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
                        }
                        Button {
                            docFuerNeueGruppe = nil
                            neueGruppeName = ""
                            showNeueGruppe = true
                        } label: {
                            ArcaKategorieHinzufuegenKarte()
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal, 20)
                    .scrollTargetLayout()
                }
                .scrollPosition(id: $sichtbareDokKarte, anchor: .leading)

                // Seiten-Punkte
                if dokumentGruppen.count > 1 {
                    HStack(spacing: 6) {
                        ForEach(dokumentGruppen, id: \.name) { g in
                            Circle()
                                .fill((sichtbareDokKarte ?? dokumentGruppen.first?.name) == g.name
                                      ? ArcaWarm.terrakotta.opacity(0.85)
                                      : Color.secondary.opacity(0.25))
                                .frame(width: 6, height: 6)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.top, 6)

                    // Dreh-Regler in der Farbe der aktiven Gruppe + „virtual crown"-Gag
                    let aktiveGruppe = sichtbareDokKarte ?? dokumentGruppen.first?.name ?? "Unsortiert"
                    let radFarbe = categoryColor(aktiveGruppe, overrides: store.categoryColors).accent
                    VStack(spacing: 3) {
                        ArcaDrehregler(breite: 210, hoehe: 38, tint: radFarbe) { dir in
                            let namen = dokumentGruppen.map { $0.name }
                            guard !namen.isEmpty else { return }
                            let cur = sichtbareDokKarte.flatMap { namen.firstIndex(of: $0) } ?? 0
                            let neu = min(max(cur + dir, 0), namen.count - 1)
                            if neu != cur {
                                withAnimation(.easeOut(duration: 0.25)) { sichtbareDokKarte = namen[neu] }
                            }
                        }
                        HStack(spacing: 4) {
                            Text("virtual crown")
                                .font(.system(size: 9, weight: .medium, design: .rounded))
                                .italic()
                                .foregroundStyle(.secondary)
                            ArcaSmiley(farbe: radFarbe.opacity(0.85))
                                .frame(width: 15, height: 11)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.top, 8)
                }
            }
        }
    }

    private func favSymbol(_ kind: FavoriteKind) -> String {
        switch kind {
        case .document: return "ArcaDocument"
        case .note:     return "ArcaIdee"
        case .list:     return "ArcaChecklist"
        case .vault:    return "ArcaKey"
        }
    }
    private func favFarbe(_ kind: FavoriteKind) -> Color {
        switch kind {
        case .document: return .orange
        case .note:     return ArcaWarm.ideenGelb
        case .list:     return .green
        case .vault:    return .blue
        }
    }

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
        store.fokusKategorie = category
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
                                        subtitle: n.isQuickIdea ? "Blitzidee" : "Idee",
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

                // Die Lupe: holt das Suchfeld hervor und schickt es wieder weg
                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        sucheOffen.toggle()
                    }
                    if sucheOffen {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                            isSearchFocused = true
                        }
                    } else {
                        searchText = ""
                        isSearchFocused = false
                    }
                } label: {
                    ArcaIcon(name: sucheOffen ? "xmark" : "ArcaSearch", groesse: 17)
                        .foregroundStyle(sucheOffen ? ArcaWarm.terrakotta : .primary)
                        .frame(width: 36, height: 36)
                        .glassEffect(.regular, in: Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Alles durchsuchen")

                // Notfall immer griffbereit: Notrufnummern + Karten sperren
                Button {
                    store.zeigeNotfall = true
                } label: {
                    Image(systemName: "cross.case.fill")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.red)
                        .frame(width: 36, height: 36)
                        .glassEffect(.regular, in: Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Notfall")

                // Erfassen läuft sonst komplett über den Plus unten
                Button { showQRScanner = true } label: {
                    ArcaIcon(name: "ArcaScan", groesse: 18)
                        .foregroundStyle(.primary)
                        .frame(width: 36, height: 36)
                        .glassEffect(.regular, in: Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("QR-Code scannen")

                // Zahnrad: auf iPad/Mac ist die Seitenleiste oft zu —
                // die Einstellungen bleiben trotzdem einen Tipp entfernt
                if horizontalSizeClass == .regular {
                    Button {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
                            selectedSection = .settings
                        }
                    } label: {
                        ArcaIcon(name: "ArcaSettings", groesse: 18)
                            .foregroundStyle(.primary)
                            .frame(width: 36, height: 36)
                            .glassEffect(.regular, in: Circle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Einstellungen")
                }
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

            // ── Die Suche kommt nur auf Ruf der Lupe ──
            if sucheOffen || isSearching {
                HomeSearchBar(text: $searchText, focused: $isSearchFocused)
                    .padding(.horizontal, 20)
                    .padding(.bottom, 12)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
            }
            .frame(maxWidth: homeContentMaxWidth)
            .frame(maxWidth: .infinity, alignment: deskSichtbar ? .leading : .center)
            .padding(.leading, deskSichtbar ? 16 : 0)

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
                        HStack {
                            ArcaSectionTitle(title: "Favoriten", icon: "ArcaStar")
                            Spacer()
                        }
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
                            Text("angepinnt für den schnellen Zugriff")
                                .font(.system(size: 12))
                                .foregroundStyle(.secondary)
                                .padding(.leading, 32)
                                .padding(.top, -4)
                        }
                    }
                    .transition(.scale.combined(with: .opacity))
                    .id("seitenAnfang")


                    // ── Der Strom: alle Einträge gemischt, Filter statt Räume ──
                    VStack(alignment: .leading, spacing: 10) {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 6) {
                                // Reihenfolge ist frei sortierbar: Blase gedrückt
                                // halten und an die Wunschposition ziehen
                                ForEach(store.bereichsOrdnung, id: \.self) { filter in
                                    Group {
                                        // Schicke Liquid-Glass-Blasen (iOS 26/27): gewählt = in ihrer
                                        // Bereichsfarbe getöntes Glas, die übrigen als klares Glas
                                        let blasenFarbe: Color = switch filter {
                                        case .dokumente:   NoteColor.for_(5).accent
                                        case .notizen:     ArcaWarm.ideenGelb
                                        case .tasks:       NoteColor.for_(3).accent
                                        case .passwoerter: NoteColor.for_(2).accent
                                        }
                                        if streamFilter == filter {
                                            Text(filter.label)
                                                .font(.system(size: 13, weight: .semibold))
                                                .foregroundStyle(.white)
                                                .padding(.horizontal, 15)
                                                .padding(.vertical, 8)
                                                .glassEffect(.regular.tint(blasenFarbe).interactive(), in: Capsule())
                                        } else {
                                            Text(filter.label)
                                                .font(.system(size: 13, weight: .medium))
                                                .foregroundStyle(.primary.opacity(0.7))
                                                .padding(.horizontal, 15)
                                                .padding(.vertical, 8)
                                                .glassEffect(.regular.interactive(), in: Capsule())
                                        }
                                    }
                                    .contentShape(Rectangle())
                                    // Doppeltipp auf „Ideen" öffnet die Pinnwand
                                    .onTapGesture(count: 2) {
                                        if filter == .notizen {
                                            store.homeStreamFilter = .notizen
                                            withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                                                store.zeigeIdeenPinnwand = true
                                            }
                                        }
                                    }
                                    .onTapGesture {
                                        withAnimation(.easeInOut(duration: 0.2)) {
                                            store.homeStreamFilter = filter
                                            streamLimit = 25
                                        }
                                    }
                                    .onDrag {
                                        gezogeneBlase = filter
                                        return NSItemProvider(object: filter.rawValue as NSString)
                                    }
                                    .onDrop(of: [.text], delegate: BlasenTauschDelegate(
                                        ziel: filter, gezogen: $gezogeneBlase, store: store))
                                }
                            }
                            .padding(.horizontal, 20)
                        }

                        if streamFilter == .dokumente {
                            dokumentKarussell
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
                                    // Ziehbar auf den Schreibtisch (iPad/Mac)
                                    .wennDraggable(item.kind != .vault, item.id.uuidString)
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
                                                        Label("Feste Idee", systemImage: "lightbulb.fill")
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
                    .frame(maxWidth: .infinity, alignment: deskSichtbar ? .leading : .center)
                    .padding(.leading, deskSichtbar ? 16 : 0)
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
        .sheet(item: $symbolZiel) { ziel in
            CategoryIconPickerSheet(
                categoryName: ziel.name,
                current: store.categoryIcons[ziel.name],
                farbe: categoryColor(ziel.name, overrides: store.categoryColors)
            ) { symbol in
                if let symbol {
                    store.categoryIcons[ziel.name] = symbol
                } else {
                    store.categoryIcons.removeValue(forKey: ziel.name)
                }
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                symbolZiel = nil
            }
            .environmentObject(store)
        }
        .sheet(isPresented: $showAlleFavoriten) {
            NavigationStack {
                List {
                    ForEach(store.favoriteItems) { fav in
                        Button {
                            showAlleFavoriten = false
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { openFavorite(fav) }
                        } label: {
                            HStack(spacing: 12) {
                                ArcaIcon(name: favSymbol(fav.kind), groesse: 17)
                                    .foregroundStyle(favFarbe(fav.kind))
                                    .frame(width: 34, height: 34)
                                    .background(favFarbe(fav.kind).opacity(0.12),
                                                in: RoundedRectangle(cornerRadius: 9))
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(fav.title)
                                        .font(.system(size: 15, weight: .medium))
                                        .foregroundStyle(.primary)
                                        .lineLimit(1)
                                    Text(fav.subtitle)
                                        .font(.system(size: 11))
                                        .foregroundStyle(.secondary)
                                        .lineLimit(1)
                                }
                                Spacer()
                            }
                        }
                    }
                }
                .navigationTitle("Favoriten")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Fertig") { showAlleFavoriten = false }
                    }
                }
            }
            .presentationDetents([.medium, .large])
        }
        .sheet(item: $quickAccessNote) { note in
            NoteDetailView(note: note)
                .environmentObject(store)
                .presentationDetents([.medium, .large])
                .presentationCornerRadius(28)
                .presentationBackground(.ultraThinMaterial)
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
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) { sucheOffen = true }
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
            $0.category.lowercased().contains(q) ||
            $0.ocrText.lowercased().contains(q)
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
                        title: "Tresor",
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
                        title: "Ideen",
                        icon: "lightbulb.fill",
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
        case .document: return "ArcaDocument"
        case .note:     return "ArcaIdee"
        case .list:     return "ArcaChecklist"
        case .vault:    return "ArcaLock"
        }
    }

    private var tint: Color {
        switch item.kind {
        case .document: return .orange
        case .note:     return ArcaWarm.ideenGelb
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

/// Klick-und-Ziehen für die Bereichs-Blasen: beim Darüberziehen
/// rückt die gezogene Blase sofort an die neue Stelle.
struct BlasenTauschDelegate: DropDelegate {
    let ziel: HomeStreamFilter
    @Binding var gezogen: HomeStreamFilter?
    let store: AppStore

    func dropEntered(info: DropInfo) {
        guard let g = gezogen, g != ziel else { return }
        var folge = store.bereichsOrdnung
        guard let von = folge.firstIndex(of: g),
              let nach = folge.firstIndex(of: ziel) else { return }
        folge.move(fromOffsets: IndexSet(integer: von),
                   toOffset: nach > von ? nach + 1 : nach)
        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
            store.bereichsOrdnung = folge
        }
    }

    func dropUpdated(info: DropInfo) -> DropProposal? {
        DropProposal(operation: .move)
    }

    func performDrop(info: DropInfo) -> Bool {
        gezogen = nil
        return true
    }
}

enum HomeStreamFilter: String, CaseIterable {
    case dokumente, notizen, tasks, passwoerter

    var label: String {
        switch self {
        case .dokumente:   return "Dokumente"
        case .notizen:     return "Ideen"
        case .tasks:       return "Aufgaben"
        case .passwoerter: return "Tresor"
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
        case .document: return "ArcaDocument"
        case .note:     return "ArcaIdee"
        case .list:     return "ArcaChecklist"
        case .vault:    return "ArcaLock"
        }
    }

    private var tint: Color {
        switch item.kind {
        case .document: return .orange
        case .note:     return ArcaWarm.ideenGelb
        case .list:     return .green
        case .vault:    return .blue
        }
    }

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                ArcaIcon(name: icon, groesse: 17)
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
            Bereich(id: "notes", section: .notes, title: "Ideen",
                    subtitle: "Einfälle, Texte, Blitzideen", icon: "lightbulb.fill", tint: ArcaWarm.ideenGelb,
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
            statItem(icon: "lightbulb.fill", value: notes, color: ArcaWarm.ideenGelb)
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

