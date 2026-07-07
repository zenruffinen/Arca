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

    @State private var settingsPath: [SettingsRoute] = []
    @State private var showContactsManagement = false
    @State private var showReleaseNotes = false
    @AppStorage("arcaHoliday.tapHintDismissed") private var tapHintDismissed = false
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
    @State private var showDeleteAllTicketsConfirm = false

    private var ticketsBackupType: UTType {
        TicketsBackupType.contentType
    }

    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
    }

    /// SwiftUI kann den `NavigationStack`-Zustand über App-Runs hinweg restaurieren.
    /// Wenn sich der Pfad-Typ über Releases ändert, kann das zu `comparisonTypeMismatch` führen.
    /// Wir umgehen das, indem wir beim Öffnen der Einstellungen den Stack neu identifizieren
    /// (damit es keine alte Restore-Navigation geben kann).

    // MARK: - Icon styling

    private func coloredLabel(_ title: String, systemImage: String, tint: Color) -> some View {
        Label {
            Text(title)
        } icon: {
            Image(systemName: systemImage)
                .symbolRenderingMode(.palette)
                .foregroundStyle(tint, tint.opacity(0.35))
        }
    }

    var body: some View {
        NavigationStack(path: $settingsPath) {
            Form {
                holidaySetupSection
                holidaySection
                securitySection
                contactsSection

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
                        coloredLabel("Date sichere", systemImage: "square.and.arrow.up.fill", tint: ArcaTicketsDesign.travelOcean)
                    }

                    Button {
                        showImportConfirm = true
                    } label: {
                        coloredLabel("Date wiederherstelle", systemImage: "square.and.arrow.down.fill", tint: ArcaTicketsDesign.golfFairway)
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

                // "Arca Holiday" / About + Promo ganz nach unten
                aboutSection
                arcaTresorPromoSection
            }
            .scrollContentBackground(.hidden)
            .travelScreenBackground()
            .navigationTitle("Istellige")
            .navigationBarTitleDisplayMode(.inline)
            .alert(ArcaTicketsStrings.deleteAllTicketsTitle, isPresented: $showDeleteAllTicketsConfirm) {
                Button(ArcaTicketsStrings.cancel, role: .cancel) {}
                Button(ArcaTicketsStrings.delete, role: .destructive) {
                    TicketsHaptics.delete()
                    store.deleteAllTickets()
                    store.showToast("Alli Tickets glöscht 🗑️")
                }
            } message: {
                Text("Alli Boarding Passes, Bahncharte und anderi Ticket werded endgültig glöscht. Pass, Notize und Kontakt bliibed.")
            }
            .onAppear {
                // Defensive: möglichen Restore-Pfad beim Öffnen neutralisieren.
                // Wichtig nach Updates/Beta-Runs, wenn alte Restore-Daten existieren.
                if !settingsPath.isEmpty {
                    settingsPath.removeAll()
                }
                consumePendingBackupURL()
                consumePendingSettingsRoute()
            }
            .onChange(of: store.pendingBackupURL) { _, url in
                guard url != nil else { return }
                consumePendingBackupURL()
            }
            .onChange(of: store.pendingSettingsRoute) { _, route in
                guard route != nil else { return }
                consumePendingSettingsRoute()
            }
            .navigationDestination(for: SettingsRoute.self) { route in
                switch route {
                case .reiseSetup:
                    HolidayReiseSetupSettingsView()
                case .taxi:
                    TaxiSetupSettingsView()
                case .boarding:
                    BoardingInfoSettingsView()
                case .tickets:
                    TicketsManagementSettingsView()
                case .wichtigeNummern:
                    QuickContactsManagementPushView()
                case .notizen:
                    TravelNotesSettingsView()
                case .pass:
                    PersonalIDCardSettingsView()
                case .kofferPIN:
                    KofferPINSettingsPushView()
                case .golf:
                    GolfschlaegerSettingsPushView()
                }
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
        }
        .id(store.settingsNavigationSeed)
    }

    private func consumePendingSettingsRoute() {
        guard let route = store.pendingSettingsRoute else { return }
        store.pendingSettingsRoute = nil
        if settingsPath.last != route {
            settingsPath.append(route)
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

    // MARK: - Sections

    @ViewBuilder
    private var holidaySetupSection: some View {
        Section {
            // Reihenfolge nach Wichtigkeit / Dringlichkeit
            NavigationLink(value: SettingsRoute.boarding) {
                coloredLabel("Boarding / Flug-Infos", systemImage: "airplane", tint: ArcaTicketsDesign.travelGlassCyan)
            }
            NavigationLink(value: SettingsRoute.tickets) {
                HStack {
                    coloredLabel("Tickets verwalte", systemImage: "ticket.fill", tint: ArcaTicketsDesign.travelGlassCyan)
                    Spacer()
                    Text("\(store.tickets.count)")
                        .foregroundStyle(.secondary)
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
            }
            NavigationLink(value: SettingsRoute.pass) {
                coloredLabel("Pass / Visitenkarte", systemImage: "person.text.rectangle.fill", tint: Color(red: 0.95, green: 0.25, blue: 0.30))
            }
            NavigationLink(value: SettingsRoute.wichtigeNummern) {
                coloredLabel("Wichtige Nummern / Familie", systemImage: "phone.fill", tint: ArcaTicketsDesign.travelOcean)
            }
            NavigationLink(value: SettingsRoute.taxi) {
                coloredLabel("Taxi (Urlaub & Daheim)", systemImage: "car.side.fill", tint: ArcaTicketsDesign.taxiYellowDeep)
            }
            NavigationLink(value: SettingsRoute.kofferPIN) {
                coloredLabel("Koffer-PIN", systemImage: "lock.fill", tint: ArcaTicketsDesign.travelOcean)
            }
            NavigationLink(value: SettingsRoute.notizen) {
                coloredLabel("Notizen", systemImage: "note.text", tint: ArcaTicketsDesign.travelGlassPurple)
            }
            NavigationLink(value: SettingsRoute.golf) {
                coloredLabel("Golf", systemImage: "figure.golf", tint: ArcaTicketsDesign.golfFairwayDeep)
            }
        } header: {
            Text("Holiday Setup")
        } footer: {
            Text("Boarding/Gate, Pass, Nummern, Taxi, Koffer, Notizen — alles wo du aktiv bearbeitisch.")
        }
    }

    @ViewBuilder
    private var holidaySection: some View {
        Section {
            Toggle(isOn: Binding(
                get: { !tapHintDismissed },
                set: { tapHintDismissed = !$0 }
            )) {
                coloredLabel("Kleck-Hinwiis", systemImage: "hand.tap.fill", tint: ArcaTicketsDesign.travelSunset)
            }
        } header: {
            Text("Ferie-Grafik")
        } footer: {
            Text("Beim erste Mal churz „Tipp uf d'Klecks“ — danach us oder wieder a über de Schalter.")
        }
    }

    @ViewBuilder
    private var ticketsSection: some View {
        Section {
            NavigationLink(value: SettingsRoute.tickets) {
                HStack {
                    coloredLabel("Tickets verwalte", systemImage: "ticket.fill", tint: ArcaTicketsDesign.travelGlassCyan)
                    Spacer()
                    Text("\(store.tickets.count)")
                        .foregroundStyle(.secondary)
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
            }
        } header: {
            Text("Tickets")
        } footer: {
            Text("Tickets hinzufügen, importieren, bearbeiten und löschen machsch im Ticket-Manager.")
        }
    }

    @ViewBuilder
    private var contactsSection: some View {
        Section {
            Button {
                showContactsManagement = true
            } label: {
                HStack {
                    coloredLabel("Wichtigi Nummerä", systemImage: "phone.fill", tint: ArcaTicketsDesign.travelOcean)
                    Spacer()
                    Text("\(store.quickContacts.count)")
                        .foregroundStyle(.secondary)
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
            }
            .foregroundStyle(.primary)
        } header: {
            Text("Notfall & Kontakt")
        } footer: {
            Text("Hotel, Familie, Notfall — erreichbar über de Kleck „Notizen“. \(LegalCopy.contactsCallFooter)")
        }
    }

    @ViewBuilder
    private var aboutSection: some View {
        Section {
            Button {
                showReleaseNotes = true
            } label: {
                HStack {
                    coloredLabel("Version \(appVersion)", systemImage: "app.badge", tint: ArcaTicketsDesign.travelGlassPurple)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .foregroundStyle(.primary)

            coloredLabel("Entwickler: Hans zen Ruffinen", systemImage: "person.fill", tint: ArcaTicketsDesign.travelSunset)

            Button {
                requestReview()
            } label: {
                HStack {
                    coloredLabel("Arca Holiday bewerten", systemImage: "star.fill", tint: ArcaTicketsDesign.travelSunYellow)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .foregroundStyle(.primary)
        } header: {
            Text("Über Arca Holiday")
        } footer: {
            Text("Eini Ferie-Grafik, sächs Klecks — genau für dini Reis gmacht.")
        }
    }

    @ViewBuilder
    private var legalSection: some View {
        Section {
            Button {
                showPrivacyDetail = true
            } label: {
                HStack {
                    coloredLabel("Dateschutz & Hinweis", systemImage: "hand.raised.fill", tint: ArcaTicketsDesign.travelSunset)
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
    private var arcaTresorPromoSection: some View {
        Section {
            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 12) {
                    Image(systemName: "lock.shield.fill")
                        .font(.system(size: 26, weight: .semibold))
                        .foregroundStyle(ArcaTicketsDesign.travelOcean)
                        .frame(width: 48, height: 48)
                        .background(
                            ArcaTicketsDesign.travelOcean.opacity(0.12),
                            in: RoundedRectangle(cornerRadius: 12, style: .continuous)
                        )

                    VStack(alignment: .leading, spacing: 3) {
                        Text("Bruchsch no meh?")
                            .font(.system(size: 17, weight: .bold, design: .rounded))
                        Text("Arca Tresor")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(ArcaTicketsDesign.travelOcean)
                    }
                }

                Text("Arca Holiday isch genau für dini Reis gmacht — Pass, Ticket, Notize, alles griffbereit. Wenn du de volle Tresor wotsch: Arca Tresor het Dokument, Passwort, Notize und no viel meh. Absolut geil für alles a einem Ort.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                Button {
                    ArcaTresorPromo.openInAppStore()
                } label: {
                    Label("Arca Tresor im App Store", systemImage: "arrow.up.right.square")
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(ArcaTicketsDesign.travelOcean)
            }
            .padding(.vertical, 4)
            .listRowInsets(EdgeInsets(top: 12, leading: 16, bottom: 12, trailing: 16))
        } header: {
            Text("Dini Reise & meh vo Arca")
        } footer: {
            Text("Arca Holiday begleitet di uf dr Reis — Arca Tresor isch dr grosse Bruder für de volle Tresor.")
        }
    }

    @ViewBuilder
    private var securitySection: some View {
        Section {
            coloredLabel("PIN und Face ID aktiv", systemImage: "lock.fill", tint: ArcaTicketsDesign.golfFairway)
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
                    coloredLabel("Ferie-Grafik mit sächs Klecks", systemImage: "photo.artframe", tint: ArcaTicketsDesign.travelSunset)
                    coloredLabel("Pass, Notize, Koffer, Taxi, Golf, Boarding Card", systemImage: "hand.tap.fill", tint: ArcaTicketsDesign.travelGlassCyan)
                    coloredLabel("PIN und Face ID — App-Sperre", systemImage: "lock.fill", tint: ArcaTicketsDesign.golfFairway)
                    coloredLabel("iCloud und verschlüsselts Backup", systemImage: "icloud.fill", tint: ArcaTicketsDesign.travelOcean)
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

// MARK: - Settings destinations (Holiday Setup)

private struct HolidayReiseSetupSettingsView: View {
    var body: some View {
        List {
            Section {
                NavigationLink(value: SettingsRoute.boarding) {
                    Label {
                        Text("Boarding / Flug-Infos")
                    } icon: {
                        Image(systemName: "airplane")
                            .symbolRenderingMode(.palette)
                            .foregroundStyle(ArcaTicketsDesign.travelGlassCyan, ArcaTicketsDesign.travelGlassCyan.opacity(0.35))
                    }
                }
                NavigationLink(value: SettingsRoute.tickets) {
                    Label {
                        Text("Tickets verwalte")
                    } icon: {
                        Image(systemName: "ticket.fill")
                            .symbolRenderingMode(.palette)
                            .foregroundStyle(ArcaTicketsDesign.travelGlassCyan, ArcaTicketsDesign.travelGlassCyan.opacity(0.35))
                    }
                }
                NavigationLink(value: SettingsRoute.pass) {
                    Label {
                        Text("Pass / Visitenkarte")
                    } icon: {
                        Image(systemName: "person.text.rectangle.fill")
                            .symbolRenderingMode(.palette)
                            .foregroundStyle(Color(red: 0.95, green: 0.25, blue: 0.30), Color(red: 0.95, green: 0.25, blue: 0.30).opacity(0.35))
                    }
                }
                NavigationLink(value: SettingsRoute.wichtigeNummern) {
                    Label {
                        Text("Wichtige Nummern / Familie")
                    } icon: {
                        Image(systemName: "phone.fill")
                            .symbolRenderingMode(.palette)
                            .foregroundStyle(ArcaTicketsDesign.travelOcean, ArcaTicketsDesign.travelOcean.opacity(0.35))
                    }
                }
                NavigationLink(value: SettingsRoute.taxi) {
                    Label {
                        Text("Taxi (Urlaub & Daheim)")
                    } icon: {
                        Image(systemName: "car.side.fill")
                            .symbolRenderingMode(.palette)
                            .foregroundStyle(ArcaTicketsDesign.taxiYellowDeep, ArcaTicketsDesign.taxiYellowDeep.opacity(0.35))
                    }
                }
                NavigationLink(value: SettingsRoute.kofferPIN) {
                    Label {
                        Text("Koffer-PIN")
                    } icon: {
                        Image(systemName: "lock.fill")
                            .symbolRenderingMode(.palette)
                            .foregroundStyle(ArcaTicketsDesign.travelOcean, ArcaTicketsDesign.travelOcean.opacity(0.35))
                    }
                }
                NavigationLink(value: SettingsRoute.golf) {
                    Label {
                        Text("Golf (Bag-Tag & Club)")
                    } icon: {
                        Image(systemName: "figure.golf")
                            .symbolRenderingMode(.palette)
                            .foregroundStyle(ArcaTicketsDesign.golfFairwayDeep, ArcaTicketsDesign.golfFairwayDeep.opacity(0.35))
                    }
                }
                NavigationLink(value: SettingsRoute.notizen) {
                    Label {
                        Text("Notizen")
                    } icon: {
                        Image(systemName: "note.text")
                            .symbolRenderingMode(.palette)
                            .foregroundStyle(ArcaTicketsDesign.travelGlassPurple, ArcaTicketsDesign.travelGlassPurple.opacity(0.35))
                    }
                }
            } footer: {
                Text("Die Klecks in der Ferien-Grafik sind bewusst nur noch „Anzeigen & Aktionen“. Bearbeitung passiert hier.")
            }
        }
        .navigationTitle("Holiday Setup")
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct TaxiSetupSettingsView: View {
    @EnvironmentObject private var store: TicketStore
    @State private var vacationCompany = ""
    @State private var vacationPhone = ""
    @State private var homeCompany = ""
    @State private var homePhone = ""

    var body: some View {
        Form {
            Section {
                TextField("Nummer am Ferienort", text: $vacationPhone)
                    .keyboardType(.phonePad)
                    .textContentType(.telephoneNumber)
                TextField("Name vom Taxi (optional)", text: $vacationCompany)
                    .textContentType(.organizationName)
            } header: {
                Text("Taxi im Urlaub")
            } footer: {
                Text("Wird im Taxi-Kleck als „Anrufen“-Button angezeigt.")
            }

            Section {
                TextField("Nummer daheim", text: $homePhone)
                    .keyboardType(.phonePad)
                    .textContentType(.telephoneNumber)
                TextField("z.B. Züri-Taxi (optional)", text: $homeCompany)
                    .textContentType(.organizationName)
            } header: {
                Text("Taxi daheim")
            } footer: {
                Text("Praktisch, wenn du wieder zuhause bist.")
            }
        }
        .navigationTitle("Taxi")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button(ArcaTicketsStrings.save) { save() }
            }
        }
        .onAppear { load() }
    }

    private func load() {
        vacationCompany = store.taxiContact.companyName
        vacationPhone = store.taxiContact.phoneNumber
        homeCompany = store.homeTaxiContact.companyName
        homePhone = store.homeTaxiContact.phoneNumber
    }

    private func save() {
        store.updateTaxiContact(TaxiContact(
            companyName: vacationCompany.trimmingCharacters(in: .whitespacesAndNewlines),
            phoneNumber: vacationPhone.trimmingCharacters(in: .whitespacesAndNewlines)
        ))
        store.updateHomeTaxiContact(TaxiContact(
            companyName: homeCompany.trimmingCharacters(in: .whitespacesAndNewlines),
            phoneNumber: homePhone.trimmingCharacters(in: .whitespacesAndNewlines)
        ))
        TicketsHaptics.lightImpact()
        store.showToast("Taxi-Nummern gespeichert")
    }
}

private struct BoardingInfoSettingsView: View {
    @EnvironmentObject private var store: TicketStore
    @State private var showAddTicket = false

    private var activeTickets: [TicketEntry] {
        store.tickets
            .filter(\.isValid)
            .sorted { lhs, rhs in
                if lhs.isPinned != rhs.isPinned { return lhs.isPinned }
                return lhs.unterwegsSortDate < rhs.unterwegsSortDate
            }
    }

    var body: some View {
        List {
            Section {
                Button {
                    showAddTicket = true
                } label: {
                    Label(ArcaTicketsStrings.addBoardingPass, systemImage: "plus.circle.fill")
                }
            }

            Section {
                if activeTickets.isEmpty {
                    ContentUnavailableView("Noch keine Tickets", systemImage: "ticket")
                } else {
                    ForEach(activeTickets) { ticket in
                        NavigationLink {
                            TicketDetailView(ticket: ticket)
                        } label: {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(ticket.title)
                                    .font(.body.weight(.semibold))
                                Text(ticket.flightTodayLine)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            } header: {
                Text("Tickets")
            } footer: {
                Text("Gate, Boarding-Zeit usw. bearbeitisch im Ticket-Detail (Bearbeiten).")
            }
        }
        .navigationTitle("Boarding / Flug")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showAddTicket) {
            AddTicketView(forHolidayBoarding: true)
        }
    }
}

private struct TravelNotesSettingsView: View {
    @EnvironmentObject private var store: TicketStore
    @FocusState private var isFocused: Bool
    @State private var draftText = ""

    var body: some View {
        Form {
            Section {
                TextEditor(text: $draftText)
                    .font(.system(.body, design: .rounded))
                    .frame(minHeight: 180)
                    .focused($isFocused)
            } header: {
                Text("Notizen")
            } footer: {
                Text("Wird im Notizen-Kleck angezeigt (dort nur lesen).")
            }
        }
        .navigationTitle("Notizen")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { draftText = store.travelNotes.text }
        .onDisappear { save() }
    }

    private func save() {
        let trimmed = draftText.trimmingCharacters(in: .whitespacesAndNewlines)
        let notes = TravelNotes(
            text: draftText,
            updatedAt: trimmed.isEmpty && store.travelNotes.isEmpty ? store.travelNotes.updatedAt : Date()
        )
        if notes != store.travelNotes {
            store.updateTravelNotes(notes)
        }
    }
}

private struct TicketsManagementSettingsView: View {
    @EnvironmentObject private var store: TicketStore
    @State private var showAddTicket = false
    @State private var ticketToDelete: TicketEntry?
    @State private var showDeleteConfirm = false
    @State private var showDeleteAllConfirm = false

    private var sortedTickets: [TicketEntry] {
        store.tickets.sorted { $0.unterwegsSortDate < $1.unterwegsSortDate }
    }

    var body: some View {
        List {
            Section {
                Button {
                    showAddTicket = true
                } label: {
                    Label("Ticket hinzufügen / importieren", systemImage: "plus.circle.fill")
                }
            }

            Section {
                if sortedTickets.isEmpty {
                    ContentUnavailableView("Keine Tickets", systemImage: "ticket")
                } else {
                    ForEach(sortedTickets) { ticket in
                        NavigationLink {
                            TicketDetailView(ticket: ticket)
                        } label: {
                            TicketRow(ticket: ticket, showPinIndicator: true)
                        }
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            Button(role: .destructive) {
                                deleteTicket(ticket)
                            } label: {
                                Label(ArcaTicketsStrings.delete, systemImage: "trash")
                            }
                        }
                    }
                }
            } header: {
                Text("Alle Tickets")
            }

            if !store.tickets.isEmpty {
                Section {
                    Button(role: .destructive) {
                        showDeleteAllConfirm = true
                    } label: {
                        Label(ArcaTicketsStrings.deleteAllTickets, systemImage: "trash")
                    }
                }
            }
        }
        .navigationTitle("Tickets")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showAddTicket) {
            AddTicketView(forHolidayBoarding: true)
        }
        .alert("Ticket löschen?", isPresented: $showDeleteConfirm) {
            Button(ArcaTicketsStrings.cancel, role: .cancel) { ticketToDelete = nil }
            Button(ArcaTicketsStrings.delete, role: .destructive) {
                if let ticket = ticketToDelete {
                    TicketsHaptics.delete()
                    store.deleteTicket(ticket)
                }
                ticketToDelete = nil
            }
        } message: {
            if let ticket = ticketToDelete {
                Text("\u{201E}\(ticket.title)\u{201C} würklich lösche? Das gaht nöd rückgängig.")
            }
        }
        .alert(ArcaTicketsStrings.deleteAllTicketsTitle, isPresented: $showDeleteAllConfirm) {
            Button(ArcaTicketsStrings.cancel, role: .cancel) {}
            Button(ArcaTicketsStrings.delete, role: .destructive) {
                TicketsHaptics.delete()
                store.deleteAllTickets()
            }
        } message: {
            Text("Alli Tickets werded endgültig glöscht.")
        }
    }

    private func deleteTicket(_ ticket: TicketEntry) {
        if ticket.needsDeleteConfirmation {
            ticketToDelete = ticket
            showDeleteConfirm = true
        } else {
            TicketsHaptics.delete()
            store.deleteTicket(ticket)
        }
    }
}

// MARK: - Arca Tresor cross-promo

enum ArcaTresorPromo {
    static let bundleID = "com.hansruffin.Arca"
    private static let appStoreSearchURL = URL(string: "https://apps.apple.com/search?term=Arca%20Tresor")!

    static func openInAppStore() {
        #if canImport(UIKit)
        UIApplication.shared.open(appStoreSearchURL)
        #endif
    }
}
