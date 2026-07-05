//
//  SettingsView.swift
//  ArcaTickets
//
//  Entwickler: Hans zen Ruffinen
//

import SwiftUI
import StoreKit

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.requestReview) private var requestReview
    @EnvironmentObject private var store: TicketStore

    @State private var showFolderManagement = false

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
                    Text("Eigene Ordner anlegen oder umbenennen — z. B. „Sommerreise 2026“.")
                }

                Section {
                    LabeledContent("Tickets gespeichert", value: "\(store.tickets.count)")
                    Text("Du wirst einen Tag vor Ablauf an gültige Tickets erinnert.")
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
        }
    }
}
