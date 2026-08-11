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

