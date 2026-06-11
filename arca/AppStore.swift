import SwiftUI
import Combine
import CryptoKit
import WidgetKit
import AppleArchive
import System

struct ArcaBackup: Codable {
    var vaultItems: [VaultEntry]
    var documents: [DocumentEntry]
    var notes: [NoteEntry]
    var lists: [ListEntry]
    var documentCategories: [String]
    var exportDate: Date
    /// Tatsächliche Dokument-Dateien (filename → bytes). Optional für Rückwärtskompatibilität
    /// mit alten Backups, die nur die Metadaten enthielten.
    var fileData: [String: Data]?
    var documentSubcategories: [String: [String]]?

    enum CodingKeys: String, CodingKey {
        case vaultItems, documents, notes, lists, documentCategories, exportDate, fileData, documentSubcategories
    }

    init(vaultItems: [VaultEntry],
         documents: [DocumentEntry],
         notes: [NoteEntry],
         lists: [ListEntry],
         documentCategories: [String],
         exportDate: Date,
         fileData: [String: Data]? = nil,
         documentSubcategories: [String: [String]]? = nil) {
        self.vaultItems = vaultItems
        self.documents = documents
        self.notes = notes
        self.lists = lists
        self.documentCategories = documentCategories
        self.exportDate = exportDate
        self.fileData = fileData
        self.documentSubcategories = documentSubcategories
    }

    // Safe Decoder — alte Backups ohne fileData / lists bleiben kompatibel
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        vaultItems              = try c.decode([VaultEntry].self,                   forKey: .vaultItems)
        documents               = try c.decode([DocumentEntry].self,                forKey: .documents)
        notes                   = try c.decode([NoteEntry].self,                    forKey: .notes)
        lists                   = try c.decodeIfPresent([ListEntry].self,           forKey: .lists)                   ?? []
        documentCategories      = try c.decode([String].self,                       forKey: .documentCategories)
        exportDate              = try c.decode(Date.self,                           forKey: .exportDate)
        fileData                = try c.decodeIfPresent([String: Data].self,        forKey: .fileData)
        documentSubcategories   = try c.decodeIfPresent([String: [String]].self,   forKey: .documentSubcategories)
    }
}

final class AppStore: ObservableObject {
    @Published var vaultItems: [VaultEntry] = [] {
        didSet { saveVault() }
    }
    @Published var documents: [DocumentEntry] = [] {
        didSet { saveDocuments() }
    }
    @Published var notes: [NoteEntry] = [] {
        didSet { saveNotes() }
    }
    @Published var documentCategories: [String] = [] {
        didSet { saveDocumentCategories() }
    }
    @Published var categoryColors: [String: Int] = [:] {
        didSet { saveCategoryColors() }
    }
    @Published var lists: [ListEntry] = [] {
        didSet { saveLists() }
    }
    @Published var documentSubcategories: [String: [String]] = [:] {
        didSet { saveDocumentSubcategories() }
    }
    /// Wenn eine Datei von außen (z. B. Mail) geöffnet wird, landet die URL hier.
    @Published var pendingSharedURL: URL? = nil
    @Published var pendingBackupURL: URL? = nil
    @Published var pendingScrollCategory: String? = nil
    @Published var pendingSection: ArcaSection? = nil
    @Published var pendingQuickCapture: Bool = false

    var importCategoryName: String {
        get { UserDefaults.standard.string(forKey: "importCategoryName") ?? "Import" }
        set { UserDefaults.standard.set(newValue, forKey: "importCategoryName") }
    }

    /// Stellt sicher, dass die Import-Gruppe existiert, und gibt ihren Namen zurück.
    @discardableResult
    func ensureImportCategoryExists() -> String {
        let name = importCategoryName
        if !documentCategories.contains(name) {
            documentCategories.insert(name, at: 0)
        }
        return name
    }

    static let defaultCategories = ["Reise", "Papiere", "Rechnungen", "Verträge", "Gesundheit", "Sonstiges"]

    // MARK: - iCloud Storage

    private let cloudContainerID = "iCloud.com.hansruffin.Arca"

    /// Liefert die iCloud-Container-URL oder nil wenn iCloud nicht verfügbar.
    /// iOS cached den Wert intern, wiederholte Aufrufe sind schnell.
    private var cloudContainer: URL? {
        FileManager.default.url(forUbiquityContainerIdentifier: cloudContainerID)
    }

    /// Verzeichnis für JSON-Datendateien (iCloud oder lokaler Fallback).
    private var dataDirectory: URL {
        if let c = cloudContainer {
            let dir = c.appendingPathComponent("Documents/arcadata")
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            return dir
        }
        let dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("arcadata")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    /// Verzeichnis für Dokument-Binärdateien (PDFs, Bilder, …).
    var filesDirectory: URL {
        if let c = cloudContainer {
            let dir = c.appendingPathComponent("Documents/files")
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            return dir
        }
        return FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }

    private func dataURL(_ key: String) -> URL {
        dataDirectory.appendingPathComponent("\(key).json")
    }

    // MARK: - iCloud Download (Platzhalter-Dateien)

    /// Prüft ob eine Dokument-Datei lokal vorliegt. Falls sie nur als iCloud-
    /// Platzhalter existiert, wird der Download angestossen.
    /// - Returns: true wenn die Datei sofort verfügbar ist.
    @discardableResult
    func ensureFileDownloaded(_ filename: String) -> Bool {
        let url = filesDirectory.appendingPathComponent(filename)
        if FileManager.default.fileExists(atPath: url.path) { return true }
        let placeholder = filesDirectory.appendingPathComponent(".\(filename).icloud")
        if FileManager.default.fileExists(atPath: placeholder.path) {
            try? FileManager.default.startDownloadingUbiquitousItem(at: url)
        }
        return false
    }

    /// Stößt den Download aller noch nicht geladenen iCloud-Dateien an,
    /// damit Arca komplett offline nutzbar bleibt (z. B. nach Installation auf dem iPad).
    func downloadAllCloudFiles() {
        guard cloudContainer != nil else { return }
        let dirs = [filesDirectory, dataDirectory]
        DispatchQueue.global(qos: .utility).async {
            for dir in dirs {
                guard let files = try? FileManager.default.contentsOfDirectory(
                    at: dir, includingPropertiesForKeys: nil) else { continue }
                for f in files where f.lastPathComponent.hasSuffix(".icloud") {
                    // ".Name.ext.icloud" → "Name.ext"
                    var name = f.lastPathComponent
                    name.removeFirst()
                    name.removeLast(".icloud".count)
                    let target = dir.appendingPathComponent(name)
                    try? FileManager.default.startDownloadingUbiquitousItem(at: target)
                }
            }
        }
    }

    // MARK: - Generische JSON I/O mit NSFileCoordinator

    private func saveJSON<T: Encodable>(_ value: T, key: String) {
        guard let data = try? JSONEncoder().encode(value) else { return }
        let url = dataURL(key)
        let coordinator = NSFileCoordinator(filePresenter: nil)
        var err: NSError?
        coordinator.coordinate(writingItemAt: url, options: .forReplacing, error: &err) { u in
            try? data.write(to: u, options: .atomic)
        }
    }

    private func loadJSON<T: Decodable>(_ type: T.Type, key: String) -> T? {
        let url = dataURL(key)
        guard FileManager.default.fileExists(atPath: url.path) else { return nil }
        var result: T? = nil
        let coordinator = NSFileCoordinator(filePresenter: nil)
        var err: NSError?
        coordinator.coordinate(readingItemAt: url, options: .withoutChanges, error: &err) { u in
            guard let data = try? Data(contentsOf: u) else { return }
            result = try? JSONDecoder().decode(type, from: data)
        }
        return result
    }

    // MARK: - Init

    init() {
        migrateFromUserDefaultsIfNeeded()
        load()
        downloadAllCloudFiles()
        createDefaultListIfNeeded()
    }

    /// Legt beim ersten Start eine Beispiel-Taskliste an, damit die Funktion
    /// sofort sichtbar und verständlich ist.
    private func createDefaultListIfNeeded() {
        let key = "arcaDefaultListCreated_v1"
        guard !UserDefaults.standard.bool(forKey: key) else { return }
        if lists.isEmpty {
            let demo = ListEntry(
                title: "Einkaufen",
                items: [
                    ChecklistItem(text: "Butter"),
                    ChecklistItem(text: "Käse"),
                    ChecklistItem(text: "Milch")
                ],
                colorTag: 3
            )
            lists.append(demo)
        }
        UserDefaults.standard.set(true, forKey: key)
    }

    // MARK: - Migration: UserDefaults → iCloud/lokale Dateien (einmalig)

    private func migrateFromUserDefaultsIfNeeded() {
        guard !UserDefaults.standard.bool(forKey: "arcaStorageMigrated_v1") else { return }

        func migrate(udKey: String, fileKey: String) {
            guard let data = UserDefaults.standard.data(forKey: udKey) else { return }
            let target = dataURL(fileKey)
            // Nicht überschreiben wenn Datei schon existiert (z. B. vom anderen Gerät)
            guard !FileManager.default.fileExists(atPath: target.path) else { return }
            try? data.write(to: target)
        }

        migrate(udKey: "notes",                 fileKey: "notes")
        migrate(udKey: "documents",             fileKey: "documents")
        migrate(udKey: "lists",                 fileKey: "lists")
        migrate(udKey: "vaultItems",            fileKey: "vaultItems")
        migrate(udKey: "documentCategories",    fileKey: "documentCategories")
        migrate(udKey: "categoryColors",        fileKey: "categoryColors")
        migrate(udKey: "documentSubcategories", fileKey: "documentSubcategories")

        // Dokument-Dateien in neues Verzeichnis kopieren (nur wenn Ziel != Quelle)
        let oldDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let newDir = filesDirectory
        if oldDir.standardizedFileURL != newDir.standardizedFileURL {
            if let files = try? FileManager.default.contentsOfDirectory(
                at: oldDir, includingPropertiesForKeys: nil) {
                for file in files where !file.hasDirectoryPath {
                    let dest = newDir.appendingPathComponent(file.lastPathComponent)
                    guard !FileManager.default.fileExists(atPath: dest.path) else { continue }
                    try? FileManager.default.copyItem(at: file, to: dest)
                }
            }
        }

        UserDefaults.standard.set(true, forKey: "arcaStorageMigrated_v1")
    }

    // MARK: - Reload (aufgerufen wenn App in den Vordergrund kommt)

    func reloadFromCloud() {
        load()
        downloadAllCloudFiles()
    }

    // MARK: - Export / Import

    /// Backup-Export, Format v2: verschlüsseltes Apple-Archiv (AEA).
    /// Speicherschonend — die Dateien werden gestreamt statt in den RAM geladen.
    func exportData(password: String) -> URL? {
        // 1. Staging-Ordner: manifest.json (Metadaten) + files/ (Hardlinks/Kopien)
        let stage = FileManager.default.temporaryDirectory
            .appendingPathComponent("ArcaExport_\(UUID().uuidString)")
        let stageFiles = stage.appendingPathComponent("files")
        defer { try? FileManager.default.removeItem(at: stage) }
        do {
            try FileManager.default.createDirectory(at: stageFiles, withIntermediateDirectories: true)
            let backup = ArcaBackup(
                vaultItems: vaultItems,
                documents: documents,
                notes: notes,
                lists: lists,
                documentCategories: documentCategories,
                exportDate: Date(),
                fileData: nil,
                documentSubcategories: documentSubcategories
            )
            let manifest = try JSONEncoder().encode(backup)
            try manifest.write(to: stage.appendingPathComponent("manifest.json"))
            for doc in documents {
                // Falls nur iCloud-Platzhalter: Download anstossen
                ensureFileDownloaded(doc.filename)
                let src = documentURL(for: doc.filename)
                guard FileManager.default.fileExists(atPath: src.path) else { continue }
                let dst = stageFiles.appendingPathComponent(doc.filename)
                // Hardlink (kein Platzverbrauch); falls nicht möglich: kopieren
                if (try? FileManager.default.linkItem(at: src, to: dst)) == nil {
                    try? FileManager.default.copyItem(at: src, to: dst)
                }
            }
        } catch { return nil }

        // 2. Verschlüsselt archivieren
        let filename = "ArcaBackup_\(Date().formatted(date: .abbreviated, time: .omitted)).arcabackup"
            .replacingOccurrences(of: " ", with: "_")
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(filename)
        guard archiveDirectory(stage, to: url, password: password),
              let size = try? FileManager.default.attributesOfItem(atPath: url.path)[.size] as? Int,
              size > 0 else { return nil }
        return url
    }

    func importData(from url: URL, password: String, merge: Bool = false) -> Bool {
        guard url.startAccessingSecurityScopedResource() else { return false }
        defer { url.stopAccessingSecurityScopedResource() }

        // Neues Format (v2): verschlüsseltes Apple-Archiv
        if isAppleEncryptedArchive(url) {
            guard let extracted = extractArchive(url, password: password) else { return false }
            defer { try? FileManager.default.removeItem(at: extracted) }
            guard let manifestData = try? Data(contentsOf: extracted.appendingPathComponent("manifest.json")),
                  let backup = try? JSONDecoder().decode(ArcaBackup.self, from: manifestData) else { return false }
            let extractedFiles = extracted.appendingPathComponent("files")
            if let files = try? FileManager.default.contentsOfDirectory(
                at: extractedFiles, includingPropertiesForKeys: nil) {
                for f in files {
                    let dest = documentURL(for: f.lastPathComponent)
                    try? FileManager.default.removeItem(at: dest)
                    try? FileManager.default.copyItem(at: f, to: dest)
                }
            }
            applyBackup(backup, merge: merge)
            return true
        }

        // Altes Format (v1): AES-GCM-verschlüsseltes JSON
        guard let encryptedData = try? Data(contentsOf: url),
              let plaintext = try? decryptData(encryptedData, password: password),
              let backup = try? JSONDecoder().decode(ArcaBackup.self, from: plaintext) else {
            return false
        }

        if let fileData = backup.fileData {
            for (filename, data) in fileData {
                let dest = documentURL(for: filename)
                try? data.write(to: dest)
            }
        }

        applyBackup(backup, merge: merge)
        return true
    }

    /// Übernimmt die Metadaten eines Backups (ersetzen oder zusammenführen).
    private func applyBackup(_ backup: ArcaBackup, merge: Bool) {
        if merge {
            let existingNoteIDs  = Set(notes.map(\.id))
            let existingDocIDs   = Set(documents.map(\.id))
            let existingListIDs  = Set(lists.map(\.id))
            let existingVaultIDs = Set(vaultItems.map(\.id))

            notes      += backup.notes.filter      { !existingNoteIDs.contains($0.id) }
            documents  += backup.documents.filter  { !existingDocIDs.contains($0.id) }
            lists      += backup.lists.filter      { !existingListIDs.contains($0.id) }
            vaultItems += backup.vaultItems.filter { !existingVaultIDs.contains($0.id) }

            let newCategories = backup.documentCategories.filter { !documentCategories.contains($0) }
            if !newCategories.isEmpty { documentCategories += newCategories }

            if let backupSubs = backup.documentSubcategories {
                for (cat, subs) in backupSubs {
                    var existing = documentSubcategories[cat] ?? []
                    for s in subs where !existing.contains(s) { existing.append(s) }
                    documentSubcategories[cat] = existing
                }
            }
        } else {
            vaultItems = backup.vaultItems
            documents  = backup.documents
            notes      = backup.notes
            lists      = backup.lists
            documentCategories = backup.documentCategories.isEmpty
                ? AppStore.defaultCategories
                : backup.documentCategories
            documentSubcategories = backup.documentSubcategories ?? [:]
        }
    }

    // MARK: - Ordner Teilen

    func exportFolder(category: String) -> URL? {
        let docsInCategory = documents.filter { $0.category == category }
        let safeName = category.replacingOccurrences(of: " ", with: "_")
        return exportFolderArchive(
            filename: "Arca_\(safeName).arcafolder",
            docs: docsInCategory,
            categoryName: category,
            subcategories: documentSubcategories[category]
        )
    }

    func exportDocument(_ doc: DocumentEntry) -> URL? {
        let safeName = doc.title.replacingOccurrences(of: " ", with: "_")
            .replacingOccurrences(of: "/", with: "-")
        return exportFolderArchive(
            filename: "Arca_\(safeName).arcafolder",
            docs: [doc],
            categoryName: doc.category,
            subcategories: documentSubcategories[doc.category]
        )
    }

    /// Ordner-Export, Format v2: unverschlüsseltes Apple-Archiv mit manifest.json + files/.
    private func exportFolderArchive(filename: String, docs: [DocumentEntry],
                                     categoryName: String, subcategories: [String]?) -> URL? {
        let stage = FileManager.default.temporaryDirectory
            .appendingPathComponent("ArcaFolderExport_\(UUID().uuidString)")
        let stageFiles = stage.appendingPathComponent("files")
        defer { try? FileManager.default.removeItem(at: stage) }
        do {
            try FileManager.default.createDirectory(at: stageFiles, withIntermediateDirectories: true)
            let folder = ArcaFolder(
                categoryName: categoryName,
                documents: docs,
                fileData: [:],          // Dateien liegen im Archiv unter files/
                exportDate: Date(),
                subcategories: subcategories
            )
            let manifest = try JSONEncoder().encode(folder)
            try manifest.write(to: stage.appendingPathComponent("manifest.json"))
            for doc in docs {
                // Falls nur iCloud-Platzhalter: Download anstossen
                ensureFileDownloaded(doc.filename)
                let src = documentURL(for: doc.filename)
                guard FileManager.default.fileExists(atPath: src.path) else { continue }
                let dst = stageFiles.appendingPathComponent(doc.filename)
                if (try? FileManager.default.linkItem(at: src, to: dst)) == nil {
                    try? FileManager.default.copyItem(at: src, to: dst)
                }
            }
        } catch { return nil }

        let url = FileManager.default.temporaryDirectory.appendingPathComponent(filename)
        guard archiveDirectory(stage, to: url, password: nil),
              let size = try? FileManager.default.attributesOfItem(atPath: url.path)[.size] as? Int,
              size > 0 else { return nil }
        return url
    }

    func importFolder(from url: URL) -> String? {
        let accessing = url.startAccessingSecurityScopedResource()
        defer { if accessing { url.stopAccessingSecurityScopedResource() } }

        let folder: ArcaFolder
        if isJSONFile(url) {
            // Altes Format (v1): JSON mit eingebetteten Dateidaten
            guard let data = try? Data(contentsOf: url),
                  let f = try? JSONDecoder().decode(ArcaFolder.self, from: data) else { return nil }
            folder = f
            for (filename, fileData) in folder.fileData {
                let dest = documentURL(for: filename)
                try? fileData.write(to: dest)
            }
        } else {
            // Neues Format (v2): Apple-Archiv
            guard let extracted = extractArchive(url, password: nil) else { return nil }
            defer { try? FileManager.default.removeItem(at: extracted) }
            guard let manifestData = try? Data(contentsOf: extracted.appendingPathComponent("manifest.json")),
                  let f = try? JSONDecoder().decode(ArcaFolder.self, from: manifestData) else { return nil }
            folder = f
            let extractedFiles = extracted.appendingPathComponent("files")
            if let files = try? FileManager.default.contentsOfDirectory(
                at: extractedFiles, includingPropertiesForKeys: nil) {
                for f in files {
                    let dest = documentURL(for: f.lastPathComponent)
                    try? FileManager.default.removeItem(at: dest)
                    try? FileManager.default.copyItem(at: f, to: dest)
                }
            }
        }

        var newCategoryName = folder.categoryName
        var counter = 2
        while documentCategories.contains(newCategoryName) {
            newCategoryName = "\(folder.categoryName) \(counter)"
            counter += 1
        }
        documentCategories.append(newCategoryName)
        let importedDocs = folder.documents.map { doc -> DocumentEntry in
            var d = doc; d.id = UUID(); d.category = newCategoryName; return d
        }
        documents.append(contentsOf: importedDocs)
        if let subs = folder.subcategories, !subs.isEmpty {
            var existing = documentSubcategories[newCategoryName] ?? []
            for s in subs where !existing.contains(s) { existing.append(s) }
            documentSubcategories[newCategoryName] = existing
        }
        return newCategoryName
    }

    // MARK: - Notiz Teilen

    func exportNote(_ note: NoteEntry) -> URL? {
        let arcaNote = ArcaNote(note: note, exportDate: Date())
        guard let data = try? JSONEncoder().encode(arcaNote) else { return nil }
        let safeName = note.title.isEmpty ? "Notiz" : note.title.replacingOccurrences(of: " ", with: "_")
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("Arca_\(safeName).arcanote")
        try? FileManager.default.removeItem(at: url)
        do { try data.write(to: url) } catch { return nil }
        guard FileManager.default.fileExists(atPath: url.path) else { return nil }
        return url
    }

    func importNote(from url: URL) -> Bool {
        let accessing = url.startAccessingSecurityScopedResource()
        defer { if accessing { url.stopAccessingSecurityScopedResource() } }
        guard let data = try? Data(contentsOf: url),
              let arcaNote = try? JSONDecoder().decode(ArcaNote.self, from: data) else { return false }
        var newNote = arcaNote.note
        newNote.id = UUID()
        notes.append(newNote)
        return true
    }

    // MARK: - Aufgabenliste Teilen

    func exportList(_ list: ListEntry) -> URL? {
        let arcaList = ArcaList(list: list, exportDate: Date())
        guard let data = try? JSONEncoder().encode(arcaList) else { return nil }
        let safeName = list.title.replacingOccurrences(of: " ", with: "_")
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("Arca_\(safeName).arcalist")
        try? FileManager.default.removeItem(at: url)
        do { try data.write(to: url) } catch { return nil }
        guard FileManager.default.fileExists(atPath: url.path) else { return nil }
        return url
    }

    func importList(from url: URL) -> Bool {
        let accessing = url.startAccessingSecurityScopedResource()
        defer { if accessing { url.stopAccessingSecurityScopedResource() } }
        guard let data = try? Data(contentsOf: url),
              let arcaList = try? JSONDecoder().decode(ArcaList.self, from: data) else { return false }
        var newList = arcaList.list
        newList.id = UUID()
        lists.append(newList)
        return true
    }

    // MARK: - Apple-Archiv-Helfer (speicherschonend, gestreamt)

    /// Archiviert einen Ordner in eine Datei — optional passwortverschlüsselt (AEA).
    private func archiveDirectory(_ dir: URL, to dest: URL, password: String?) -> Bool {
        try? FileManager.default.removeItem(at: dest)
        do {
            guard let fileStream = ArchiveByteStream.fileStream(
                path: FilePath(dest.path), mode: .writeOnly,
                options: [.create, .truncate],
                permissions: FilePermissions(rawValue: 0o644)) else { return false }
            defer { try? fileStream.close() }

            var targetStream = fileStream
            var encryptionStream: ArchiveByteStream? = nil
            if let password {
                let ctx = ArchiveEncryptionContext(
                    profile: .hkdf_sha256_aesctr_hmac__scrypt__none,
                    compressionAlgorithm: .lzfse)
                try ctx.setPassword(password)
                guard let es = ArchiveByteStream.encryptionStream(
                    writingTo: fileStream, encryptionContext: ctx) else { return false }
                encryptionStream = es
                targetStream = es
            }
            defer { if let s = encryptionStream { try? s.close() } }

            guard let encoder = ArchiveStream.encodeStream(writingTo: targetStream) else { return false }
            defer { try? encoder.close() }

            try encoder.writeDirectoryContents(
                archiveFrom: FilePath(dir.path), keySet: .defaultForArchive)

            try encoder.close()
            if let s = encryptionStream { try? s.close() }
            try fileStream.close()
            return true
        } catch {
            try? FileManager.default.removeItem(at: dest)
            return false
        }
    }

    /// Entpackt ein Apple-Archiv (optional verschlüsselt) in einen temporären Ordner.
    private func extractArchive(_ url: URL, password: String?) -> URL? {
        let outDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("ArcaExtract_\(UUID().uuidString)")
        do {
            try FileManager.default.createDirectory(at: outDir, withIntermediateDirectories: true)
            guard let fileStream = ArchiveByteStream.fileStream(
                path: FilePath(url.path), mode: .readOnly,
                options: [], permissions: FilePermissions(rawValue: 0o644)) else { return nil }
            defer { try? fileStream.close() }

            var sourceStream = fileStream
            var decryptionStream: ArchiveByteStream? = nil
            if let password {
                guard let ctx = ArchiveEncryptionContext(from: fileStream) else { return nil }
                try ctx.setPassword(password)
                guard let ds = ArchiveByteStream.decryptionStream(
                    readingFrom: fileStream, encryptionContext: ctx) else { return nil }
                decryptionStream = ds
                sourceStream = ds
            }
            defer { if let s = decryptionStream { try? s.close() } }

            guard let decoder = ArchiveStream.decodeStream(readingFrom: sourceStream) else { return nil }
            defer { try? decoder.close() }
            guard let extractor = ArchiveStream.extractStream(
                extractingTo: FilePath(outDir.path),
                flags: [.ignoreOperationNotPermitted]) else { return nil }
            defer { try? extractor.close() }

            _ = try ArchiveStream.process(readingFrom: decoder, writingTo: extractor)
            return outDir
        } catch {
            try? FileManager.default.removeItem(at: outDir)
            return nil
        }
    }

    /// Erkennt das neue Backup-Format am AEA-Magic-Header.
    private func isAppleEncryptedArchive(_ url: URL) -> Bool {
        guard let fh = try? FileHandle(forReadingFrom: url) else { return false }
        defer { try? fh.close() }
        guard let magic = try? fh.read(upToCount: 4) else { return false }
        return magic == Data("AEA1".utf8)
    }

    /// Erkennt das alte JSON-Format am ersten Zeichen "{".
    private func isJSONFile(_ url: URL) -> Bool {
        guard let fh = try? FileHandle(forReadingFrom: url) else { return false }
        defer { try? fh.close() }
        guard let first = try? fh.read(upToCount: 1) else { return false }
        return first == Data("{".utf8)
    }

    // MARK: - Encryption (AES-GCM, password-derived key via HKDF)

    private static let backupMagic = Data("ARCA".utf8)

    private func encryptData(_ data: Data, password: String) throws -> Data {
        var salt = Data(count: 16)
        salt.withUnsafeMutableBytes { _ = SecRandomCopyBytes(kSecRandomDefault, 16, $0.baseAddress!) }
        let key = deriveKey(from: password, salt: salt)
        let sealed = try AES.GCM.seal(data, using: key)
        guard let combined = sealed.combined else { throw CryptoError.encryptionFailed }
        return Self.backupMagic + salt + combined
    }

    private func decryptData(_ data: Data, password: String) throws -> Data {
        if data.prefix(4) == Self.backupMagic {
            guard data.count > 20 else { throw CryptoError.encryptionFailed }
            let salt = data[4..<20]
            let ciphertext = data[20...]
            let key = deriveKey(from: password, salt: Data(salt))
            let box = try AES.GCM.SealedBox(combined: Data(ciphertext))
            return try AES.GCM.open(box, using: key)
        } else {
            guard let fixedSalt = "ArcaBackupSalt_v1".data(using: .utf8),
                  let passwordData = password.data(using: .utf8) else { throw CryptoError.encryptionFailed }
            let inputKey = SymmetricKey(data: passwordData)
            let derived = HKDF<SHA256>.deriveKey(inputKeyMaterial: inputKey, salt: fixedSalt, info: Data(), outputByteCount: 32)
            let keyData = derived.withUnsafeBytes { Data($0) }
            let key = SymmetricKey(data: keyData)
            let box = try AES.GCM.SealedBox(combined: data)
            return try AES.GCM.open(box, using: key)
        }
    }

    private func deriveKey(from password: String, salt: Data) -> SymmetricKey {
        guard let passwordData = password.data(using: .utf8) else {
            return SymmetricKey(size: .bits256)
        }
        let inputKey = SymmetricKey(data: passwordData)
        return HKDF<SHA256>.deriveKey(inputKeyMaterial: inputKey, salt: salt, info: Data(), outputByteCount: 32)
    }

    enum CryptoError: Error {
        case encryptionFailed
    }

    // MARK: - Dokumente

    func addDocument(title: String, type: DocumentType, filename: String, category: String = "Sonstiges", subcategory: String = "") {
        let entry = DocumentEntry(title: title, type: type, filename: filename, dateAdded: Date(), category: category, subcategory: subcategory)
        documents.append(entry)
    }

    func renameCategory(from old: String, to new: String) {
        let trimmed = new.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, trimmed != old else { return }
        if let idx = documentCategories.firstIndex(of: old) {
            documentCategories[idx] = trimmed
        }
        documents = documents.map { doc in
            var d = doc; if d.category == old { d.category = trimmed }; return d
        }
        if old == importCategoryName { importCategoryName = trimmed }
        if let subs = documentSubcategories[old] {
            documentSubcategories[trimmed] = subs
            documentSubcategories.removeValue(forKey: old)
        }
    }

    func deleteCategory(_ name: String) {
        let fallback = documentCategories.first(where: { $0 != name }) ?? "Sonstiges"
        documents = documents.map { doc in
            var d = doc; if d.category == name { d.category = fallback }; return d
        }
        documentCategories.removeAll { $0 == name }
        documentSubcategories.removeValue(forKey: name)
    }

    func addSubcategory(to category: String, name: String) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        var subs = documentSubcategories[category] ?? []
        guard !subs.contains(trimmed) else { return }
        subs.append(trimmed)
        documentSubcategories[category] = subs
    }

    func deleteSubcategory(category: String, name: String) {
        documents = documents.map { doc in
            var d = doc
            if d.category == category && d.subcategory == name { d.subcategory = "" }
            return d
        }
        var subs = documentSubcategories[category] ?? []
        subs.removeAll { $0 == name }
        if subs.isEmpty { documentSubcategories.removeValue(forKey: category) }
        else { documentSubcategories[category] = subs }
    }

    func renameSubcategory(category: String, old: String, new: String) {
        let trimmed = new.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, trimmed != old else { return }
        documents = documents.map { doc in
            var d = doc
            if d.category == category && d.subcategory == old { d.subcategory = trimmed }
            return d
        }
        var subs = documentSubcategories[category] ?? []
        if let idx = subs.firstIndex(of: old) { subs[idx] = trimmed }
        documentSubcategories[category] = subs
    }

    func deleteDocument(_ entry: DocumentEntry) {
        let url = documentURL(for: entry.filename)
        try? FileManager.default.removeItem(at: url)
        documents.removeAll { $0.id == entry.id }
    }

    /// Gibt die URL einer Dokument-Datei zurück (iCloud oder lokaler Fallback).
    func documentURL(for filename: String) -> URL {
        let url = filesDirectory.appendingPathComponent(filename)
        // Selbstheilung: Datei wurde früher fälschlich lokal gespeichert → in den
        // richtigen Ordner kopieren, damit sie wieder auffindbar ist
        if !FileManager.default.fileExists(atPath: url.path) {
            let local = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
                .appendingPathComponent(filename)
            if local.standardizedFileURL != url.standardizedFileURL,
               FileManager.default.fileExists(atPath: local.path) {
                try? FileManager.default.copyItem(at: local, to: url)
            }
        }
        return url
    }

    // MARK: - Widget-Daten

    private func updateWidgetData() {
        guard let defaults = UserDefaults(suiteName: "group.com.hansruffin.arca") else { return }
        defaults.set(vaultItems.count, forKey: "widget_vaultCount")
        defaults.set(documents.count, forKey: "widget_docCount")
        defaults.set(notes.count,     forKey: "widget_noteCount")
        defaults.set(lists.count,     forKey: "widget_listCount")
        defaults.set(UserDefaults.standard.string(forKey: "quickAccessTitle") ?? "", forKey: "widget_quickAccessTitle")
        defaults.set(UserDefaults.standard.string(forKey: "quickAccessKind")  ?? "", forKey: "widget_quickAccessKind")
        defaults.set(UserDefaults.standard.string(forKey: "quickAccessId")    ?? "", forKey: "widget_quickAccessId")
        WidgetCenter.shared.reloadAllTimelines()
    }

    // MARK: - Speichern

    private func saveVault() {
        let withoutPasswords = vaultItems.map {
            VaultEntry(id: $0.id, title: $0.title, username: $0.username,
                       password: "", url: $0.url, isFavorite: $0.isFavorite,
                       dateCreated: $0.dateCreated, colorTag: $0.colorTag)
        }
        saveJSON(withoutPasswords, key: "vaultItems")
        // Passwörter im iCloud Keychain (synchronizable: true → geräteübergreifend)
        for item in vaultItems {
            KeychainManager.shared.save(key: "vault_\(item.id)", value: item.password, synchronizable: true)
        }
        updateWidgetData()
    }

    private func saveDocuments() {
        saveJSON(documents, key: "documents")
        updateWidgetData()
    }

    private func saveNotes() {
        saveJSON(notes, key: "notes")
        updateWidgetData()
    }

    private func saveDocumentCategories() {
        saveJSON(documentCategories, key: "documentCategories")
    }

    private func saveCategoryColors() {
        saveJSON(categoryColors, key: "categoryColors")
    }

    private func saveLists() {
        saveJSON(lists, key: "lists")
        updateWidgetData()
    }

    private func saveDocumentSubcategories() {
        saveJSON(documentSubcategories, key: "documentSubcategories")
    }

    // MARK: - Laden

    private func load() {
        if var decoded = loadJSON([VaultEntry].self, key: "vaultItems") {
            for i in decoded.indices {
                // Passwort: zuerst sync Keychain, Fallback auf nicht-sync (alte Geräte)
                decoded[i].password =
                    KeychainManager.shared.load(key: "vault_\(decoded[i].id)", synchronizable: true)
                    ?? KeychainManager.shared.load(key: "vault_\(decoded[i].id)", synchronizable: false)
                    ?? ""
            }
            vaultItems = decoded
        }
        if let decoded = loadJSON([DocumentEntry].self, key: "documents") {
            documents = decoded
        }
        if let decoded = loadJSON([NoteEntry].self, key: "notes") {
            notes = decoded
        }
        if let decoded = loadJSON([ListEntry].self, key: "lists") {
            lists = decoded
        }
        if let decoded = loadJSON([String].self, key: "documentCategories") {
            documentCategories = decoded
        } else if documentCategories.isEmpty {
            documentCategories = AppStore.defaultCategories
        }
        if let decoded = loadJSON([String: Int].self, key: "categoryColors") {
            categoryColors = decoded
        }
        if let decoded = loadJSON([String: [String]].self, key: "documentSubcategories") {
            documentSubcategories = decoded
        }
        updateWidgetData()
    }

    // MARK: - Listen

    func addList(title: String, colorTag: Int = 0) {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        lists.append(ListEntry(title: trimmed, colorTag: colorTag))
    }

    func updateList(_ entry: ListEntry) {
        if let idx = lists.firstIndex(where: { $0.id == entry.id }) {
            lists[idx] = entry
        }
    }

    func updateNote(_ entry: NoteEntry) {
        if let idx = notes.firstIndex(where: { $0.id == entry.id }) {
            notes[idx] = entry
        }
    }

    func addQuickIdea(title: String, text: String) {
        let cleanTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanText  = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanTitle.isEmpty || !cleanText.isEmpty else { return }
        notes.insert(NoteEntry(title: cleanTitle, text: cleanText, isQuickIdea: true), at: 0)
    }

    func addNote(title: String, text: String, colorTag: Int = 0) {
        let cleanTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanTitle.isEmpty || !cleanText.isEmpty else { return }
        notes.append(NoteEntry(title: cleanTitle, text: cleanText, colorTag: colorTag))
    }

    func updateVaultEntry(_ entry: VaultEntry) {
        if let idx = vaultItems.firstIndex(where: { $0.id == entry.id }) {
            vaultItems[idx] = entry
        }
    }

    // MARK: - Schnellzugriff

    func pinDocumentForQuickAccess(_ doc: DocumentEntry) {
        UserDefaults.standard.set("doc",            forKey: "quickAccessKind")
        UserDefaults.standard.set(doc.id.uuidString, forKey: "quickAccessId")
        UserDefaults.standard.set(doc.title,         forKey: "quickAccessTitle")
        updateWidgetData()
    }

    func pinCategoryForQuickAccess(_ category: String) {
        UserDefaults.standard.set("category", forKey: "quickAccessKind")
        UserDefaults.standard.set(category,   forKey: "quickAccessId")
        UserDefaults.standard.set(category,   forKey: "quickAccessTitle")
        updateWidgetData()
    }

    func pinNoteForQuickAccess(_ note: NoteEntry) {
        UserDefaults.standard.set("note",                                           forKey: "quickAccessKind")
        UserDefaults.standard.set(note.id.uuidString,                              forKey: "quickAccessId")
        UserDefaults.standard.set(note.title.isEmpty ? "Notiz" : note.title,       forKey: "quickAccessTitle")
        updateWidgetData()
    }

    func unpinQuickAccess() {
        UserDefaults.standard.set("", forKey: "quickAccessKind")
        UserDefaults.standard.set("", forKey: "quickAccessId")
        UserDefaults.standard.set("", forKey: "quickAccessTitle")
        updateWidgetData()
    }

    func addVaultEntry(title: String, username: String, password: String, url: String = "", colorTag: Int = 0) {
        let cleanTitle    = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanUsername = username.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanPassword = password.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanURL      = url.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanTitle.isEmpty, !cleanPassword.isEmpty else { return }
        vaultItems.append(VaultEntry(title: cleanTitle, username: cleanUsername,
                                     password: cleanPassword, url: cleanURL, colorTag: colorTag))
    }
}
