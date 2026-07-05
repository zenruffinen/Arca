//
//  FolderSharing.swift
//  ArcaTickets
//
//  Entwickler: Hans zen Ruffinen
//

import SwiftUI
import UniformTypeIdentifiers
import AppleArchive
import System

// MARK: - Package format

struct TicketsFolderExport: Codable {
    static let formatVersion = 1

    var formatVersion: Int
    var folderName: String
    var tickets: [TicketEntry]
    var exportDate: Date
    var exportedBy: String?

    init(folderName: String, tickets: [TicketEntry], exportedBy: String? = nil) {
        self.formatVersion = Self.formatVersion
        self.folderName = folderName
        self.tickets = tickets
        self.exportDate = Date()
        self.exportedBy = exportedBy
    }
}

enum FolderImportError: Equatable, Error {
    case fileAccessDenied
    case invalidPackage
    case emptyFolder
}

enum TicketsFolderShareType {
    static let extensionName = "arcaticketsfolder"
    static let uti = "com.hansruffin.arca.ticketsfolder"

    static var contentType: UTType {
        if let declared = UTType(uti) { return declared }
        if let byExt = UTType(filenameExtension: extensionName) { return byExt }
        return UTType(tag: extensionName, tagClass: .filenameExtension, conformingTo: .data)
            ?? UTType.data
    }

    static func isPackageURL(_ url: URL) -> Bool {
        if url.pathExtension.lowercased() == extensionName { return true }
        return FolderArchive.canExtract(at: url)
    }
}

// MARK: - Archive I/O

enum FolderArchive {
    private static let manifestName = "manifest.json"

    static func canExtract(at url: URL) -> Bool {
        let accessing = url.startAccessingSecurityScopedResource()
        defer { if accessing { url.stopAccessingSecurityScopedResource() } }
        guard let outDir = tryExtract(url) else { return false }
        defer { try? FileManager.default.removeItem(at: outDir) }
        let manifest = outDir.appendingPathComponent(manifestName)
        guard FileManager.default.fileExists(atPath: manifest.path),
              let data = try? Data(contentsOf: manifest),
              let export = try? JSONDecoder().decode(TicketsFolderExport.self, from: data) else {
            return false
        }
        return export.formatVersion == TicketsFolderExport.formatVersion
    }

    static func exportPackage(folderName: String, tickets: [TicketEntry], filesDirectory: URL) -> URL? {
        let stage = FileManager.default.temporaryDirectory
            .appendingPathComponent("ArcaTicketsFolderExport_\(UUID().uuidString)")
        let stageFiles = stage.appendingPathComponent("files")
        defer { try? FileManager.default.removeItem(at: stage) }

        do {
            try FileManager.default.createDirectory(at: stageFiles, withIntermediateDirectories: true)
            let manifest = TicketsFolderExport(folderName: folderName, tickets: tickets)
            let manifestData = try JSONEncoder().encode(manifest)
            try manifestData.write(to: stage.appendingPathComponent(manifestName))

            for ticket in tickets {
                let src = filesDirectory.appendingPathComponent(ticket.fileName)
                guard FileManager.default.fileExists(atPath: src.path) else { continue }
                let dst = stageFiles.appendingPathComponent(ticket.fileName)
                if (try? FileManager.default.linkItem(at: src, to: dst)) == nil {
                    try? FileManager.default.copyItem(at: src, to: dst)
                }
            }
        } catch {
            return nil
        }

        let safeName = folderName
            .replacingOccurrences(of: " ", with: "_")
            .replacingOccurrences(of: "/", with: "-")
        let dest = FileManager.default.temporaryDirectory
            .appendingPathComponent("ArcaTickets_\(safeName).\(TicketsFolderShareType.extensionName)")

        guard archiveDirectory(stage, to: dest),
              let size = try? FileManager.default.attributesOfItem(atPath: dest.path)[.size] as? Int,
              size > 0 else {
            return nil
        }
        return dest
    }

    static func importPackage(from url: URL, into store: TicketStore) -> Result<String, FolderImportError> {
        let accessing = url.startAccessingSecurityScopedResource()
        defer { if accessing { url.stopAccessingSecurityScopedResource() } }

        guard let extracted = tryExtract(url) else { return .failure(.invalidPackage) }
        defer { try? FileManager.default.removeItem(at: extracted) }

        let manifestURL = extracted.appendingPathComponent(manifestName)
        guard let manifestData = try? Data(contentsOf: manifestURL),
              let export = try? JSONDecoder().decode(TicketsFolderExport.self, from: manifestData),
              export.formatVersion == TicketsFolderExport.formatVersion else {
            return .failure(.invalidPackage)
        }
        guard !export.tickets.isEmpty else { return .failure(.emptyFolder) }

        let importedName = store.mergeImportedFolder(from: export, filesFrom: extracted.appendingPathComponent("files"))
        return .success(importedName)
    }

    private static func archiveDirectory(_ dir: URL, to dest: URL) -> Bool {
        try? FileManager.default.removeItem(at: dest)
        do {
            guard let fileStream = ArchiveByteStream.fileStream(
                path: FilePath(dest.path), mode: .writeOnly,
                options: [.create, .truncate],
                permissions: FilePermissions(rawValue: 0o644)) else { return false }
            defer { try? fileStream.close() }

            guard let encoder = ArchiveStream.encodeStream(writingTo: fileStream) else { return false }
            defer { try? encoder.close() }

            try encoder.writeDirectoryContents(
                archiveFrom: FilePath(dir.path), keySet: .defaultForArchive)

            try encoder.close()
            try fileStream.close()
            return true
        } catch {
            try? FileManager.default.removeItem(at: dest)
            return false
        }
    }

    private static func tryExtract(_ url: URL) -> URL? {
        let outDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("ArcaTicketsExtract_\(UUID().uuidString)")
        do {
            try FileManager.default.createDirectory(at: outDir, withIntermediateDirectories: true)
            guard let fileStream = ArchiveByteStream.fileStream(
                path: FilePath(url.path), mode: .readOnly,
                options: [], permissions: FilePermissions(rawValue: 0o644)) else { return nil }
            defer { try? fileStream.close() }

            guard let decoder = ArchiveStream.decodeStream(readingFrom: fileStream) else { return nil }
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

// MARK: - Share UI

struct ShareURLItem: Identifiable {
    let id = UUID()
    let url: URL
    var isTicketsBackup: Bool = false
}

struct ShareSheet: UIViewControllerRepresentable {
    let activityItems: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
    }

    func updateUIViewController(_ uvc: UIActivityViewController, context: Context) {}
}

struct BackupImportDocumentPicker: UIViewControllerRepresentable {
    var contentType: UTType
    var directoryURL: URL?
    var onPick: (URL) -> Void
    var onCancel: () -> Void

    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: [contentType], asCopy: true)
        picker.directoryURL = directoryURL
        picker.delegate = context.coordinator
        picker.allowsMultipleSelection = false
        return picker
    }

    func updateUIViewController(_ picker: UIDocumentPickerViewController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(onPick: onPick, onCancel: onCancel)
    }

    final class Coordinator: NSObject, UIDocumentPickerDelegate {
        let onPick: (URL) -> Void
        let onCancel: () -> Void

        init(onPick: @escaping (URL) -> Void, onCancel: @escaping () -> Void) {
            self.onPick = onPick
            self.onCancel = onCancel
        }

        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            guard let url = urls.first else {
                onCancel()
                return
            }
            onPick(url)
        }

        func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
            onCancel()
        }
    }
}

struct FolderShareExportItem: Transferable {
    let url: URL

    static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(exportedContentType: TicketsFolderShareType.contentType) { item in
            SentTransferredFile(item.url)
        }
    }
}
