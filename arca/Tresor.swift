//
//  Tresor.swift
//  Arca
//
//  Passwörter: Liste, Detail, neuer Eintrag, Generator.
//  (Aus ContentView.swift herausgelöst — Code unverändert.)
//
//  Entwickler: Hans zen Ruffinen
//

import SwiftUI
import UniformTypeIdentifiers

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

