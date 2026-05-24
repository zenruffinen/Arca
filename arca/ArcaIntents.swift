import AppIntents

// MARK: - Notification names for in-process intent delivery
extension Notification.Name {
    static let arcaNavigate    = Notification.Name("com.hansruffin.arca.navigate")
    static let arcaBlitzidee   = Notification.Name("com.hansruffin.arca.blitzidee")
    static let arcaQuickNote   = Notification.Name("com.hansruffin.arca.quicknote")
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

// MARK: - Kurznotiz per Siri (ohne App zu öffnen)
struct CreateQuickNoteIntent: AppIntent {
    static var title: LocalizedStringResource = "Kurznotiz erstellen"
    static var description = IntentDescription("Erstellt sofort eine neue Notiz in Arca – die App muss nicht geöffnet werden")
    // false = Siri bestätigt kurz, App öffnet sich NICHT → schnellster Weg
    static var openAppWhenRun: Bool = false

    @Parameter(
        title: "Notiztext",
        description: "Was soll notiert werden?",
        requestValueDialog: "Was soll ich notieren?"
    )
    var text: String

    func perform() async throws -> some IntentResult & ProvidesDialog {
        let defaults = UserDefaults(suiteName: "group.com.hansruffin.arca")

        // Bestehende Queue lesen
        var pending = defaults?.array(forKey: "pendingQuickNotes") as? [[String: String]] ?? []

        // Neue Notiz anhängen
        pending.append([
            "id":   UUID().uuidString,
            "text": text,
            "date": ISO8601DateFormatter().string(from: Date())
        ])
        defaults?.set(pending, forKey: "pendingQuickNotes")

        return .result(dialog: "Kurznotiz in Arca gespeichert")
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
        AppShortcut(
            intent: CreateQuickNoteIntent(),
            phrases: [
                // Kurznotiz-Varianten
                "Kurznotiz in \(.applicationName)",
                "Neue Kurznotiz in \(.applicationName)",
                "\(.applicationName) Kurznotiz erstellen",
                // Ideen-Varianten
                "Ich habe eine Idee für \(.applicationName)",
                "\(.applicationName) ich habe eine Idee"
            ],
            shortTitle: "Kurznotiz",
            systemImageName: "note.text.badge.plus"
        )
    }
}
