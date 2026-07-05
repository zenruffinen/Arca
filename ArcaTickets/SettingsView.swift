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
    @State private var dialectMode = SwissDialectPreferences.rotationMode
    @State private var dialectFavoriteID = SwissDialectPreferences.favoritePhraseID
    @State private var unterwegsViewMode = UnterwegsViewPreferences.viewMode
    @State private var ferienEinstiegEnabled = UnterwegsViewPreferences.einstiegEnabled
    @State private var showPrivacyDetail = false

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
                         ? LegalCopy.iCloudAvailableFooter
                         : LegalCopy.iCloudUnavailableFooter)
                }

                Section {
                    Button {
                        exportPassword = ""
                        exportPasswordConfirm = ""
                        exportPasswordError = ""
                        showExportPassword = false
                        showExportPasswordSheet = true
                    } label: {
                        Label("Date sichere", systemImage: "square.and.arrow.up.fill")
                            .foregroundStyle(.blue)
                    }

                    Button {
                        showImportConfirm = true
                    } label: {
                        Label("Date wiederherstelle", systemImage: "square.and.arrow.down.fill")
                            .foregroundStyle(.green)
                    }
                } header: {
                    Text("Sichere und wiederherstelle")
                } footer: {
                    Text(LegalCopy.backupFooter)
                }

                Section {
                    TicketsDidYouKnowCard()
                        .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                } footer: {
                    Text(LegalCopy.privacySummary)
                }

                legalSection

                tabOrderSection
                unterwegsDialectSection
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
                unterwegsViewMode = UnterwegsViewPreferences.viewMode
                ferienEinstiegEnabled = UnterwegsViewPreferences.einstiegEnabled
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
            .sheet(isPresented: $showPrivacyDetail) {
                LegalPrivacyDetailView()
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
                            Text("Backup-Passwort feschtle")
                        } footer: {
                            VStack(alignment: .leading, spacing: 6) {
                                Text("S'Passwort muess mindestens 4 Zeiche lang si.")
                                Text(LegalCopy.backupPasswordHint)
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
                    .navigationTitle("Date sichere")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button(ArcaTicketsStrings.cancel) {
                                exportPasswordFieldFocused = false
                                showExportPasswordSheet = false
                            }
                        }
                        ToolbarItem(placement: .confirmationAction) {
                            Button(ArcaTicketsStrings.backup) { performBackupExport() }
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
                        Text(ArcaTicketsStrings.backupFailed)
                            .font(.headline)
                        Text("D'Backup-Datei het nöd chönne erstellt werde. Bitte nomal probiere.")
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                        Button(ArcaTicketsStrings.close) { exportShareItem = nil }
                            .buttonStyle(.borderedProminent)
                            .padding(.top, 8)
                    }
                    .padding()
                }
            }
            .alert("Date wiederherstelle", isPresented: $showImportConfirm) {
                Button(ArcaTicketsStrings.cancel, role: .cancel) {}
                Button(ArcaTicketsStrings.proceed) {
                    importPickerStartFolder = store.beginAccessingRememberedBackupFolder()
                    showImportPicker = true
                }
            } message: {
                Text("Bestehendi Date werded ersetzt, wenn du nöd zämmefüege. Wotsch witerfahre?")
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
                            Text("Backup-Passwort ii gä")
                        } footer: {
                            Text("Gib s'Passwort ii, wo bim Export vergä worde isch.")
                        }

                        Section {
                            Toggle(isOn: $importMerge) {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(ArcaTicketsStrings.merge)
                                        .font(.body)
                                    Text("Bestehendi Date bliibed — nur neui Iiträg werded dezue gfüegt.")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        } footer: {
                            Text(importMerge
                                 ? "Vorhandeni Ticket, Ordner und Kontakt bliibed."
                                 : "Alles wird dur de Backup-Stand ersetzt.")
                                .foregroundStyle(importMerge ? .green : .orange)
                        }
                    }
                    .navigationTitle("Wiederherstelle")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button(ArcaTicketsStrings.cancel) {
                                importPasswordFieldFocused = false
                                showImportPasswordSheet = false
                                pendingImportURL = nil
                                showImportPasswordReveal = false
                            }
                        }
                        ToolbarItem(placement: .confirmationAction) {
                            Button(importMerge ? ArcaTicketsStrings.merge : ArcaTicketsStrings.replace) {
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
            .alert(ArcaTicketsStrings.importSuccess, isPresented: $showImportSuccess) {
                Button(ArcaTicketsStrings.ok, role: .cancel) {}
            } message: {
                Text("Alli Date sind erfolgriich wiederherstellt worde.")
            }
            .alert(ArcaTicketsStrings.importFailed, isPresented: $showImportError) {
                Button(ArcaTicketsStrings.ok, role: .cancel) {}
            } message: {
                Text(importErrorMessage)
            }
            .alert("Ordner importiert", isPresented: $showFolderImportAlert) {
                Button(ArcaTicketsStrings.ok, role: .cancel) { folderImportResult = nil }
            } message: {
                if let name = folderImportResult {
                    Text("Ticket us dr geteilti Reise liged in „\(name)“.")
                }
            }
            .alert(ArcaTicketsStrings.didNotWork, isPresented: $folderImportFailed) {
                Button(ArcaTicketsStrings.retry, role: .cancel) {}
            } message: {
                Text("D'Datei isch kein gültige geteilti Arca-Tickets-Ordner.")
            }
        }
    }

    // MARK: - Backup helpers

    private func backupImportErrorMessage(for url: URL, error: TicketsBackupArchive.ImportError) -> String {
        if store.isBlockedDocumentExtension(url) {
            let ext = url.pathExtension.uppercased()
            if ext == "PDF" {
                return "Das isch es PDF-Dokument, kei Arca-Tickets-Sicherig (.arcaticketsbackup). Bitte d'exportierti Datei „ArcaTicketsBackup_….arcaticketsbackup“ wähle — kei Ticket-PDF."
            }
            return "Das isch e \(ext)-Datei, kei Arca-Tickets-Sicherig (.arcaticketsbackup). Bitte d'exportierti Backup-Datei wähle."
        }
        switch error {
        case .fileAccessDenied:
            return "Kei Zuegriff uf d'Datei. Bitte nomal uswähle."
        case .invalidBackupFile:
            return "Kei gültigi Arca-Tickets-Backup-Datei (.arcaticketsbackup). Bitte d'exportierti Sicherigsdatei wähle — kei PDF oder anders Dokument."
        case .wrongPasswordOrCorrupt, .manifestInvalid:
            return "D'Datei het nöd gläse werde chönne. Falsches Passwort oder beschädigti Datei."
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
                exportPasswordError = "S'Passwort muess mindestens 4 Zeiche lang si."
                return
            }
            guard password == passwordConfirm else {
                exportPasswordError = "Passwörter stimmed nöd überein."
                return
            }

            switch store.exportBackup(password: password) {
            case .success(let url):
                showExportPasswordSheet = false
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                    exportShareItem = ShareURLItem(url: url, isTicketsBackup: true)
                }
            case .failure(.passwordTooShort):
                exportPasswordError = "S'Passwort muess mindestens 4 Zeiche lang si."
            case .failure(.archiveFailed):
                exportPasswordError = "Sicherig fehlgschlage. Bitte nomal probiere."
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
                importErrorMessage = "Kei Zuegriff uf d'Datei. Bitte nomal uswähle."
                showImportError = true
            case .failure(.manifestInvalid):
                importErrorMessage = "Backup-Datei beschädigt (manifest.json ungültig)."
                showImportError = true
            case .failure(.wrongPasswordOrCorrupt):
                importErrorMessage = "Falsches Passwort oder beschädigte Datei."
                showImportError = true
            case .failure(.invalidBackupFile):
                importErrorMessage = "Kei gültigi Arca-Tickets-Backup-Datei (.arcaticketsbackup)."
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
            Text("D'schlanki Schwester vo Arca — nur Ticket, nüt Überflüssigs. Speichere, zeig, rächtziitig erinnert.")
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
            Text("Tab-Riihfolge")
        } footer: {
            Text("Leg fest, weli Registercharte bim Öffne zeerscht erschint. Istellige bliibed immer als letschte Tab unte.")
        }
    }

    @ViewBuilder
    private var unterwegsDialectSection: some View {
        Section {
            Toggle(isOn: $ferienEinstiegEnabled) {
                Label("Zeerscht", systemImage: "photo.artframe")
            }
            .onChange(of: ferienEinstiegEnabled) { _, enabled in
                UnterwegsViewPreferences.einstiegEnabled = enabled
            }

            Picker(selection: $unterwegsViewMode) {
                ForEach(UnterwegsViewMode.allCases) { mode in
                    Label(mode.label, systemImage: mode.settingsIcon).tag(mode)
                }
            } label: {
                Label("Aasicht nach Zeerscht", systemImage: "map.fill")
            }
            .onChange(of: unterwegsViewMode) { _, mode in
                UnterwegsViewPreferences.viewMode = mode
            }

            Picker(selection: $dialectMode) {
                ForEach(SwissDialectRotationMode.allCases) { mode in
                    Text(mode.label).tag(mode)
                }
            } label: {
                Label("Spruch auf Unterwägs", systemImage: "textformat")
            }
            .onChange(of: dialectMode) { _, mode in
                SwissDialectPreferences.rotationMode = mode
            }

            if dialectMode == .locked {
                Picker(selection: $dialectFavoriteID) {
                    ForEach(SwissDialectPhrases.all) { phrase in
                        Text(phrase.text).tag(phrase.id)
                    }
                } label: {
                    Label("Lieblings-Spruch", systemImage: "heart.fill")
                }
                .onChange(of: dialectFavoriteID) { _, id in
                    SwissDialectPreferences.favoritePhraseID = id
                }
            }
        } header: {
            Text("Unterwägs")
        } footer: {
            Text("Beim Öffne vom Tab: Vollbild-Ferie-Grafik im Querformat mit versteckte Tippzone. Beim erste Mal churze Hinweis und dezents Pulsiere — danach optional dauerhaft Glas-Chreise über „Tipp-Hinwiis“. Jederzeit wieder über „Zeerscht“ obe rächts uf Unterwägs.")
        }
    }

    @ViewBuilder
    private var organisationSection: some View {
        Section {
            Button {
                showContactsManagement = true
            } label: {
                HStack {
                    Label("Wichtigi Nummerä", systemImage: "phone.fill")
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
                    Label("Ordner verwalte", systemImage: "folder.badge.gearshape")
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
            Text("Notrufnummerä, Hotel, Fluggsellschaft und Familie — uf em Tab „Notfall“ griffbereit. \(LegalCopy.contactsCallFooter)")
        }
    }

    @ViewBuilder
    private var familySection: some View {
        Section {
            Button {
                showFolderImportPicker = true
            } label: {
                Label("Geteilti Ordner importiere", systemImage: "square.and.arrow.down")
            }
        } header: {
            Text("Familie")
        } footer: {
            Text("Schritt 1: Ordner teile · Schritt 2: AirDrop oder Nachrichte · Schritt 3: Datei öffne. \(LegalCopy.familyShareWarning) \(LegalCopy.familyImportFooter)")
        }
    }

    @ViewBuilder
    private var legalSection: some View {
        Section {
            Button {
                showPrivacyDetail = true
            } label: {
                HStack {
                    Label("Dateschutz & Hinweis", systemImage: "hand.raised.fill")
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .foregroundStyle(.primary)
        } footer: {
            Text(LegalCopy.emergencyDisclaimer)
        }
    }

    @ViewBuilder
    private var remindersSection: some View {
        Section {
            LabeledContent("Ticket gspeicheret", value: "\(store.tickets.count)")
        } header: {
            Text("Erinnerungen")
        } footer: {
            Text("Abo und Saisoncharte: Erinnerig 30 Tag vor Ablauf. Alli andere Ticket: 1 Tag vorher.")
        }
    }

    @ViewBuilder
    private var securitySection: some View {
        Section {
            Label("PIN und Face ID aktiv", systemImage: "lock.fill")
        } header: {
            Text("Sicherheit")
        } footer: {
            Text(LegalCopy.appLockFooter)
        }
    }

    private var releaseNotesSheet: some View {
        NavigationStack {
            List {
                Section {
                    Label("Istellige im Arca-Stil: Über Arca Tickets, iCloud, Backup, Wüssisch?", systemImage: "gearshape.fill")
                    Label("Vollständigs verschlüsseltes Backup (.arcaticketsbackup)", systemImage: "lock.shield.fill")
                    Label("Tab-Riihfolge: Istellige bliibed unte in dr Tab-Leiste", systemImage: "arrow.up.arrow.down")
                    Label("Notfall-Tab mit wichtige Nummerä und Usweisdate", systemImage: "phone.circle.fill")
                    Label("Reiseordner teile und importiere", systemImage: "person.2.fill")
                } header: {
                    Text("Neu in Version \(appVersion)")
                }
            }
            .navigationTitle("Release Notes")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(ArcaTicketsStrings.done) { showReleaseNotes = false }
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
                                    Label("Mit Familie teile", systemImage: "person.2.fill")
                                }
                                .disabled(store.ticketCount(in: folder) == 0)

                                Button("Umbenenne") {
                                    folderToRename = folder
                                    renameText = folder
                                }
                                if store.folders.count > 1 {
                                    Button(ArcaTicketsStrings.delete, role: .destructive) {
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
                    Text("Dini Ordner")
                }

                Section {
                    Button {
                        showAddAlert = true
                    } label: {
                        Label("Neue Ordner hinzuefüege", systemImage: "folder.badge.plus")
                    }
                }
            }
            .navigationTitle("Ordner verwalte")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(ArcaTicketsStrings.done) { dismiss() }
                }
            }
            .alert("Neuer Ordner", isPresented: $showAddAlert) {
                TextField("Ordnername", text: $newFolderName)
                Button(ArcaTicketsStrings.cancel, role: .cancel) { newFolderName = "" }
                Button(ArcaTicketsStrings.addFull) {
                    _ = store.addFolder(named: newFolderName)
                    newFolderName = ""
                }
            }
            .alert("Ordner umbenenne", isPresented: Binding(
                get: { folderToRename != nil },
                set: { if !$0 { folderToRename = nil } }
            )) {
                TextField("Neue Name", text: $renameText)
                Button(ArcaTicketsStrings.cancel, role: .cancel) { folderToRename = nil }
                Button(ArcaTicketsStrings.save) {
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
