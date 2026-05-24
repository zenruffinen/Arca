import AppIntents

// MARK: - Notification names for in-process intent delivery
extension Notification.Name {
    static let arcaNavigate    = Notification.Name("com.hansruffin.arca.navigate")
    static let arcaBlitzidee   = Notification.Name("com.hansruffin.arca.blitzidee")
}

// MARK: - Siri Shortcuts

struct OpenDocumentsIntent: AppIntent {
    static var title: LocalizedStringResource = "Dokumente öffnen"
    static var description = IntentDescription("Öffnet die Dokumentenansicht in Arca")
    static var openAppWhenRun: Bool = true

    @MainActor
    func perform() async throws -> some IntentResult {
        NotificationCenter.default.post(name: .arcaNavigate, object: "documents")
        UserDefaults(suiteName: "group.com.hansruffin.arca")?.set("documents", forKey: "intentNavigation")
        return .result()
    }
}

struct OpenVaultIntent: AppIntent {
    static var title: LocalizedStringResource = "Passwörter öffnen"
    static var description = IntentDescription("Öffnet den Passwort-Tresor in Arca")
    static var openAppWhenRun: Bool = true

    @MainActor
    func perform() async throws -> some IntentResult {
        NotificationCenter.default.post(name: .arcaNavigate, object: "vault")
        UserDefaults(suiteName: "group.com.hansruffin.arca")?.set("vault", forKey: "intentNavigation")
        return .result()
    }
}

struct OpenNotesIntent: AppIntent {
    static var title: LocalizedStringResource = "Notizen öffnen"
    static var description = IntentDescription("Öffnet die Notizen in Arca")
    static var openAppWhenRun: Bool = true

    @MainActor
    func perform() async throws -> some IntentResult {
        NotificationCenter.default.post(name: .arcaNavigate, object: "notes")
        UserDefaults(suiteName: "group.com.hansruffin.arca")?.set("notes", forKey: "intentNavigation")
        return .result()
    }
}

struct OpenTasksIntent: AppIntent {
    static var title: LocalizedStringResource = "Tasks öffnen"
    static var description = IntentDescription("Öffnet die Aufgabenlisten in Arca")
    static var openAppWhenRun: Bool = true

    @MainActor
    func perform() async throws -> some IntentResult {
        NotificationCenter.default.post(name: .arcaNavigate, object: "tasks")
        UserDefaults(suiteName: "group.com.hansruffin.arca")?.set("tasks", forKey: "intentNavigation")
        return .result()
    }
}

struct BlitzideeIntent: AppIntent {
    static var title: LocalizedStringResource = "Blitzidee aufnehmen"
    static var description = IntentDescription("Öffnet Arca und startet sofort eine Sprachnotiz")
    static var openAppWhenRun: Bool = true

    @MainActor
    func perform() async throws -> some IntentResult {
        NotificationCenter.default.post(name: .arcaBlitzidee, object: nil)
        UserDefaults(suiteName: "group.com.hansruffin.arca")?.set(true, forKey: "intentQuickCapture")
        return .result()
    }
}

@available(iOS 16.0, *)
struct ArcaShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: OpenDocumentsIntent(),
            phrases: [
                "Dokumente in \(.applicationName) öffnen",
                "\(.applicationName) Dokumente zeigen"
            ],
            shortTitle: "Dokumente",
            systemImageName: "doc.fill"
        )
        AppShortcut(
            intent: OpenVaultIntent(),
            phrases: [
                "Passwörter in \(.applicationName) öffnen",
                "\(.applicationName) Tresor öffnen"
            ],
            shortTitle: "Passwörter",
            systemImageName: "key.fill"
        )
        AppShortcut(
            intent: OpenNotesIntent(),
            phrases: [
                "Notizen in \(.applicationName) öffnen",
                "\(.applicationName) Notizen zeigen"
            ],
            shortTitle: "Notizen",
            systemImageName: "note.text"
        )
        AppShortcut(
            intent: OpenTasksIntent(),
            phrases: [
                "Tasks in \(.applicationName) öffnen",
                "\(.applicationName) Aufgaben zeigen"
            ],
            shortTitle: "Tasks",
            systemImageName: "checklist"
        )
        AppShortcut(
            intent: BlitzideeIntent(),
            phrases: [
                "Blitzidee in \(.applicationName)",
                "\(.applicationName) Idee aufnehmen",
                "Erstelle eine Blitzidee in \(.applicationName)"
            ],
            shortTitle: "Blitzidee",
            systemImageName: "bolt.fill"
        )
    }
}
