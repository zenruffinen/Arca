//
//  Einstellungen.swift
//  Arca
//
//  Einstellungen: Profil, Sync, Sichern, Wusstest du?
//  (Aus ContentView.swift herausgelöst — Code unverändert.)
//
//  Entwickler: Hans zen Ruffinen
//

import SwiftUI
import UniformTypeIdentifiers
import StoreKit
import LinkPresentation
import MessageUI

// MARK: - Settings

/// MARK: - Share URL Item (Identifiable wrapper — eliminates Bool+URL race condition)

struct ShareURLItem: Identifiable {
    let id = UUID()
    let url: URL
    /// true = Arca-Backup-Export mit erzwungener .arcabackup-Endung im Share-Sheet
    var isArcaBackup: Bool = false
}

#if canImport(UIKit)
import LinkPresentation

/// Share-Item für Backup-Export: erzwingt UTType + Dateiname mit .arcabackup (Speichern in Dateien-App).
final class BackupShareActivityItem: NSObject, UIActivityItemSource {
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
        AppStore.arcabackupContentType.identifier
    }

    func activityViewControllerLinkMetadata(_ activityViewController: UIActivityViewController) -> LPLinkMetadata? {
        let meta = LPLinkMetadata()
        meta.title = fileURL.lastPathComponent
        meta.originalURL = fileURL
        meta.url = fileURL
        return meta
    }
}
#endif

// MARK: - Share Sheet
struct ShareSheet: UIViewControllerRepresentable {
    let activityItems: [Any]
    /// Meldet nach dem Schließen zurück: (Aktivität, wurde wirklich geteilt?)
    var onComplete: ((String?, Bool) -> Void)? = nil

    func makeUIViewController(context: Context) -> UIActivityViewController {
        let vc = UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
        if let onComplete {
            vc.completionWithItemsHandler = { activity, completed, _, _ in
                onComplete(activity?.rawValue, completed)
            }
        }
        return vc
    }
    func updateUIViewController(_ uvc: UIActivityViewController, context: Context) {}
}

// MARK: - Backup Import Document Picker (mit gemerktem Startordner)
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

// MARK: - Stat Row (für Statistik in Settings)

struct StatRow: View {
    let icon: String
    let color: Color
    let label: String
    let value: String
    var subValue: String? = nil

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 32, height: 32)
                .background(color, in: RoundedRectangle(cornerRadius: 8))
            VStack(alignment: .leading, spacing: 1) {
                Text(label)
                    .font(.body)
                if let sub = subValue {
                    Text(sub)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
            Text(value)
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundStyle(color)
        }
        .padding(.vertical, 2)
    }
}

// MARK: - Wusstest du? Karte

struct ArcaTip {
    let icon: String
    let text: String
    let tint: Color
}

struct DidYouKnowCard: View {
    private static let tips: [ArcaTip] = [
        ArcaTip(icon: "hand.draw.fill", text: "Tippe lange auf einen Ordner, um ihn umzubenennen, einzufärben oder zu teilen.", tint: .orange),
        ArcaTip(icon: "house.fill", text: "Über „In Schnellansicht anzeigen“ legst du fest, welche Ordner auf dem Startbildschirm erscheinen.", tint: .blue),
        ArcaTip(icon: "mic.fill", text: "Notizen kannst du einfach einsprechen – Arca wandelt deine Stimme in Text um.", tint: .purple),
        ArcaTip(icon: "bolt.fill", text: "Mit der Blitzidee hältst du Gedanken in Sekunden fest, bevor sie weg sind.", tint: .yellow),
        ArcaTip(icon: "qrcode.viewfinder", text: "Der QR-Scanner auf dem Start liest Codes blitzschnell ein.", tint: .teal),
        ArcaTip(icon: "lock.shield.fill", text: "Alle Passwörter liegen sicher im iCloud-Schlüsselbund – verschlüsselt und nur für dich.", tint: .green),
        ArcaTip(icon: "icloud.fill", text: "Deine Daten synchronisieren sich automatisch zwischen iPhone und iPad.", tint: .cyan),
        ArcaTip(icon: "square.and.arrow.up.fill", text: "Sichere deinen Tresor regelmäßig über „Daten sichern“ – so bist du auch bei Geräteverlust geschützt.", tint: .indigo),
        ArcaTip(icon: "ticket.fill", text: "Lege deine Fahrkarten und Tickets in einen Ordner und zeig ihn in der Schnellansicht – am Bahnsteig sofort griffbereit.", tint: .pink),
        ArcaTip(icon: "airplane", text: "Reisedokumente wie Pass, Buchungen und Bordkarten an einem Ort – auf Reisen alles schnell zur Hand.", tint: .orange),
        ArcaTip(icon: "car.fill", text: "Führerschein, Fahrzeugschein und Versichertenkarte fotografieren – bei einer Kontrolle in Sekunden gefunden.", tint: .blue),
        ArcaTip(icon: "cross.case.fill", text: "Impfpass, Rezepte und Befunde an einem Ort – beim Arztbesuch alles sofort zur Hand.", tint: .red),
        ArcaTip(icon: "receipt.fill", text: "Kassenbons und Garantiebelege fotografieren – beim Umtausch oder Garantiefall sofort griffbereit.", tint: .green),
        ArcaTip(icon: "wifi", text: "Speichere dein WLAN-Passwort einmal – und zeig es Gästen blitzschnell, ohne langes Suchen.", tint: .cyan),
        ArcaTip(icon: "sparkles", text: "Tippe auf dem Startbildschirm mehrmals auf das Arca-Logo – vielleicht entdeckst du etwas. 🕷️", tint: .pink),
    ]

    @State private var index = Int.random(in: 0..<DidYouKnowCard.tips.count)

    private var tip: ArcaTip { Self.tips[index] }

    var body: some View {
        Button {
            withAnimation(.easeInOut(duration: 0.25)) {
                var next = index
                while next == index && Self.tips.count > 1 {
                    next = Int.random(in: 0..<Self.tips.count)
                }
                index = next
            }
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        } label: {
            HStack(alignment: .top, spacing: 14) {
                Image(systemName: tip.icon)
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(tip.tint)
                    .frame(width: 44, height: 44)
                    .background(tip.tint.opacity(0.15), in: RoundedRectangle(cornerRadius: 12, style: .continuous))

                VStack(alignment: .leading, spacing: 4) {
                    Text("Wusstest du?")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(tip.tint)
                    Text(tip.text)
                        .font(.system(size: 14))
                        .foregroundStyle(.primary)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(tip.tint.opacity(0.08), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(alignment: .bottomTrailing) {
                Image(systemName: "arrow.triangle.2.circlepath")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .padding(10)
            }
        }
        .buttonStyle(.plain)
    }
}

struct RateAppRow: View {
    /// Numerische App-Store-ID von Arca. Der Knopf öffnet direkt die Bewertungsseite.
    /// Solange leer, nutzt Arca die System-Bewertungsabfrage von Apple als Fallback.
    private let appStoreID = "6764523136"

    @Environment(\.requestReview) private var requestReview

    var body: some View {
        Button {
            if !appStoreID.isEmpty,
               let url = URL(string: "https://apps.apple.com/app/id\(appStoreID)?action=write-review") {
                UIApplication.shared.open(url)
            } else {
                requestReview()
            }
        } label: {
            HStack {
                Label("Arca bewerten", systemImage: "star.fill")
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .foregroundStyle(.primary)
    }
}

struct FeedbackLinkRow: View {
    let url: URL?
    let email = "kontakt@arcavault.app"

    @State private var showCopiedAlert = false

    private var canOpenMail: Bool {
        guard let url else { return false }
        return UIApplication.shared.canOpenURL(url)
    }

    var body: some View {
        Button {
            if let url, canOpenMail {
                UIApplication.shared.open(url)
            } else {
                UIPasteboard.general.string = email
                showCopiedAlert = true
            }
        } label: {
            HStack {
                Label("Feedback senden", systemImage: "envelope.fill")
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .foregroundStyle(.primary)
        .alert("E-Mail-Adresse kopiert", isPresented: $showCopiedAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Auf diesem Gerät ist keine Mail-App eingerichtet. Schreib uns gern an \(email) – die Adresse wurde in die Zwischenablage kopiert.")
        }
    }
}

struct SettingsView: View {
    @EnvironmentObject var store: AppStore
    @AppStorage("arcaUserName") private var userName: String = ""

    /// Vom Mehr-Menü der Leiste angestoßen: Sichern oder Wiederherstellen
    /// öffnet direkt das passende Blatt.
    private func verarbeiteSettingsAktion() {
        guard let aktion = store.pendingSettingsAktion else { return }
        store.pendingSettingsAktion = nil
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
            switch aktion {
            case "export": showExportPasswordSheet = true
            case "import": showImportConfirm = true
            default: break
            }
        }
    }

    // Export flow
    @State private var showExportPasswordSheet = false
    @State private var exportPassword = ""
    @State private var exportPasswordConfirm = ""
    @State private var exportPasswordError = ""
    @State private var showExportPassword = false
    @FocusState private var exportPasswordFieldFocused: Bool
    @FocusState private var importPasswordFieldFocused: Bool
    @State private var showImportPasswordReveal = false
    @State private var importMerge = true
    @State private var exportShareItem: ShareURLItem? = nil
    @State private var exportErfolgText: String? = nil

    // Import flow
    @State private var showImportPicker = false
    @State private var pendingImportURL: URL? = nil
    @State private var showImportPasswordSheet = false
    @State private var importPassword = ""
    @State private var showImportSuccess = false
    @State private var showImportError = false
    @State private var importErrorMessage = ""
    @State private var showReleaseNotes = false
    @State private var showImportConfirm = false
    @State private var importPickerStartFolder: URL? = nil

    private var feedbackURL: URL? {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "2.4.1"
        let subject = "Arca Feedback (Version \(version))"
        var components = URLComponents()
        components.scheme = "mailto"
        components.path = "kontakt@arcavault.app"
        components.queryItems = [URLQueryItem(name: "subject", value: subject)]
        return components.url
    }

    @ViewBuilder
    private var aboutSection: some View {
        Section {
            Button {
                showReleaseNotes = true
            } label: {
                HStack {
                    Label("Version \(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "2.4.1")", systemImage: "app.badge")
                    Spacer()
                    Text("Aktuell")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.green)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Color.green.opacity(0.14), in: Capsule())
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .foregroundStyle(.primary)
            Label("Entwickler: Hans zen Ruffinen", systemImage: "person.fill")
            RateAppRow()
            FeedbackLinkRow(url: feedbackURL)
        } header: {
            Text("Über ARCA")
        } footer: {
            Text("Fragen, Wünsche oder ein Lob? Schreib mir gern – über jedes Feedback freue ich mich.")
        }
    }

    /// Welches App-Symbol gerade auf dem Home-Bildschirm liegt
    @State private var aktivesIcon: String? = UIApplication.shared.alternateIconName

    /// Eine wählbare Icon-Kachel: Tipp wechselt das Home-Bildschirm-Symbol.
    @ViewBuilder
    private func iconWahl(name: String?, bild: String, titel: String) -> some View {
        let gewaehlt = aktivesIcon == name
        Button {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            UIApplication.shared.setAlternateIconName(name) { fehler in
                if fehler == nil {
                    DispatchQueue.main.async { aktivesIcon = name }
                }
            }
        } label: {
            VStack(spacing: 4) {
                Image(bild)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 46, height: 46)
                    .clipShape(RoundedRectangle(cornerRadius: 11))
                    .overlay(RoundedRectangle(cornerRadius: 11)
                        .strokeBorder(gewaehlt ? ArcaWarm.terrakotta : Color.secondary.opacity(0.25),
                                      lineWidth: gewaehlt ? 2.5 : 1))
                Text(titel)
                    .font(.system(size: 10, weight: gewaehlt ? .semibold : .regular))
                    .foregroundStyle(gewaehlt ? ArcaWarm.terrakotta : .secondary)
            }
        }
        .buttonStyle(.plain)
    }

    private var arcabackupType: UTType {
        AppStore.arcabackupContentType
    }

    private func backupImportErrorMessage(for url: URL, error: AppStore.BackupImportError) -> String {
        if store.isBlockedDocumentExtension(url) {
            let ext = url.pathExtension.uppercased()
            if ext == "PDF" {
                return "Das ist ein PDF-Dokument, keine Arca-Sicherung (.arcabackup). Bitte die exportierte Datei „ArcaBackup_….arcabackup“ wählen — nicht ein Dokument aus dem Tresor."
            }
            return "Das ist eine \(ext)-Datei, keine Arca-Sicherung (.arcabackup). Bitte die exportierte Backup-Datei wählen."
        }
        switch error {
        case .fileAccessDenied:
            return "Kein Zugriff auf die Datei. Bitte erneut auswählen."
        case .invalidBackupFile:
            return "Keine gültige Arca-Backup-Datei (.arcabackup). Bitte die exportierte Sicherungsdatei wählen — keine PDF oder anderes Dokument."
        case .wrongPasswordOrCorrupt, .manifestInvalid:
            return "Die Datei konnte nicht gelesen werden."
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
            // Kurz warten, bis der Dateiwähler wirklich zu ist — sonst
            // verpufft das Passwort-Blatt still (Blatt-auf-Blatt-Rennen,
            // besonders auf iPad/Mac).
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                showImportPasswordSheet = true
            }
        case .failure(let error):
            importErrorMessage = backupImportErrorMessage(for: url, error: error)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                showImportError = true
            }
        }
    }

    private func backupShareActivityItems(for item: ShareURLItem) -> [Any] {
        #if canImport(UIKit)
        if item.isArcaBackup {
            return [BackupShareActivityItem(fileURL: item.url)]
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
            guard password.count >= AppStore.minBackupPasswordLength else {
                exportPasswordError = "Das Passwort muss mindestens 4 Zeichen lang sein."
                return
            }
            guard password == passwordConfirm else {
                exportPasswordError = "Passwörter stimmen nicht überein."
                return
            }

            switch store.exportData(password: password) {
            case .success(let url):
                showExportPasswordSheet = false
                // Warten bis das Passwort-Blatt wirklich zu ist — sonst schluckt
                // iOS das Teilen-Blatt (0,6 s wie beim Import; 0,35 s war zu knapp).
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                    exportShareItem = ShareURLItem(url: url, isArcaBackup: true)
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

        // SecureField committet den Text erst nach Focus-Verlust — vor async einfrieren
        // (gleiches Muster wie performBackupExport).
        let password = importPassword
        let url = pendingImportURL
        let mergeMode = importMerge

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            guard let url else { return }
            switch store.importData(from: url, password: password, merge: mergeMode) {
            case .success:
                showImportPasswordSheet = false
                showImportPasswordReveal = false
                pendingImportURL = nil
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
                importErrorMessage = "Keine gültige Arca-Backup-Datei (.arcabackup)."
                showImportError = true
            }
        }
    }

    var body: some View {
        NavigationStack {
            List {
                // ── Kopf: kompakt ──
                Section {
                    HStack(alignment: .center) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Einstellungen")
                                .font(.system(size: 24, weight: .bold, design: .rounded))
                            Text("App, Daten und Präferenzen.")
                                .font(.system(size: 12))
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        ArcaGlassIcon(size: 34)
                    }
                    .listRowInsets(EdgeInsets(top: 0, leading: 4, bottom: 0, trailing: 4))
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                }

                // ── Profil: eine Zeile, Name direkt hier tippbar ──
                Section {
                    HStack(spacing: 12) {
                        Image(systemName: "person.fill")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundStyle(ArcaWarm.terrakotta)
                            .frame(width: 38, height: 38)
                            .background(ArcaWarm.terrakotta.opacity(0.14), in: Circle())
                        VStack(alignment: .leading, spacing: 1) {
                            TextField("Dein Name", text: $userName)
                                .font(.system(size: 16, weight: .semibold))
                                .textInputAutocapitalization(.words)
                            Text("Für die Begrüßung auf dem Start")
                                .font(.system(size: 11))
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.vertical, 1)

                    // App-Symbol: Standard oder Gold
                    if UIApplication.shared.supportsAlternateIcons {
                        HStack(spacing: 16) {
                            Label("App-Symbol", systemImage: "app.gift")
                            Spacer()
                            iconWahl(name: nil, bild: "ArcaIcon", titel: "Arca")
                            iconWahl(name: "ArcaGold", bild: "ArcaGoldVorschau", titel: "Gold")
                        }
                        .padding(.vertical, 2)
                    }
                }

                aboutSection

                // ── Nutzer & Synchronisation ──
                Section {
                    HStack {
                        Label("iCloud", systemImage: "icloud.fill")
                        Spacer()
                        HStack(spacing: 4) {
                            if store.iCloudStatus == .synced {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.system(size: 13))
                            }
                            Text(store.iCloudStatus.rawValue)
                        }
                        .font(.subheadline)
                        .foregroundStyle(store.iCloudStatus == .synced ? .green :
                                         store.iCloudStatus == .downloading ? .orange : .secondary)
                    }

                    // „Gut zu wissen" — kompakt
                    HStack(alignment: .top, spacing: 10) {
                        Image(systemName: "icloud.and.arrow.down.fill")
                            .font(.system(size: 18))
                            .foregroundStyle(.blue.opacity(0.75))
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Gut zu wissen")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundStyle(.blue)
                            Text("Deine Daten wandern sicher über iCloud zwischen deinen Geräten. „Warte auf Download“ heißt: Inhalte kommen gerade aus der Cloud.")
                                .font(.system(size: 11))
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.vertical, 2)
                    .listRowBackground(Color.blue.opacity(0.07))
                } header: {
                    Text("Nutzer & Synchronisation")
                }

                // Backup — wichtigste Funktion, direkt oben
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
                    // „Deine Daten. Deine Sicherheit." — kompakt
                    HStack(alignment: .top, spacing: 10) {
                        Image(systemName: "checkmark.shield.fill")
                            .font(.system(size: 18))
                            .foregroundStyle(.green)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Deine Daten. Deine Sicherheit.")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundStyle(.green)
                            Text("Backups sind verschlüsselt — in iCloud Drive, per Mail oder lokal gesichert, jederzeit wiederherstellbar.")
                                .font(.system(size: 11))
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.vertical, 2)
                    .listRowBackground(Color.green.opacity(0.08))
                } header: {
                    Text("Sichern und Wiederherstellen")
                }

                // Wusstest du? – wechselnde Tipps & versteckte Funktionen
                Section {
                    DidYouKnowCard()
                        .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                } footer: {
                    Label("Arca ist kostenlos, werbefrei und sammelt keine Daten über dich.", systemImage: "lock.shield.fill")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

            }
            .listSectionSpacing(14)
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Image(systemName: "gearshape")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(.secondary)
                }
            }

            // --- Release Notes Sheet ---
            .sheet(isPresented: $showReleaseNotes) {
                NavigationStack {
                    List {
                        Section {
                            Label("iCloud: Datenverlust beim App-Update behoben – Downloads werden vollständig abgewartet", systemImage: "icloud.fill")
                            Label("Ladehinweis beim iCloud-Download und Sync-Status in den Einstellungen", systemImage: "icloud.and.arrow.down.fill")
                            Label("Hinweis zur Datenwiederherstellung für von Update betroffene Nutzer", systemImage: "arrow.counterclockwise.icloud.fill")
                            Label("Backup teilen: Freigabe-Dialog erscheint zuverlässig nach Passworteingabe", systemImage: "square.and.arrow.up.fill")
                            Label("Verbesserter Passwortschutz für verschlüsselte Backups (HKDF/AEA)", systemImage: "lock.shield.fill")
                            Label("Import: Passworteingabe und Dateiauswahl zuverlässiger (.arcabackup)", systemImage: "square.and.arrow.down.fill")
                            Label("Falsche Dateitypen beim Import werden klar abgewiesen", systemImage: "doc.badge.gearshape.fill")
                            Label("Letzter Backup-Ordner wird gemerkt", systemImage: "folder.fill")
                            Label("Bestätigung vor dem Datenimport", systemImage: "checkmark.circle.fill")
                            Label("Passwort-Hinweise beim Sichern und Wiederherstellen", systemImage: "info.circle.fill")
                        } header: {
                            Text("Neu in Version 2.4.1")
                        }

                        Section {
                            Label("Neues, modernes App-Icon im Liquid-Glass-Stil – hell und dunkel", systemImage: "app.gift.fill")
                            Label("Frischer Startbildschirm mit wählbarer Ordner-Schnellansicht", systemImage: "square.grid.2x2.fill")
                            Label("Ordner per Drag & Drop sortieren, leere Ordner werden ausgeblendet", systemImage: "arrow.up.arrow.down")
                            Label("„Wusstest du?“-Tipps mit praktischen Anwendungen", systemImage: "lightbulb.fill")
                            Label("Feedback senden und Arca im App Store bewerten", systemImage: "star.fill")
                        } header: {
                            Text("Version 2.4.0")
                        }

                        Section {
                            Label("Videos mit Mehrfachauswahl in Dokumente importieren", systemImage: "film.stack.fill")
                            Label("Diktat-Einträge direkt in Tasklisten", systemImage: "mic.fill")
                            Label("Datei-Vorschauen für Bilder und Dokumente", systemImage: "doc.text.viewfinder")
                            Label("iCloud-Download-Handling – Dateien werden bei Bedarf nachgeladen", systemImage: "icloud.and.arrow.down.fill")
                            Label("Speicherschonendes Backup – große Archive ohne RAM-Überlast", systemImage: "externaldrive.fill.badge.checkmark")
                            Label("Einheitliche Bedienführung auf allen Seiten", systemImage: "hand.tap.fill")
                            Label("Scan-Fix und verbesserte Dokumentenerfassung", systemImage: "doc.viewfinder.fill")
                            Label("iPad-Layout optimiert, App-Store-Compliance (Guideline 4)", systemImage: "ipad")
                            Label("Undurchsichtiger Sperrbildschirm im Hintergrund", systemImage: "lock.shield.fill")
                        } header: {
                            Text("Version 2.3.0")
                        }

                        Section {
                            Label("iCloud Sync – alle Daten automatisch zwischen iPhone und iPad", systemImage: "icloud.fill")
                            Label("Passwörter, Notizen, Tasks und Dokumente auf allen Geräten synchron", systemImage: "arrow.triangle.2.circlepath")
                            Label("Offline voll nutzbar – Sync im Hintergrund sobald Verbindung besteht", systemImage: "wifi.slash")
                            Label("Bestehende Daten werden automatisch migriert – kein Datenverlust", systemImage: "checkmark.shield.fill")
                        } header: {
                            Text("Version 2.2.4")
                        }

                        Section {
                            Label("iPad: Dokumente – Master-Detail-Ansicht mit direkter Vorschau", systemImage: "doc.text.magnifyingglass")
                            Label("iPad: Tasks – Master-Detail-Ansicht, Liste und Detail nebeneinander", systemImage: "checklist")
                            Label("iPad: Alle vier Bereiche (Passwörter, Notizen, Dokumente, Tasks) als Master-Detail", systemImage: "rectangle.split.2x1")
                        } header: {
                            Text("Version 2.2.3")
                        }

                        Section {
                            Label("Einzelne Dokumente teilen, drucken & an Arca-Nutzer senden", systemImage: "square.and.arrow.up.fill")
                            Label("Untergruppen für Dokumente – volle Hierarchie (Gruppe → Untergruppe → Dokument)", systemImage: "folder.fill.badge.plus")
                            Label("Kontextmenüs auf allen Seiten komplett modernisiert", systemImage: "contextualmenu.and.cursorarrow")
                            Label("Farben für Passwörter, Notizen und Listen einzeln änderbar", systemImage: "paintpalette.fill")
                            Label("Startseite: Header mit Logo und Statistiken fixiert", systemImage: "pin.fill")
                            Label("Suchleiste ergonomisch unten auf der Startseite", systemImage: "magnifyingglass")
                            Label("Ende-zu-Ende verschlüsselt – Hinweis über Schnellzugriff", systemImage: "checkmark.shield.fill")
                            Label("Sicherheitshinweis-Badge auf Passwörter-Seite rechts neben Sortierung", systemImage: "exclamationmark.shield.fill")
                            Label("Einheitlicher + Button auf allen Seiten", systemImage: "plus.circle.fill")
                            Label("Seiten-Icons in der Navigationsleiste", systemImage: "rectangle.grid.1x2.fill")
                            Label("Release Notes hinter dem Versions-Eintrag versteckt", systemImage: "doc.text.magnifyingglass")
                            Label("Abstände kompakter – mehr Platz für Inhalte", systemImage: "arrow.up.and.down.square")
                        } header: {
                            Text("Version 2.2.2")
                        }

                        Section {
                            Label("Öffnen mit – Arca-Dateien erscheinen zuverlässig in der Auswahl", systemImage: "square.and.arrow.down.fill")
                            Label("Backup importieren – Zusammenführen oder Ersetzen wählbar", systemImage: "arrow.triangle.merge")
                            Label("Siri: Kurznotiz in Arca speichert ohne App zu öffnen", systemImage: "mic.fill")
                            Label("Siri: Ich habe eine Idee für Arca – neuer Befehl", systemImage: "lightbulb.fill")
                            Label("Bestätigung beim Speichern per Vibration & Meldung", systemImage: "checkmark.circle.fill")
                        } header: {
                            Text("Version 2.2.1")
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

            // --- Export: password input sheet ---
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
                                        .foregroundStyle(.blue)
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
                            Button("Sichern") {
                                performBackupExport()
                            }
                            .disabled(exportPassword.isEmpty)
                        }
                    }
                }
            }

            // --- Export: share sheet ---
            .sheet(item: $exportShareItem) { item in
                if FileManager.default.fileExists(atPath: item.url.path) {
                    ShareSheet(activityItems: backupShareActivityItems(for: item)) { aktivitaet, fertig in
                        exportShareItem = nil
                        guard fertig else { return }
                        // Ein echtes Backup: Datum für die Erinnerung stempeln
                        store.letztesBackup = Date()
                        let ziel: String
                        if let a = aktivitaet, a.contains("SaveToFiles") {
                            ziel = "in der Dateien-App abgelegt"
                        } else if let a = aktivitaet, a.contains("AirDrop") {
                            ziel = "per AirDrop übertragen"
                        } else if let a = aktivitaet, a.lowercased().contains("mail") {
                            ziel = "per Mail versendet"
                        } else {
                            ziel = "übergeben"
                        }
                        let name = item.url.lastPathComponent
                        // Kurz warten, bis das Teilen-Blatt zu ist (Blatt-auf-Blatt)
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                            exportErfolgText = "„\(name)“ wurde \(ziel)."
                        }
                    }
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

            // --- Export: Bestätigung nach dem Sichern ---
            .alert("Gesichert ✓", isPresented: Binding(
                get: { exportErfolgText != nil },
                set: { if !$0 { exportErfolgText = nil } }
            )) {
                Button("OK") { exportErfolgText = nil }
            } message: {
                Text(exportErfolgText ?? "")
            }

            // --- Import: file picker ---
            .alert("Daten wiederherstellen", isPresented: $showImportConfirm) {
                Button("Abbrechen", role: .cancel) {}
                Button("Fortfahren") {
                    importPickerStartFolder = store.beginAccessingRememberedBackupFolder()
                    showImportPicker = true
                }
            } message: {
                Text("Bestehende Daten werden ersetzt. Möchtest du fortfahren?")
            }
            .sheet(isPresented: $showImportPicker, onDismiss: {
                store.releaseRememberedBackupFolderAccess()
                importPickerStartFolder = nil
            }) {
                BackupImportDocumentPicker(
                    contentType: arcabackupType,
                    directoryURL: importPickerStartFolder
                ) { url in
                    showImportPicker = false
                    beginBackupImport(from: url)
                } onCancel: {
                    showImportPicker = false
                }
            }
            // Mehr-Menü in der Leiste: Sichern/Wiederherstellen direkt anspringen
            .onAppear { verarbeiteSettingsAktion() }
            .onChange(of: store.pendingSettingsAktion) { _, _ in verarbeiteSettingsAktion() }

            // "Öffnen mit .arcabackup" von aussen → Passwort-Sheet öffnen
            .onAppear { consumePendingBackupURL() }
            .onChange(of: store.pendingBackupURL) { _, url in
                guard url != nil else { return }
                consumePendingBackupURL()
            }

            // --- Import: password input sheet ---
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
                                        .foregroundStyle(.blue)
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
                                 ? "✓ Sicher: Vorhandene Notizen, Dokumente und Listen bleiben."
                                 : "⚠️ Alles wird durch den Backup-Stand ersetzt.")
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

            .alert("Import erfolgreich! ✅", isPresented: $showImportSuccess) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("Alle Daten wurden erfolgreich wiederhergestellt.")
            }
            .alert("Import fehlgeschlagen ❌", isPresented: $showImportError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(importErrorMessage)
            }
        }
    }
}

