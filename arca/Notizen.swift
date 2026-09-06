//
//  Notizen.swift
//  Arca
//
//  Notizen: Farben, Zeilen, neue Notiz, Bausteine.
//  (Aus ContentView.swift herausgelöst — Code unverändert.)
//
//  Entwickler: Hans zen Ruffinen
//

import SwiftUI
import PhotosUI
import QuickLook

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

    /// Auch der Akzent muss die Seite wechseln: ein tiefes Oliv verschwindet
    /// auf dunklem Grund, ein helles Ocker blendet auf hellem.
    private static func adaptiveAccent(
        lightR: Double, lightG: Double, lightB: Double,
        darkR:  Double, darkG:  Double, darkB:  Double
    ) -> Color {
        Color(UIColor { trait in
            trait.userInterfaceStyle == .dark
                ? UIColor(red: darkR,  green: darkG,  blue: darkB,  alpha: 1)
                : UIColor(red: lightR, green: lightG, blue: lightB, alpha: 1)
        })
    }

    /// Die Palette: vier Farbfamilien statt sechs Bunttoene.
    ///
    /// Vorher standen hier Gelb, Rosa, Blau, Gruen, Lila und Pfirsich in den
    /// System-Farben. Lila und Rosa waren Fremdkoerper — Arca ist warm und
    /// papieren, ein Pink daneben wirkt wie ein Textmarker im Aktenschrank.
    /// Und sechs konkurrierende Toene sind auf einer Seite mit neunzehn
    /// Gruppen einfach unruhig.
    ///
    /// Jetzt: Ocker und Terrakotta (warm), Rauchblau und Tinte (kuehl),
    /// Salbei und Oliv (gruen) — vier Familien, je zwei Abstufungen. Alle
    /// gedaempft, alle aus derselben Welt wie ArcaWarm.
    ///
    /// GENAU SECHS PLAETZE. Die selbst gewaehlten Gruppenfarben liegen als
    /// Zahl in `categoryColors`, und `for_` rechnet modulo — ein Platz mehr
    /// oder weniger wuerde jede bestehende Zuordnung verschieben.
    static let palette: [NoteColor] = [
        // 0 — Ocker: das alte Gelb, nur mit Erde drin
        NoteColor(bg: adaptiveBg(lightR: 0.99, lightG: 0.93, lightB: 0.76,
                                  darkR:  0.26, darkG:  0.21, darkB:  0.06),
                  accent: adaptiveAccent(lightR: 0.72, lightG: 0.53, lightB: 0.14,
                                          darkR:  0.90, darkG:  0.73, darkB:  0.35),
                  name: "Ocker"),
        // 1 — Terrakotta: Arcas eigene Farbe, wo vorher Rosa stand
        NoteColor(bg: adaptiveBg(lightR: 0.99, lightG: 0.88, lightB: 0.82,
                                  darkR:  0.31, darkG:  0.16, darkB:  0.11),
                  accent: adaptiveAccent(lightR: 0.76, lightG: 0.40, lightB: 0.26,
                                          darkR:  0.93, darkG:  0.60, darkB:  0.46),
                  name: "Terrakotta"),
        // 2 — Rauchblau: das alte Blau, entstaubt
        NoteColor(bg: adaptiveBg(lightR: 0.85, lightG: 0.91, lightB: 0.95,
                                  darkR:  0.09, darkG:  0.17, darkB:  0.25),
                  accent: adaptiveAccent(lightR: 0.29, lightG: 0.47, lightB: 0.60,
                                          darkR:  0.58, darkG:  0.76, darkB:  0.90),
                  name: "Rauchblau"),
        // 3 — Salbei: das alte Gruen, ohne Neon
        NoteColor(bg: adaptiveBg(lightR: 0.87, lightG: 0.93, lightB: 0.85,
                                  darkR:  0.11, darkG:  0.21, darkB:  0.13),
                  accent: adaptiveAccent(lightR: 0.36, lightG: 0.55, lightB: 0.38,
                                          darkR:  0.62, darkG:  0.83, darkB:  0.64),
                  name: "Salbei"),
        // 4 — Tinte: dunkles Blaugrau, wo vorher Lila stand
        NoteColor(bg: adaptiveBg(lightR: 0.88, lightG: 0.89, lightB: 0.93,
                                  darkR:  0.13, darkG:  0.15, darkB:  0.21),
                  accent: adaptiveAccent(lightR: 0.28, lightG: 0.32, lightB: 0.44,
                                          darkR:  0.68, darkG:  0.73, darkB:  0.86),
                  name: "Tinte"),
        // 5 — Oliv: die dunklere Schwester von Salbei, wo Pfirsich war
        NoteColor(bg: adaptiveBg(lightR: 0.93, lightG: 0.93, lightB: 0.80,
                                  darkR:  0.19, darkG:  0.20, darkB:  0.08),
                  accent: adaptiveAccent(lightR: 0.48, lightG: 0.49, lightB: 0.24,
                                          darkR:  0.79, darkG:  0.81, darkB:  0.50),
                  name: "Oliv"),
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
    /// Welche Notiz ist der Keim beim Zusammenlegen?
    @State private var zusammenlegenKeim: NoteEntry? = nil
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
                    Image(systemName: "lightbulb.fill")
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
            .sheet(item: $selectedNote) { note in
                NoteDetailView(note: note)
                .presentationDetents([.large])
                .presentationCornerRadius(28)
            }
            .sheet(item: $shareItem) { item in ShareSheet(activityItems: [item.url]) }
            .overlay {
                if let keim = zusammenlegenKeim {
                    NotizenZusammenlegenEinblendung(keim: keim) { weitere in
                        zusammenlegenKeim = nil
                        guard !weitere.isEmpty else { return }
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                            store.legeNotizenZusammen([keim.id] + weitere)
                        }
                        UINotificationFeedbackGenerator().notificationOccurred(.success)
                    } abbrechen: {
                        zusammenlegenKeim = nil
                    }
                    .environmentObject(store)
                }
            }
            .animation(.spring(response: 0.3, dampingFraction: 0.86), value: zusammenlegenKeim?.id)
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
                Text(store.notes.isEmpty ? "Noch keine Ideen." : "Keine Treffer.")
                    .foregroundStyle(.secondary)
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
            } else {
                ForEach(filteredNotes) { note in
                    NoteRow(note: note)
                        .contentShape(Rectangle())
                        .onTapGesture { selectedNote = note }
                        // Ziehbar auf den Schreibtisch (iPad/Mac)
                        .onDrag { NSItemProvider(object: note.id.uuidString as NSString) }
                        .listRowBackground(Color(.secondarySystemBackground))
                        .listRowSeparator(.visible)
                        .listRowSeparatorTint(Color.primary.opacity(0.06))
                        .listRowInsets(EdgeInsets(top: 0, leading: 16, bottom: 0, trailing: 12))
                        .contextMenu {
                            ArcaMenue.favorit(ist: store.istAngepinnt(kind: .note, refID: note.id)) {
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
                            // Beim Diktieren waechst ein Gedanke oft ueber
                            // zwei Aufnahmen — hier wachsen sie wieder zusammen.
                            if store.notes.count > 1 {
                                Button {
                                    zusammenlegenKeim = note
                                } label: {
                                    Label("Zusammenlegen mit …", systemImage: "arrow.triangle.merge")
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

// MARK: - Notizen zusammenlegen — schwebendes Panel
//
// Kein Blatt vom Bildschirmrand: das verdeckte die Leiste und den unteren
// Rand. Ein Fenster, das ueber der Seite haengt — Champagner-Glas wie
// „An diese Wand", die Seite dahinter bleibt sichtbar, nur weich.
//
// Bewusst kein Bearbeiten-Modus in der Liste — der kaempft dort mit dem
// Antippen zum Oeffnen. Hier sagt die Notiz, die der Keim ist, es selbst,
// und man kreuzt die Ergaenzungen an.

struct NotizenZusammenlegenPanel: View {
    @EnvironmentObject var store: AppStore
    let keim: NoteEntry
    let breite: CGFloat
    /// Obergrenze — das Fenster nimmt sich so viel, wie sein Inhalt braucht,
    /// und nicht mehr. Vier Kandidaten ergeben ein kleines Fenster, vierzig
    /// ein grosses mit Scrollen.
    let maxHoehe: CGFloat
    let fertig: ([UUID]) -> Void
    let abbrechen: () -> Void

    @State private var gewaehlt: Set<UUID> = []
    @State private var da = false

    private let tinte = Color(red: 0.20, green: 0.16, blue: 0.11)
    private let zeilenHoehe: CGFloat = 78

    /// Alles ausser dem Keim, neueste zuerst — die Ergaenzung ist meist
    /// die, die man gerade gesprochen hat.
    private var kandidaten: [NoteEntry] {
        store.notes.filter { $0.id != keim.id }
            .sorted { $0.dateCreated > $1.dateCreated }
    }

    /// Kopf (~150) + Aktion (~110) bleiben immer, die Liste bekommt den Rest.
    private var listenHoehe: CGFloat {
        let noetig = CGFloat(kandidaten.count) * zeilenHoehe + 8
        return min(noetig, max(zeilenHoehe * 2, maxHoehe - 262))
    }

    /// Blitzideen nehmen ihren Titel aus dem Anfang des Textes — dann
    /// wuerde die Vorschau den Titel nur wiederholen. Also zeigen wir, was
    /// NACH dem Titel kommt; ist da nichts, bleibt die Zeile weg.
    private func vorschau(_ n: NoteEntry) -> String? {
        var t = n.text.trimmingCharacters(in: .whitespacesAndNewlines)
        let titel = n.title.trimmingCharacters(in: .whitespacesAndNewlines)
        if !titel.isEmpty, t.hasPrefix(titel) {
            t = String(t.dropFirst(titel.count)).trimmingCharacters(in: .whitespacesAndNewlines)
        }
        t = t.replacingOccurrences(of: "\n", with: " ")
        return t.isEmpty ? nil : t
    }

    var body: some View {
        VStack(spacing: 0) {
            Capsule()
                .fill(Color(red: 0.35, green: 0.29, blue: 0.22).opacity(0.22))
                .frame(width: 34, height: 4)
                .padding(.top, 12)

            Text("Zusammenlegen")
                .font(.system(size: 21, weight: .bold))
                .foregroundStyle(tinte)
                .padding(.top, 10)

            keimKarte
                .padding(.horizontal, 16)
                .padding(.top, 12)

            Text("WAS SOLL DAZU?")
                .font(.system(size: 10.5, weight: .bold))
                .tracking(0.8)
                .foregroundStyle(tinte.opacity(0.5))
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 20)
                .padding(.top, 14)
                .padding(.bottom, 6)

            ScrollView(showsIndicators: false) {
                VStack(spacing: 8) {
                    ForEach(Array(kandidaten.enumerated()), id: \.element.id) { i, n in
                        zeile(n)
                            .opacity(da ? 1 : 0)
                            .scaleEffect(da ? 1 : 0.94)
                            .animation(.spring(response: 0.34, dampingFraction: 0.86)
                                .delay(Double(min(i, 8)) * 0.03), value: da)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 14)
            }
            .frame(height: listenHoehe)
            // Auslauf statt Abbruch: die letzte Karte verschwindet weich,
            // bevor die Aktion beginnt.
            .mask(
                VStack(spacing: 0) {
                    Color.black
                    LinearGradient(colors: [.black, .clear], startPoint: .top, endPoint: .bottom)
                        .frame(height: 22)
                }
            )

            aktion
                .padding(.horizontal, 20)
                .padding(.top, 4)

            Button("Abbrechen", action: abbrechen)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(tinte.opacity(0.65))
                .padding(.top, 10)
                .padding(.bottom, 14)
        }
        .frame(width: breite)
        // Nur so hoch wie der Inhalt — sonst spannt ein dehnbares Kind
        // (der Grat der Keim-Karte) das ganze Fenster auf.
        .fixedSize(horizontal: false, vertical: true)
        .background(ArcaChampagnerGlas(breite: breite))
        .clipShape(RoundedRectangle(cornerRadius: 34, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 34, style: .continuous)
                .strokeBorder(
                    LinearGradient(colors: [.white.opacity(0.85), .white.opacity(0.18),
                                            .white.opacity(0.55)],
                                   startPoint: .topLeading, endPoint: .bottomTrailing),
                    lineWidth: 1)
        )
        .shadow(color: Color(red: 1.0, green: 0.88, blue: 0.68).opacity(0.45), radius: 26)
        .shadow(color: .black.opacity(0.30), radius: 40, x: 0, y: 24)
        .shadow(color: .black.opacity(0.16), radius: 7, x: 0, y: 4)
        .scaleEffect(da ? 1 : 0.95)
        .opacity(da ? 1 : 0)
        .animation(.spring(response: 0.30, dampingFraction: 0.86), value: da)
        .onAppear { da = true }
    }

    /// Der Keim: eine ruhige Karte, kein Schild. Links ein Terrakotta-Grat
    /// sagt „hierhin", der Titel bleibt lesbar statt in eine Kapsel gepresst.
    private var keimKarte: some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 2)
                .fill(LinearGradient(
                    colors: [Color(red: 0.85, green: 0.50, blue: 0.33),
                             Color(red: 0.72, green: 0.38, blue: 0.24)],
                    startPoint: .top, endPoint: .bottom))
                .frame(width: 3)
            VStack(alignment: .leading, spacing: 3) {
                Text("HIERHIN WÄCHST ES")
                    .font(.system(size: 9.5, weight: .bold))
                    .tracking(0.8)
                    .foregroundStyle(ArcaWarm.terrakotta)
                Text(keim.title.isEmpty ? "Ohne Titel" : keim.title)
                    .font(.system(size: 14.5, weight: .semibold))
                    .foregroundStyle(tinte)
                    .lineLimit(2)
                if let v = vorschau(keim) {
                    Text(v)
                        .font(.system(size: 11))
                        .foregroundStyle(tinte.opacity(0.65))
                        .lineLimit(1)
                }
            }
            Spacer(minLength: 0)
        }
        // Der Grat hat keine eigene Hoehe — er soll die des Textes nehmen,
        // nicht die des Fensters.
        .fixedSize(horizontal: false, vertical: true)
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            ZStack {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(.ultraThinMaterial)
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(LinearGradient(
                        colors: [ArcaWarm.terrakotta.opacity(0.16), ArcaWarm.terrakotta.opacity(0.06)],
                        startPoint: .topLeading, endPoint: .bottomTrailing))
            }
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(ArcaWarm.terrakotta.opacity(0.35), lineWidth: 0.9)
        )
        .shadow(color: .black.opacity(0.08), radius: 5, x: 0, y: 2)
    }

    /// Der Knopf zeigt seinen Zustand: wartend als Kontur, bereit als
    /// gefuellte Terrakotta-Kapsel. Ein verblasster Knopf sieht kaputt aus.
    @ViewBuilder
    private var aktion: some View {
        if gewaehlt.isEmpty {
            Text("Notizen auswählen")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(tinte.opacity(0.45))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .overlay(Capsule().strokeBorder(tinte.opacity(0.18), lineWidth: 1))
        } else {
            Button {
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                fertig(Array(gewaehlt))
            } label: {
                Text(gewaehlt.count == 1 ? "Zusammenlegen" : "Zusammenlegen (\(gewaehlt.count))")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(
                        Capsule().fill(LinearGradient(
                            colors: [Color(red: 0.85, green: 0.50, blue: 0.33),
                                     Color(red: 0.72, green: 0.38, blue: 0.24)],
                            startPoint: .top, endPoint: .bottom))
                            .overlay(Capsule().fill(LinearGradient(
                                colors: [.white.opacity(0.35), .clear],
                                startPoint: .top, endPoint: .center)))
                    )
                    .overlay(Capsule().strokeBorder(.white.opacity(0.35), lineWidth: 0.8))
                    .shadow(color: Color(red: 0.6, green: 0.3, blue: 0.15).opacity(0.35),
                            radius: 8, x: 0, y: 4)
            }
            .buttonStyle(.plain)
            .transition(.scale(scale: 0.96).combined(with: .opacity))
        }
    }

    private func zeile(_ n: NoteEntry) -> some View {
        let dran = gewaehlt.contains(n.id)
        return Button {
            UISelectionFeedbackGenerator().selectionChanged()
            withAnimation(.spring(response: 0.28, dampingFraction: 0.85)) {
                if dran { gewaehlt.remove(n.id) } else { gewaehlt.insert(n.id) }
            }
        } label: {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .strokeBorder(dran ? ArcaWarm.terrakotta : tinte.opacity(0.28), lineWidth: 1.4)
                        .background(Circle().fill(dran ? ArcaWarm.terrakotta : .clear))
                    if dran {
                        Image(systemName: "checkmark")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(.white)
                    }
                }
                .frame(width: 22, height: 22)
                VStack(alignment: .leading, spacing: 2) {
                    Text(n.title.isEmpty ? "Ohne Titel" : n.title)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(tinte)
                        .lineLimit(1)
                    if let v = vorschau(n) {
                        Text(v)
                            .font(.system(size: 11))
                            .foregroundStyle(tinte.opacity(0.68))
                            .lineLimit(1)
                    }
                    Text(n.dateCreated.formatted(date: .abbreviated, time: .shortened))
                        .font(.system(size: 10))
                        .foregroundStyle(tinte.opacity(0.42))
                }
                Spacer(minLength: 0)
                if !n.fotos.isEmpty {
                    Label("\(n.fotos.count)", systemImage: "photo")
                        .font(.system(size: 10))
                        .foregroundStyle(tinte.opacity(0.55))
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 9)
            .frame(height: zeilenHoehe - 8)
            .background(
                ZStack {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(.ultraThinMaterial)
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(LinearGradient(
                            colors: [.white.opacity(dran ? 0.34 : 0.26),
                                     Color(red: 0.97, green: 0.91, blue: 0.81).opacity(0.12)],
                            startPoint: .top, endPoint: .bottom))
                }
            )
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .strokeBorder(dran ? ArcaWarm.terrakotta.opacity(0.55) : .white.opacity(0.65),
                                  lineWidth: dran ? 1.2 : 0.9)
            )
            .shadow(color: .black.opacity(0.10), radius: 6, x: 0, y: 3)
        }
        .buttonStyle(.plain)
    }
}

/// Die Einblendung: Vignette drueber, Panel in der Mitte. Fuer Start und
/// Ideen dieselbe — damit sie sich nirgends unterscheidet.
struct NotizenZusammenlegenEinblendung: View {
    let keim: NoteEntry
    let fertig: ([UUID]) -> Void
    let abbrechen: () -> Void

    var body: some View {
        GeometryReader { geo in
            ZStack {
                // Vignette: nimmt die Raender zurueck, damit das Panel traegt
                RadialGradient(colors: [.black.opacity(0.04), .black.opacity(0.34)],
                               center: .center,
                               startRadius: geo.size.width * 0.22,
                               endRadius: geo.size.height * 0.72)
                    .ignoresSafeArea()
                    .onTapGesture { abbrechen() }
                NotizenZusammenlegenPanel(keim: keim,
                                          breite: min(geo.size.width * 0.86, 420),
                                          maxHoehe: min(geo.size.height * 0.72, 620),
                                          fertig: fertig,
                                          abbrechen: abbrechen)
                    .position(x: geo.size.width / 2, y: geo.size.height / 2)
            }
        }
        .transition(.opacity)
        .zIndex(200)
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
    @State private var fotoAuswahl: PhotosPickerItem? = nil
    @State private var zeigeDokumentWahl = false
    @State private var vorschauURL: URL? = nil

    private var displayColor: NoteColor {
        NoteColor.for_(isEditing ? editColor : note.colorTag)
    }

    /// Immer der aktuelle Stand aus dem Store (Anhänge ändern sich live).
    private var aktuelleNotiz: NoteEntry {
        store.notes.first(where: { $0.id == note.id }) ?? note
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
                    // Das Korkblatt: eine ganze Seite in Arca-Creme-Glas.
                    let n = aktuelleNotiz
                    ScrollView {
                        VStack(alignment: .leading, spacing: 18) {
                            // Kopf
                            HStack(alignment: .top, spacing: 10) {
                                RoundedRectangle(cornerRadius: 3)
                                    .fill(displayColor.accent)
                                    .frame(width: 5, height: 28)
                                Text(n.title.isEmpty ? "Ohne Titel" : n.title)
                                    .font(.title2.bold())
                            }
                            Text(n.dateCreated.formatted(date: .abbreviated, time: .shortened))
                                .font(.caption)
                                .foregroundStyle(.secondary)

                            // Transkript / Text als Anfang der Seite
                            if !n.text.isEmpty {
                                Text(n.text)
                                    .font(.body)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }

                            if !n.fotos.isEmpty || !n.verknuepfteDokumente.isEmpty {
                                Divider().opacity(0.4)
                            }

                            // Fotos (Fluss-Raster)
                            if !n.fotos.isEmpty {
                                LazyVGrid(columns: [GridItem(.adaptive(minimum: 104), spacing: 10)], spacing: 10) {
                                    ForEach(n.fotos, id: \.self) { name in
                                        let url = store.documentURL(for: name)
                                        Button { vorschauURL = url } label: {
                                            DocThumbnail(url: url, type: .image, gross: true)
                                                .frame(height: 104)
                                                .frame(maxWidth: .infinity)
                                                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                                                .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(.white.opacity(0.5), lineWidth: 0.5))
                                        }
                                        .buttonStyle(.plain)
                                        .contextMenu {
                                            Button(role: .destructive) {
                                                store.entferneFotoVonNotiz(name, notiz: note.id)
                                            } label: { Label("Foto entfernen", systemImage: "trash") }
                                        }
                                    }
                                }
                            }

                            // Verknüpfte Dokumente
                            ForEach(n.verknuepfteDokumente, id: \.self) { docID in
                                if let doc = store.documents.first(where: { $0.id == docID }) {
                                    Button {
                                        _ = store.ensureFileDownloaded(doc.filename)
                                        vorschauURL = store.documentURL(for: doc.filename)
                                    } label: {
                                        HStack(spacing: 12) {
                                            DocThumbnail(url: store.documentURL(for: doc.filename), type: doc.type)
                                            VStack(alignment: .leading, spacing: 1) {
                                                Text(doc.title).font(.system(size: 15, weight: .medium)).foregroundStyle(.primary).lineLimit(1)
                                                Text(doc.type.rawValue).font(.caption).foregroundStyle(.secondary)
                                            }
                                            Spacer()
                                            Image(systemName: "chevron.right").font(.caption).foregroundStyle(.secondary)
                                        }
                                        .padding(10)
                                        .glassEffect(.regular.tint(ArcaWarm.creme.opacity(0.6)), in: RoundedRectangle(cornerRadius: 12))
                                    }
                                    .buttonStyle(.plain)
                                    .contextMenu {
                                        Button(role: .destructive) {
                                            store.loeseDokumentVerknuepfung(docID, notiz: note.id)
                                        } label: { Label("Verknüpfung lösen", systemImage: "link.badge.plus") }
                                    }
                                }
                            }

                            // Hinzufügen: Foto · Dokument
                            HStack(spacing: 10) {
                                PhotosPicker(selection: $fotoAuswahl, matching: .images, photoLibrary: .shared()) {
                                    Label("Foto", systemImage: "photo")
                                        .font(.system(size: 14, weight: .semibold))
                                        .padding(.horizontal, 14).padding(.vertical, 9)
                                        .glassEffect(.regular.tint(displayColor.accent.opacity(0.18)), in: Capsule())
                                }
                                .buttonStyle(.plain)
                                Button { zeigeDokumentWahl = true } label: {
                                    Label("Dokument", systemImage: "doc.text")
                                        .font(.system(size: 14, weight: .semibold))
                                        .padding(.horizontal, 14).padding(.vertical, 9)
                                        .glassEffect(.regular.tint(displayColor.accent.opacity(0.18)), in: Capsule())
                                }
                                .buttonStyle(.plain)
                                Spacer()
                            }
                            .padding(.top, 4)

                            Spacer(minLength: 20)
                        }
                        .padding(20)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .background(ArcaWarm.hintergrund)
                }
            }
            .navigationTitle(isEditing ? "Bearbeiten" : "Idee")
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
                            // aktuellen Stand holen (Anhänge könnten sich geändert haben)
                            let aktuell = store.notes.first(where: { $0.id == note.id }) ?? note
                            let updated = NoteEntry(
                                id: note.id,
                                title: editTitle,
                                text: editText,
                                isPinned: note.isPinned,
                                isFavorite: note.isFavorite,
                                dateCreated: note.dateCreated,
                                colorTag: editColor,
                                isQuickIdea: false,
                                fotos: aktuell.fotos,
                                verknuepfteDokumente: aktuell.verknuepfteDokumente
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
            // Foto ans Korkblatt heften
            .onChange(of: fotoAuswahl) { _, neu in
                guard let neu else { return }
                Task {
                    if let data = try? await neu.loadTransferable(type: Data.self),
                       let ui = UIImage(data: data),
                       let jpg = ui.arcaSkaliert(maxKante: 1600) {
                        store.haengeFotoAnNotiz(note.id, bildData: jpg)
                    }
                    fotoAuswahl = nil
                }
            }
            // Bestehendes Dokument verknüpfen
            .sheet(isPresented: $zeigeDokumentWahl) {
                NavigationStack {
                    List {
                        let frei = store.documents.filter { !aktuelleNotiz.verknuepfteDokumente.contains($0.id) }
                        if frei.isEmpty {
                            Text("Keine weiteren Dokumente zum Anhängen.")
                                .foregroundStyle(.secondary)
                        } else {
                            ForEach(frei) { doc in
                                Button {
                                    store.verknuepfeDokument(doc.id, mitNotiz: note.id)
                                    zeigeDokumentWahl = false
                                } label: {
                                    HStack(spacing: 12) {
                                        DocThumbnail(url: store.documentURL(for: doc.filename), type: doc.type)
                                        Text(doc.title).foregroundStyle(.primary)
                                        Spacer()
                                    }
                                }
                            }
                        }
                    }
                    .navigationTitle("Dokument anhängen")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Abbrechen") { zeigeDokumentWahl = false }
                        }
                    }
                }
            }
            // Wie ueberall sonst: ohne Formular-Ausfuellen-Angebot.
            .arcaVorschau($vorschauURL)
        }
    }

}

// MARK: - Foto skalieren (für das Korkblatt)

extension UIImage {
    /// Verkleinert auf eine maximale Kantenlänge (Seitenverhältnis bleibt), als JPEG.
    func arcaSkaliert(maxKante: CGFloat = 1600) -> Data? {
        let groesste = max(size.width, size.height)
        let faktor = groesste > maxKante ? maxKante / groesste : 1
        let ziel = CGSize(width: size.width * faktor, height: size.height * faktor)
        let renderer = UIGraphicsImageRenderer(size: ziel)
        let bild = renderer.image { _ in draw(in: CGRect(origin: .zero, size: ziel)) }
        return bild.jpegData(compressionQuality: 0.82)
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
            .navigationTitle("Neue Idee")
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

