//
//  Dokumente.swift
//  Arca
//
//  Dokumente: Gruppen, Quellen, Vorschau, Detail-Panel.
//  (Aus ContentView.swift herausgelöst — Code unverändert.)
//
//  Entwickler: Hans zen Ruffinen
//

import SwiftUI
import UniformTypeIdentifiers
import QuickLook
import QuickLookThumbnailing
import PhotosUI
import PDFKit
import AVFoundation

// MARK: - Documents

// Helpers für Dokument-Stil

// Farbe pro Dokument-Typ (für Streifen + Icon)
func docTypeColor(_ type: DocumentType) -> Color {
    switch type {
    case .pdf:   return .red
    case .image: return .blue
    case .text:  return .green
    case .video: return .orange
    case .mail:  return .indigo
    }
}

// Deterministische Farbe pro Kategorie-Name (gleicher Name → gleiche Farbe)
func categoryColor(_ name: String, overrides: [String: Int] = [:]) -> NoteColor {
    if let idx = overrides[name] { return NoteColor.for_(idx) }
    // Stabiler Wert statt hashValue: der wechselt bei jedem App-Start
    // (Zufalls-Saat) — so bekam dieselbe Gruppe je nach Gerät und
    // Sitzung andere Farben. Die Zeichensumme bleibt für immer gleich.
    let summe = name.unicodeScalars.reduce(0) { $0 + Int($1.value) }
    return NoteColor.for_(summe % NoteColor.palette.count)
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

    enum Action { case scan, pdf, image, text, diktat, stift }

    static let all: [DocSource] = [
        DocSource(id: "scan",  icon: "ArcaScan",                  label: "Scannen",        colorTag: 4, action: .scan),  // Lila
        DocSource(id: "pdf",   icon: "ArcaDocument",              label: "PDF",            colorTag: 1, action: .pdf),   // Rosa
        DocSource(id: "image", icon: "photo.fill.on.rectangle.fill", label: "Fotos / Videos", colorTag: 2, action: .image), // Blau
        DocSource(id: "text",  icon: "doc.text.fill",             label: "Text",           colorTag: 3, action: .text),  // Grün
        DocSource(id: "diktat", icon: "mic.fill",                 label: "Diktieren",      colorTag: 5, action: .diktat), // Pfirsich
        DocSource(id: "stift", icon: "pencil.and.scribble",       label: "Stift",          colorTag: 0, action: .stift),  // Gelb
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
    @State private var pendingOcrText = ""
    @State private var previewURL: URL? = nil
    @State private var previewImageURL: URL? = nil
    @State private var showTextInput = false
    @State private var showStiftNotiz = false
    @State private var textDiktatStart = false
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
            $0.category.localizedCaseInsensitiveContains(searchText) ||
            $0.ocrText.localizedCaseInsensitiveContains(searchText)
        }
    }

    private func handleImport(_ action: DocSource.Action) {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        switch action {
        case .scan:  showScanner = true
        case .pdf:   filePickerTypes = [.pdf]; filePickerDocType = .pdf; showFilePicker = true
        case .image: showImagePicker = true
        case .text:  textCategory = store.ensureImportCategoryExists(); showTextInput = true
        case .diktat:
            textCategory = store.ensureImportCategoryExists()
            textDiktatStart = true
            showTextInput = true
        case .stift:
            showStiftNotiz = true
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
                DocumentScannerView { pdfURL, erkannterText in
                    let filename = "\(UUID().uuidString).pdf"
                    let destination = store.documentURL(for:filename)
                    try? FileManager.default.copyItem(at: pdfURL, to: destination)
                    // Erste erkannte Zeile als Titel-Vorschlag — besser als „Scan <Datum>"
                    let ersteZeile = erkannterText
                        .components(separatedBy: .newlines)
                        .map { $0.trimmingCharacters(in: .whitespaces) }
                        .first { $0.count >= 4 }
                    pendingTitle = ersteZeile.map { String($0.prefix(60)) }
                        ?? "Scan \(Date().formatted(date: .abbreviated, time: .omitted))"
                    pendingOcrText = erkannterText
                    pendingFilename = filename
                    pendingType = .pdf
                    pendingCategory = store.ensureImportCategoryExists()
                    scanReady = true
                    showScanner = false
                }
            }
            .sheet(isPresented: $showStiftNotiz) {
                ArcaStiftNotiz()
                    .environmentObject(store)
            }
            .sheet(isPresented: $showTextInput) {
                TextDocumentInputView(title: $textTitle, content: $textContent, category: $textCategory,
                                      autoDiktat: textDiktatStart) {
                    saveTextDocument()
                    showTextInput = false
                }
                .onDisappear { textDiktatStart = false }
            }
            .sheet(isPresented: $showCategoryPicker) {
                DocumentSaveSheet(
                    title: $pendingTitle,
                    category: $pendingCategory
                ) {
                    store.addDocument(title: pendingTitle, type: pendingType, filename: pendingFilename, category: pendingCategory, ocrText: pendingOcrText)
                    pendingOcrText = ""
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
        .contentShape(Rectangle())
        .onTapGesture { openDocument(doc) }
        // Ziehbar: in andere Gruppen oder auf den Schreibtisch
        .onDrag { NSItemProvider(object: doc.id.uuidString as NSString) }
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
                            Label(targetCategory, image: store.iconFor(targetCategory))
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
                            Label(targetCategory, image: store.iconFor(targetCategory))
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
            if store.fokusKategorie != nil {
                Button {
                    withAnimation { store.fokusKategorie = nil }
                } label: {
                    HStack(spacing: 5) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 12, weight: .bold))
                        Text("Alle Kategorien")
                            .font(.system(size: 14, weight: .semibold))
                    }
                    .foregroundStyle(ArcaWarm.terrakotta)
                }
                .buttonStyle(.plain)
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
            }
            let grouped = Dictionary(grouping: filteredDocuments, by: \.category)
            if grouped.isEmpty {
                Text(store.documents.isEmpty ? "Noch keine Dokumente vorhanden." : "Keine Treffer.")
                    .foregroundStyle(.secondary)
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
            } else {
                ForEach(store.documentCategories.filter { store.fokusKategorie == nil || $0 == store.fokusKategorie }, id: \.self) { category in
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
                                        Image(store.iconFor(category))
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
                                // Datei auf den Gruppen-Kopf ziehen = dort einsortieren
                                .dropDestination(for: String.self) { werte, _ in
                                    guard let wert = werte.first,
                                          let uuid = UUID(uuidString: wert),
                                          let idx = store.documents.firstIndex(where: { $0.id == uuid }),
                                          store.documents[idx].category != category else { return false }
                                    withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                                        store.documents[idx].category = category
                                        store.documents[idx].subcategory = ""
                                    }
                                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                                    return true
                                }
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
        let ersteZeile = textContent
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .first { !$0.isEmpty }
        let titel = textTitle.isEmpty
            ? (ersteZeile.map { String($0.prefix(60)) } ?? "Textdokument")
            : textTitle
        store.addDocument(title: titel, type: .text, filename: filename, category: textCategory)
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
    /// true: ganze Seite einpassen (Schreibtisch-Post-it) statt fuellen/anschneiden
    var passendEinpassen = false
    /// true: frei skalierend in voller Groesse (Schreibtisch) statt 42×50-Stempel
    var gross = false

    @State private var image: UIImage? = nil
    @Environment(\.displayScale) private var displayScale

    private var fallbackIcon: String {
        switch type {
        case .pdf:   return "doc.fill"
        case .image: return "photo"
        case .text:  return "doc.text.fill"
        case .video: return "video.fill"
        case .mail:  return "envelope.fill"
        }
    }

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 6)
                .fill(Color(.tertiarySystemFill))
            if let image {
                if passendEinpassen {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                        .shadow(color: .black.opacity(0.10), radius: 2, x: 0, y: 1)
                        .padding(6)
                } else if gross {
                    // Oben ausgerichtet statt mittig: Kamera-Scans haben oft
                    // schwarze Raender unten - der Briefkopf soll zaehlen
                    GeometryReader { geo in
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFill()
                            .frame(width: geo.size.width, height: geo.size.height, alignment: .top)
                            .clipped()
                    }
                } else {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                }
            } else {
                Image(systemName: fallbackIcon)
                    .font(.system(size: gross ? 34 : 15, weight: .semibold))
                    .foregroundStyle(docTypeColor(type).opacity(0.7))
            }
            if type == .video, image != nil {
                Image(systemName: "play.circle.fill")
                    .font(.system(size: 16))
                    .foregroundStyle(.white)
                    .shadow(radius: 2)
            }
        }
        .frame(width: gross ? nil : 42, height: gross ? nil : 50)
        .clipShape(RoundedRectangle(cornerRadius: 6))
        .overlay {
            RoundedRectangle(cornerRadius: 6)
                .strokeBorder(Color.primary.opacity(0.08), lineWidth: 0.5)
        }
        .onAppear { loadThumbnail() }
    }

    private func loadThumbnail() {
        // Grosse Vorschau getrennt zwischenspeichern — sonst liefert der
        // Cache die 42×50-Briefmarke auch auf dem Schreibtisch
        let schluessel = gross ? URL(fileURLWithPath: url.path + "#gross") : url
        if let cached = ThumbnailCache.shared.image(for: schluessel) {
            image = cached
            return
        }
        guard FileManager.default.fileExists(atPath: url.path) else { return }
        let request = QLThumbnailGenerator.Request(
            fileAt: url,
            size: gross ? CGSize(width: 320, height: 420) : CGSize(width: 42, height: 50),
            scale: displayScale,
            representationTypes: .thumbnail
        )
        QLThumbnailGenerator.shared.generateBestRepresentation(for: request) { rep, _ in
            guard var img = rep?.uiImage else { return }
            if gross {
                // Fest auf Weiss legen: transparente PDF-Hintergruende und
                // Passungs-Raender rendert das iPad sonst SCHWARZ
                let format = UIGraphicsImageRendererFormat()
                format.opaque = true
                format.scale = img.scale
                let groesse = img.size
                img = UIGraphicsImageRenderer(size: groesse, format: format).image { ctx in
                    UIColor.white.setFill()
                    ctx.fill(CGRect(origin: .zero, size: groesse))
                    img.draw(at: .zero)
                }
            }
            ThumbnailCache.shared.store(img, for: schluessel)
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

                // Drei Spalten mit kompakteren Kacheln — so bleiben
                // alle fünf Quellen ohne Scrollen sichtbar
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                    ForEach(DocSource.all) { source in
                        Button {
                            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                            dismiss()
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                                onSelect(source.action)
                            }
                        } label: {
                            VStack(spacing: 8) {
                                ArcaIcon(name: source.icon, groesse: 21)
                                    .foregroundStyle(NoteColor.for_(source.colorTag).accent)
                                    .frame(width: 44, height: 44)
                                    .background(NoteColor.for_(source.colorTag).bg.opacity(0.7),
                                                in: RoundedRectangle(cornerRadius: 13))
                                Text(source.label)
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundStyle(.primary)
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.8)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .padding(.horizontal, 4)
                            .background(Color(.secondarySystemBackground))
                            .clipShape(RoundedRectangle(cornerRadius: 14))
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
                                Image(store.iconFor(cat))
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
    /// true: Diktat startet sofort beim Öffnen (Quelle „Diktieren")
    var autoDiktat: Bool = false
    let onSave: () -> Void
    @Environment(\.dismiss) var dismiss
    @StateObject private var speech = SpeechManager()

    private func diktatUmschalten() {
        if speech.isRecording {
            speech.stopRecording()
        } else {
            // Bestehender Text bleibt stehen — das Diktat hängt sich an
            let vorhanden = content.trimmingCharacters(in: .whitespacesAndNewlines)
            speech.onTextUpdate = { neu in content = neu }
            speech.startRecording(prefix: vorhanden.isEmpty ? "" : vorhanden + "\n")
        }
    }

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
                                Image(store.iconFor(cat))
                                    .foregroundStyle(categoryColor(cat, overrides: store.categoryColors).accent)
                                Text(cat)
                            }.tag(cat)
                        }
                    }
                    .pickerStyle(.inline)
                    .labelsHidden()
                }
                Section {
                    TextEditor(text: $content)
                        .frame(minHeight: 150)
                } header: {
                    HStack {
                        Text("Inhalt")
                        Spacer()
                        // Sprache zu Text: Mikro an, sprechen, Text erscheint
                        Button {
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                            diktatUmschalten()
                        } label: {
                            HStack(spacing: 5) {
                                Image(systemName: speech.isRecording ? "stop.circle.fill" : "mic.fill")
                                    .symbolEffect(.pulse, isActive: speech.isRecording)
                                Text(speech.isRecording ? "Diktat läuft …" : "Diktieren")
                            }
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(speech.isRecording ? .red : ArcaWarm.terrakotta)
                        }
                        .buttonStyle(.plain)
                        .textCase(nil)
                    }
                }
            }
            .navigationTitle("Textdokument")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Abbrechen") {
                    speech.stopRecording()
                    dismiss()
                } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Speichern") {
                        speech.stopRecording()
                        onSave()
                    }
                    .disabled(content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .onAppear {
                guard autoDiktat else { return }
                // Blatt erst stehen lassen, dann Mikro an
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    if !speech.isRecording { diktatUmschalten() }
                }
            }
            .onDisappear { speech.stopRecording() }
        }
    }
}

