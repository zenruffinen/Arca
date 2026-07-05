//
//  SettingsView.swift
//  ArcaTickets
//
//  Entwickler: Hans zen Ruffinen
//

import SwiftUI
import StoreKit
import UniformTypeIdentifiers

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.requestReview) private var requestReview
    @EnvironmentObject private var store: TicketStore

    @State private var showFolderManagement = false
    @State private var showContactsManagement = false
    @State private var showFolderImportPicker = false
    @State private var folderImportResult: String?
    @State private var showFolderImportAlert = false
    @State private var folderImportFailed = false

    private var appVersion: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "\(version) (\(build))"
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack {
                        Label("iCloud", systemImage: "icloud.fill")
                        Spacer()
                        Text(store.iCloudStatus.rawValue)
                            .font(.subheadline)
                            .foregroundStyle(store.iCloudStatus == .downloading ? .orange : .secondary)
                    }
                    if store.isICloudAvailable {
                        Text("Tickets und Dateien werden über iCloud Drive synchronisiert. Bei „Warte auf Download“ werden Inhalte noch aus der Cloud geladen.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else {
                        Text("iCloud ist nicht verfügbar. Daten werden lokal auf diesem Gerät gespeichert.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                } header: {
                    Text("Synchronisation")
                }

                Section {
                    Button {
                        showContactsManagement = true
                    } label: {
                        HStack {
                            Label("Wichtige Nummern", systemImage: "phone.fill")
                            Spacer()
                            Text("\(store.quickContacts.count)")
                                .foregroundStyle(.secondary)
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                        }
                    }
                    .foregroundStyle(.primary)

                    Button {
                        showFolderManagement = true
                    } label: {
                        HStack {
                            Label("Ordner verwalten", systemImage: "folder.badge.gearshape")
                            Spacer()
                            Text("\(store.folders.count)")
                                .foregroundStyle(.secondary)
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                        }
                    }
                    .foregroundStyle(.primary)
                } header: {
                    Text("Organisation")
                } footer: {
                    Text("Notrufnummern, Hotel, Fluggesellschaft und Familie — auf dem Tab „Unterwegs“ griffbereit. Ordner z. B. „Reise Zermatt“ für die ganze Familie.")
                }

                Section {
                    Button {
                        showFolderImportPicker = true
                    } label: {
                        Label("Geteilten Ordner importieren", systemImage: "square.and.arrow.down")
                    }
                } header: {
                    Text("Familie")
                } footer: {
                    Text("Reise teilen — Familie erhält alle Tickets. Wenn dir jemand eine .arcaticketsfolder-Datei geschickt hat, importiere sie hier oder tippe die Datei in Dateien/Nachrichten an.")
                }

                Section {
                    LabeledContent("Tickets gespeichert", value: "\(store.tickets.count)")
                    Text("Abos und Saisonkarten: Erinnerung 30 Tage vor Ablauf. Alle anderen Tickets: 1 Tag vorher.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } header: {
                    Text("Erinnerungen")
                }

                Section {
                    Text("PIN und Face ID schützen den Zugriff auf deine Tickets.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } header: {
                    Text("Sicherheit")
                }

                aboutSection
            }
            .navigationTitle("Einstellungen")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Fertig") { dismiss() }
                }
            }
            .sheet(isPresented: $showFolderManagement) {
                FolderManagementView()
            }
            .sheet(isPresented: $showContactsManagement) {
                QuickContactsManagementView()
            }
            .fileImporter(
                isPresented: $showFolderImportPicker,
                allowedContentTypes: [TicketsFolderShareType.contentType],
                allowsMultipleSelection: false
            ) { result in
                switch result {
                case .success(let urls):
                    guard let url = urls.first else { return }
                    switch store.importSharedFolder(from: url) {
                    case .success(let name):
                        folderImportResult = name
                        showFolderImportAlert = true
                    case .failure:
                        folderImportFailed = true
                    }
                case .failure:
                    folderImportFailed = true
                }
            }
            .alert("Ordner importiert", isPresented: $showFolderImportAlert) {
                Button("OK", role: .cancel) { folderImportResult = nil }
            } message: {
                if let name = folderImportResult {
                    Text("Tickets aus der geteilten Reise liegen in „\(name)“.")
                }
            }
            .alert("Import fehlgeschlagen", isPresented: $folderImportFailed) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("Die Datei ist kein gültiger geteilter Arca-Tickets-Ordner.")
            }
        }
    }

    @ViewBuilder
    private var aboutSection: some View {
        Section {
            LabeledContent {
                Text(appVersion)
            } label: {
                Label("Version", systemImage: "app.badge")
            }
            Label("Entwickler: Hans zen Ruffinen", systemImage: "person.fill")
            Button {
                requestReview()
            } label: {
                HStack {
                    Label("Arca Tickets bewerten", systemImage: "star.fill")
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .foregroundStyle(.primary)
        } header: {
            Text("Über Arca Tickets")
        } footer: {
            Text("Die schlanke Schwester von Arca — nur Tickets, nichts Überflüssiges. Speichern, vorzeigen, rechtzeitig erinnert.")
        }
    }
}

struct FolderManagementView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var store: TicketStore
    @State private var newFolderName = ""
    @State private var folderToRename: String?
    @State private var renameText = ""
    @State private var showAddAlert = false
    @State private var shareItem: ShareURLItem?

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(store.folders, id: \.self) { folder in
                        HStack {
                            Image(systemName: TicketFolderStyle.style(for: folder).icon)
                                .foregroundStyle(ArcaTicketsDesign.tint(for: TicketFolderStyle.style(for: folder).tintName))
                                .frame(width: 28)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(folder)
                                Text(store.ticketCount(in: folder) == 1
                                     ? "1 Ticket"
                                     : "\(store.ticketCount(in: folder)) Tickets")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Menu {
                                Button {
                                    if let url = store.exportFolder(folder) {
                                        shareItem = ShareURLItem(url: url)
                                    }
                                } label: {
                                    Label("Mit Familie teilen", systemImage: "person.2.fill")
                                }
                                .disabled(store.ticketCount(in: folder) == 0)

                                Button("Umbenennen") {
                                    folderToRename = folder
                                    renameText = folder
                                }
                                if store.folders.count > 1 {
                                    Button("Löschen", role: .destructive) {
                                        _ = store.deleteFolder(folder)
                                    }
                                }
                            } label: {
                                Image(systemName: "ellipsis.circle")
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                } header: {
                    Text("Deine Ordner")
                }

                Section {
                    Button {
                        showAddAlert = true
                    } label: {
                        Label("Neuen Ordner hinzufügen", systemImage: "folder.badge.plus")
                    }
                }
            }
            .navigationTitle("Ordner verwalten")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Fertig") { dismiss() }
                }
            }
            .alert("Neuer Ordner", isPresented: $showAddAlert) {
                TextField("Ordnername", text: $newFolderName)
                Button("Abbrechen", role: .cancel) { newFolderName = "" }
                Button("Hinzufügen") {
                    _ = store.addFolder(named: newFolderName)
                    newFolderName = ""
                }
            }
            .alert("Ordner umbenennen", isPresented: Binding(
                get: { folderToRename != nil },
                set: { if !$0 { folderToRename = nil } }
            )) {
                TextField("Neuer Name", text: $renameText)
                Button("Abbrechen", role: .cancel) { folderToRename = nil }
                Button("Speichern") {
                    if let old = folderToRename {
                        _ = store.renameFolder(from: old, to: renameText)
                    }
                    folderToRename = nil
                }
            }
            .sheet(item: $shareItem) { item in
                ShareSheet(activityItems: [item.url])
            }
        }
    }
}
