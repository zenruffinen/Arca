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
    @Environment(\.requestReview) private var requestReview
    @EnvironmentObject private var store: TicketStore

    @State private var showFolderManagement = false
    @State private var showContactsManagement = false
    @State private var showFolderImportPicker = false
    @State private var folderImportResult: String?
    @State private var showFolderImportAlert = false
    @State private var folderImportFailed = false
    @State private var tabOrder = TabOrderPreferences.reorderableTabOrder
    @State private var leadTab = TabOrderPreferences.leadTab
    @State private var showReleaseNotes = false

    // Backup export
    @State private var showExportPasswordSheet = false
    @State private var exportPassword = ""
    @State private var exportPasswordConfirm = ""
    @State private var exportPasswordError = ""
    @State private var showExportPassword = false
    @FocusState private var exportPasswordFieldFocused: Bool
    @State private var exportShareItem: ShareURLItem?

    // Backup import
    @State private var showImportPicker = false
    @State private var pendingImportURL: URL?
    @State private var showImportPasswordSheet = false
    @State private var importPassword = ""
    @State private var showImportPasswordReveal = false
    @FocusState private var importPasswordFieldFocused: Bool
    @State private var importMerge = true
    @State private var showImportSuccess = false
    @State private var showImportError = false
    @State private var importErrorMessage = ""
    @State private var showImportConfirm = false
    @State private var importPickerStartFolder: URL?

    private var ticketsBackupType: UTType {
        TicketsBackupType.contentType
    }

    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
    }

    var body: some View {
        NavigationStack {
            List {
                aboutSection

                Section {
                    HStack {
                        Label("iCloud", systemImage: "icloud.fill")
                        Spacer()
                        Text(store.iCloudStatus.rawValue)
                            .font(.subheadline)
                            .foregroundStyle(store.iCloudStatus == .downloading ? .orange : .secondary)
                    }
                } footer: {
                    Text(store.isICloudAvailable
                         ? "Tickets und Dateien werden über iCloud Drive synchronisiert. Bei „Warte auf Download“ werden Inhalte noch aus der Cloud geladen."
                         : "iCloud ist nicht verfügbar. Daten werden lokal auf diesem Gerät gespeichert.")
                }

                Section {
                    Button {
                        exportPassword = ""
                        exportPasswordConfirm = ""
                        exportPasswordError = ""
                        showExportPassword = false
                        showExportPasswordSheet = true
                    } label: {
                        Label("Daten sichern", systemImage: "square.and.arrow.up.fill")
                            .foregroundStyle(.blue)
                    }

                    Button {
                        showImportConfirm = true
                    } label: {
                        Label("Daten wiederherstellen", systemImage: "square.and.arrow.down.fill")
                            .foregroundStyle(.green)
                    }
                } header: {
                    Text("Sichern und wiederherstellen")
                } footer: {
                    Text("Das Backup wird verschlüsselt gespeichert (.arcaticketsbackup). Du kannst es in iCloud Drive, per Mail oder lokal sichern — ideal beim Gerätewechsel.")
                }

                Section {
                    TicketsDidYouKnowCard()
                        .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                } footer: {
                    Label("Arca Tickets ist kostenlos, werbefrei und sammelt keine Daten über dich.", systemImage: "lock.shield.fill")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                tabOrderSection
                organisationSection
                familySection
                remindersSection
                securitySection
            }
            .scrollContentBackground(.hidden)
            .travelScreenBackground()
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Image(systemName: "gearshape")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(.secondary)
                }
            }
            .onAppear {
                tabOrder = TabOrderPreferences.reorderableTabOrder
                leadTab = TabOrderPreferences.leadTab
                consumePendingBackupURL()
            }
            .onChange(of: store.pendingBackupURL) { _, url in
                guard url != nil else { return }
                consumePendingBackupURL()
            }
            .sheet(isPresented: $showFolderManagement) {
                FolderManagementView()
            }
            .sheet(isPresented: $showContactsManagement) {
                QuickContactsManagementView()
            }
            .sheet(isPresented: $showReleaseNotes) {
                releaseNotesSheet
            }
            .sheet(isPresented: $showExportPasswordSheet) {
                NavigationStack {
                    Form {
                        Section {
                            HStack {
                                Group {
                                    if showExportPassword {
                                        TextField("Passwort", text: $exportPassword)
                                    } else {
                                        SecureField("Passwort", text: $exportPassword)
                                    }
                                }
                                .focused($exportPasswordFieldFocused)
                                .autocorrectionDisabled()
                                .textInputAutocapitalization(.never)
                                .font(.system(.body, design: .monospaced))
                                .onChange(of: exportPassword) { _, _ in exportPasswordError = "" }
                                Button {
                                    showExportPassword.toggle()
                                } label: {
                                    Image(systemName: showExportPassword ? "eye.slash" : "eye")
                                        .foregroundStyle(ArcaTicketsDesign.travelOcean)
                                }
                                .buttonStyle(.borderless)
                            }
                            HStack {
                                Group {
                                    if showExportPassword {
                                        TextField("Passwort bestätigen", text: $exportPasswordConfirm)
                                    } else {
                                        SecureField("Passwort bestätigen", text: $exportPasswordConfirm)
                                    }
                                }
                                .autocorrectionDisabled()
                                .textInputAutocapitalization(.never)
                                .font(.system(.body, design: .monospaced))
                                .onChange(of: exportPasswordConfirm) { _, _ in exportPasswordError = "" }
                            }
                        } header: {
                            Text("Backup-Passwort festlegen")
                        } footer: {
                            VStack(alignment: .leading, spacing: 6) {
                                Text("Das Passwort muss mindestens 4 Zeichen lang sein.")
                                Text("Das Backup wird verschlüsselt. Ohne dieses Passwort kann es nicht wiederhergestellt werden.")
                            }
                        }
                        if !exportPasswordError.isEmpty {
                            Section {
                                Label(exportPasswordError, systemImage: "exclamationmark.triangle.fill")
                                    .foregroundStyle(.red)
                                    .font(.subheadline)
                            }
                        }
                    }
                    .navigationTitle("Daten sichern")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Abbrechen") {
                                exportPasswordFieldFocused = false
                                showExportPasswordSheet = false
                            }
                        }
                        ToolbarItem(placement: .confirmationAction) {
                            Button("Sichern") { performBackupExport() }
                                .disabled(exportPassword.isEmpty)
                        }
                    }
                }
            }
            .sheet(item: $exportShareItem) { item in
                if FileManager.default.fileExists(atPath: item.url.path) {
                    ShareSheet(activityItems: backupShareActivityItems(for: item))
                } else {
                    VStack(spacing: 16) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 40))
                            .foregroundStyle(.orange)
                        Text("Sicherung fehlgeschlagen")
                            .font(.headline)
                        Text("Die Backup-Datei konnte nicht erstellt werden. Bitte versuche es erneut.")
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                        Button("Schließen") { exportShareItem = nil }
                            .buttonStyle(.borderedProminent)
                            .padding(.top, 8)
                    }
                    .padding()
                }
            }
            .alert("Daten wiederherstellen", isPresented: $showImportConfirm) {
                Button("Abbrechen", role: .cancel) {}
                Button("Fortfahren") {
                    importPickerStartFolder = store.beginAccessingRememberedBackupFolder()
                    showImportPicker = true
                }
            } message: {
                Text("Bestehende Daten werden ersetzt, sofern du nicht zusammenführst. Möchtest du fortfahren?")
            }
            .sheet(isPresented: $showImportPicker, onDismiss: {
                store.releaseRememberedBackupFolderAccess()
                importPickerStartFolder = nil
            }) {
                BackupImportDocumentPicker(
                    contentType: ticketsBackupType,
                    directoryURL: importPickerStartFolder
                ) { url in
                    showImportPicker = false
                    beginBackupImport(from: url)
                } onCancel: {
                    showImportPicker = false
                }
            }
            .sheet(isPresented: $showImportPasswordSheet) {
                NavigationStack {
                    Form {
                        Section {
                            HStack {
                                Group {
                                    if showImportPasswordReveal {
                                        TextField("Passwort", text: $importPassword)
                                    } else {
                                        SecureField("Passwort", text: $importPassword)
                                    }
                                }
                                .focused($importPasswordFieldFocused)
                                .autocorrectionDisabled()
                                .textInputAutocapitalization(.never)
                                .font(.system(.body, design: .monospaced))
                                Button {
                                    showImportPasswordReveal.toggle()
                                } label: {
                                    Image(systemName: showImportPasswordReveal ? "eye.slash" : "eye")
                                        .foregroundStyle(ArcaTicketsDesign.travelOcean)
                                }
                                .buttonStyle(.borderless)
                            }
                        } header: {
                            Text("Backup-Passwort eingeben")
                        } footer: {
                            Text("Gib das Passwort ein, das beim Export vergeben wurde.")
                        }

                        Section {
                            Toggle(isOn: $importMerge) {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Zusammenführen")
                                        .font(.body)
                                    Text("Bestehende Daten bleiben erhalten — nur neue Einträge werden hinzugefügt.")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        } footer: {
                            Text(importMerge
                                 ? "Vorhandene Tickets, Ordner und Kontakte bleiben erhalten."
                                 : "Alles wird durch den Backup-Stand ersetzt.")
                                .foregroundStyle(importMerge ? .green : .orange)
                        }
                    }
                    .navigationTitle("Wiederherstellen")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Abbrechen") {
                                importPasswordFieldFocused = false
                                showImportPasswordSheet = false
                                pendingImportURL = nil
                                showImportPasswordReveal = false
                            }
                        }
                        ToolbarItem(placement: .confirmationAction) {
                            Button(importMerge ? "Zusammenführen" : "Ersetzen") {
                                performBackupImport()
                            }
                            .disabled(importPassword.isEmpty)
                        }
                    }
                }
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
            .alert("Import erfolgreich", isPresented: $showImportSuccess) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("Alle Daten wurden erfolgreich wiederhergestellt.")
            }
            .alert("Import fehlgeschlagen", isPresented: $showImportError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(importErrorMessage)
            }
            .alert("Ordner importiert", isPresented: $showFolderImportAlert) {
                Button("OK", role: .cancel) { folderImportResult = nil }
            } message: {
                if let name = folderImportResult {
                    Text("Tickets aus der geteilten Reise liegen in „\(name)“.")
                }
            }
            .alert("Das hat nicht geklappt", isPresented: $folderImportFailed) {
                Button("Nochmal versuchen", role: .cancel) {}
            } message: {
                Text("Die Datei ist kein gültiger geteilter Arca-Tickets-Ordner.")
            }
        }
    }

    // MARK: - Backup helpers

    private func backupImportErrorMessage(for url: URL, error: TicketsBackupArchive.ImportError) -> String {
        if store.isBlockedDocumentExtension(url) {
            let ext = url.pathExtension.uppercased()
            if ext == "PDF" {
                return "Das ist ein PDF-Dokument, keine Arca-Tickets-Sicherung (.arcaticketsbackup). Bitte die exportierte Datei „ArcaTicketsBackup_….arcaticketsbackup“ wählen — nicht ein Ticket-PDF."
            }
            return "Das ist eine \(ext)-Datei, keine Arca-Tickets-Sicherung (.arcaticketsbackup). Bitte die exportierte Backup-Datei wählen."
        }
        switch error {
        case .fileAccessDenied:
            return "Kein Zugriff auf die Datei. Bitte erneut auswählen."
        case .invalidBackupFile:
            return "Keine gültige Arca-Tickets-Backup-Datei (.arcaticketsbackup). Bitte die exportierte Sicherungsdatei wählen — keine PDF oder anderes Dokument."
        case .wrongPasswordOrCorrupt, .manifestInvalid:
            return "Die Datei konnte nicht gelesen werden. Falsches Passwort oder beschädigte Datei."
        }
    }

    private func consumePendingBackupURL() {
        guard let url = store.pendingBackupURL else { return }
        store.pendingBackupURL = nil
        beginBackupImport(from: url)
    }

    private func beginBackupImport(from url: URL) {
        store.rememberBackupFolder(containing: url)
        switch store.prepareBackupImport(from: url) {
        case .success(let staged):
            pendingImportURL = staged
            importPassword = ""
            showImportPasswordReveal = false
            showImportPasswordSheet = true
        case .failure(let error):
            importErrorMessage = backupImportErrorMessage(for: url, error: error)
            showImportError = true
        }
    }

    private func backupShareActivityItems(for item: ShareURLItem) -> [Any] {
        #if canImport(UIKit)
        if item.isTicketsBackup {
            return [TicketsBackupShareActivityItem(fileURL: item.url)]
        }
        #endif
        return [item.url]
    }

    private func performBackupExport() {
        exportPasswordFieldFocused = false
        #if canImport(UIKit)
        UIApplication.shared.sendAction(
            #selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
        #endif

        let password = exportPassword
        let passwordConfirm = exportPasswordConfirm

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            guard password.count >= TicketStore.minBackupPasswordLength else {
                exportPasswordError = "Das Passwort muss mindestens 4 Zeichen lang sein."
                return
            }
            guard password == passwordConfirm else {
                exportPasswordError = "Passwörter stimmen nicht überein."
                return
            }

            switch store.exportBackup(password: password) {
            case .success(let url):
                showExportPasswordSheet = false
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                    exportShareItem = ShareURLItem(url: url, isTicketsBackup: true)
                }
            case .failure(.passwordTooShort):
                exportPasswordError = "Das Passwort muss mindestens 4 Zeichen lang sein."
            case .failure(.archiveFailed):
                exportPasswordError = "Sicherung fehlgeschlagen. Bitte erneut versuchen."
            }
        }
    }

    private func performBackupImport() {
        importPasswordFieldFocused = false
        #if canImport(UIKit)
        UIApplication.shared.sendAction(
            #selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
        #endif

        let password = importPassword
        let url = pendingImportURL
        let mergeMode = importMerge

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            guard let url else { return }
            switch store.importBackup(from: url, password: password, merge: mergeMode) {
            case .success:
                showImportPasswordSheet = false
                showImportPasswordReveal = false
                pendingImportURL = nil
                try? FileManager.default.removeItem(at: url)
                showImportSuccess = true
            case .failure(.fileAccessDenied):
                importErrorMessage = "Kein Zugriff auf die Datei. Bitte erneut auswählen."
                showImportError = true
            case .failure(.manifestInvalid):
                importErrorMessage = "Backup-Datei beschädigt (manifest.json ungültig)."
                showImportError = true
            case .failure(.wrongPasswordOrCorrupt):
                importErrorMessage = "Falsches Passwort oder beschädigte Datei."
                showImportError = true
            case .failure(.invalidBackupFile):
                importErrorMessage = "Keine gültige Arca-Tickets-Backup-Datei (.arcaticketsbackup)."
                showImportError = true
            }
        }
    }

    private func moveTab(from source: IndexSet, to destination: Int) {
        tabOrder.move(fromOffsets: source, toOffset: destination)
        TabOrderPreferences.save(tabOrder)
        leadTab = TabOrderPreferences.leadTab
    }

    private func tabIconColor(for tab: ArcaTicketsTab) -> Color {
        switch tab {
        case .notfall: return .red
        case .settings: return .secondary
        default: return ArcaTicketsDesign.travelOcean
        }
    }

    // MARK: - Sections

    @ViewBuilder
    private var aboutSection: some View {
        Section {
            Button {
                showReleaseNotes = true
            } label: {
                HStack {
                    Label("Version \(appVersion)", systemImage: "app.badge")
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .foregroundStyle(.primary)

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

    @ViewBuilder
    private var tabOrderSection: some View {
        Section {
            Picker(selection: $leadTab) {
                ForEach(TabOrderPreferences.LeadTab.allCases) { option in
                    Text(option.label).tag(option)
                }
            } label: {
                Label("Startseite", systemImage: "house.fill")
            }
            .onChange(of: leadTab) { _, tab in
                TabOrderPreferences.setLeadTab(tab)
                tabOrder = TabOrderPreferences.reorderableTabOrder
            }

            if tabOrder.count > 1 {
                List {
                    ForEach(tabOrder) { tab in
                        HStack(spacing: 12) {
                            Image(systemName: tab.icon)
                                .foregroundStyle(tabIconColor(for: tab))
                                .frame(width: 24)
                            Text(tab.label)
                            Spacer()
                            Image(systemName: "line.3.horizontal")
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                        }
                    }
                    .onMove(perform: moveTab)
                }
                .listStyle(.plain)
                .frame(minHeight: CGFloat(tabOrder.count) * 46)
                .scrollDisabled(true)
                .environment(\.editMode, .constant(.active))
            }
        } header: {
            Text("Tab-Reihenfolge")
        } footer: {
            Text("Lege fest, welche Registerkarte beim Öffnen zuerst erscheint. Einstellungen bleiben immer als letzter Tab unten.")
        }
    }

    @ViewBuilder
    private var organisationSection: some View {
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
            Text("Notrufnummern, Hotel, Fluggesellschaft und Familie — auf dem Tab „Notfall“ griffbereit. Ordner z. B. „Reise Zermatt“ für die ganze Familie.")
        }
    }

    @ViewBuilder
    private var familySection: some View {
        Section {
            Button {
                showFolderImportPicker = true
            } label: {
                Label("Geteilten Ordner importieren", systemImage: "square.and.arrow.down")
            }
        } header: {
            Text("Familie")
        } footer: {
            Text("Schritt 1: Ordner teilen · Schritt 2: AirDrop oder Nachrichten · Schritt 3: Datei öffnen. Reise teilen — Familie erhält alle Tickets.")
        }
    }

    @ViewBuilder
    private var remindersSection: some View {
        Section {
            LabeledContent("Tickets gespeichert", value: "\(store.tickets.count)")
        } header: {
            Text("Erinnerungen")
        } footer: {
            Text("Abos und Saisonkarten: Erinnerung 30 Tage vor Ablauf. Alle anderen Tickets: 1 Tag vorher.")
        }
    }

    @ViewBuilder
    private var securitySection: some View {
        Section {
            Label("PIN und Face ID aktiv", systemImage: "lock.fill")
        } header: {
            Text("Sicherheit")
        } footer: {
            Text("PIN und Face ID schützen den Zugriff auf deine Tickets.")
        }
    }

    private var releaseNotesSheet: some View {
        NavigationStack {
            List {
                Section {
                    Label("Einstellungen im Arca-Stil: Über Arca Tickets, iCloud, Backup, Wusstest du?", systemImage: "gearshape.fill")
                    Label("Vollständiges verschlüsseltes Backup (.arcaticketsbackup)", systemImage: "lock.shield.fill")
                    Label("Tab-Reihenfolge: Einstellungen bleiben unten in der Tab-Leiste", systemImage: "arrow.up.arrow.down")
                    Label("Notfall-Tab mit wichtigen Nummern und Ausweisdaten", systemImage: "phone.circle.fill")
                    Label("Reiseordner teilen und importieren", systemImage: "person.2.fill")
                } header: {
                    Text("Neu in Version \(appVersion)")
                }
            }
            .navigationTitle("Release Notes")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Fertig") { showReleaseNotes = false }
                }
            }
        }
    }
}

// MARK: - Folder management

struct FolderManagementView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var store: TicketStore
    @State private var newFolderName = ""
    @State private var folderToRename: String?
    @State private var renameText = ""
    @State private var showAddAlert = false
    @State private var shareItem: ShareURLItem?
    @State private var shareGuideFolder: String?

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
                                    shareGuideFolder = folder
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
            .sheet(item: Binding(
                get: { shareGuideFolder.map { ShareGuideItem(name: $0) } },
                set: { shareGuideFolder = $0?.name }
            )) { item in
                FolderShareGuideView(folderName: item.name) {
                    shareGuideFolder = nil
                    if let url = store.exportFolder(item.name) {
                        TicketsHaptics.lightImpact()
                        shareItem = ShareURLItem(url: url)
                    }
                }
                .presentationDetents([.medium, .large])
            }
        }
    }
}

private struct ShareGuideItem: Identifiable {
    let name: String
    var id: String { name }
}
