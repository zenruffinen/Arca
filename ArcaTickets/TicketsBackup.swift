//
//  TicketsBackup.swift
//  ArcaTickets
//
//  Entwickler: Hans zen Ruffinen
//

import CryptoKit
import Foundation
import UniformTypeIdentifiers
import AppleArchive
import System

// MARK: - Format

struct TicketsBackupManifest: Codable {
    static let formatVersion = 1

    var formatVersion: Int
    var tickets: [TicketEntry]
    var folders: [String]
    var sharedFolders: [String]
    var quickContacts: [QuickContact]
    var personalIDCard: PersonalIDCard
    var taxiContact: TaxiContact?
    var homeTaxiContact: TaxiContact?
    var golfContact: GolfContact?
    var travelNotes: TravelNotes?
    var opaSouvenirs: [SouvenirItem]?
    var kofferPIN: String?
    var golfschlaegerInfo: GolfschlaegerInfo?
    var exportDate: Date

    init(
        tickets: [TicketEntry],
        folders: [String],
        sharedFolders: Set<String>,
        quickContacts: [QuickContact],
        personalIDCard: PersonalIDCard,
        taxiContact: TaxiContact? = nil,
        homeTaxiContact: TaxiContact? = nil,
        golfContact: GolfContact? = nil,
        travelNotes: TravelNotes? = nil,
        opaSouvenirs: [SouvenirItem]? = nil,
        kofferPIN: String? = nil,
        golfschlaegerInfo: GolfschlaegerInfo? = nil
    ) {
        self.formatVersion = Self.formatVersion
        self.tickets = tickets
        self.folders = folders
        self.sharedFolders = Array(sharedFolders)
        self.quickContacts = quickContacts
        self.personalIDCard = personalIDCard
        self.taxiContact = taxiContact
        self.homeTaxiContact = homeTaxiContact
        self.golfContact = golfContact
        self.travelNotes = travelNotes
        self.opaSouvenirs = opaSouvenirs
        self.kofferPIN = kofferPIN
        self.golfschlaegerInfo = golfschlaegerInfo
        self.exportDate = Date()
    }
}

enum TicketsBackupType {
    static let extensionName = "arcaticketsbackup"
    static let uti = "com.hansruffin.arca.ticketsbackup"

    static var contentType: UTType {
        if let declared = UTType(uti) { return declared }
        if let byExt = UTType(filenameExtension: extensionName) { return byExt }
        return UTType(tag: extensionName, tagClass: .filenameExtension, conformingTo: .data)
            ?? UTType.data
    }

    static func isBackupURL(_ url: URL) -> Bool {
        if url.pathExtension.lowercased() == extensionName { return true }
        return TicketsBackupArchive.canExtractEncrypted(at: url)
    }
}

// MARK: - Archive I/O

enum TicketsBackupArchive {
    private static let manifestName = "manifest.json"
    private static let passwordSalt = Data("ArcaTicketsBackupSalt_v1".utf8)

    static let minPasswordLength = 4

    enum ExportError: Equatable, Error {
        case passwordTooShort
        case archiveFailed
    }

    enum ImportError: Equatable, Error {
        case fileAccessDenied
        case wrongPasswordOrCorrupt
        case manifestInvalid
        case invalidBackupFile
    }

    static func exportBackup(
        manifest: TicketsBackupManifest,
        filesDirectory: URL,
        password: String
    ) -> Result<URL, ExportError> {
        guard password.count >= minPasswordLength else { return .failure(.passwordTooShort) }

        let stage = FileManager.default.temporaryDirectory
            .appendingPathComponent("ArcaTicketsExport_\(UUID().uuidString)")
        let stageFiles = stage.appendingPathComponent("files")
        defer { try? FileManager.default.removeItem(at: stage) }

        do {
            try FileManager.default.createDirectory(at: stageFiles, withIntermediateDirectories: true)
            let manifestData = try JSONEncoder().encode(manifest)
            try manifestData.write(to: stage.appendingPathComponent(manifestName))

            for ticket in manifest.tickets {
                let src = filesDirectory.appendingPathComponent(ticket.fileName)
                guard FileManager.default.fileExists(atPath: src.path) else { continue }
                let dst = stageFiles.appendingPathComponent(ticket.fileName)
                if (try? FileManager.default.linkItem(at: src, to: dst)) == nil {
                    try? FileManager.default.copyItem(at: src, to: dst)
                }
            }
        } catch {
            return .failure(.archiveFailed)
        }

        let filename = "ArcaTicketsBackup_\(Date().formatted(date: .abbreviated, time: .omitted))"
            .replacingOccurrences(of: " ", with: "_")
            + ".\(TicketsBackupType.extensionName)"
        let dest = FileManager.default.temporaryDirectory.appendingPathComponent(filename)

        guard archiveDirectory(stage, to: dest, password: password),
              let size = try? FileManager.default.attributesOfItem(atPath: dest.path)[.size] as? Int,
              size > 0 else {
            return .failure(.archiveFailed)
        }
        return .success(dest)
    }

    private static let stagedImportPrefix = "ArcaTicketsImport_"

    /// Kopiert eine externe Backup-Datei lokal und prüft AEA-Magic-Bytes.
    static func stageImport(from url: URL) -> Result<URL, ImportError> {
        let accessing = url.startAccessingSecurityScopedResource()
        defer { if accessing { url.stopAccessingSecurityScopedResource() } }

        guard FileManager.default.isReadableFile(atPath: url.path) else {
            return .failure(.fileAccessDenied)
        }

        let staged = FileManager.default.temporaryDirectory
            .appendingPathComponent("\(stagedImportPrefix)\(UUID().uuidString).\(TicketsBackupType.extensionName)")
        try? FileManager.default.removeItem(at: staged)
        do {
            try FileManager.default.copyItem(at: url, to: staged)
        } catch {
            return .failure(.fileAccessDenied)
        }

        guard canExtractEncrypted(at: staged) else {
            try? FileManager.default.removeItem(at: staged)
            return .failure(.invalidBackupFile)
        }
        return .success(staged)
    }

    static func canExtractEncrypted(at url: URL) -> Bool {
        guard readMagic(at: url, count: 4) == Data("AEA1".utf8) else { return false }
        return true
    }

    static func importBackup(
        from url: URL,
        password: String,
        into store: TicketStore,
        merge: Bool
    ) -> Result<TicketsBackupManifest, ImportError> {
        guard let extracted = extractArchive(url, password: password) else {
            return .failure(.wrongPasswordOrCorrupt)
        }
        defer { try? FileManager.default.removeItem(at: extracted) }

        let manifestURL = extracted.appendingPathComponent(manifestName)
        guard let manifestData = try? Data(contentsOf: manifestURL),
              let manifest = try? JSONDecoder().decode(TicketsBackupManifest.self, from: manifestData),
              manifest.formatVersion == TicketsBackupManifest.formatVersion else {
            return .failure(.manifestInvalid)
        }

        store.applyBackup(manifest, filesFrom: extracted.appendingPathComponent("files"), merge: merge)
        return .success(manifest)
    }

    // MARK: - Private helpers

    private static func aeaPassword(from userPassword: String) -> String {
        guard let passwordData = userPassword.data(using: .utf8) else { return userPassword }
        let key = HKDF<SHA256>.deriveKey(
            inputKeyMaterial: SymmetricKey(data: passwordData),
            salt: passwordSalt,
            info: Data("AEA".utf8),
            outputByteCount: 32)
        return key.withUnsafeBytes { Data($0) }.base64EncodedString()
    }

    private static func readMagic(at url: URL, count: Int) -> Data? {
        guard let fh = try? FileHandle(forReadingFrom: url) else { return nil }
        defer { try? fh.close() }
        return try? fh.read(upToCount: count)
    }

    private static func archiveDirectory(_ dir: URL, to dest: URL, password: String) -> Bool {
        try? FileManager.default.removeItem(at: dest)
        do {
            guard let fileStream = ArchiveByteStream.fileStream(
                path: FilePath(dest.path), mode: .writeOnly,
                options: [.create, .truncate],
                permissions: FilePermissions(rawValue: 0o644)) else { return false }
            defer { try? fileStream.close() }

            let aeaPwd = aeaPassword(from: password)
            let ctx = ArchiveEncryptionContext(
                profile: .hkdf_sha256_aesctr_hmac__scrypt__none,
                compressionAlgorithm: .lzfse)
            try ctx.setPassword(aeaPwd)
            guard let encryptionStream = ArchiveByteStream.encryptionStream(
                writingTo: fileStream, encryptionContext: ctx) else { return false }
            defer { try? encryptionStream.close() }

            guard let encoder = ArchiveStream.encodeStream(writingTo: encryptionStream) else { return false }
            defer { try? encoder.close() }

            try encoder.writeDirectoryContents(
                archiveFrom: FilePath(dir.path), keySet: .defaultForArchive)

            try encoder.close()
            try encryptionStream.close()
            try fileStream.close()
            return true
        } catch {
            try? FileManager.default.removeItem(at: dest)
            return false
        }
    }

    private static func extractArchive(_ url: URL, password: String) -> URL? {
        let derived = aeaPassword(from: password)
        for candidate in [derived, password] {
            if let outDir = tryExtractArchive(url, password: candidate) {
                return outDir
            }
        }
        return nil
    }

    private static func tryExtractArchive(_ url: URL, password: String) -> URL? {
        let outDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("ArcaTicketsExtract_\(UUID().uuidString)")
        do {
            try FileManager.default.createDirectory(at: outDir, withIntermediateDirectories: true)
            guard let fileStream = ArchiveByteStream.fileStream(
                path: FilePath(url.path), mode: .readOnly,
                options: [], permissions: FilePermissions(rawValue: 0o644)) else { return nil }
            defer { try? fileStream.close() }

            guard let ctx = ArchiveEncryptionContext(from: fileStream) else { return nil }
            try ctx.setPassword(password)
            guard let decryptionStream = ArchiveByteStream.decryptionStream(
                readingFrom: fileStream, encryptionContext: ctx) else { return nil }
            defer { try? decryptionStream.close() }

            guard let decoder = ArchiveStream.decodeStream(readingFrom: decryptionStream) else { return nil }
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
}

#if canImport(UIKit)
import LinkPresentation

/// Share-Item für Backup-Export: erzwingt UTType + Dateiname mit .arcaticketsbackup.
final class TicketsBackupShareActivityItem: NSObject, UIActivityItemSource {
    let fileURL: URL

    init(fileURL: URL) {
        self.fileURL = fileURL
    }

    func activityViewControllerPlaceholderItem(_ activityViewController: UIActivityViewController) -> Any {
        fileURL
    }

    func activityViewController(
        _ activityViewController: UIActivityViewController,
        itemForActivityType activityType: UIActivity.ActivityType?
    ) -> Any? {
        fileURL
    }

    func activityViewController(
        _ activityViewController: UIActivityViewController,
        subjectForActivityType activityType: UIActivity.ActivityType?
    ) -> String {
        fileURL.lastPathComponent
    }

    func activityViewController(
        _ activityViewController: UIActivityViewController,
        dataTypeIdentifierForActivityType activityType: UIActivity.ActivityType?
    ) -> String {
        TicketsBackupType.contentType.identifier
    }
}
#endif
