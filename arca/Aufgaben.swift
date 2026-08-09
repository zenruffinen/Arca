//
//  Aufgaben.swift
//  Arca
//
//  Aufgabenlisten: Vorlagen, Zeilen, neue Liste.
//  (Aus ContentView.swift herausgelöst — Code unverändert.)
//
//  Entwickler: Hans zen Ruffinen
//

import SwiftUI

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
                            // Ziehbar auf den Schreibtisch (iPad/Mac)
                            .onDrag { NSItemProvider(object: list.id.uuidString as NSString) }
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

