import SwiftUI
import Combine
import CryptoKit
import WidgetKit

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
    }

    // MARK: - Export / Import

    func exportData(password: String) -> URL? {
        var fileData: [String: Data] = [:]
        for doc in documents {
            let fileURL = documentURL(for: doc.filename)
            if let data = try? Data(contentsOf: fileURL) {
                fileData[doc.filename] = data
            }
        }

        let backup = ArcaBackup(
            vaultItems: vaultItems,
            documents: documents,
            notes: notes,
            lists: lists,
            documentCategories: documentCategories,
            exportDate: Date(),
            fileData: fileData,
            documentSubcategories: documentSubcategories
        )
        guard let plaintext = try? JSONEncoder().encode(backup) else { return nil }
        guard let encrypted = try? encryptData(plaintext, password: password) else { return nil }
        let filename = "ArcaBackup_\(Date().formatted(date: .abbreviated, time: .omitted)).arcabackup"
            .replacingOccurrences(of: " ", with: "_")
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(filename)
        try? FileManager.default.removeItem(at: url)
        do { try encrypted.write(to: url) } catch { return nil }
        guard FileManager.default.fileExists(atPath: url.path),
              let size = try? FileManager.default.attributesOfItem(atPath: url.path)[.size] as? Int,
              size > 0 else {
            return nil
        }
        return url
    }

    func importData(from url: URL, password: String, merge: Bool = false) -> Bool {
        guard url.startAccessingSecurityScopedResource() else { return false }
        defer { url.stopAccessingSecurityScopedResource() }
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
        return true
    }

    // MARK: - Ordner Teilen

    func exportFolder(category: String) -> URL? {
        let docsInCategory = documents.filter { $0.category == category }
        var fileData: [String: Data] = [:]
        for doc in docsInCategory {
            let fileURL = documentURL(for: doc.filename)
            if let data = try? Data(contentsOf: fileURL) {
                fileData[doc.filename] = data
            }
        }
        let folder = ArcaFolder(
            categoryName: category,
            documents: docsInCategory,
            fileData: fileData,
            exportDate: Date(),
            subcategories: documentSubcategories[category]
        )
        guard let data = try? JSONEncoder().encode(folder) else { return nil }
        let safeName = category.replacingOccurrences(of: " ", with: "_")
        let filename = "Arca_\(safeName).arcafolder"
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(filename)
        try? FileManager.default.removeItem(at: url)
        do { try data.write(to: url) } catch { return nil }
        guard FileManager.default.fileExists(atPath: url.path),
              let size = try? FileManager.default.attributesOfItem(atPath: url.path)[.size] as? Int,
              size > 0 else { return nil }
        return url
    }

    func exportDocument(_ doc: DocumentEntry) -> URL? {
        var fileData: [String: Data] = [:]
        let fileURL = documentURL(for: doc.filename)
        if let data = try? Data(contentsOf: fileURL) {
            fileData[doc.filename] = data
        }
        let folder = ArcaFolder(
            categoryName: doc.category,
            documents: [doc],
            fileData: fileData,
            exportDate: Date(),
            subcategories: documentSubcategories[doc.category]
        )
        guard let data = try? JSONEncoder().encode(folder) else { return nil }
        let safeName = doc.title.replacingOccurrences(of: " ", with: "_")
            .replacingOccurrences(of: "/", with: "-")
        let filename = "Arca_\(safeName).arcafolder"
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(filename)
        try? FileManager.default.removeItem(at: url)
        do { try data.write(to: url) } catch { return nil }
        guard FileManager.default.fileExists(atPath: url.path),
              let size = try? FileManager.default.attributesOfItem(atPath: url.path)[.size] as? Int,
              size > 0 else { return nil }
        return url
    }

    func importFolder(from url: URL) -> String? {
        let accessing = url.startAccessingSecurityScopedResource()
        defer { if accessing { url.stopAccessingSecurityScopedResource() } }
        guard let data = try? Data(contentsOf: url),
              let folder = try? JSONDecoder().decode(ArcaFolder.self, from: data) else {
            return nil
        }
        for (filename, fileData) in folder.fileData {
            let dest = documentURL(for: filename)
            try? fileData.write(to: dest)
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
        filesDirectory.appendingPathComponent(filename)
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
