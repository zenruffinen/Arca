//
//  TicketStore.swift
//  ArcaTickets
//
//  Entwickler: Hans zen Ruffinen
//

import SwiftUI
import Combine

final class TicketStore: ObservableObject {
    private var isLoadingData = false

    @Published var tickets: [TicketEntry] = [] {
        didSet {
            guard !isLoadingData else { return }
            saveTickets()
            NotificationManager.rescheduleAll(for: tickets)
            WidgetDataUpdater.update(from: tickets)
        }
    }
    @Published var folders: [String] = [] {
        didSet { guard !isLoadingData else { return }; saveFolders() }
    }
    @Published private(set) var isCloudSyncPending = false

    enum ICloudStatus: String {
        case unavailable = "Nicht verfügbar"
        case connected = "iCloud: verbunden"
        case downloading = "Warte auf Download"
        case synced = "Synchronisiert"
    }

    @Published private(set) var iCloudStatus: ICloudStatus = .unavailable

    static let defaultFolders = ["Bahn", "Abos", "Berge", "Sonstiges"]
    static let pinHashKey = "arcatickets_pin_hash"

    private static let cloudSyncTimeout: TimeInterval = 30
    private var cloudSyncPollTimer: Timer?
    private var cloudSyncStartedAt: Date?

    private let cloudContainerID = "iCloud.com.hansruffin.ArcaTickets"

    private var cloudContainer: URL? {
        FileManager.default.url(forUbiquityContainerIdentifier: cloudContainerID)
    }

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

    private func cloudPlaceholderURL(for fileURL: URL) -> URL {
        fileURL.deletingLastPathComponent()
            .appendingPathComponent(".\(fileURL.lastPathComponent).icloud")
    }

    private func hasCloudPlaceholder(at fileURL: URL) -> Bool {
        FileManager.default.fileExists(atPath: cloudPlaceholderURL(for: fileURL).path)
    }

    var isICloudAvailable: Bool { cloudContainer != nil }

    private func hasPendingCloudDataDownloads() -> Bool {
        guard cloudContainer != nil else { return false }
        for dir in [dataDirectory, filesDirectory] {
            guard let files = try? FileManager.default.contentsOfDirectory(
                at: dir, includingPropertiesForKeys: nil) else { continue }
            if files.contains(where: { $0.lastPathComponent.hasSuffix(".icloud") }) { return true }
        }
        return false
    }

    private func hasAnyExistingDataStore() -> Bool {
        for key in ["tickets", "folders"] {
            let url = dataURL(key)
            if FileManager.default.fileExists(atPath: url.path) { return true }
            if hasCloudPlaceholder(at: url) { return true }
        }
        return false
    }

    func updateCloudSyncState() {
        guard isICloudAvailable else {
            iCloudStatus = .unavailable
            isCloudSyncPending = false
            return
        }
        if hasPendingCloudDataDownloads() {
            iCloudStatus = .downloading
            isCloudSyncPending = true
        } else if hasAnyExistingDataStore() {
            iCloudStatus = .synced
            isCloudSyncPending = false
        } else {
            iCloudStatus = .connected
            isCloudSyncPending = false
        }
    }

    private func beginCloudSyncMonitoringIfNeeded() {
        updateCloudSyncState()
        guard isCloudSyncPending else {
            stopCloudSyncMonitoring()
            return
        }
        cloudSyncStartedAt = cloudSyncStartedAt ?? Date()
        guard cloudSyncPollTimer == nil else { return }
        cloudSyncPollTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            self?.pollCloudSyncProgress()
        }
    }

    private func stopCloudSyncMonitoring() {
        cloudSyncPollTimer?.invalidate()
        cloudSyncPollTimer = nil
        cloudSyncStartedAt = nil
    }

    private func pollCloudSyncProgress() {
        updateCloudSyncState()
        if !isCloudSyncPending {
            stopCloudSyncMonitoring()
            return
        }
        downloadAllCloudFiles()
        if let started = cloudSyncStartedAt,
           Date().timeIntervalSince(started) >= Self.cloudSyncTimeout {
            isCloudSyncPending = false
            stopCloudSyncMonitoring()
        }
    }

    private func waitForPendingCloudDownloads(timeout: TimeInterval = 3.0) {
        guard cloudContainer != nil else { return }
        var pending: [URL] = []
        guard let files = try? FileManager.default.contentsOfDirectory(
            at: dataDirectory, includingPropertiesForKeys: nil) else { return }
        for f in files where f.lastPathComponent.hasSuffix(".icloud") {
            var name = f.lastPathComponent
            name.removeFirst()
            name.removeLast(".icloud".count)
            let target = dataDirectory.appendingPathComponent(name)
            pending.append(target)
            try? FileManager.default.startDownloadingUbiquitousItem(at: target)
        }
        guard !pending.isEmpty else { return }
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            let stillPending = pending.contains { url in
                guard FileManager.default.fileExists(atPath: url.path) else { return true }
                guard let status = try? url.resourceValues(forKeys: [.ubiquitousItemDownloadingStatusKey])
                    .ubiquitousItemDownloadingStatus else { return true }
                return status != .current
            }
            if !stillPending { break }
            RunLoop.current.run(until: Date().addingTimeInterval(0.05))
        }
    }

    private func startObservingCloudDownloads() {
        NotificationCenter.default.addObserver(
            forName: Notification.Name("NSUbiquitousItemDidDownload"),
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.reloadFromCloud()
            self?.updateCloudSyncState()
            self?.beginCloudSyncMonitoringIfNeeded()
        }
    }

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

    func downloadAllCloudFiles() {
        guard cloudContainer != nil else { return }
        let dirs = [filesDirectory, dataDirectory]
        DispatchQueue.global(qos: .utility).async {
            for dir in dirs {
                guard let files = try? FileManager.default.contentsOfDirectory(
                    at: dir, includingPropertiesForKeys: nil) else { continue }
                for f in files where f.lastPathComponent.hasSuffix(".icloud") {
                    var name = f.lastPathComponent
                    name.removeFirst()
                    name.removeLast(".icloud".count)
                    let target = dir.appendingPathComponent(name)
                    try? FileManager.default.startDownloadingUbiquitousItem(at: target)
                }
            }
        }
    }

    private func saveJSON<T: Encodable>(_ value: T, key: String) {
        guard !isLoadingData else { return }
        let url = dataURL(key)
        if hasCloudPlaceholder(at: url) { return }
        guard let data = try? JSONEncoder().encode(value) else { return }
        let coordinator = NSFileCoordinator(filePresenter: nil)
        var err: NSError?
        coordinator.coordinate(writingItemAt: url, options: .forReplacing, error: &err) { u in
            try? data.write(to: u, options: .atomic)
        }
    }

    private func loadJSON<T: Decodable>(_ type: T.Type, key: String) -> T? {
        let url = dataURL(key)
        if hasCloudPlaceholder(at: url) {
            try? FileManager.default.startDownloadingUbiquitousItem(at: url)
            return nil
        }
        guard FileManager.default.fileExists(atPath: url.path) else { return nil }
        var result: T? = nil
        let coordinator = NSFileCoordinator(filePresenter: nil)
        var err: NSError?
        coordinator.coordinate(readingItemAt: url, options: .withoutChanges, error: &err) { u in
            guard let data = try? Data(contentsOf: u), !data.isEmpty else { return }
            result = try? JSONDecoder().decode(type, from: data)
        }
        return result
    }

    init() {
        waitForPendingCloudDownloads()
        isLoadingData = true
        load()
        isLoadingData = false
        persistFreshInstallDefaults()
        downloadAllCloudFiles()
        startObservingCloudDownloads()
        updateCloudSyncState()
        beginCloudSyncMonitoringIfNeeded()
        NotificationManager.rescheduleAll(for: tickets)
        WidgetDataUpdater.update(from: tickets)
    }

    private func persistFreshInstallDefaults() {
        guard !hasAnyExistingDataStore() else { return }
        guard !hasPendingCloudDataDownloads() else { return }
        if folders.isEmpty {
            folders = Self.defaultFolders
        } else {
            saveFolders()
        }
    }

    func reloadFromCloud() {
        waitForPendingCloudDownloads(timeout: 1.0)
        isLoadingData = true
        load()
        isLoadingData = false
        downloadAllCloudFiles()
        updateCloudSyncState()
        beginCloudSyncMonitoringIfNeeded()
    }

    private func load() {
        if let decoded = loadJSON([TicketEntry].self, key: "tickets") {
            tickets = decoded
        }
        if let decoded = loadJSON([String].self, key: "folders") {
            folders = decoded
        } else if folders.isEmpty,
                  !hasPendingCloudDataDownloads(),
                  !hasAnyExistingDataStore() {
            folders = Self.defaultFolders
        }
    }

    private func saveTickets() {
        saveJSON(tickets, key: "tickets")
    }

    private func saveFolders() {
        saveJSON(folders, key: "folders")
    }

    // MARK: - Tickets

    func ticketCount(in folder: String) -> Int {
        tickets.filter { $0.folder == folder }.count
    }

    func tickets(in folder: String, filter: TicketExpiryFilter = .active) -> [TicketEntry] {
        tickets
            .filter { $0.folder == folder }
            .filter { matchesFilter($0, filter: filter) }
            .sorted { lhs, rhs in
                switch (lhs.expiryDate, rhs.expiryDate) {
                case let (l?, r?): return l < r
                case (nil, _?): return false
                case (_?, nil): return true
                case (nil, nil): return lhs.createdAt > rhs.createdAt
                }
            }
    }

    private func matchesFilter(_ ticket: TicketEntry, filter: TicketExpiryFilter) -> Bool {
        switch filter {
        case .active: return ticket.isValid
        case .expired: return ticket.isExpired || ticket.isArchived
        case .all: return true
        }
    }

    func addFolder(named name: String) -> Bool {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !folders.contains(trimmed) else { return false }
        folders.append(trimmed)
        return true
    }

    func renameFolder(from oldName: String, to newName: String) -> Bool {
        let trimmed = newName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, trimmed != oldName, !folders.contains(trimmed) else { return false }
        guard let idx = folders.firstIndex(of: oldName) else { return false }
        folders[idx] = trimmed
        for i in tickets.indices where tickets[i].folder == oldName {
            tickets[i].folder = trimmed
        }
        return true
    }

    func deleteFolder(_ name: String, moveTicketsTo fallback: String = "Sonstiges") -> Bool {
        guard folders.contains(name), folders.count > 1 else { return false }
        let target = folders.contains(fallback) ? fallback : folders.first { $0 != name } ?? fallback
        for i in tickets.indices where tickets[i].folder == name {
            tickets[i].folder = target
        }
        folders.removeAll { $0 == name }
        return true
    }

    func allTicketsSorted() -> [TicketEntry] {
        tickets.sorted { lhs, rhs in
            switch (lhs.expiryDate, rhs.expiryDate) {
            case let (l?, r?): return l < r
            case (nil, _?): return false
            case (_?, nil): return true
            case (nil, nil): return lhs.createdAt > rhs.createdAt
            }
        }
    }

    /// Nächstes gültiges Ticket — zuerst mit baldigem Ablauf, sonst zuletzt hinzugefügt.
    func archiveTicket(_ entry: TicketEntry) {
        guard let idx = tickets.firstIndex(where: { $0.id == entry.id }) else { return }
        tickets[idx].isArchived = true
        NotificationManager.removeReminder(for: tickets[idx])
    }

    var nextTicket: TicketEntry? {
        let valid = tickets.filter(\.isValid)
        let withExpiry = valid
            .filter { $0.expiryDate != nil }
            .sorted { ($0.expiryDate ?? .distantFuture) < ($1.expiryDate ?? .distantFuture) }
        if let soonest = withExpiry.first { return soonest }
        return valid.max(by: { $0.createdAt < $1.createdAt })
    }

    func fileURL(for filename: String) -> URL {
        let url = filesDirectory.appendingPathComponent(filename)
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

    @discardableResult
    func importFile(from sourceURL: URL, suggestedTitle: String, folder: String) -> TicketEntry? {
        let accessing = sourceURL.startAccessingSecurityScopedResource()
        defer { if accessing { sourceURL.stopAccessingSecurityScopedResource() } }

        let ext = sourceURL.pathExtension.isEmpty ? "jpg" : sourceURL.pathExtension
        let filename = "\(UUID().uuidString).\(ext)"
        let dest = fileURL(for: filename)

        do {
            if FileManager.default.fileExists(atPath: dest.path) {
                try FileManager.default.removeItem(at: dest)
            }
            try FileManager.default.copyItem(at: sourceURL, to: dest)
        } catch {
            return nil
        }

        let title = suggestedTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        let entry = TicketEntry(
            title: title.isEmpty ? sourceURL.deletingPathExtension().lastPathComponent : title,
            folder: folder,
            fileName: filename
        )
        tickets.append(entry)
        return entry
    }

    @discardableResult
    func importData(_ data: Data, fileExtension: String, title: String, folder: String) -> TicketEntry? {
        let ext = fileExtension.isEmpty ? "jpg" : fileExtension
        let filename = "\(UUID().uuidString).\(ext)"
        let dest = fileURL(for: filename)
        do {
            try data.write(to: dest, options: .atomic)
        } catch {
            return nil
        }
        let entry = TicketEntry(title: title, folder: folder, fileName: filename)
        tickets.append(entry)
        return entry
    }

    func updateTicket(_ entry: TicketEntry) {
        if let idx = tickets.firstIndex(where: { $0.id == entry.id }) {
            tickets[idx] = entry
        }
    }

    func deleteTicket(_ entry: TicketEntry) {
        let url = fileURL(for: entry.fileName)
        try? FileManager.default.removeItem(at: url)
        NotificationManager.removeReminder(for: entry)
        tickets.removeAll { $0.id == entry.id }
    }

    func resetAllData() {
        for ticket in tickets {
            try? FileManager.default.removeItem(at: fileURL(for: ticket.fileName))
        }
        tickets = []
        folders = Self.defaultFolders
        KeychainManager.shared.delete(key: Self.pinHashKey)
    }
}
