import SwiftUI
import AppIntents
import UserNotifications

@main
struct ArcaApp: App {
    @StateObject private var store = AppStore()

    init() {
        ArcaShortcuts.updateAppShortcutParameters()
        // Benachrichtigungs-Berechtigung anfragen (für Kurznotiz-Quittierung)
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }
    @State private var isUnlocked = false
    @Environment(\.scenePhase) private var scenePhase

    /// Zeitpunkt wann die App zuletzt in den Hintergrund ging
    @State private var backgroundedAt: Date? = nil
    /// Nach wie vielen Sekunden automatisch sperren (0 = sofort)
    private let autoLockTimeout: TimeInterval = 60

    var body: some Scene {
        WindowGroup {
            ZStack {
                // ContentView bleibt IMMER im Speicher — auch wenn gesperrt.
                // So überleben Edit-Sheets, Sucheingaben usw. einen Lock-Zyklus.
                ContentView(isUnlocked: isUnlocked)
                    .environmentObject(store)
                    .onOpenURL { url in
                        handleURL(url)
                    }

                // LockView als Overlay (verdeckt ContentView, zerstört es aber nicht)
                if !isUnlocked {
                    LockView(isUnlocked: $isUnlocked)
                        .onOpenURL { url in
                            handleURL(url)
                        }
                        .transition(.opacity)
                }

                // Privacy Screen: Inhalt verstecken wenn App im Hintergrund
                if scenePhase == .inactive || scenePhase == .background {
                    Color(.systemBackground)
                        .ignoresSafeArea()
                        .overlay {
                            VStack(spacing: 16) {
                                Image(systemName: "lock.shield.fill")
                                    .font(.system(size: 56))
                                    .foregroundStyle(.secondary)
                                Text("ARCA")
                                    .font(.title2.bold())
                                    .foregroundStyle(.secondary)
                            }
                        }
                }
            }
            .animation(.easeInOut(duration: 0.2), value: isUnlocked)
            .onReceive(NotificationCenter.default.publisher(for: .arcaBlitzidee)) { _ in
                store.pendingQuickCapture = true
            }
            .onReceive(NotificationCenter.default.publisher(for: .arcaNavigate)) { note in
                guard let dest = note.object as? String else { return }
                switch dest {
                case "vault":      store.pendingSection = .vault
                case "documents":  store.pendingSection = .documents
                case "notes":      store.pendingSection = .notes
                case "tasks":      store.pendingSection = .lists
                default: break
                }
            }
        }
        .onChange(of: scenePhase) { _, phase in
            switch phase {
            case .background:
                backgroundedAt = Date()
            case .active:
                if isUnlocked, let bg = backgroundedAt {
                    let elapsed = Date().timeIntervalSince(bg)
                    if elapsed > autoLockTimeout {
                        isUnlocked = false
                    }
                }
                backgroundedAt = nil
                // Neueste Daten aus iCloud laden (andere Geräte können Änderungen gemacht haben)
                store.reloadFromCloud()
                // Kurznotiz-Queue aus Siri verarbeiten
                processPendingQuickNotes()
                // Siri-Intent-Navigation auswerten (gesetzt von ArcaIntents.perform())
                checkIntentNavigation()
            default:
                break
            }
        }
    }

    /// Verarbeitet eingehende URLs (arca:// Deeplinks + externe Datei-URLs)
    private func handleURL(_ url: URL) {
        if url.scheme == "arca" {
            switch url.host {
            case "vault":      store.pendingSection = .vault
            case "documents":  store.pendingSection = .documents
            case "notes":      store.pendingSection = .notes
            case "tasks":      store.pendingSection = .lists
            case "blitzidee":
                store.pendingQuickCapture = true
            default:           store.pendingSection = .home
            }
        } else {
            store.pendingSharedURL = url
        }
    }

    /// Verarbeitet Kurznotizen die Siri im Hintergrund in die Queue geschrieben hat
    private func processPendingQuickNotes() {
        guard let defaults = UserDefaults(suiteName: "group.com.hansruffin.arca") else { return }
        guard let pending = defaults.array(forKey: "pendingQuickNotes") as? [[String: String]],
              !pending.isEmpty else { return }

        // Queue sofort leeren (damit doppelte Verarbeitung unmöglich ist)
        defaults.removeObject(forKey: "pendingQuickNotes")

        for noteData in pending {
            guard let text = noteData["text"], !text.isEmpty else { continue }
            // Erste Zeile → Titel, Rest → Body
            let lines = text.components(separatedBy: "\n")
            let title = String(lines.first?.prefix(60) ?? "Kurznotiz")
            let body  = lines.count > 1
                ? lines.dropFirst().joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
                : ""
            store.addNote(title: title, text: body)

            // Quittierung: lokale Benachrichtigung zeigen
            sendSavedNotification(title: title, preview: text)
        }
    }

    /// Sendet eine lokale Benachrichtigung als Quittierung für eine gespeicherte Kurznotiz
    private func sendSavedNotification(title: String, preview: String) {
        let content = UNMutableNotificationContent()
        content.title = "📝 Kurznotiz gespeichert"
        content.body  = String(preview.prefix(100))
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil  // sofort anzeigen
        )
        UNUserNotificationCenter.current().add(request)
    }

    /// Prüft ob ein Siri-Intent eine Navigation hinterlassen hat
    private func checkIntentNavigation() {
        guard let defaults = UserDefaults(suiteName: "group.com.hansruffin.arca") else { return }

        // Blitzidee-Intent
        if defaults.bool(forKey: "intentQuickCapture") {
            defaults.removeObject(forKey: "intentQuickCapture")
            store.pendingSection = .notes
            store.pendingQuickCapture = true
            return
        }

        // Standard-Navigation
        guard let nav = defaults.string(forKey: "intentNavigation"), !nav.isEmpty else { return }
        defaults.removeObject(forKey: "intentNavigation")
        switch nav {
        case "vault":     store.pendingSection = .vault
        case "documents": store.pendingSection = .documents
        case "notes":     store.pendingSection = .notes
        case "tasks":     store.pendingSection = .lists
        default: break
        }
    }
}
