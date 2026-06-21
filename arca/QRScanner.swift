//
//  QRScanner.swift
//  Arca
//
//  Entwickler: Hans zen Ruffinen
//

import SwiftUI
import Vision
import VisionKit
import AVFoundation
import NetworkExtension
import Contacts
import ContactsUI

// MARK: - Smart Parser

enum QRPayload {
    case wifi(ssid: String, password: String, security: String)
    case url(URL)
    case email(address: String, subject: String?, body: String?)
    case phone(String)
    case sms(number: String, message: String?)
    case vcard(raw: String, name: String?)
    case plainText(String)

    static func parse(_ raw: String) -> QRPayload {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)

        // WLAN: WIFI:T:WPA;S:MeinNetz;P:geheim;;
        if trimmed.uppercased().hasPrefix("WIFI:") {
            let body = String(trimmed.dropFirst(5))
            var ssid = "", password = "", security = "WPA"
            // Felder sind durch ; getrennt, Werte mit : geprefixt
            // Wir splitten an ; (außer escaped \;) — pragmatisch, ohne komplettes Escape-Handling
            let parts = body.split(separator: ";").map(String.init)
            for part in parts {
                guard let colon = part.firstIndex(of: ":") else { continue }
                let key = String(part[part.startIndex..<colon]).uppercased()
                let value = String(part[part.index(after: colon)...])
                switch key {
                case "S": ssid = value
                case "P": password = value
                case "T": security = value
                default: break
                }
            }
            return .wifi(ssid: ssid, password: password, security: security)
        }

        // mailto:
        if trimmed.lowercased().hasPrefix("mailto:") {
            let rest = String(trimmed.dropFirst(7))
            let (addr, query) = rest.split(separator: "?", maxSplits: 1).map(String.init).pad(to: 2, with: "")
            var subject: String? = nil
            var body: String? = nil
            for pair in query.split(separator: "&") {
                let kv = pair.split(separator: "=", maxSplits: 1).map(String.init)
                if kv.count == 2 {
                    let value = kv[1].removingPercentEncoding ?? kv[1]
                    if kv[0].lowercased() == "subject" { subject = value }
                    if kv[0].lowercased() == "body" { body = value }
                }
            }
            return .email(address: addr, subject: subject, body: body)
        }

        // tel:
        if trimmed.lowercased().hasPrefix("tel:") {
            return .phone(String(trimmed.dropFirst(4)))
        }

        // sms:
        if trimmed.lowercased().hasPrefix("sms:") || trimmed.lowercased().hasPrefix("smsto:") {
            let prefixLen = trimmed.lowercased().hasPrefix("smsto:") ? 6 : 4
            let rest = String(trimmed.dropFirst(prefixLen))
            let parts = rest.split(separator: ":", maxSplits: 1).map(String.init)
            return .sms(number: parts[0], message: parts.count > 1 ? parts[1] : nil)
        }

        // vCard
        if trimmed.uppercased().hasPrefix("BEGIN:VCARD") {
            // Versuche Namen zu extrahieren
            var name: String? = nil
            for line in trimmed.split(separator: "\n") {
                let l = line.trimmingCharacters(in: .whitespaces)
                if l.uppercased().hasPrefix("FN:") {
                    name = String(l.dropFirst(3))
                    break
                } else if l.uppercased().hasPrefix("N:") {
                    name = String(l.dropFirst(2))
                        .replacingOccurrences(of: ";", with: " ")
                        .trimmingCharacters(in: .whitespaces)
                }
            }
            return .vcard(raw: trimmed, name: name)
        }

        // URL
        if let url = URL(string: trimmed),
           let scheme = url.scheme?.lowercased(),
           ["http", "https"].contains(scheme) {
            return .url(url)
        }

        return .plainText(trimmed)
    }

    var typeLabel: String {
        switch self {
        case .wifi:      return "WLAN-Netzwerk"
        case .url:       return "Webseite"
        case .email:     return "E-Mail"
        case .phone:     return "Telefonnummer"
        case .sms:       return "SMS"
        case .vcard:     return "Kontakt"
        case .plainText: return "Text"
        }
    }

    var iconName: String {
        switch self {
        case .wifi:      return "wifi"
        case .url:       return "link"
        case .email:     return "envelope.fill"
        case .phone:     return "phone.fill"
        case .sms:       return "message.fill"
        case .vcard:     return "person.crop.rectangle.fill"
        case .plainText: return "text.alignleft"
        }
    }
}

private extension Array where Element == String {
    func pad(to count: Int, with filler: String) -> (String, String) {
        var copy = self
        while copy.count < count { copy.append(filler) }
        return (copy[0], copy[1])
    }
}

// MARK: - Scanner Sheet

struct QRScannerSheet: View {
    @EnvironmentObject var store: AppStore
    @Environment(\.dismiss) private var dismiss
    @State private var scannedRaw: String? = nil
    @State private var cameraDenied = false

    var body: some View {
        NavigationStack {
            Group {
                if !DataScannerViewController.isSupported || !DataScannerViewController.isAvailable {
                    unavailableView
                } else if cameraDenied {
                    deniedView
                } else if let raw = scannedRaw {
                    QRResultView(raw: raw, onClose: { dismiss() }, onScanAgain: { scannedRaw = nil })
                        .environmentObject(store)
                } else {
                    DataScannerWrapper(onScan: { value in
                        UINotificationFeedbackGenerator().notificationOccurred(.success)
                        scannedRaw = value
                    })
                    .ignoresSafeArea(edges: .bottom)
                    .overlay(alignment: .top) {
                        scanHint
                    }
                }
            }
            .navigationTitle("QR-Code scannen")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Fertig") { dismiss() }
                }
            }
            .task {
                await checkCameraPermission()
            }
        }
    }

    private var scanHint: some View {
        Text("Richte die Kamera auf einen QR-Code")
            .font(.subheadline.weight(.medium))
            .foregroundStyle(.white)
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(.ultraThinMaterial, in: Capsule())
            .padding(.top, 8)
    }

    private var unavailableView: some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 44))
                .foregroundStyle(.orange)
            Text("QR-Scanner nicht verfügbar")
                .font(.headline)
            Text("Dieses Gerät unterstützt den Scanner nicht.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
        .padding()
    }

    private var deniedView: some View {
        VStack(spacing: 16) {
            Image(systemName: "camera.fill")
                .font(.system(size: 44))
                .foregroundStyle(.red)
            Text("Kamera-Zugriff fehlt")
                .font(.headline)
            Text("Erlaube Arca den Kamerazugriff in den Einstellungen, um QR-Codes scannen zu können.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            Button {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            } label: {
                Text("Einstellungen öffnen")
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
    }

    private func checkCameraPermission() async {
        let status = AVCaptureDevice.authorizationStatus(for: .video)
        switch status {
        case .notDetermined:
            let ok = await AVCaptureDevice.requestAccess(for: .video)
            if !ok { cameraDenied = true }
        case .denied, .restricted:
            cameraDenied = true
        default:
            break
        }
    }
}

// MARK: - DataScanner UIViewControllerRepresentable

struct DataScannerWrapper: UIViewControllerRepresentable {
    let onScan: (String) -> Void

    func makeUIViewController(context: Context) -> DataScannerViewController {
        let scanner = DataScannerViewController(
            recognizedDataTypes: [.barcode(symbologies: [.qr])],
            qualityLevel: .balanced,
            recognizesMultipleItems: false,
            isHighFrameRateTrackingEnabled: false,
            isPinchToZoomEnabled: true,
            isGuidanceEnabled: true,
            isHighlightingEnabled: true
        )
        scanner.delegate = context.coordinator
        return scanner
    }

    func updateUIViewController(_ uiViewController: DataScannerViewController, context: Context) {
        if !uiViewController.isScanning {
            try? uiViewController.startScanning()
        }
    }

    func makeCoordinator() -> Coordinator { Coordinator(onScan: onScan) }

    class Coordinator: NSObject, DataScannerViewControllerDelegate {
        let onScan: (String) -> Void
        var hasReported = false

        init(onScan: @escaping (String) -> Void) { self.onScan = onScan }

        func dataScanner(_ dataScanner: DataScannerViewController, didAdd addedItems: [RecognizedItem], allItems: [RecognizedItem]) {
            guard !hasReported, let first = addedItems.first else { return }
            if case let .barcode(barcode) = first, let value = barcode.payloadStringValue {
                hasReported = true
                onScan(value)
            }
        }

        func dataScanner(_ dataScanner: DataScannerViewController, didTapOn item: RecognizedItem) {
            guard !hasReported else { return }
            if case let .barcode(barcode) = item, let value = barcode.payloadStringValue {
                hasReported = true
                onScan(value)
            }
        }
    }
}

// MARK: - Result View

struct QRResultView: View {
    @EnvironmentObject var store: AppStore
    let raw: String
    let onClose: () -> Void
    let onScanAgain: () -> Void

    @State private var showSavedHint = false
    @State private var savedMessage = ""
    @State private var contactToImport: CNContact? = nil

    private var payload: QRPayload { QRPayload.parse(raw) }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                // Header
                HStack(spacing: 12) {
                    Image(systemName: payload.iconName)
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(width: 44, height: 44)
                        .background(Color.pink, in: RoundedRectangle(cornerRadius: 12))
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Erkannt:")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(payload.typeLabel)
                            .font(.headline)
                    }
                    Spacer()
                }

                // Content preview
                contentPreview
                    .padding(14)
                    .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 12))

                // Actions
                VStack(spacing: 10) {
                    actionButtons
                }

                if showSavedHint {
                    HStack(spacing: 8) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                        Text(savedMessage)
                            .font(.subheadline.weight(.medium))
                    }
                    .padding(10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.green.opacity(0.15), in: RoundedRectangle(cornerRadius: 10))
                    .transition(.opacity)
                }
            }
            .padding()
        }
        .safeAreaInset(edge: .bottom) {
            HStack(spacing: 10) {
                Button {
                    onScanAgain()
                } label: {
                    Label("Erneut scannen", systemImage: "qrcode.viewfinder")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                Button {
                    onClose()
                } label: {
                    Text("Schließen")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
            }
            .padding()
            .background(.ultraThinMaterial)
        }
        .sheet(item: $contactToImport) { contact in
            ContactImportView(contact: contact)
        }
    }

    @ViewBuilder
    private var contentPreview: some View {
        switch payload {
        case .wifi(let ssid, let password, let security):
            VStack(alignment: .leading, spacing: 6) {
                row("SSID", ssid)
                row("Passwort", password.isEmpty ? "(keins)" : password)
                row("Sicherheit", security.isEmpty ? "WPA" : security)
            }
        case .url(let url):
            Text(url.absoluteString)
                .font(.callout.monospaced())
                .foregroundStyle(.blue)
                .textSelection(.enabled)
        case .email(let address, let subject, _):
            VStack(alignment: .leading, spacing: 6) {
                row("Adresse", address)
                if let subject, !subject.isEmpty { row("Betreff", subject) }
            }
        case .phone(let number):
            row("Nummer", number)
        case .sms(let number, let message):
            VStack(alignment: .leading, spacing: 6) {
                row("Nummer", number)
                if let message, !message.isEmpty { row("Nachricht", message) }
            }
        case .vcard(_, let name):
            row("Name", name ?? "(unbekannt)")
        case .plainText(let text):
            Text(text)
                .font(.callout)
                .textSelection(.enabled)
        }
    }

    private func row(_ key: String, _ value: String) -> some View {
        HStack(alignment: .top) {
            Text(key)
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(width: 80, alignment: .leading)
            Text(value)
                .font(.callout)
                .textSelection(.enabled)
            Spacer(minLength: 0)
        }
    }

    @ViewBuilder
    private var actionButtons: some View {
        switch payload {
        case .wifi(let ssid, let password, let security):
            actionButton("Verbinden + Speichern", icon: "wifi") {
                connectToWifi(ssid: ssid, password: password, security: security)
                store.addVaultEntry(title: "WLAN: \(ssid)", username: ssid, password: password, colorTag: 2)
            }
            actionButton("Nur speichern", icon: "key.fill") {
                store.addVaultEntry(title: "WLAN: \(ssid)", username: ssid, password: password, colorTag: 2)
                flash("WLAN als Passwort gespeichert")
            }
            actionButton("Passwort kopieren", icon: "doc.on.doc.fill") {
                UIPasteboard.general.string = password
                flash("Passwort in Zwischenablage")
            }
        case .url(let url):
            actionButton("Im Browser öffnen", icon: "safari") {
                UIApplication.shared.open(url)
            }
            actionButton("Als Notiz speichern", icon: "note.text") {
                store.addNote(title: url.host ?? "Webseite", text: url.absoluteString)
                flash("Notiz angelegt")
            }
            actionButton("Link kopieren", icon: "doc.on.doc.fill") {
                UIPasteboard.general.string = url.absoluteString
                flash("Link in Zwischenablage")
            }
        case .email(let address, let subject, let body):
            actionButton("E-Mail schreiben", icon: "envelope.fill") {
                var components = URLComponents(string: "mailto:\(address)")
                var query: [URLQueryItem] = []
                if let subject, !subject.isEmpty { query.append(URLQueryItem(name: "subject", value: subject)) }
                if let body, !body.isEmpty { query.append(URLQueryItem(name: "body", value: body)) }
                if !query.isEmpty { components?.queryItems = query }
                if let url = components?.url { UIApplication.shared.open(url) }
            }
            actionButton("Adresse kopieren", icon: "doc.on.doc.fill") {
                UIPasteboard.general.string = address
                flash("Adresse in Zwischenablage")
            }
        case .phone(let number):
            actionButton("Anrufen", icon: "phone.fill") {
                if let url = URL(string: "tel:\(number)") { UIApplication.shared.open(url) }
            }
            actionButton("Als Notiz speichern", icon: "note.text") {
                store.addNote(title: "Telefonnummer", text: number)
                flash("Notiz angelegt")
            }
            actionButton("Nummer kopieren", icon: "doc.on.doc.fill") {
                UIPasteboard.general.string = number
                flash("Nummer in Zwischenablage")
            }
        case .sms(let number, let message):
            actionButton("SMS schreiben", icon: "message.fill") {
                var urlString = "sms:\(number)"
                if let message, !message.isEmpty,
                   let encoded = message.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) {
                    urlString += "&body=\(encoded)"
                }
                if let url = URL(string: urlString) { UIApplication.shared.open(url) }
            }
        case .vcard(let raw, let name):
            actionButton("In Kontakte importieren", icon: "person.crop.circle.badge.plus") {
                if let data = raw.data(using: .utf8),
                   let contacts = try? CNContactVCardSerialization.contacts(with: data),
                   let first = contacts.first {
                    contactToImport = first
                } else {
                    flash("Kontakt konnte nicht gelesen werden")
                }
            }
            actionButton("Als Notiz speichern", icon: "note.text") {
                store.addNote(title: "Kontakt: \(name ?? "Unbekannt")", text: raw)
                flash("Notiz angelegt")
            }
            actionButton("Inhalt kopieren", icon: "doc.on.doc.fill") {
                UIPasteboard.general.string = raw
                flash("Kontakt in Zwischenablage")
            }
        case .plainText(let text):
            actionButton("Als Notiz speichern", icon: "note.text") {
                let title = text.prefix(40).trimmingCharacters(in: .whitespacesAndNewlines)
                store.addNote(title: title.isEmpty ? "QR-Text" : String(title), text: text)
                flash("Notiz angelegt")
            }
            actionButton("Text kopieren", icon: "doc.on.doc.fill") {
                UIPasteboard.general.string = text
                flash("Text in Zwischenablage")
            }
        }
    }

    private func actionButton(_ title: String, icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack {
                Image(systemName: icon)
                    .frame(width: 22)
                Text(title)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(.tertiarySystemBackground), in: RoundedRectangle(cornerRadius: 12))
            .foregroundStyle(.primary)
        }
        .buttonStyle(.plain)
    }

    private func flash(_ message: String) {
        savedMessage = message
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        withAnimation(.easeInOut(duration: 0.25)) { showSavedHint = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
            withAnimation(.easeInOut(duration: 0.4)) { showSavedHint = false }
        }
    }

    private func connectToWifi(ssid: String, password: String, security: String) {
        let config: NEHotspotConfiguration
        let secLower = security.lowercased()

        if password.isEmpty || secLower.contains("nopass") {
            // Offenes Netzwerk
            config = NEHotspotConfiguration(ssid: ssid)
        } else if secLower.contains("wep") {
            // WEP (alt, selten)
            config = NEHotspotConfiguration(ssid: ssid, passphrase: password, isWEP: true)
        } else {
            // WPA / WPA2 / WPA3 (Standard)
            config = NEHotspotConfiguration(ssid: ssid, passphrase: password, isWEP: false)
        }
        config.joinOnce = false  // dauerhaft, iOS speichert die Verbindung

        flash("Verbinde mit \(ssid)…")

        NEHotspotConfigurationManager.shared.apply(config) { error in
            DispatchQueue.main.async {
                if let nsError = error as NSError? {
                    if nsError.domain == NEHotspotConfigurationErrorDomain,
                       nsError.code == NEHotspotConfigurationError.alreadyAssociated.rawValue {
                        self.flash("Bereits mit diesem WLAN verbunden")
                    } else if nsError.domain == NEHotspotConfigurationErrorDomain,
                              nsError.code == NEHotspotConfigurationError.userDenied.rawValue {
                        self.flash("Verbindung abgelehnt")
                    } else {
                        self.flash("Verbindung fehlgeschlagen")
                    }
                } else {
                    self.flash("Mit \(ssid) verbunden!")
                }
            }
        }
    }
}

// MARK: - Contact Import


struct ContactImportView: UIViewControllerRepresentable {
    let contact: CNContact
    @Environment(\.dismiss) private var dismiss

    func makeUIViewController(context: Context) -> UINavigationController {
        let vc = CNContactViewController(forUnknownContact: contact)
        vc.contactStore = CNContactStore()
        vc.delegate = context.coordinator
        vc.allowsEditing = true
        return UINavigationController(rootViewController: vc)
    }

    func updateUIViewController(_ uiViewController: UINavigationController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(dismiss: dismiss) }

    class Coordinator: NSObject, CNContactViewControllerDelegate {
        let dismiss: DismissAction
        init(dismiss: DismissAction) { self.dismiss = dismiss }

        func contactViewController(_ viewController: CNContactViewController, didCompleteWith contact: CNContact?) {
            dismiss()
        }
    }
}

// MARK: - Coming Soon Sheet

struct ComingSoonSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var sparkleRotation: Double = 0

    var body: some View {
        VStack(spacing: 24) {
            Capsule()
                .fill(Color.secondary.opacity(0.4))
                .frame(width: 36, height: 5)
                .padding(.top, 8)

            Spacer()

            ZStack {
                Circle()
                    .fill(LinearGradient(
                        colors: [Color.purple.opacity(0.6), Color.pink.opacity(0.5), Color.orange.opacity(0.4)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ))
                    .frame(width: 130, height: 130)
                    .blur(radius: 18)

                Image(systemName: "sparkles")
                    .font(.system(size: 64, weight: .semibold))
                    .foregroundStyle(LinearGradient(
                        colors: [.purple, .pink, .orange],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ))
                    .rotationEffect(.degrees(sparkleRotation))
            }

            VStack(spacing: 10) {
                Text("Bald da")
                    .font(.title.bold())
                Text("Wir tüfteln gerade an neuen Features für Arca.\nFreu dich auf das nächste Update!")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
            }

            Spacer()

            Button {
                dismiss()
            } label: {
                Text("Verstanden")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
            }
            .buttonStyle(.borderedProminent)
            .padding(.horizontal)
            .padding(.bottom, 20)
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 3.0).repeatForever(autoreverses: true)) {
                sparkleRotation = 12
            }
        }
    }
}
