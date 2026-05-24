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

    enum CodingKeys: String, CodingKey {
        case vaultItems, documents, notes, lists, documentCategories, exportDate, fileData
    }

    init(vaultItems: [VaultEntry],
         documents: [DocumentEntry],
         notes: [NoteEntry],
         lists: [ListEntry],
         documentCategories: [String],
         exportDate: Date,
         fileData: [String: Data]? = nil) {
        self.vaultItems = vaultItems
        self.documents = documents
        self.notes = notes
        self.lists = lists
        self.documentCategories = documentCategories
        self.exportDate = exportDate
        self.fileData = fileData
    }

    // Safe Decoder — alte Backups ohne fileData / lists bleiben kompatibel
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        vaultItems         = try c.decode([VaultEntry].self,            forKey: .vaultItems)
        documents          = try c.decode([DocumentEntry].self,         forKey: .documents)
        notes              = try c.decode([NoteEntry].self,             forKey: .notes)
        lists              = try c.decodeIfPresent([ListEntry].self,    forKey: .lists)              ?? []
        documentCategories = try c.decode([String].self,                forKey: .documentCategories)
        exportDate         = try c.decode(Date.self,                    forKey: .exportDate)
        fileData           = try c.decodeIfPresent([String: Data].self, forKey: .fileData)
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
    /// Wenn eine Datei von außen (z. B. Mail) geöffnet wird, landet die URL hier.
    /// DocumentsView beobachtet diesen Wert und zeigt dann den Save-Dialog.
    @Published var pendingSharedURL: URL? = nil
    @Published var pendingScrollCategory: String? = nil
    /// Von Siri-Shortcuts oder Widget-Deep-Links gesetzter Navigations-Tab
    @Published var pendingSection: ArcaSection? = nil
    /// Blitzidee-Aufnahme soll sofort starten (via Action Button Intent)
    @Published var pendingQuickCapture: Bool = false
    var importCategoryName: String {
        get { UserDefaults.standard.string(forKey: "importCategoryName") ?? "Import" }
        set { UserDefaults.standard.set(newValue, forKey: "importCategoryName") }
    }

    static let defaultCategories = ["Reise", "Papiere", "Rechnungen", "Verträge", "Gesundheit", "Sonstiges"]

    init() {
        load()
    }

    // MARK: - Export / Import

    func exportData(password: String) -> URL? {
        // Alle Dokument-Dateien mit ins Backup packen
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
            fileData: fileData
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

    func importData(from url: URL, password: String) -> Bool {
        guard url.startAccessingSecurityScopedResource() else { return false }
        defer { url.stopAccessingSecurityScopedResource() }
        guard let encryptedData = try? Data(contentsOf: url),
              let plaintext = try? decryptData(encryptedData, password: password),
              let backup = try? JSONDecoder().decode(ArcaBackup.self, from: plaintext) else {
            return false
        }

        // Dokument-Dateien wiederherstellen (falls im Backup enthalten)
        if let fileData = backup.fileData {
            for (filename, data) in fileData {
                let dest = documentURL(for: filename)
                try? data.write(to: dest)
            }
        }

        vaultItems = backup.vaultItems
        documents = backup.documents
        notes = backup.notes
        lists = backup.lists
        documentCategories = backup.documentCategories.isEmpty
            ? AppStore.defaultCategories
            : backup.documentCategories
        return true
    }

    // MARK: - Ordner Teilen (Familien-Funktion)

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
            exportDate: Date()
        )
        guard let data = try? JSONEncoder().encode(folder) else { return nil }
        let safeName = category.replacingOccurrences(of: " ", with: "_")
        let filename = "Arca_\(safeName).arcafolder"
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(filename)
        // Vorhandene Datei vorher löschen, sonst kann iOS bei manchen FS-Zuständen fehlschlagen
        try? FileManager.default.removeItem(at: url)
        do {
            try data.write(to: url)
        } catch {
            return nil
        }
        // Verifizieren dass die Datei existiert und nicht leer ist
        guard FileManager.default.fileExists(atPath: url.path),
              let size = try? FileManager.default.attributesOfItem(atPath: url.path)[.size] as? Int,
              size > 0 else {
            return nil
        }
        return url
    }

    func importFolder(from url: URL) -> String? {
        let accessing = url.startAccessingSecurityScopedResource()
        defer { if accessing { url.stopAccessingSecurityScopedResource() } }
        guard let data = try? Data(contentsOf: url),
              let folder = try? JSONDecoder().decode(ArcaFolder.self, from: data) else {
            return nil
        }
        // Dokument-Dateien speichern
        for (filename, fileData) in folder.fileData {
            let dest = documentURL(for: filename)
            try? fileData.write(to: dest)
        }
        // Kategorie hinzufügen falls nicht vorhanden
        var newCategoryName = folder.categoryName
        var counter = 2
        while documentCategories.contains(newCategoryName) {
            newCategoryName = "\(folder.categoryName) \(counter)"
            counter += 1
        }
        documentCategories.append(newCategoryName)
        // Dokumente mit neuer Kategorie hinzufügen
        let importedDocs = folder.documents.map { doc -> DocumentEntry in
            var d = doc
            d.id = UUID() // neue ID
            d.category = newCategoryName
            return d
        }
        documents.append(contentsOf: importedDocs)
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

    // Format v2: [4 magic "ARCA"] + [16 random salt] + [AES-GCM combined]
    // Format v1 (legacy): raw AES-GCM combined with fixed salt
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
            // Legacy format mit festem Salt
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

    func addDocument(title: String, type: DocumentType, filename: String, category: String = "Sonstiges") {
        let entry = DocumentEntry(title: title, type: type, filename: filename, dateAdded: Date(), category: category)
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
    }

    func deleteCategory(_ name: String) {
        let fallback = documentCategories.first(where: { $0 != name }) ?? "Sonstiges"
        documents = documents.map { doc in
            var d = doc; if d.category == name { d.category = fallback }; return d
        }
        documentCategories.removeAll { $0 == name }
    }

    func deleteDocument(_ entry: DocumentEntry) {
        let url = documentURL(for: entry.filename)
        try? FileManager.default.removeItem(at: url)
        documents.removeAll { $0.id == entry.id }
    }

    func documentURL(for filename: String) -> URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent(filename)
    }

    // MARK: - Speichern

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

    private func saveVault() {
        let itemsWithoutPasswords = vaultItems.map {
            VaultEntry(
                id: $0.id,
                title: $0.title,
                username: $0.username,
                password: "",
                url: $0.url,
                isFavorite: $0.isFavorite,
                dateCreated: $0.dateCreated,
                colorTag: $0.colorTag
            )
        }
        if let encoded = try? JSONEncoder().encode(itemsWithoutPasswords) {
            UserDefaults.standard.set(encoded, forKey: "vaultItems")
        }
        for item in vaultItems {
            KeychainManager.shared.save(key: "vault_\(item.id)", value: item.password)
        }
        updateWidgetData()
    }

    private func saveDocuments() {
        if let encoded = try? JSONEncoder().encode(documents) {
            UserDefaults.standard.set(encoded, forKey: "documents")
        }
        updateWidgetData()
    }

    private func saveNotes() {
        if let encoded = try? JSONEncoder().encode(notes) {
            UserDefaults.standard.set(encoded, forKey: "notes")
        }
        updateWidgetData()
    }

    private func saveDocumentCategories() {
        if let encoded = try? JSONEncoder().encode(documentCategories) {
            UserDefaults.standard.set(encoded, forKey: "documentCategories")
        }
    }

    private func saveCategoryColors() {
        if let encoded = try? JSONEncoder().encode(categoryColors) {
            UserDefaults.standard.set(encoded, forKey: "categoryColors")
        }
    }

    private func saveLists() {
        if let encoded = try? JSONEncoder().encode(lists) {
            UserDefaults.standard.set(encoded, forKey: "lists")
        }
        updateWidgetData()
    }

    // MARK: - Laden

    private func load() {
        if let data = UserDefaults.standard.data(forKey: "vaultItems"),
           var decoded = try? JSONDecoder().decode([VaultEntry].self, from: data) {
            for i in decoded.indices {
                decoded[i].password = KeychainManager.shared.load(key: "vault_\(decoded[i].id)") ?? ""
            }
            vaultItems = decoded
        }
        if let data = UserDefaults.standard.data(forKey: "documents"),
           let decoded = try? JSONDecoder().decode([DocumentEntry].self, from: data) {
            documents = decoded
        }
        if let data = UserDefaults.standard.data(forKey: "notes"),
           let decoded = try? JSONDecoder().decode([NoteEntry].self, from: data) {
            notes = decoded
        }
        if let data = UserDefaults.standard.data(forKey: "lists"),
           let decoded = try? JSONDecoder().decode([ListEntry].self, from: data) {
            lists = decoded
        }
        if let data = UserDefaults.standard.data(forKey: "documentCategories"),
           let decoded = try? JSONDecoder().decode([String].self, from: data) {
            documentCategories = decoded
        } else {
            documentCategories = AppStore.defaultCategories
        }
        if let data = UserDefaults.standard.data(forKey: "categoryColors"),
           let decoded = try? JSONDecoder().decode([String: Int].self, from: data) {
            categoryColors = decoded
        }
        updateWidgetData()
    }

    // MARK: - Funktionen

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

    // MARK: - Schnellzugriff (Quick Access auf Home-Screen)

    func pinDocumentForQuickAccess(_ doc: DocumentEntry) {
        UserDefaults.standard.set("doc", forKey: "quickAccessKind")
        UserDefaults.standard.set(doc.id.uuidString, forKey: "quickAccessId")
        UserDefaults.standard.set(doc.title, forKey: "quickAccessTitle")
        updateWidgetData()
    }

    func pinCategoryForQuickAccess(_ category: String) {
        UserDefaults.standard.set("category", forKey: "quickAccessKind")
        UserDefaults.standard.set(category, forKey: "quickAccessId")
        UserDefaults.standard.set(category, forKey: "quickAccessTitle")
        updateWidgetData()
    }

    func pinNoteForQuickAccess(_ note: NoteEntry) {
        UserDefaults.standard.set("note", forKey: "quickAccessKind")
        UserDefaults.standard.set(note.id.uuidString, forKey: "quickAccessId")
        UserDefaults.standard.set(note.title.isEmpty ? "Notiz" : note.title, forKey: "quickAccessTitle")
        updateWidgetData()
    }

    func unpinQuickAccess() {
        UserDefaults.standard.set("", forKey: "quickAccessKind")
        UserDefaults.standard.set("", forKey: "quickAccessId")
        UserDefaults.standard.set("", forKey: "quickAccessTitle")
        updateWidgetData()
    }

    func addVaultEntry(title: String, username: String, password: String, url: String = "", colorTag: Int = 0) {
        let cleanTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanUsername = username.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanPassword = password.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanURL = url.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanTitle.isEmpty, !cleanPassword.isEmpty else { return }
        vaultItems.append(VaultEntry(title: cleanTitle, username: cleanUsername, password: cleanPassword, url: cleanURL, colorTag: colorTag))
    }
}
