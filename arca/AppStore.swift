//
//  AppStore.swift
//  Arca
//
//  Entwickler: Hans zen Ruffinen
//

import SwiftUI
import Combine
import UniformTypeIdentifiers
import CryptoKit
import WidgetKit
import AppleArchive
import System
import UniformTypeIdentifiers
import os

struct ArcaBackup: Codable {
    var vaultItems: [VaultEntry]
    var documents: [DocumentEntry]
    var notes: [NoteEntry]
    var lists: [ListEntry]
    var documentCategories: [String]
    var exportDate: Date
    /// Tatsächliche Dokument-Dateien (filename → bytes). Optional für Rückwärtskompatibilität
    /// mit alten Backups, die nur die Metadaten enthielten.
    var fileData: [String: Data]?
    var documentSubcategories: [String: [String]]?
    /// Notfallkoffer: Medikamente und Kontakte. Optional — aeltere Sicherungen
    /// kennen das Feld nicht und bleiben lesbar.
    var notfallEintraege: [NotfallEintrag]?

    enum CodingKeys: String, CodingKey {
        case vaultItems, documents, notes, lists, documentCategories, exportDate, fileData, documentSubcategories
        case notfallEintraege
    }

    init(vaultItems: [VaultEntry],
         documents: [DocumentEntry],
         notes: [NoteEntry],
         lists: [ListEntry],
         documentCategories: [String],
         exportDate: Date,
         fileData: [String: Data]? = nil,
         documentSubcategories: [String: [String]]? = nil,
         notfallEintraege: [NotfallEintrag]? = nil) {
        self.vaultItems = vaultItems
        self.documents = documents
        self.notes = notes
        self.lists = lists
        self.documentCategories = documentCategories
        self.exportDate = exportDate
        self.fileData = fileData
        self.documentSubcategories = documentSubcategories
        self.notfallEintraege = notfallEintraege
    }

    // Safe Decoder — alte Backups ohne fileData / lists bleiben kompatibel
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        vaultItems              = try c.decode([VaultEntry].self,                   forKey: .vaultItems)
        documents               = try c.decode([DocumentEntry].self,                forKey: .documents)
        notes                   = try c.decode([NoteEntry].self,                    forKey: .notes)
        lists                   = try c.decodeIfPresent([ListEntry].self,           forKey: .lists)                   ?? []
        documentCategories      = try c.decode([String].self,                       forKey: .documentCategories)
        exportDate              = try c.decode(Date.self,                           forKey: .exportDate)
        fileData                = try c.decodeIfPresent([String: Data].self,        forKey: .fileData)
        documentSubcategories   = try c.decodeIfPresent([String: [String]].self,   forKey: .documentSubcategories)
        notfallEintraege        = try c.decodeIfPresent([NotfallEintrag].self,     forKey: .notfallEintraege)
    }
}

final class AppStore: ObservableObject {
    /// Unterdrückt didSet-Speichern während load()/Migration — verhindert Überschreiben
    /// von iCloud-Daten mit leeren Defaults, bevor Platzhalter-Dateien geladen sind.
    private var isLoadingData = false
    /// Wächter gegen Stempel-Rekursion (didSet stempelt und weist neu zu)
    private var stempeltGerade = false
    /// Welche Bestände nach einer Fusion zurückgeschrieben werden müssen
    private var nachfusionSpeichern: Set<String> = []

    /// Grabsteine: IDs gelöschter Einträge samt Löschzeit — damit ein
    /// Gerät mit altem Stand Gelöschtes nicht wieder anschleppt.
    /// Synct mit; Pflege beim Laden (90 Tage Haltezeit).
    @Published var grabsteine: [UUID: Date] = [:] {
        didSet { guard !isLoadingData else { return }; saveJSON(grabsteine, key: "grabsteine") }
    }

    @Published var vaultItems: [VaultEntry] = [] {
        didSet {
            guard !isLoadingData, !stempeltGerade else { return }
            if let neu = gepflegt(vaultItems, oldValue) {
                stempeltGerade = true; vaultItems = neu; stempeltGerade = false
            }
            saveVault()
        }
    }

    // MARK: - Digitales Erbe (Nachlass-Mappe mit Totmannschalter)
    /// Die Inhalte der Nachlass-Mappe (Abos, Konten, Hinweise, Nachrichten).
    @Published var erbeEintraege: [ErbeEintrag] = [] {
        didSet { guard !isLoadingData else { return }; saveJSON(erbeEintraege, key: "erbeEintraege") }
    }
    /// Name der Vertrauensperson, die im Ernstfall zugreifen darf.
    @Published var erbeVertrauensperson: String = "" {
        didSet { guard !isLoadingData else { return }; UserDefaults.standard.set(erbeVertrauensperson, forKey: "erbeVertrauensperson") }
    }
    /// Frei wählbare Freigabe-Frage (Standard: Geburtsort).
    @Published var erbeFrage: String = "Geburtsort" {
        didSet { guard !isLoadingData else { return }; UserDefaults.standard.set(erbeFrage, forKey: "erbeFrage") }
    }
    /// Nach wie vielen Tagen ohne Lebenszeichen der Schalter auslöst.
    @Published var erbeFristTage: Int = 90 {
        didSet { guard !isLoadingData else { return }; UserDefaults.standard.set(erbeFristTage, forKey: "erbeFristTage") }
    }
    /// Totmannschalter scharf?
    @Published var erbeAktiv: Bool = false {
        didSet { guard !isLoadingData else { return }; UserDefaults.standard.set(erbeAktiv, forKey: "erbeAktiv") }
    }
    /// Letztes Lebenszeichen (erfolgreiches Entsperren durch den Besitzer).
    @Published var erbeLetzteAktivitaet: Date = Date() {
        didSet { guard !isLoadingData else { return }; UserDefaults.standard.set(erbeLetzteAktivitaet, forKey: "erbeLetzteAktivitaet") }
    }

    /// Die Freigabe-Antwort liegt nur als Hash im iCloud-Keychain — nie im Klartext.
    private static let erbeAntwortKey = "arca_erbe_antwort_hash"

    private func erbeHash(_ s: String) -> String {
        let norm = s.trimmingCharacters(in: .whitespacesAndNewlines)
            .folding(options: .diacriticInsensitive, locale: .current)
            .lowercased()
        let digest = SHA256.hash(data: Data(norm.utf8))
        return digest.compactMap { String(format: "%02x", $0) }.joined()
    }

    /// Ist eine Freigabe-Antwort hinterlegt?
    var erbeHatAntwort: Bool {
        KeychainManager.shared.load(key: Self.erbeAntwortKey, synchronizable: true) != nil
    }
    /// Antwort setzen (nur der Hash wird gespeichert).
    func erbeAntwortSetzen(_ antwort: String) {
        let t = antwort.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !t.isEmpty else { return }
        KeychainManager.shared.save(key: Self.erbeAntwortKey, value: erbeHash(t), synchronizable: true)
        objectWillChange.send()
    }
    func erbeAntwortLoeschen() {
        KeychainManager.shared.delete(key: Self.erbeAntwortKey)
        objectWillChange.send()
    }
    /// Prüft die vom Angehörigen eingegebene Antwort.
    func erbePruefeAntwort(_ antwort: String) -> Bool {
        guard let gespeichert = KeychainManager.shared.load(key: Self.erbeAntwortKey, synchronizable: true)
        else { return false }
        return erbeHash(antwort) == gespeichert
    }
    /// Lebenszeichen setzen — verschiebt den Auslöse-Zeitpunkt nach hinten.
    func erbeAktivitaetBestaetigen() {
        erbeLetzteAktivitaet = Date()
    }
    /// Tage seit dem letzten Lebenszeichen.
    var erbeTageInaktiv: Int {
        max(0, Int(Date().timeIntervalSince(erbeLetzteAktivitaet) / 86400))
    }
    /// Verbleibende Tage bis zur Freigabe (0 = ausgelöst).
    var erbeTageBisFreigabe: Int {
        max(0, erbeFristTage - erbeTageInaktiv)
    }
    /// Totmannschalter ausgelöst? Scharf + Antwort hinterlegt + Frist überschritten.
    var erbeAusgeloest: Bool {
        erbeAktiv && erbeHatAntwort && erbeTageInaktiv >= erbeFristTage
    }
    func addErbeEintrag(_ e: ErbeEintrag) { erbeEintraege.append(e) }
    func loescheErbeEintrag(_ id: UUID) { erbeEintraege.removeAll { $0.id == id } }

    // MARK: - Demo/Tutorial (nur beim allerersten, leeren Start)

    private static let demoFlagKey = "arcaDemoSeeded_v1"
    static let willkommenDatei = "arca_willkommen.jpg"
    private static let demoKategorien = ["Reise", "Papiere", "Finanzen", "Gesundheit"]

    /// Schreibt das Willkommens-Bild in den Dateispeicher und legt das Dokument an.
    private func erzeugeWillkommensDokument() -> DocumentEntry? {
        guard let bild = UIImage(named: "ArcaWillkommen"),
              let jpg = bild.jpegData(compressionQuality: 0.9) else { return nil }
        try? jpg.write(to: documentURL(for: Self.willkommenDatei))
        var doc = DocumentEntry(title: "Willkommen bei Arca", type: .image,
                                filename: Self.willkommenDatei, dateAdded: Date(), category: "Unsortiert")
        doc.isFavorite = true
        doc.favoritePinned = true
        return doc
    }

    /// Nur beim allerersten, wirklich leeren Start: Fantasie-Demodaten erzeugen.
    /// Auf bestehenden/synchronisierenden Installationen passiert nichts.
    func seedeDemodatenWennErststart() {
        guard !UserDefaults.standard.bool(forKey: Self.demoFlagKey) else { return }
        guard !hasAnyExistingDataStore(), !hasPendingCloudDataDownloads() else { return }
        UserDefaults.standard.set(true, forKey: Self.demoFlagKey)

        for k in Self.demoKategorien where !documentCategories.contains(k) {
            documentCategories.append(k)
        }

        var docs: [DocumentEntry] = []
        if let w = erzeugeWillkommensDokument() { docs.append(w) }
        func demoDoc(_ t: String, _ cat: String) -> DocumentEntry {
            DocumentEntry(title: t, type: .pdf, filename: "", dateAdded: Date(), category: cat)
        }
        docs.append(contentsOf: [
            demoDoc("Reisepass", "Papiere"),
            demoDoc("Mietvertrag Musterstraße 3", "Papiere"),
            demoDoc("Stromrechnung", "Finanzen"),
            demoDoc("Impfpass", "Gesundheit"),
            demoDoc("Hotelbuchung Rom", "Reise"),
        ])
        documents.append(contentsOf: docs)

        notes.insert(NoteEntry(title: "Geschenkidee für Anna 🎁",
                               text: "Aquarellkasten und der neue Roman."), at: 0)
        notes.insert(NoteEntry(title: "Buchtipp",
                               text: "„Der Klang der Berge“ — unbedingt lesen."), at: 0)

        lists.insert(ListEntry(title: "Einkauf",
            items: [ChecklistItem(text: "Milch"), ChecklistItem(text: "Brot"),
                    ChecklistItem(text: "Kaffee"), ChecklistItem(text: "Äpfel")],
            colorTag: 3), at: 0)

        vaultItems.append(VaultEntry(title: "WLAN Zuhause", username: "FritzBox",
                                     password: "sonne-mond-42", colorTag: 2))
        vaultItems.append(VaultEntry(title: "Meine Visa", username: "", password: "",
                                     colorTag: 2, art: .karte,
                                     kartennummer: "4000 1234 5678 9010",
                                     karteninhaber: "Hans Muster", ablauf: "08/29"))

        demoModusAktiv = true
    }

    /// „Loslegen": alle Demodaten löschen — nur das Willkommens-Dokument bleibt.
    /// Läuft nur im Demo-Modus (auf echten Installationen nie aktiv).
    func raeumeDemodatenAuf() {
        guard demoModusAktiv else { return }
        documents.removeAll { $0.filename != Self.willkommenDatei }
        notes.removeAll { _ in true }
        lists.removeAll { _ in true }
        for v in vaultItems { KeychainManager.shared.delete(key: "vault_\(v.id)") }
        vaultItems.removeAll()
        for k in Self.demoKategorien where documents.first(where: { $0.category == k }) == nil {
            documentCategories.removeAll { $0 == k }
        }
        demoModusAktiv = false
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }
    @Published var documents: [DocumentEntry] = [] {
        didSet {
            guard !isLoadingData, !stempeltGerade else { return }
            if let neu = gepflegt(documents, oldValue) {
                stempeltGerade = true; documents = neu; stempeltGerade = false
            }
            saveDocuments()
        }
    }
    @Published var notes: [NoteEntry] = [] {
        didSet {
            guard !isLoadingData, !stempeltGerade else { return }
            if let neu = gepflegt(notes, oldValue) {
                stempeltGerade = true; notes = neu; stempeltGerade = false
            }
            saveNotes()
        }
    }
    @Published var documentCategories: [String] = [] {
        didSet { guard !isLoadingData else { return }; saveDocumentCategories() }
    }
    @Published var categoryColors: [String: Int] = [:] {
        didSet { guard !isLoadingData else { return }; saveCategoryColors() }
    }
    /// Vom Nutzer gewähltes Symbol pro Gruppe (überstimmt die Auto-Erkennung).
    @Published var categoryIcons: [String: String] = [:] {
        didSet { guard !isLoadingData else { return }; saveCategoryIcons() }
    }
    /// Symbol einer Gruppe: Nutzerwahl vor Auto-Erkennung nach Stichwort.
    func iconFor(_ category: String) -> String {
        categoryIcons[category] ?? categoryIcon(category)
    }
    /// Der Schreibtisch (iPad/Mac): Karten links/rechts vom Space
    @Published var deskItems: [DeskItem] = [] {
        didSet {
            guard !isLoadingData, !stempeltGerade else { return }
            if let neu = gepflegt(deskItems, oldValue) {
                stempeltGerade = true; deskItems = neu; stempeltGerade = false
            }
            saveJSON(deskItems, key: "deskItems")
        }
    }
    /// Titel und Farben der Schreibtisch-Flächen — überall gleich
    @Published var deskStil = DeskFlaechenStil() {
        didSet { guard !isLoadingData else { return }; saveJSON(deskStil, key: "deskStil") }
    }
    /// Positionen der Ideen auf der Pinnwand (id → [x,y]) — synct mit
    @Published var pinnwandLayout: [String: [Double]] = [:] {
        didSet { guard !isLoadingData else { return }; saveJSON(pinnwandLayout, key: "pinnwandLayout") }
    }
    /// Die Wände: „Meine Wand", die Ideen, Themen-Boards, Pult und Tresor.
    @Published var pinnBoards: [PinnBoard] = [] {
        didSet {
            guard !isLoadingData, !stempeltGerade else { return }
            if let neu = gepflegt(pinnBoards, oldValue) {
                stempeltGerade = true; pinnBoards = neu; stempeltGerade = false
            }
            saveJSON(pinnBoards, key: "pinnBoards")
        }
    }
    /// Was an den Wänden hängt. Löst Favoriten, Schreibtisch und
    /// Ideen-Layout ab — angepinnt IST Favorit.
    @Published var anschlaege: [Anschlag] = [] {
        didSet {
            guard !isLoadingData, !stempeltGerade else { return }
            if let neu = gepflegt(anschlaege, oldValue) {
                stempeltGerade = true; anschlaege = neu; stempeltGerade = false
            }
            saveJSON(anschlaege, key: "anschlaege")
        }
    }
    /// Notfallkoffer: Medikamente und Notfallkontakte (siehe NotfallEintrag).
    @Published var notfallEintraege: [NotfallEintrag] = [] {
        didSet {
            guard !isLoadingData, !stempeltGerade else { return }
            if let neu = gepflegt(notfallEintraege, oldValue) {
                stempeltGerade = true; notfallEintraege = neu; stempeltGerade = false
            }
            saveNotfall()
        }
    }

    @Published var lists: [ListEntry] = [] {
        didSet {
            guard !isLoadingData, !stempeltGerade else { return }
            if let neu = gepflegt(lists, oldValue) {
                stempeltGerade = true; lists = neu; stempeltGerade = false
            }
            saveLists()
        }
    }
    @Published var documentSubcategories: [String: [String]] = [:] {
        didSet { guard !isLoadingData else { return }; saveDocumentSubcategories() }
    }
    /// Ordner, die auf dem Startbildschirm unter „Ordner“ erscheinen (Reihenfolge = Anzeige).
    @Published var homeFolderQuickView: [String] = [] {
        didSet { guard !isLoadingData else { return }; saveHomeFolderQuickView() }
    }
    /// Wenn eine Datei von außen (z. B. Mail) geöffnet wird, landet die URL hier.
    @Published var pendingSharedURL: URL? = nil
    @Published var pendingBackupURL: URL? = nil
    @Published var pendingScrollCategory: String? = nil
    /// Nur diese eine Kategorie in der Dokumente-Ansicht zeigen (Reingehen)
    @Published var fokusKategorie: String? = nil
    /// Nur die angepinnten Dokumente zeigen — der eigene „Ordner", den die
    /// Kachel „Angepinnt" aufmacht.
    ///
    /// Eine eigene Fahne statt `fokusKategorie = "Angepinnt"`: Angepinnt IST
    /// keine Kategorie, es liegt quer über allen. Als Kategorie getarnt
    /// fände die Gruppierung in der Dokumentliste kein einziges Dokument.
    @Published var nurAngepinnteDokumente: Bool = false
    @Published var pendingSection: ArcaSection? = nil
    @Published var pendingQuickCapture: Bool = false
    /// Wurde etwas von einer Wand aus angelegt? Dann hängt es hinterher
    /// genau dort — und auf dem Platz, an dem der Finger lag. Nicht
    /// gespeichert, gilt nur für den einen Vorgang.
    var wandZiel: (board: UUID, platz: [Double]?)? = nil
    /// Blitzidee per „halten": Diktat startet sofort, ohne extra Tipp aufs Mikro
    @Published var quickCaptureAutoRecord: Bool = false
    /// Erfassen vom Start: Zielsektion öffnet direkt ihr „Neu"-Blatt
    @Published var pendingNewEntry: ArcaSection? = nil
    /// Space-Tab erneut angetippt → Start springt nach oben (Zähler als Signal)
    @Published var homeSprungNachOben: Int = 0
    /// Aktiver Filter-Chip auf dem Start — der Plus-Knopf richtet sich danach
    @Published var homeStreamFilter: HomeStreamFilter = .dokumente
    /// Zuletzt geöffnete Einträge (id → Zeitpunkt) — lokal, gerätespezifisch
    @Published var zuletztGeoeffnet: [UUID: Date] = [:]

    /// Reihenfolge des Stroms auf dem Start. Gilt für alle vier Bereiche:
    /// eine Liste, die je nach Chip anders sortiert, muss man bei jedem
    /// Wechsel neu lesen.
    @Published var stromSortierung: StromSortierung = .neuesteZuerst {
        didSet { UserDefaults.standard.set(stromSortierung.rawValue, forKey: "arcaStromSortierung") }
    }

    func ladeStromSortierung() {
        if let roh = UserDefaults.standard.string(forKey: "arcaStromSortierung"),
           let s = StromSortierung(rawValue: roh) {
            stromSortierung = s
        }
    }

    /// Merkt einen Öffnen-Zeitpunkt (behält die letzten 24, speichert lokal).
    func merkeGeoeffnet(_ id: UUID) {
        zuletztGeoeffnet[id] = Date()
        if zuletztGeoeffnet.count > 24 {
            for (k, _) in zuletztGeoeffnet.sorted(by: { $0.value < $1.value }).prefix(zuletztGeoeffnet.count - 24) {
                zuletztGeoeffnet.removeValue(forKey: k)
            }
        }
        let roh = zuletztGeoeffnet.reduce(into: [String: Double]()) { $0[$1.key.uuidString] = $1.value.timeIntervalSince1970 }
        UserDefaults.standard.set(roh, forKey: "arcaZuletztGeoeffnet")
    }

    func ladeZuletztGeoeffnet() {
        guard let roh = UserDefaults.standard.dictionary(forKey: "arcaZuletztGeoeffnet") as? [String: Double] else { return }
        zuletztGeoeffnet = roh.reduce(into: [UUID: Date]()) {
            if let id = UUID(uuidString: $1.key) { $0[id] = Date(timeIntervalSince1970: $1.value) }
        }
    }

    /// Die zuletzt geöffneten Einträge als Anzeige-Objekte (alle Typen, jüngste zuerst).
    var zuletztGeoeffneteItems: [FavoriteItem] {
        func relativ(_ d: Date) -> String {
            let cal = Calendar.current
            if cal.isDateInToday(d) { return "Heute" }
            if cal.isDateInYesterday(d) { return "Gestern" }
            let tage = cal.dateComponents([.day], from: d, to: Date()).day ?? 0
            return tage <= 0 ? "Heute" : "vor \(tage) T"
        }
        return zuletztGeoeffnet.sorted { $0.value > $1.value }.compactMap { (id, wann) in
            if let d = documents.first(where: { $0.id == id }) {
                return FavoriteItem(id: d.id, kind: .document, title: d.title,
                                    subtitle: "\(d.type.rawValue) · \(relativ(wann))", pinned: false, date: wann)
            }
            if let n = notes.first(where: { $0.id == id }) {
                return FavoriteItem(id: n.id, kind: .note, title: n.title.isEmpty ? "Notiz" : n.title,
                                    subtitle: "\(n.isQuickIdea ? "Blitzidee" : "Idee") · \(relativ(wann))", pinned: false, date: wann)
            }
            if let l = lists.first(where: { $0.id == id }) {
                return FavoriteItem(id: l.id, kind: .list, title: l.title,
                                    subtitle: "Aufgabe · \(relativ(wann))", pinned: false, date: wann)
            }
            // Tresor-Einträge erscheinen hier NICHT. Der Start ist die
            // Seite, die jeder Schulterblick mitliest — dieselbe Regel wie
            // bei den Wänden: ein Tresor zeigt keine Vorschau.
            return nil
        }
    }
    /// Mehr-Menü in der Leiste: „export"/„import" springt die Aktion direkt an
    @Published var pendingSettingsAktion: String? = nil
    /// Notfall-Bereich anzeigen (aus dem Mehr-Menü der Leiste)
    @Published var zeigeNotfall: Bool = false
    /// Notfall-Widget bei gesperrter App: der Sperrbildschirm oeffnet die
    /// oeffentliche Fassung des Koffers (nie die entsperrte).
    @Published var zeigeNotfallGesperrt: Bool = false
    /// Aufräumen/Sortieren-Fenster anzeigen (aus dem Unsortiert-Korb der Leiste)
    @Published var zeigeAufraeumen: Bool = false
    /// Persönliches Profilbild (lokal, klein). Macht den Kopf persönlicher.
    @Published var profilBildData: Data? = nil {
        didSet {
            guard !isLoadingData else { return }
            if let d = profilBildData { UserDefaults.standard.set(d, forKey: "profilBild") }
            else { UserDefaults.standard.removeObject(forKey: "profilBild") }
        }
    }

    /// Demo-/Tutorial-Modus aktiv? (lokal, synct nicht) — zeigt den Aufräum-Hinweis.
    @Published var demoModusAktiv: Bool = false {
        didSet { guard !isLoadingData else { return }; UserDefaults.standard.set(demoModusAktiv, forKey: "arcaDemoModus") }
    }
    /// Die Ideen-Pinnwand rechts eingeblendet?
    @Published var zeigeIdeenPinnwand: Bool = false
    /// Pinnwand formatfüllend (Vollbild) statt rechts angedockt?
    @Published var ideenPinnwandGross: Bool = false
    /// ⌘F: Suche auf dem Start fokussieren (Zähler als Signal)
    @Published var sucheFokusSignal: Int = 0
    /// Reihenfolge der Bereichs-Blasen auf dem Start (und der Seitenleiste) —
    /// frei sortierbar, neue Bereiche hängen sich automatisch hinten an.
    var bereichsOrdnung: [HomeStreamFilter] {
        get {
            let roh = UserDefaults.standard.string(forKey: "arcaBereichsOrdnung") ?? ""
            var folge = roh.split(separator: ",")
                .compactMap { HomeStreamFilter(rawValue: String($0)) }
            for f in HomeStreamFilter.allCases where !folge.contains(f) { folge.append(f) }
            return folge
        }
        set {
            UserDefaults.standard.set(
                newValue.map(\.rawValue).joined(separator: ","),
                forKey: "arcaBereichsOrdnung")
            objectWillChange.send()
        }
    }

    /// Datum der letzten erfolgreichen Sicherung (für die Erinnerung)
    var letztesBackup: Date? {
        get { UserDefaults.standard.object(forKey: "arcaLetztesBackup") as? Date }
        set {
            UserDefaults.standard.set(newValue, forKey: "arcaLetztesBackup")
            objectWillChange.send()
        }
    }
    /// Blitzidee → Passwort: Titel fürs vorbefüllte Tresor-Blatt …
    @Published var vaultVorbefuellung: String? = nil
    /// … und die Notiz, die nach erfolgreichem Speichern einsortiert (gelöscht) wird
    @Published var notizNachTresorUmwandlung: UUID? = nil

    /// true solange iCloud-Platzhalter noch heruntergeladen werden (UI-Hinweis).
    @Published private(set) var isCloudSyncPending = false

    enum ICloudStatus: String {
        case unavailable = "Nicht verfügbar"
        case connected = "iCloud: verbunden"
        case downloading = "Warte auf Download"
        case synced = "Synchronisiert"
    }

    @Published private(set) var iCloudStatus: ICloudStatus = .unavailable

    static let recoveryHintKey = "arcaRecoveryHintShown_v241"
    private static let cloudSyncTimeout: TimeInterval = 30
    private var cloudSyncPollTimer: Timer?
    private var cloudSyncStartedAt: Date?

    /// Wohin Neues zuerst fällt. Normalerweise „Unsortiert" — es sei denn,
    /// eine eigene Eingangs-Gruppe ist eingestellt und existiert auch noch.
    var eingangsKategorie: String {
        documentCategories.contains(importCategoryName) ? importCategoryName : "Unsortiert"
    }

    var importCategoryName: String {
        get { UserDefaults.standard.string(forKey: "importCategoryName") ?? "Import" }
        set { UserDefaults.standard.set(newValue, forKey: "importCategoryName") }
    }

    /// Stellt sicher, dass die Import-Gruppe existiert, und gibt ihren Namen zurück.
    @discardableResult
    func ensureImportCategoryExists() -> String {
        let name = importCategoryName
        if !documentCategories.contains(name) {
            documentCategories.insert(name, at: 0)
        }
        return name
    }

    static let defaultCategories = ["Reise", "Papiere", "Rechnungen", "Verträge", "Gesundheit", "Unsortiert"]

    // MARK: - iCloud Storage

    private let cloudContainerID = "iCloud.com.hansruffin.Arca"

    /// Liefert die iCloud-Container-URL oder nil wenn iCloud nicht verfügbar.
    /// iOS cached den Wert intern, wiederholte Aufrufe sind schnell.
    private var cloudContainer: URL? {
        FileManager.default.url(forUbiquityContainerIdentifier: cloudContainerID)
    }

    /// Verzeichnis für JSON-Datendateien (iCloud oder lokaler Fallback).
    private var dataDirectory: URL {
        if let c = cloudContainer {
            let dir = c.appendingPathComponent("Documents/arcadata")
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            return dir
        }
        let dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("arcadata")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    /// Verzeichnis für Dokument-Binärdateien (PDFs, Bilder, …).
    var filesDirectory: URL {
        if let c = cloudContainer {
            let dir = c.appendingPathComponent("Documents/files")
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            return dir
        }
        return FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }

    private func dataURL(_ key: String) -> URL {
        dataDirectory.appendingPathComponent("\(key).json")
    }

    /// iCloud-Platzhalter für eine Datendatei (z. B. `.notes.json.icloud`).
    private func cloudPlaceholderURL(for fileURL: URL) -> URL {
        fileURL.deletingLastPathComponent()
            .appendingPathComponent(".\(fileURL.lastPathComponent).icloud")
    }

    private func hasCloudPlaceholder(at fileURL: URL) -> Bool {
        FileManager.default.fileExists(atPath: cloudPlaceholderURL(for: fileURL).path)
    }

    var isICloudAvailable: Bool { cloudContainer != nil }

    /// true wenn iCloud-Platzhalter noch nicht lokal verfügbar sind (Download ausstehend).
    private func hasPendingCloudDataDownloads() -> Bool {
        guard cloudContainer != nil else { return false }
        for dir in [dataDirectory, filesDirectory] {
            guard let files = try? FileManager.default.contentsOfDirectory(
                at: dir, includingPropertiesForKeys: nil) else { continue }
            if files.contains(where: { $0.lastPathComponent.hasSuffix(".icloud") }) { return true }
        }
        return false
    }

    /// Leerer App-Zustand, aber iCloud-Daten existieren noch als Platzhalter.
    var isLikelyEmptyWithPendingCloud: Bool {
        guard vaultItems.isEmpty, documents.isEmpty, notes.isEmpty, lists.isEmpty else { return false }
        return hasPendingCloudDataDownloads() || hasAnyExistingDataStore()
    }

    var shouldShowRecoveryHint: Bool {
        !UserDefaults.standard.bool(forKey: Self.recoveryHintKey)
    }

    func markRecoveryHintShown() {
        UserDefaults.standard.set(true, forKey: Self.recoveryHintKey)
    }

    func updateCloudSyncState() {
        guard isICloudAvailable else {
            iCloudStatus = .unavailable
            isCloudSyncPending = false
            return
        }
        if hasPendingCloudDataDownloads() {
            iCloudStatus = .downloading
            isCloudSyncPending = true
        } else if hasAnyExistingDataStore() {
            iCloudStatus = .synced
            isCloudSyncPending = false
        } else {
            iCloudStatus = .connected
            isCloudSyncPending = false
        }
    }

    private func beginCloudSyncMonitoringIfNeeded() {
        updateCloudSyncState()
        guard isCloudSyncPending else {
            stopCloudSyncMonitoring()
            return
        }
        cloudSyncStartedAt = cloudSyncStartedAt ?? Date()
        guard cloudSyncPollTimer == nil else { return }
        cloudSyncPollTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            self?.pollCloudSyncProgress()
        }
    }

    private func stopCloudSyncMonitoring() {
        cloudSyncPollTimer?.invalidate()
        cloudSyncPollTimer = nil
        cloudSyncStartedAt = nil
    }

    private func pollCloudSyncProgress() {
        updateCloudSyncState()
        if !isCloudSyncPending {
            stopCloudSyncMonitoring()
            // Frisch fertig heruntergeladene Cloud-Daten sofort übernehmen —
            // niemand soll auf einen leeren Start schauen, während die
            // Wahrheit schon auf der Platte liegt.
            isLoadingData = true
            load()
            isLoadingData = false
            speichereNachfusion()
            return
        }
        downloadAllCloudFiles()
        if let started = cloudSyncStartedAt,
           Date().timeIntervalSince(started) >= Self.cloudSyncTimeout {
            isCloudSyncPending = false
            stopCloudSyncMonitoring()
        }
    }

    /// true wenn bereits Arca-Daten (lokal oder als iCloud-Platzhalter) existieren.
    private func hasAnyExistingDataStore() -> Bool {
        let keys = [
            "vaultItems", "documents", "notes", "lists", "notfallEintraege",
            "documentCategories", "categoryColors", "categoryIcons", "documentSubcategories", "homeFolderQuickView"
        ]
        for key in keys {
            let url = dataURL(key)
            if FileManager.default.fileExists(atPath: url.path) { return true }
            if hasCloudPlaceholder(at: url) { return true }
        }
        return false
    }

    /// Stößt Downloads an und wartet kurz, damit load() nach App-Update nicht leer startet.
    private func waitForPendingCloudDownloads(timeout: TimeInterval = 3.0) {
        guard cloudContainer != nil else { return }
        var pending: [URL] = []
        guard let files = try? FileManager.default.contentsOfDirectory(
            at: dataDirectory, includingPropertiesForKeys: nil) else { return }
        for f in files where f.lastPathComponent.hasSuffix(".icloud") {
            var name = f.lastPathComponent
            name.removeFirst()
            name.removeLast(".icloud".count)
            let target = dataDirectory.appendingPathComponent(name)
            pending.append(target)
            try? FileManager.default.startDownloadingUbiquitousItem(at: target)
        }
        guard !pending.isEmpty else { return }
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            let stillPending = pending.contains { url in
                guard FileManager.default.fileExists(atPath: url.path) else { return true }
                guard let status = try? url.resourceValues(forKeys: [.ubiquitousItemDownloadingStatusKey])
                    .ubiquitousItemDownloadingStatus else { return true }
                return status != .current
            }
            if !stillPending { break }
            RunLoop.current.run(until: Date().addingTimeInterval(0.05))
        }
    }

    private func startObservingCloudDownloads() {
        NotificationCenter.default.addObserver(
            forName: Notification.Name("NSUbiquitousItemDidDownload"),
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.reloadFromCloud()
            self?.updateCloudSyncState()
            self?.beginCloudSyncMonitoringIfNeeded()
        }
    }

    // MARK: - iCloud Download (Platzhalter-Dateien)

    /// Prüft ob eine Dokument-Datei lokal vorliegt. Falls sie nur als iCloud-
    /// Platzhalter existiert, wird der Download angestossen.
    /// - Returns: true wenn die Datei sofort verfügbar ist.
    @discardableResult
    func ensureFileDownloaded(_ filename: String) -> Bool {
        let url = filesDirectory.appendingPathComponent(filename)
        if FileManager.default.fileExists(atPath: url.path) { return true }
        let placeholder = filesDirectory.appendingPathComponent(".\(filename).icloud")
        if FileManager.default.fileExists(atPath: placeholder.path) {
            try? FileManager.default.startDownloadingUbiquitousItem(at: url)
        }
        return false
    }

    /// Stößt den Download aller noch nicht geladenen iCloud-Dateien an,
    /// damit Arca komplett offline nutzbar bleibt (z. B. nach Installation auf dem iPad).
    func downloadAllCloudFiles() {
        guard cloudContainer != nil else { return }
        let dirs = [filesDirectory, dataDirectory]
        DispatchQueue.global(qos: .utility).async {
            for dir in dirs {
                guard let files = try? FileManager.default.contentsOfDirectory(
                    at: dir, includingPropertiesForKeys: nil) else { continue }
                for f in files where f.lastPathComponent.hasSuffix(".icloud") {
                    // ".Name.ext.icloud" → "Name.ext"
                    var name = f.lastPathComponent
                    name.removeFirst()
                    name.removeLast(".icloud".count)
                    let target = dir.appendingPathComponent(name)
                    try? FileManager.default.startDownloadingUbiquitousItem(at: target)
                }
            }
        }
    }

    // MARK: - Generische JSON I/O mit NSFileCoordinator

    /// Welche Datenschlüssel diese Sitzung erfolgreich GELESEN (oder selbst
    /// erzeugt) hat. Nur für solche Schlüssel darf gespeichert werden, wenn
    /// bereits eine Datei existiert — verhindert, dass ein frisch
    /// angeschlossenes Gerät mit leerem Zustand echte Daten überschreibt
    /// (Ursache des Datenverlusts vom 08.08.2026).
    private var geladeneSchluessel: Set<String> = []

    // MARK: - Sync-Härtung: Stempeln und Zusammenführen

    /// Nach jeder Änderung: geänderte Einträge frisch stempeln und für
    /// Entferntes Grabsteine setzen. Gibt das gestempelte Feld zurück,
    /// wenn etwas zu stempeln war — sonst nil.
    private func gepflegt<T: ZeitGestempelt & Identifiable & Equatable>(
        _ neu: [T], _ alt: [T]) -> [T]? where T.ID == UUID {
        var ergebnis = neu
        var geaendert = false
        let alteMap = Dictionary(alt.map { ($0.id, $0) }, uniquingKeysWith: { a, _ in a })
        let neueIDs = Set(neu.map(\.id))

        for i in ergebnis.indices {
            if let alter = alteMap[ergebnis[i].id],
               ergebnis[i] != alter,
               ergebnis[i].geaendertAm == alter.geaendertAm {
                ergebnis[i].geaendertAm = Date()
                geaendert = true
            }
        }
        for alter in alt where !neueIDs.contains(alter.id) {
            grabsteine[alter.id] = Date()
        }
        return geaendert ? ergebnis : nil
    }

    // MARK: - Selbstheilung gegen iCloud-Ordner-Gabelungen
    //
    // iCloud kopiert bei einem Ordner-Konflikt den GANZEN Ordner zu
    // „arcadata 2" / „files 3" — die App öffnet aber stur „arcadata".
    // Verschiedene Geräte landen so in verschiedenen Kopien (der Grund
    // für die leeren Geräte am Morgen). Hier suchen wir solche
    // Geschwister-Kopien, führen ihren Inhalt in den kanonischen Ordner
    // zusammen (Fusion wie beim Sync) und räumen die Kopie weg.

    /// Fand die letzte Prüfung eine Gabelung? Dann muss neu geladen werden.
    private var gabelungGeheilt = false

    func heileOrdnerGabelungen() {
        guard let c = cloudContainer else { return }
        let docs = c.appendingPathComponent("Documents")
        guard let inhalt = try? FileManager.default.contentsOfDirectory(
            at: docs, includingPropertiesForKeys: nil) else { return }

        func gabelungenVon(_ basis: String) -> [URL] {
            inhalt.filter { url in
                let n = url.lastPathComponent
                return n != basis
                    && n.range(of: "^\(basis) \\d+$", options: .regularExpression) != nil
            }
        }

        for fork in gabelungenVon("arcadata") {
            schmelzeDatenGabelung(fork)
            entferneOrdnerKoordiniert(fork)
            gabelungGeheilt = true
        }
        for fork in gabelungenVon("files") {
            let dateien = (try? FileManager.default.contentsOfDirectory(
                at: fork, includingPropertiesForKeys: nil)) ?? []
            for datei in dateien where !datei.lastPathComponent.hasPrefix(".") {
                let ziel = filesDirectory.appendingPathComponent(datei.lastPathComponent)
                if !FileManager.default.fileExists(atPath: ziel.path) {
                    try? FileManager.default.copyItem(at: datei, to: ziel)
                }
            }
            entferneOrdnerKoordiniert(fork)
            gabelungGeheilt = true
        }
    }

    private func schmelzeDatenGabelung(_ fork: URL) {
        func lies<T: Decodable>(_ t: T.Type, _ key: String, in dir: URL) -> T? {
            let u = dir.appendingPathComponent("\(key).json")
            let ph = dir.appendingPathComponent(".\(key).json.icloud")
            if FileManager.default.fileExists(atPath: ph.path) {
                try? FileManager.default.startDownloadingUbiquitousItem(at: u)
            }
            guard let d = try? Data(contentsOf: u), !d.isEmpty else { return nil }
            return try? JSONDecoder().decode(t, from: d)
        }
        func schreib<T: Encodable>(_ v: T, _ key: String) {
            let u = dataURL(key)
            guard let d = try? JSONEncoder().encode(v) else { return }
            let co = NSFileCoordinator(filePresenter: nil); var e: NSError?
            co.coordinate(writingItemAt: u, options: .forReplacing, error: &e) {
                try? d.write(to: $0, options: .atomic)
            }
        }

        // Eintrags-Bestände: jüngerer gewinnt (dieselbe Fusion wie beim Sync)
        if let f = lies([VaultEntry].self, "vaultItems", in: fork) {
            schreib(fusioniere(lies([VaultEntry].self, "vaultItems", in: dataDirectory) ?? [], f), "vaultItems")
        }
        if let f = lies([DocumentEntry].self, "documents", in: fork) {
            schreib(fusioniere(lies([DocumentEntry].self, "documents", in: dataDirectory) ?? [], f), "documents")
        }
        if let f = lies([NoteEntry].self, "notes", in: fork) {
            schreib(fusioniere(lies([NoteEntry].self, "notes", in: dataDirectory) ?? [], f), "notes")
        }
        if let f = lies([ListEntry].self, "lists", in: fork) {
            schreib(fusioniere(lies([ListEntry].self, "lists", in: dataDirectory) ?? [], f), "lists")
        }
        if let f = lies([NotfallEintrag].self, "notfallEintraege", in: fork) {
            schreib(fusioniere(lies([NotfallEintrag].self, "notfallEintraege", in: dataDirectory) ?? [], f),
                    "notfallEintraege")
        }
        if let f = lies([DeskItem].self, "deskItems", in: fork) {
            schreib(fusioniere(lies([DeskItem].self, "deskItems", in: dataDirectory) ?? [], f), "deskItems")
        }
        if let f = lies([PinnBoard].self, "pinnBoards", in: fork) {
            schreib(fusioniere(lies([PinnBoard].self, "pinnBoards", in: dataDirectory) ?? [], f), "pinnBoards")
        }
        if let f = lies([Anschlag].self, "anschlaege", in: fork) {
            schreib(fusioniere(lies([Anschlag].self, "anschlaege", in: dataDirectory) ?? [], f), "anschlaege")
        }
        // Grabsteine vereinen (spätere Löschzeit gewinnt)
        if let f = lies([UUID: Date].self, "grabsteine", in: fork) {
            let k = lies([UUID: Date].self, "grabsteine", in: dataDirectory) ?? [:]
            schreib(k.merging(f) { max($0, $1) }, "grabsteine")
        }
        // Kategorien / Schnellansicht: Reihenfolge + fehlende ergänzen
        for key in ["documentCategories", "homeFolderQuickView"] {
            if let f = lies([String].self, key, in: fork) {
                var k = lies([String].self, key, in: dataDirectory) ?? []
                for x in f where !k.contains(x) { k.append(x) }
                schreib(k, key)
            }
        }
        // Farben / Untergruppen: Schlüssel vereinen (Gabelung gewinnt Konflikt)
        if let f = lies([String: Int].self, "categoryColors", in: fork) {
            let k = lies([String: Int].self, "categoryColors", in: dataDirectory) ?? [:]
            schreib(k.merging(f) { _, neu in neu }, "categoryColors")
        }
        if let f = lies([String: String].self, "categoryIcons", in: fork) {
            let k = lies([String: String].self, "categoryIcons", in: dataDirectory) ?? [:]
            schreib(k.merging(f) { _, neu in neu }, "categoryIcons")
        }
        if let f = lies([String: [String]].self, "documentSubcategories", in: fork) {
            let k = lies([String: [String]].self, "documentSubcategories", in: dataDirectory) ?? [:]
            schreib(k.merging(f) { _, neu in neu }, "documentSubcategories")
        }
        // Pult-Stil nur übernehmen, wenn kanonisch (noch) keiner da ist
        if lies(DeskFlaechenStil.self, "deskStil", in: dataDirectory) == nil,
           let f = lies(DeskFlaechenStil.self, "deskStil", in: fork) {
            schreib(f, "deskStil")
        }
    }

    private func entferneOrdnerKoordiniert(_ url: URL) {
        let co = NSFileCoordinator(filePresenter: nil); var e: NSError?
        co.coordinate(writingItemAt: url, options: .forDeleting, error: &e) { u in
            try? FileManager.default.removeItem(at: u)
        }
    }

    /// Zusammenführen statt Ersetzen: Eintrag für Eintrag, der jüngere
    /// gewinnt; Grabsteine halten Gelöschtes fern; lokale Neue überleben.
    /// Eine leere Wolke kann damit nie wieder ein volles Gerät leeren.
    private func fusioniere<T: ZeitGestempelt & Identifiable & Equatable>(
        _ lokal: [T], _ wolke: [T]) -> [T] where T.ID == UUID {
        let lokalMap = Dictionary(lokal.map { ($0.id, $0) }, uniquingKeysWith: { a, _ in a })
        var gesehen = Set<UUID>()
        var ergebnis: [T] = []
        for w in wolke {
            gesehen.insert(w.id)
            if let grab = grabsteine[w.id], grab > w.geaendertAm { continue }
            if let l = lokalMap[w.id], l.geaendertAm > w.geaendertAm {
                ergebnis.append(l)
            } else {
                ergebnis.append(w)
            }
        }
        var nurLokal: [T] = []
        for l in lokal where !gesehen.contains(l.id) {
            if let grab = grabsteine[l.id], grab > l.geaendertAm { continue }
            nurLokal.append(l)
        }
        return nurLokal + ergebnis
    }

    /// iCloud-Konflikte auflösen: Wenn zwei Geräte dieselbe Datei
    /// gleichzeitig geändert haben (Funkloch!), legt iCloud Konflikt-
    /// Fassungen an — und stoppt Uploads, bis sie aufgelöst sind.
    /// Wir lesen ALLE Fassungen, fusionieren sie (der jüngere Eintrag
    /// gewinnt) und erklären den Konflikt für erledigt.
    private func loeseKonflikte<T: ZeitGestempelt & Identifiable & Equatable & Codable>(
        _ aktuell: [T], key: String) -> [T] where T.ID == UUID {
        let url = dataURL(key)
        guard let konflikte = NSFileVersion.unresolvedConflictVersionsOfItem(at: url),
              !konflikte.isEmpty else { return aktuell }
        var ergebnis = aktuell
        for fassung in konflikte {
            if let data = try? Data(contentsOf: fassung.url),
               let dekodiert = try? JSONDecoder().decode([T].self, from: data) {
                ergebnis = fusioniere(ergebnis, dekodiert)
            }
            fassung.isResolved = true
        }
        try? NSFileVersion.removeOtherVersionsOfItem(at: url)
        nachfusionSpeichern.insert(key)
        return ergebnis
    }

    /// Fusion + Merker fürs Rückschreiben, wenn die Wolke etwas lernen muss.
    private func fusioniereUndMerke<T: ZeitGestempelt & Identifiable & Equatable>(
        _ lokal: [T], _ wolke: [T], schluessel: String) -> [T] where T.ID == UUID {
        let ergebnis = fusioniere(lokal, wolke)
        if ergebnis != wolke { nachfusionSpeichern.insert(schluessel) }
        return ergebnis
    }

    /// Kategorien (einfache Namen): Wolken-Reihenfolge + lokale Ergänzungen.
    private func vereinigeKategorien(_ lokal: [String], _ wolke: [String]) -> [String] {
        var ergebnis = wolke
        for k in lokal where !ergebnis.contains(k) { ergebnis.append(k) }
        if ergebnis != wolke { nachfusionSpeichern.insert("documentCategories") }
        return ergebnis
    }

    // MARK: - Frische-Wächter: Cloud-Änderungen auch bei offener App

    private var frischeWaechter: Timer?
    /// Zuletzt gesehene Datei-Stände — nur ECHTE Fremd-Änderungen lösen aus.
    private var bekannteStaende: [String: Date] = [:]
    private let synchronisierteSchluessel = [
        "vaultItems", "documents", "notes", "lists", "notfallEintraege", "deskItems", "deskStil",
        "documentCategories", "categoryColors", "categoryIcons", "documentSubcategories",
        "grabsteine", "homeFolderQuickView", "pinnwandLayout", "pinnBoards", "anschlaege"
    ]

    private func dateiStand(_ key: String) -> Date? {
        (try? FileManager.default.attributesOfItem(atPath: dataURL(key).path))?[.modificationDate] as? Date
    }

    private func merkeStand(_ key: String) {
        bekannteStaende[key] = dateiStand(key)
    }

    /// Alle 20 Sekunden: Downloads anstoßen und bei fremden Datei-
    /// Änderungen frisch fusionieren — die App bleibt lebendig, auch
    /// wenn sie den ganzen Tag offen auf dem Pult steht.
    func starteFrischeWaechter() {
        guard frischeWaechter == nil else { return }
        frischeWaechter = Timer.scheduledTimer(withTimeInterval: 20, repeats: true) { [weak self] _ in
            self?.pruefeAufFrisches()
        }
    }

    private func pruefeAufFrisches() {
        downloadAllCloudFiles()
        // Ordner-Gabelung? Einschmelzen — das ändert die kanonischen
        // Datei-Stände, was die Frische-Prüfung unten als „neu" erkennt.
        gabelungGeheilt = false
        heileOrdnerGabelungen()
        var fremdesNeues = gabelungGeheilt
        for key in synchronisierteSchluessel {
            if dateiStand(key) != bekannteStaende[key] {
                fremdesNeues = true
                break
            }
        }
        guard fremdesNeues else { return }
        isLoadingData = true
        load()
        isLoadingData = false
        speichereNachfusion()
        for key in synchronisierteSchluessel { merkeStand(key) }
    }

    /// Nach dem Zusammenführen: Bestände mit lokalen Ergänzungen zurück
    /// in die Cloud schreiben — sonst kennt sie nur dieses Gerät.
    private func speichereNachfusion() {
        let faellig = nachfusionSpeichern
        nachfusionSpeichern = []
        if faellig.contains("vaultItems") { saveVault() }
        if faellig.contains("documents") { saveDocuments() }
        if faellig.contains("notes") { saveNotes() }
        if faellig.contains("lists") { saveLists() }
        if faellig.contains("notfallEintraege") { saveNotfall() }
        if faellig.contains("deskItems") { saveJSON(deskItems, key: "deskItems") }
        if faellig.contains("documentCategories") { saveDocumentCategories() }
        if faellig.contains("categoryColors") { saveCategoryColors() }
        if faellig.contains("categoryIcons") { saveCategoryIcons() }
        if faellig.contains("documentSubcategories") { saveDocumentSubcategories() }
        if faellig.contains("pinnwandLayout") { saveJSON(pinnwandLayout, key: "pinnwandLayout") }
        if faellig.contains("pinnBoards") { saveJSON(pinnBoards, key: "pinnBoards") }
        if faellig.contains("anschlaege") { saveJSON(anschlaege, key: "anschlaege") }
    }

    private func saveJSON<T: Encodable>(_ value: T, key: String) {
        guard !isLoadingData else { return }
        let url = dataURL(key)
        // Niemals lokale Leerdaten über ausstehende iCloud-Platzhalter schreiben.
        if hasCloudPlaceholder(at: url) { return }
        // Datei existiert, aber wir haben sie nie erfolgreich gelesen?
        // Dann gehört ihr Inhalt jemand anderem — nicht anfassen.
        if FileManager.default.fileExists(atPath: url.path), !geladeneSchluessel.contains(key) {
            return
        }
        guard let data = try? JSONEncoder().encode(value) else { return }
        let coordinator = NSFileCoordinator(filePresenter: nil)
        var err: NSError?
        coordinator.coordinate(writingItemAt: url, options: .forReplacing, error: &err) { u in
            try? data.write(to: u, options: .atomic)
        }
        geladeneSchluessel.insert(key)
        merkeStand(key)
    }

    private func loadJSON<T: Decodable>(_ type: T.Type, key: String) -> T? {
        let url = dataURL(key)
        if hasCloudPlaceholder(at: url) {
            try? FileManager.default.startDownloadingUbiquitousItem(at: url)
            return nil
        }
        guard FileManager.default.fileExists(atPath: url.path) else { return nil }
        var result: T? = nil
        let coordinator = NSFileCoordinator(filePresenter: nil)
        var err: NSError?
        coordinator.coordinate(readingItemAt: url, options: .withoutChanges, error: &err) { u in
            guard let data = try? Data(contentsOf: u), !data.isEmpty else { return }
            result = try? JSONDecoder().decode(type, from: data)
        }
        if result != nil {
            geladeneSchluessel.insert(key)
            merkeStand(key)
        }
        return result
    }

    // MARK: - Init

    init() {
        migrateFromUserDefaultsIfNeeded()
        waitForPendingCloudDownloads()
        isLoadingData = true
        load()
        isLoadingData = false
        entferneDoppelteKategorien()   // bestehende Doppelnamen einmalig zusammenführen
        // Demo-Seeding vorübergehend DEAKTIVIERT (Fehler: räumt sich selbst weg).
        // seedeDemodatenWennErststart()
        ladeZuletztGeoeffnet()
        ladeStromSortierung()
        speichereNachfusion()
        persistFreshInstallDefaults()
        persistHomeFolderQuickViewMigrationIfNeeded()
        downloadAllCloudFiles()
        createDefaultListIfNeeded()
        starteFrischeWaechter()
        startObservingCloudDownloads()
        updateCloudSyncState()
        beginCloudSyncMonitoringIfNeeded()
    }

    /// Speichert Erststart-Defaults, die während load() wegen isLoadingData nicht geschrieben wurden.
    private func persistFreshInstallDefaults() {
        // Mit iCloud NIE automatisch persistieren: Ein frisch angeschlossenes
        // Gerät sieht den Container kurz leer und würde sonst die Wahrheit
        // der anderen Geräte überschreiben. Defaults leben dann nur im
        // Speicher, bis der Nutzer selbst etwas ändert.
        guard !isICloudAvailable else { return }
        guard !hasAnyExistingDataStore() else { return }
        guard !hasPendingCloudDataDownloads() else { return }
        if documentCategories.isEmpty {
            documentCategories = AppStore.defaultCategories
        } else {
            saveDocumentCategories()
        }
    }

    private func persistHomeFolderQuickViewMigrationIfNeeded() {
        let url = dataURL("homeFolderQuickView")
        guard !FileManager.default.fileExists(atPath: url.path),
              !hasCloudPlaceholder(at: url),
              !homeFolderQuickView.isEmpty else { return }
        saveHomeFolderQuickView()
    }

    /// Legt beim ersten Start eine Beispiel-Taskliste an, damit die Funktion
    /// sofort sichtbar und verständlich ist.
    private func createDefaultListIfNeeded() {
        let key = "arcaDefaultListCreated_v1"
        guard !UserDefaults.standard.bool(forKey: key) else { return }
        // Nur bei echtem lokalem Erststart ohne iCloud — ein neu
        // angeschlossenes iCloud-Gerät darf niemals Daten erfinden.
        guard !isICloudAvailable else {
            UserDefaults.standard.set(true, forKey: key)
            return
        }
        guard !hasPendingCloudDataDownloads() else { return }
        if lists.isEmpty {
            let demo = ListEntry(
                title: "Einkaufen",
                items: [
                    ChecklistItem(text: "Butter"),
                    ChecklistItem(text: "Käse"),
                    ChecklistItem(text: "Milch")
                ],
                colorTag: 3
            )
            lists.append(demo)
        }
        UserDefaults.standard.set(true, forKey: key)
    }

    // MARK: - Migration: UserDefaults → iCloud/lokale Dateien (einmalig)

    private func migrateFromUserDefaultsIfNeeded() {
        guard !UserDefaults.standard.bool(forKey: "arcaStorageMigrated_v1") else { return }

        func migrate(udKey: String, fileKey: String) {
            guard let data = UserDefaults.standard.data(forKey: udKey) else { return }
            let target = dataURL(fileKey)
            // Nicht überschreiben wenn Datei schon existiert (z. B. vom anderen Gerät)
            guard !FileManager.default.fileExists(atPath: target.path) else { return }
            // iCloud-Platzhalter = echte Daten in der Cloud, nicht mit UD überschreiben
            guard !hasCloudPlaceholder(at: target) else { return }
            try? data.write(to: target)
        }

        migrate(udKey: "notes",                 fileKey: "notes")
        migrate(udKey: "documents",             fileKey: "documents")
        migrate(udKey: "lists",                 fileKey: "lists")
        migrate(udKey: "vaultItems",            fileKey: "vaultItems")
        migrate(udKey: "documentCategories",    fileKey: "documentCategories")
        migrate(udKey: "categoryColors",        fileKey: "categoryColors")
        migrate(udKey: "categoryIcons",         fileKey: "categoryIcons")
        migrate(udKey: "documentSubcategories", fileKey: "documentSubcategories")

        // Dokument-Dateien in neues Verzeichnis kopieren (nur wenn Ziel != Quelle)
        let oldDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let newDir = filesDirectory
        if oldDir.standardizedFileURL != newDir.standardizedFileURL {
            if let files = try? FileManager.default.contentsOfDirectory(
                at: oldDir, includingPropertiesForKeys: nil) {
                for file in files where !file.hasDirectoryPath {
                    let dest = newDir.appendingPathComponent(file.lastPathComponent)
                    guard !FileManager.default.fileExists(atPath: dest.path) else { continue }
                    try? FileManager.default.copyItem(at: file, to: dest)
                }
            }
        }

        UserDefaults.standard.set(true, forKey: "arcaStorageMigrated_v1")
    }

    // MARK: - Reload (aufgerufen wenn App in den Vordergrund kommt)

    func reloadFromCloud() {
        waitForPendingCloudDownloads(timeout: 1.0)
        isLoadingData = true
        load()
        isLoadingData = false
        entferneDoppelteKategorien()
        speichereNachfusion()
        downloadAllCloudFiles()
        updateCloudSyncState()
        beginCloudSyncMonitoringIfNeeded()
    }

    // MARK: - Export / Import

    static let minBackupPasswordLength = 4

    /// Endungen, die nie als Backup importiert werden dürfen (Dokumente, Medien, Arca-Exporttypen).
    static let blockedBackupImportExtensions: Set<String> = [
        "pdf", "jpg", "jpeg", "png", "heic", "heif", "tiff", "gif", "webp",
        "mov", "mp4", "m4v", "avi",
        "doc", "docx", "txt", "rtf", "pages",
        "arcafolder", "arcanote", "arcalist",
    ]

    static var arcabackupContentType: UTType {
        if let declared = UTType("com.hansruffin.arca.arcabackup") { return declared }
        if let byExt = UTType(filenameExtension: "arcabackup") { return byExt }
        return UTType(tag: "arcabackup", tagClass: .filenameExtension, conformingTo: .data)
            ?? UTType.data
    }

    func isBlockedDocumentExtension(_ url: URL) -> Bool {
        let ext = url.pathExtension.lowercased()
        guard !ext.isEmpty else { return false }
        return Self.blockedBackupImportExtensions.contains(ext)
    }

    /// Prüft Magic-Bytes — für Routing bei „Öffnen mit Arca“ (Extension kann fehlen).
    func isBackupCandidateURL(_ url: URL) -> Bool {
        if url.pathExtension.lowercased() == "arcabackup" { return true }
        let accessing = url.startAccessingSecurityScopedResource()
        defer { if accessing { url.stopAccessingSecurityScopedResource() } }
        switch detectBackupFormat(at: url) {
        case .aeaEncrypted, .v1EncryptedJSON: return true
        case .unknown: return false
        }
    }

    enum BackupExportError: Equatable, Error {
        case passwordTooShort
        case archiveFailed
    }

    enum BackupImportError: Equatable, Error {
        case fileAccessDenied
        case wrongPasswordOrCorrupt
        case manifestInvalid
        case invalidBackupFile
    }

    enum BackupFileFormat: Equatable {
        case aeaEncrypted
        case v1EncryptedJSON
        case unknown(String)
    }

    private static let backupLog = Logger(subsystem: Bundle.main.bundleIdentifier ?? "app.arcavault", category: "Backup")
    private static let stagedImportPrefix = "ArcaImport_"
    private static let backupFolderBookmarkKey = "arcaBackupFolderBookmark_v1"
    /// Hält Security-Scope für den gemerkten Backup-Ordner (Document-Picker).
    private var rememberedBackupFolderURL: URL?

    /// Security-scoped Bookmark des zuletzt genutzten Backup-Ordners speichern.
    func rememberBackupFolder(containing fileURL: URL) {
        guard !fileURL.path.hasPrefix(FileManager.default.temporaryDirectory.path) else { return }
        guard fileURL.startAccessingSecurityScopedResource() else { return }
        defer { fileURL.stopAccessingSecurityScopedResource() }

        let folder = fileURL.deletingLastPathComponent()
        do {
            let data = try folder.bookmarkData(
                options: .minimalBookmark,
                includingResourceValuesForKeys: nil,
                relativeTo: nil
            )
            UserDefaults.standard.set(data, forKey: Self.backupFolderBookmarkKey)
            Self.backupLog.info("Backup-Ordner gemerkt: \(folder.lastPathComponent, privacy: .public)")
        } catch {
            Self.backupLog.error(
                "Backup-Ordner-Bookmark fehlgeschlagen: \(error.localizedDescription, privacy: .public)")
        }
    }

    /// Gemerkten Backup-Ordner auflösen und Security-Scope starten (für Document-Picker).
    func beginAccessingRememberedBackupFolder() -> URL? {
        releaseRememberedBackupFolderAccess()
        guard let data = UserDefaults.standard.data(forKey: Self.backupFolderBookmarkKey) else { return nil }
        var stale = false
        do {
            let url = try URL(
                resolvingBookmarkData: data,
                options: .withoutUI,
                relativeTo: nil,
                bookmarkDataIsStale: &stale
            )
            if stale { refreshBackupFolderBookmark(for: url) }
            guard url.startAccessingSecurityScopedResource() else { return nil }
            var isDirectory: ObjCBool = false
            guard FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory),
                  isDirectory.boolValue else {
                url.stopAccessingSecurityScopedResource()
                return nil
            }
            rememberedBackupFolderURL = url
            return url
        } catch {
            Self.backupLog.error(
                "Backup-Ordner-Bookmark ungültig: \(error.localizedDescription, privacy: .public)")
            UserDefaults.standard.removeObject(forKey: Self.backupFolderBookmarkKey)
            return nil
        }
    }

    func releaseRememberedBackupFolderAccess() {
        if let url = rememberedBackupFolderURL {
            url.stopAccessingSecurityScopedResource()
            rememberedBackupFolderURL = nil
        }
    }

    private func refreshBackupFolderBookmark(for folder: URL) {
        guard folder.startAccessingSecurityScopedResource() else { return }
        defer { folder.stopAccessingSecurityScopedResource() }
        if let data = try? folder.bookmarkData(
            options: .minimalBookmark,
            includingResourceValuesForKeys: nil,
            relativeTo: nil
        ) {
            UserDefaults.standard.set(data, forKey: Self.backupFolderBookmarkKey)
        }
    }

    /// Jede Datei, die ein Eintrag braucht — nicht nur die der Dokumente.
    ///
    /// FEHLER bis 14.09.2026: Der Export packte nur `documents[].filename`
    /// ein. Fotos an Notizen (`notiz_*.jpg`) und die Kartenfotos im Tresor
    /// (`karte_*.jpg`) liegen im selben Ordner, wurden aber nie gesichert.
    /// Auf demselben Geraet fiel das nicht auf — die Dateien lagen ja noch
    /// da. Auf einem neuen Telefon kamen die Eintraege zurueck, ihre Bilder
    /// nicht.
    private var gesicherteDateinamen: [String] {
        var namen: [String] = []
        var gesehen = Set<String>()
        func nimm(_ n: String) {
            guard !n.isEmpty, gesehen.insert(n).inserted else { return }
            namen.append(n)
        }
        documents.forEach { nimm($0.filename) }
        notes.forEach { $0.fotos.forEach(nimm) }
        vaultItems.forEach { nimm($0.kartenBildVorne); nimm($0.kartenBildHinten) }
        notfallEintraege.forEach { nimm($0.fotoDatei) }
        return namen
    }

    /// Backup-Export, Format v2: verschlüsseltes Apple-Archiv (AEA).
    /// Speicherschonend — die Dateien werden gestreamt statt in den RAM geladen.
    func exportData(password: String) -> Result<URL, BackupExportError> {
        guard password.count >= Self.minBackupPasswordLength else {
            return .failure(.passwordTooShort)
        }
        // 1. Staging-Ordner: manifest.json (Metadaten) + files/ (Hardlinks/Kopien)
        let stage = FileManager.default.temporaryDirectory
            .appendingPathComponent("ArcaExport_\(UUID().uuidString)")
        let stageFiles = stage.appendingPathComponent("files")
        defer { try? FileManager.default.removeItem(at: stage) }
        do {
            try FileManager.default.createDirectory(at: stageFiles, withIntermediateDirectories: true)
            let backup = ArcaBackup(
                vaultItems: vaultItems,
                documents: documents,
                notes: notes,
                lists: lists,
                documentCategories: documentCategories,
                exportDate: Date(),
                fileData: nil,
                documentSubcategories: documentSubcategories,
                notfallEintraege: notfallEintraege
            )
            let manifest = try JSONEncoder().encode(backup)
            try manifest.write(to: stage.appendingPathComponent("manifest.json"))
            for name in gesicherteDateinamen {
                // Falls nur iCloud-Platzhalter: Download anstossen
                ensureFileDownloaded(name)
                let src = documentURL(for: name)
                guard FileManager.default.fileExists(atPath: src.path) else { continue }
                let dst = stageFiles.appendingPathComponent(name)
                // Hardlink (kein Platzverbrauch); falls nicht möglich: kopieren
                if (try? FileManager.default.linkItem(at: src, to: dst)) == nil {
                    try? FileManager.default.copyItem(at: src, to: dst)
                }
            }
        } catch { return .failure(.archiveFailed) }

        // 2. Verschlüsselt archivieren
        let filename = "ArcaBackup_\(Date().formatted(date: .abbreviated, time: .omitted)).arcabackup"
            .replacingOccurrences(of: " ", with: "_")
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(filename)
        guard archiveDirectory(stage, to: url, password: password, deriveBackupPassword: true),
              let size = try? FileManager.default.attributesOfItem(atPath: url.path)[.size] as? Int,
              size > 0 else { return .failure(.archiveFailed) }
        return .success(url)
    }

    /// Kopiert eine externe Backup-Datei lokal und prüft das Format (Magic-Bytes).
    func prepareBackupImport(from url: URL) -> Result<URL, BackupImportError> {
        let filename = url.lastPathComponent
        Self.backupLog.info("Import: Datei ausgewählt — \(filename, privacy: .public)")

        if isBlockedDocumentExtension(url) {
            Self.backupLog.error(
                "Import: Abgelehnt (Dokument-Endung .\(url.pathExtension, privacy: .public)) — \(filename, privacy: .public)")
            return .failure(.invalidBackupFile)
        }

        let ext = url.pathExtension.lowercased()
        if !ext.isEmpty && ext != "arcabackup" {
            Self.backupLog.error(
                "Import: Abgelehnt (Endung .\(ext, privacy: .public), erwartet .arcabackup) — \(filename, privacy: .public)")
            return .failure(.invalidBackupFile)
        }

        switch stageBackupFileForImport(from: url) {
        case .success(let staged):
            switch detectBackupFormat(at: staged) {
            case .aeaEncrypted:
                Self.backupLog.info("Import: AEA-Format erkannt — \(filename, privacy: .public)")
                return .success(staged)
            case .v1EncryptedJSON:
                Self.backupLog.info("Import: v1-Format (AES-GCM) erkannt — \(filename, privacy: .public)")
                return .success(staged)
            case .unknown(let magic):
                try? FileManager.default.removeItem(at: staged)
                Self.backupLog.error(
                    "Import: Keine Backup-Datei (Magic: \(magic, privacy: .public)) — \(filename, privacy: .public)")
                return .failure(.invalidBackupFile)
            }
        case .failure(let error):
            return .failure(error)
        }
    }

    func importData(from url: URL, password: String, merge: Bool = false) -> Result<Void, BackupImportError> {
        Self.backupLog.info("Import: Entschlüsselung starten — \(url.lastPathComponent, privacy: .public)")
        let staged: URL
        let removeStaged: Bool
        if url.lastPathComponent.hasPrefix(Self.stagedImportPrefix) {
            staged = url
            removeStaged = true
        } else {
            switch prepareBackupImport(from: url) {
            case .success(let copy):
                staged = copy
                removeStaged = true
            case .failure(let error):
                return .failure(error)
            }
        }
        defer { if removeStaged { try? FileManager.default.removeItem(at: staged) } }

        switch detectBackupFormat(at: staged) {
        case .aeaEncrypted:
            guard let extracted = extractArchive(staged, password: password, deriveBackupPassword: true) else {
                Self.backupLog.error("Import: AEA-Entschlüsselung fehlgeschlagen (Passwort oder beschädigtes Archiv)")
                return .failure(.wrongPasswordOrCorrupt)
            }
            defer { try? FileManager.default.removeItem(at: extracted) }
            guard let manifestData = try? Data(contentsOf: extracted.appendingPathComponent("manifest.json")),
                  let backup = try? JSONDecoder().decode(ArcaBackup.self, from: manifestData) else {
                Self.backupLog.error("Import: manifest.json fehlt oder ungültig")
                return .failure(.manifestInvalid)
            }
            let extractedFiles = extracted.appendingPathComponent("files")
            if let files = try? FileManager.default.contentsOfDirectory(
                at: extractedFiles, includingPropertiesForKeys: nil) {
                for f in files {
                    let dest = documentURL(for: f.lastPathComponent)
                    try? FileManager.default.removeItem(at: dest)
                    try? FileManager.default.copyItem(at: f, to: dest)
                }
            }
            applyBackup(backup, merge: merge)
            Self.backupLog.info("Import: erfolgreich (AEA, merge=\(merge, privacy: .public))")
            return .success(())

        case .v1EncryptedJSON:
            guard let encryptedData = try? Data(contentsOf: staged),
                  let plaintext = decryptV1Backup(encryptedData, password: password),
                  let backup = try? JSONDecoder().decode(ArcaBackup.self, from: plaintext) else {
                Self.backupLog.error("Import: v1-Entschlüsselung fehlgeschlagen — \(staged.lastPathComponent, privacy: .public)")
                return .failure(.wrongPasswordOrCorrupt)
            }

            if let fileData = backup.fileData {
                for (filename, data) in fileData {
                    let dest = documentURL(for: filename)
                    try? data.write(to: dest)
                }
            }

            applyBackup(backup, merge: merge)
            Self.backupLog.info("Import: erfolgreich (v1, merge=\(merge, privacy: .public))")
            return .success(())

        case .unknown(let magic):
            Self.backupLog.error(
                "Import: Keine Backup-Datei (Magic: \(magic, privacy: .public)) — \(staged.lastPathComponent, privacy: .public)")
            return .failure(.invalidBackupFile)
        }
    }

    /// Security-scoped URL sofort in den App-Temp-Ordner kopieren (Picker-Zugriff verfällt sonst).
    private func stageBackupFileForImport(from url: URL) -> Result<URL, BackupImportError> {
        let accessing = url.startAccessingSecurityScopedResource()
        defer { if accessing { url.stopAccessingSecurityScopedResource() } }

        guard FileManager.default.isReadableFile(atPath: url.path) else {
            Self.backupLog.error("Import: Datei nicht lesbar — \(url.lastPathComponent, privacy: .public)")
            return .failure(.fileAccessDenied)
        }

        let dest = FileManager.default.temporaryDirectory
            .appendingPathComponent("\(Self.stagedImportPrefix)\(UUID().uuidString).arcabackup")
        try? FileManager.default.removeItem(at: dest)
        do {
            try FileManager.default.copyItem(at: url, to: dest)
            return .success(dest)
        } catch {
            Self.backupLog.error("Import: Kopie fehlgeschlagen — \(error.localizedDescription, privacy: .public)")
            return .failure(.fileAccessDenied)
        }
    }

    private func detectBackupFormat(at url: URL) -> BackupFileFormat {
        guard let magic = readFileMagic(at: url, count: 4) else { return .unknown("unreadable") }
        if magic == Data("AEA1".utf8) { return .aeaEncrypted }
        if magic == Self.backupMagic { return .v1EncryptedJSON }
        let label = String(data: magic, encoding: .ascii)
            ?? magic.map { String(format: "%02X", $0) }.joined()
        return .unknown(label)
    }

    private func readFileMagic(at url: URL, count: Int) -> Data? {
        guard let fh = try? FileHandle(forReadingFrom: url) else { return nil }
        defer { try? fh.close() }
        return try? fh.read(upToCount: count)
    }

    /// Übernimmt die Metadaten eines Backups (ersetzen oder zusammenführen).
    private func applyBackup(_ backup: ArcaBackup, merge: Bool) {
        // Eine Wiederherstellung geschieht auf ausdrücklichen Nutzerwunsch —
        // sie erhält Datenhoheit über alle Schlüssel, sonst würde die
        // Schutzmauer (geladeneSchluessel) ihre eigenen Schreibzugriffe blocken.
        geladeneSchluessel.formUnion([
            "vaultItems", "documents", "notes", "lists", "notfallEintraege",
            "documentCategories", "categoryColors", "categoryIcons", "documentSubcategories", "homeFolderQuickView"
        ])
        // Wiederhergestelltes ist stärker als Grabsteine: frische Stempel
        // (sonst „stürbe" es sofort wieder an jüngeren Grabsteinen) und
        // die eigenen Grabsteine werden weggeräumt.
        var backup = backup
        let jetzt = Date()
        for i in backup.notes.indices      { backup.notes[i].geaendertAm = jetzt;      grabsteine.removeValue(forKey: backup.notes[i].id) }
        for i in backup.documents.indices  { backup.documents[i].geaendertAm = jetzt;  grabsteine.removeValue(forKey: backup.documents[i].id) }
        for i in backup.lists.indices      { backup.lists[i].geaendertAm = jetzt;      grabsteine.removeValue(forKey: backup.lists[i].id) }
        for i in backup.vaultItems.indices { backup.vaultItems[i].geaendertAm = jetzt; grabsteine.removeValue(forKey: backup.vaultItems[i].id) }
        // Aeltere Sicherungen kennen den Notfallkoffer nicht: nil heisst
        // „nichts mitgebracht", nicht „alles loeschen".
        var mitgebrachtesNotfall = backup.notfallEintraege ?? []
        for i in mitgebrachtesNotfall.indices { mitgebrachtesNotfall[i].geaendertAm = jetzt; grabsteine.removeValue(forKey: mitgebrachtesNotfall[i].id) }
        if merge {
            let existingNoteIDs  = Set(notes.map(\.id))
            let existingDocIDs   = Set(documents.map(\.id))
            let existingListIDs  = Set(lists.map(\.id))
            let existingVaultIDs = Set(vaultItems.map(\.id))
            let existingNotfallIDs = Set(notfallEintraege.map(\.id))

            notes      += backup.notes.filter      { !existingNoteIDs.contains($0.id) }
            documents  += backup.documents.filter  { !existingDocIDs.contains($0.id) }
            lists      += backup.lists.filter      { !existingListIDs.contains($0.id) }
            vaultItems += backup.vaultItems.filter { !existingVaultIDs.contains($0.id) }
            notfallEintraege += mitgebrachtesNotfall.filter { !existingNotfallIDs.contains($0.id) }

            let newCategories = backup.documentCategories.filter { !documentCategories.contains($0) }
            if !newCategories.isEmpty { documentCategories += newCategories }

            if let backupSubs = backup.documentSubcategories {
                for (cat, subs) in backupSubs {
                    var existing = documentSubcategories[cat] ?? []
                    for s in subs where !existing.contains(s) { existing.append(s) }
                    documentSubcategories[cat] = existing
                }
            }
        } else {
            vaultItems = backup.vaultItems
            documents  = backup.documents
            notes      = backup.notes
            lists      = backup.lists
            // Ersetzen nur, wenn die Sicherung den Koffer ueberhaupt kennt —
            // eine alte Sicherung soll die heutige Liste nicht leeren.
            if backup.notfallEintraege != nil { notfallEintraege = mitgebrachtesNotfall }
            documentCategories = backup.documentCategories.isEmpty
                ? AppStore.defaultCategories
                : backup.documentCategories
            documentSubcategories = backup.documentSubcategories ?? [:]
        }
    }

    // MARK: - Ordner Teilen

    func exportFolder(category: String) -> URL? {
        let docsInCategory = documents.filter { $0.category == category }
        let safeName = category.replacingOccurrences(of: " ", with: "_")
        return exportFolderArchive(
            filename: "Arca_\(safeName).arcafolder",
            docs: docsInCategory,
            categoryName: category,
            subcategories: documentSubcategories[category]
        )
    }

    func exportDocument(_ doc: DocumentEntry) -> URL? {
        let safeName = doc.title.replacingOccurrences(of: " ", with: "_")
            .replacingOccurrences(of: "/", with: "-")
        return exportFolderArchive(
            filename: "Arca_\(safeName).arcafolder",
            docs: [doc],
            categoryName: doc.category,
            subcategories: documentSubcategories[doc.category]
        )
    }

    /// Ordner-Export, Format v2: unverschlüsseltes Apple-Archiv mit manifest.json + files/.
    private func exportFolderArchive(filename: String, docs: [DocumentEntry],
                                     categoryName: String, subcategories: [String]?) -> URL? {
        let stage = FileManager.default.temporaryDirectory
            .appendingPathComponent("ArcaFolderExport_\(UUID().uuidString)")
        let stageFiles = stage.appendingPathComponent("files")
        defer { try? FileManager.default.removeItem(at: stage) }
        do {
            try FileManager.default.createDirectory(at: stageFiles, withIntermediateDirectories: true)
            let folder = ArcaFolder(
                categoryName: categoryName,
                documents: docs,
                fileData: [:],          // Dateien liegen im Archiv unter files/
                exportDate: Date(),
                subcategories: subcategories
            )
            let manifest = try JSONEncoder().encode(folder)
            try manifest.write(to: stage.appendingPathComponent("manifest.json"))
            for doc in docs {
                // Falls nur iCloud-Platzhalter: Download anstossen
                ensureFileDownloaded(doc.filename)
                let src = documentURL(for: doc.filename)
                guard FileManager.default.fileExists(atPath: src.path) else { continue }
                let dst = stageFiles.appendingPathComponent(doc.filename)
                if (try? FileManager.default.linkItem(at: src, to: dst)) == nil {
                    try? FileManager.default.copyItem(at: src, to: dst)
                }
            }
        } catch { return nil }

        let url = FileManager.default.temporaryDirectory.appendingPathComponent(filename)
        guard archiveDirectory(stage, to: url, password: nil),
              let size = try? FileManager.default.attributesOfItem(atPath: url.path)[.size] as? Int,
              size > 0 else { return nil }
        return url
    }

    func importFolder(from url: URL) -> String? {
        let accessing = url.startAccessingSecurityScopedResource()
        defer { if accessing { url.stopAccessingSecurityScopedResource() } }

        let folder: ArcaFolder
        if isJSONFile(url) {
            // Altes Format (v1): JSON mit eingebetteten Dateidaten
            guard let data = try? Data(contentsOf: url),
                  let f = try? JSONDecoder().decode(ArcaFolder.self, from: data) else { return nil }
            folder = f
            for (filename, fileData) in folder.fileData {
                let dest = documentURL(for: filename)
                try? fileData.write(to: dest)
            }
        } else {
            // Neues Format (v2): Apple-Archiv
            guard let extracted = extractArchive(url, password: nil) else { return nil }
            defer { try? FileManager.default.removeItem(at: extracted) }
            guard let manifestData = try? Data(contentsOf: extracted.appendingPathComponent("manifest.json")),
                  let f = try? JSONDecoder().decode(ArcaFolder.self, from: manifestData) else { return nil }
            folder = f
            let extractedFiles = extracted.appendingPathComponent("files")
            if let files = try? FileManager.default.contentsOfDirectory(
                at: extractedFiles, includingPropertiesForKeys: nil) {
                for f in files {
                    let dest = documentURL(for: f.lastPathComponent)
                    try? FileManager.default.removeItem(at: dest)
                    try? FileManager.default.copyItem(at: f, to: dest)
                }
            }
        }

        var newCategoryName = folder.categoryName
        var counter = 2
        while documentCategories.contains(newCategoryName) {
            newCategoryName = "\(folder.categoryName) \(counter)"
            counter += 1
        }
        documentCategories.append(newCategoryName)
        let importedDocs = folder.documents.map { doc -> DocumentEntry in
            var d = doc; d.id = UUID(); d.category = newCategoryName; return d
        }
        documents.append(contentsOf: importedDocs)
        if let subs = folder.subcategories, !subs.isEmpty {
            var existing = documentSubcategories[newCategoryName] ?? []
            for s in subs where !existing.contains(s) { existing.append(s) }
            documentSubcategories[newCategoryName] = existing
        }
        return newCategoryName
    }

    // MARK: - Notiz Teilen

    func exportNote(_ note: NoteEntry) -> URL? {
        let arcaNote = ArcaNote(note: note, exportDate: Date())
        guard let data = try? JSONEncoder().encode(arcaNote) else { return nil }
        let safeName = note.title.isEmpty ? "Notiz" : note.title.replacingOccurrences(of: " ", with: "_")
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("Arca_\(safeName).arcanote")
        try? FileManager.default.removeItem(at: url)
        do { try data.write(to: url) } catch { return nil }
        guard FileManager.default.fileExists(atPath: url.path) else { return nil }
        return url
    }

    func importNote(from url: URL) -> Bool {
        let accessing = url.startAccessingSecurityScopedResource()
        defer { if accessing { url.stopAccessingSecurityScopedResource() } }
        guard let data = try? Data(contentsOf: url),
              let arcaNote = try? JSONDecoder().decode(ArcaNote.self, from: data) else { return false }
        var newNote = arcaNote.note
        newNote.id = UUID()
        notes.append(newNote)
        return true
    }

    // MARK: - Aufgabenliste Teilen

    func exportList(_ list: ListEntry) -> URL? {
        let arcaList = ArcaList(list: list, exportDate: Date())
        guard let data = try? JSONEncoder().encode(arcaList) else { return nil }
        let safeName = list.title.replacingOccurrences(of: " ", with: "_")
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("Arca_\(safeName).arcalist")
        try? FileManager.default.removeItem(at: url)
        do { try data.write(to: url) } catch { return nil }
        guard FileManager.default.fileExists(atPath: url.path) else { return nil }
        return url
    }

    func importList(from url: URL) -> Bool {
        let accessing = url.startAccessingSecurityScopedResource()
        defer { if accessing { url.stopAccessingSecurityScopedResource() } }
        guard let data = try? Data(contentsOf: url),
              let arcaList = try? JSONDecoder().decode(ArcaList.self, from: data) else { return false }
        var newList = arcaList.list
        newList.id = UUID()
        lists.append(newList)
        return true
    }

    // MARK: - Apple-Archiv-Helfer (speicherschonend, gestreamt)

    /// Leitet aus dem Nutzerpasswort ein AEA-konformes Passwort ab.
    /// Apples Scrypt-Profil lehnt schwache Kurzpasswörter ab — HKDF erzeugt
    /// immer ein ausreichend starkes Passwort für `setPassword`.
    private func aeaPassword(from userPassword: String) -> String {
        guard let passwordData = userPassword.data(using: .utf8) else { return userPassword }
        let key = HKDF<SHA256>.deriveKey(
            inputKeyMaterial: SymmetricKey(data: passwordData),
            salt: Self.backupPasswordSalt,
            info: Data("AEA".utf8),
            outputByteCount: 32)
        return key.withUnsafeBytes { Data($0) }.base64EncodedString()
    }

    private static let backupPasswordSalt = Data("ArcaBackupSalt_v1".utf8)

    /// Archiviert einen Ordner in eine Datei — optional passwortverschlüsselt (AEA).
    private func archiveDirectory(
        _ dir: URL, to dest: URL, password: String?, deriveBackupPassword: Bool = false
    ) -> Bool {
        try? FileManager.default.removeItem(at: dest)
        do {
            guard let fileStream = ArchiveByteStream.fileStream(
                path: FilePath(dest.path), mode: .writeOnly,
                options: [.create, .truncate],
                permissions: FilePermissions(rawValue: 0o644)) else { return false }
            defer { try? fileStream.close() }

            var targetStream = fileStream
            var encryptionStream: ArchiveByteStream? = nil
            if let password {
                let aeaPwd = deriveBackupPassword ? aeaPassword(from: password) : password
                let ctx = ArchiveEncryptionContext(
                    profile: .hkdf_sha256_aesctr_hmac__scrypt__none,
                    compressionAlgorithm: .lzfse)
                try ctx.setPassword(aeaPwd)
                guard let es = ArchiveByteStream.encryptionStream(
                    writingTo: fileStream, encryptionContext: ctx) else { return false }
                encryptionStream = es
                targetStream = es
            }
            defer { if let s = encryptionStream { try? s.close() } }

            guard let encoder = ArchiveStream.encodeStream(writingTo: targetStream) else { return false }
            defer { try? encoder.close() }

            try encoder.writeDirectoryContents(
                archiveFrom: FilePath(dir.path), keySet: .defaultForArchive)

            try encoder.close()
            if let s = encryptionStream { try? s.close() }
            try fileStream.close()
            return true
        } catch {
            try? FileManager.default.removeItem(at: dest)
            return false
        }
    }

    /// Entpackt ein Apple-Archiv (optional verschlüsselt) in einen temporären Ordner.
    private func extractArchive(
        _ url: URL, password: String?, deriveBackupPassword: Bool = false
    ) -> URL? {
        if deriveBackupPassword, let password {
            let derived = aeaPassword(from: password)
            for (label, candidate) in [("HKDF", derived), ("raw", password)] {
                if let outDir = tryExtractArchive(url, password: candidate) {
                    Self.backupLog.info("Import: Archiv entschlüsselt mit \(label, privacy: .public)-Passwort")
                    return outDir
                }
                Self.backupLog.debug("Import: \(label, privacy: .public)-Passwort passte nicht")
            }
            return nil
        }
        return tryExtractArchive(url, password: password)
    }

    private func tryExtractArchive(_ url: URL, password: String?) -> URL? {
        let outDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("ArcaExtract_\(UUID().uuidString)")
        do {
            try FileManager.default.createDirectory(at: outDir, withIntermediateDirectories: true)
            guard let fileStream = ArchiveByteStream.fileStream(
                path: FilePath(url.path), mode: .readOnly,
                options: [], permissions: FilePermissions(rawValue: 0o644)) else { return nil }
            defer { try? fileStream.close() }

            var sourceStream = fileStream
            var decryptionStream: ArchiveByteStream? = nil
            if let password {
                guard let ctx = ArchiveEncryptionContext(from: fileStream) else { return nil }
                try ctx.setPassword(password)
                guard let ds = ArchiveByteStream.decryptionStream(
                    readingFrom: fileStream, encryptionContext: ctx) else { return nil }
                decryptionStream = ds
                sourceStream = ds
            }
            defer { if let s = decryptionStream { try? s.close() } }

            guard let decoder = ArchiveStream.decodeStream(readingFrom: sourceStream) else { return nil }
            defer { try? decoder.close() }
            guard let extractor = ArchiveStream.extractStream(
                extractingTo: FilePath(outDir.path),
                flags: [.ignoreOperationNotPermitted]) else { return nil }
            defer { try? extractor.close() }

            _ = try ArchiveStream.process(readingFrom: decoder, writingTo: extractor)
            return outDir
        } catch {
            try? FileManager.default.removeItem(at: outDir)
            return nil
        }
    }

    /// Erkennt das neue Backup-Format am AEA-Magic-Header.
    private func isAppleEncryptedArchive(_ url: URL) -> Bool {
        guard let magic = readFileMagic(at: url, count: 4) else { return false }
        return magic == Data("AEA1".utf8)
    }

    /// Erkennt das alte JSON-Format am ersten Zeichen "{".
    private func isJSONFile(_ url: URL) -> Bool {
        guard let fh = try? FileHandle(forReadingFrom: url) else { return false }
        defer { try? fh.close() }
        guard let first = try? fh.read(upToCount: 1) else { return false }
        return first == Data("{".utf8)
    }

    // MARK: - Encryption (AES-GCM, password-derived key via HKDF)

    private static let backupMagic = Data("ARCA".utf8)

    private func encryptData(_ data: Data, password: String) throws -> Data {
        var salt = Data(count: 16)
        salt.withUnsafeMutableBytes { _ = SecRandomCopyBytes(kSecRandomDefault, 16, $0.baseAddress!) }
        let key = deriveKey(from: password, salt: salt)
        let sealed = try AES.GCM.seal(data, using: key)
        guard let combined = sealed.combined else { throw CryptoError.encryptionFailed }
        return Self.backupMagic + salt + combined
    }

    private func decryptData(_ data: Data, password: String) throws -> Data {
        if data.prefix(4) == Self.backupMagic {
            guard data.count > 20 else { throw CryptoError.encryptionFailed }
            let salt = data[4..<20]
            let ciphertext = data[20...]
            let key = deriveKey(from: password, salt: Data(salt))
            let box = try AES.GCM.SealedBox(combined: Data(ciphertext))
            return try AES.GCM.open(box, using: key)
        } else {
            guard let fixedSalt = "ArcaBackupSalt_v1".data(using: .utf8),
                  let passwordData = password.data(using: .utf8) else { throw CryptoError.encryptionFailed }
            let inputKey = SymmetricKey(data: passwordData)
            let derived = HKDF<SHA256>.deriveKey(inputKeyMaterial: inputKey, salt: fixedSalt, info: Data(), outputByteCount: 32)
            let keyData = derived.withUnsafeBytes { Data($0) }
            let key = SymmetricKey(data: keyData)
            let box = try AES.GCM.SealedBox(combined: data)
            return try AES.GCM.open(box, using: key)
        }
    }

    /// v1-Backups: Nutzerpasswort und HKDF-abgeleitetes Passwort probieren.
    private func decryptV1Backup(_ data: Data, password: String) -> Data? {
        let candidates: [(String, String)] = [
            ("raw", password),
            ("HKDF", aeaPassword(from: password)),
        ]
        for (label, candidate) in candidates {
            if let plain = try? decryptData(data, password: candidate) {
                Self.backupLog.info("Import: v1 entschlüsselt mit \(label, privacy: .public)-Passwort")
                return plain
            }
            Self.backupLog.debug("Import: v1 \(label, privacy: .public)-Passwort passte nicht")
        }
        return nil
    }

    private func deriveKey(from password: String, salt: Data) -> SymmetricKey {
        guard let passwordData = password.data(using: .utf8) else {
            return SymmetricKey(size: .bits256)
        }
        let inputKey = SymmetricKey(data: passwordData)
        return HKDF<SHA256>.deriveKey(inputKeyMaterial: inputKey, salt: salt, info: Data(), outputByteCount: 32)
    }

    enum CryptoError: Error {
        case encryptionFailed
    }

    // MARK: - Dokumente

    /// Externe Inhalte, die Arca-Fenster und Schreibtisch annehmen.
    static var externeAblageTypen: [UTType] {
        var typen: [UTType] = [.fileURL, .emailMessage]
        if let mail = UTType("com.apple.mail.email") { typen.append(mail) }
        return typen
    }

    /// Externe Datei (Mail, Finder) übernehmen: sofort in den Bestand
    /// kopieren, als Dokument in „Unsortiert" anlegen. `fertig` liefert
    /// die neue Dokument-ID am Main-Thread (z. B. fürs Anheften).
    func uebernimmExterneDatei(von url: URL, alsMail: Bool, fertig: ((UUID) -> Void)? = nil) {
        let endung = url.pathExtension.lowercased()
        let titel = url.deletingPathExtension().lastPathComponent
        let zielName = UUID().uuidString + (endung.isEmpty ? (alsMail ? ".eml" : "") : "." + endung)
        let ziel = documentURL(for: zielName)
        // Sofort kopieren — die Quelle lebt nur während der Übergabe
        guard (try? FileManager.default.copyItem(at: url, to: ziel)) != nil else { return }

        let typ: DocumentType
        if alsMail || ["eml", "emlx"].contains(endung) {
            typ = .mail
        } else if endung == "pdf" {
            typ = .pdf
        } else if ["png", "jpg", "jpeg", "heic", "heif", "gif", "webp", "tiff"].contains(endung) {
            typ = .image
        } else if ["mov", "mp4", "m4v"].contains(endung) {
            typ = .video
        } else {
            typ = .text
        }
        let neueID = UUID()
        DispatchQueue.main.async {
            let kategorie = self.ensureImportCategoryExists()
            let eintrag = DocumentEntry(
                id: neueID,
                title: titel.isEmpty ? (alsMail ? "Mail" : "Import") : titel,
                type: typ, filename: zielName, dateAdded: Date(), category: kategorie)
            self.documents.append(eintrag)
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            fertig?(neueID)
        }
    }

    func addDocument(title: String, type: DocumentType, filename: String, category: String = "Unsortiert", subcategory: String = "", ocrText: String = "") {
        let entry = DocumentEntry(title: title, type: type, filename: filename, dateAdded: Date(), category: category, subcategory: subcategory, ocrText: ocrText)
        documents.append(entry)
        haengeAufWand(.document, entry.id)
    }

    /// Existierende Kategorie, die diesem Namen entspricht (case-insensitiv, getrimmt).
    func vorhandeneKategorie(_ name: String) -> String? {
        let key = name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return documentCategories.first {
            $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() == key
        }
    }

    /// Führt eine Gruppe in eine andere zusammen (Dokumente, Untergruppen,
    /// Farbe, Icon, Schnellansicht) und entfernt die Quelle — nie Duplikate.
    func mergeKategorie(_ quelle: String, in ziel: String) {
        guard quelle != ziel else { return }
        documents = documents.map { d in
            var x = d; if x.category == quelle { x.category = ziel }; return x
        }
        if let subs = documentSubcategories[quelle] {
            var zielSubs = documentSubcategories[ziel] ?? []
            for s in subs where !zielSubs.contains(s) { zielSubs.append(s) }
            documentSubcategories[ziel] = zielSubs
            documentSubcategories.removeValue(forKey: quelle)
        }
        documentCategories.removeAll { $0 == quelle }
        if categoryColors[ziel] == nil, let f = categoryColors[quelle] { categoryColors[ziel] = f }
        categoryColors.removeValue(forKey: quelle)
        if categoryIcons[ziel] == nil, let s = categoryIcons[quelle] { categoryIcons[ziel] = s }
        categoryIcons.removeValue(forKey: quelle)
        homeFolderQuickView.removeAll { $0 == quelle }
    }

    /// Räumt bestehende Doppelnamen auf: unterschiedliche Schreibweisen
    /// werden zusammengeführt, exakte Wiederholungen aus der Liste entfernt.
    func entferneDoppelteKategorien() {
        // Kanonischen Namen je (getrimmt, kleingeschrieben) merken — erster gewinnt
        var kanonischFuer: [String: String] = [:]
        for cat in documentCategories {
            let key = cat.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            if kanonischFuer[key] == nil { kanonischFuer[key] = cat }
        }
        // Abweichende Schreibweisen in den kanonischen Namen zusammenführen
        let zusammen: [(String, String)] = documentCategories.compactMap { cat in
            let key = cat.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            if let kanonisch = kanonischFuer[key], kanonisch != cat { return (cat, kanonisch) }
            return nil
        }
        for (quelle, ziel) in zusammen { mergeKategorie(quelle, in: ziel) }
        // Exakte Wiederholungen aus der Liste entfernen (Reihenfolge wahren)
        var gesehen = Set<String>()
        let entdoppelt = documentCategories.filter { gesehen.insert($0).inserted }
        if entdoppelt.count != documentCategories.count {
            documentCategories = entdoppelt
        }
    }

    func renameCategory(from old: String, to new: String) {
        let trimmed = new.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, trimmed != old else { return }
        // Keine zwei Gruppen mit gleichem Namen: existiert das Ziel schon → zusammenführen
        if let ziel = vorhandeneKategorie(trimmed), ziel != old {
            mergeKategorie(old, in: ziel)
            return
        }
        if let idx = documentCategories.firstIndex(of: old) {
            documentCategories[idx] = trimmed
        }
        documents = documents.map { doc in
            var d = doc; if d.category == old { d.category = trimmed }; return d
        }
        if old == importCategoryName { importCategoryName = trimmed }
        if let subs = documentSubcategories[old] {
            documentSubcategories[trimmed] = subs
            documentSubcategories.removeValue(forKey: old)
        }
        if let idx = homeFolderQuickView.firstIndex(of: old) {
            homeFolderQuickView[idx] = trimmed
        }
        if let farbe = categoryColors[old] {
            categoryColors[trimmed] = farbe
            categoryColors.removeValue(forKey: old)
        }
        if let sym = categoryIcons[old] {
            categoryIcons[trimmed] = sym
            categoryIcons.removeValue(forKey: old)
        }
    }

    func deleteCategory(_ name: String) {
        guard name != "Unsortiert" else { return }
        if !documentCategories.contains("Unsortiert") {
            documentCategories.append("Unsortiert")
        }
        documents = documents.map { doc in
            var d = doc
            if d.category == name { d.category = "Unsortiert"; d.subcategory = "" }
            return d
        }
        documentCategories.removeAll { $0 == name }
        documentSubcategories.removeValue(forKey: name)
        homeFolderQuickView.removeAll { $0 == name }
        categoryColors.removeValue(forKey: name)
        categoryIcons.removeValue(forKey: name)
    }

    func addSubcategory(to category: String, name: String) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        var subs = documentSubcategories[category] ?? []
        guard !subs.contains(trimmed) else { return }
        subs.append(trimmed)
        documentSubcategories[category] = subs
    }

    func deleteSubcategory(category: String, name: String) {
        documents = documents.map { doc in
            var d = doc
            if d.category == category && d.subcategory == name { d.subcategory = "" }
            return d
        }
        var subs = documentSubcategories[category] ?? []
        subs.removeAll { $0 == name }
        if subs.isEmpty { documentSubcategories.removeValue(forKey: category) }
        else { documentSubcategories[category] = subs }
    }

    func renameSubcategory(category: String, old: String, new: String) {
        let trimmed = new.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, trimmed != old else { return }
        documents = documents.map { doc in
            var d = doc
            if d.category == category && d.subcategory == old { d.subcategory = trimmed }
            return d
        }
        var subs = documentSubcategories[category] ?? []
        if let idx = subs.firstIndex(of: old) { subs[idx] = trimmed }
        documentSubcategories[category] = subs
    }

    func deleteDocument(_ entry: DocumentEntry) {
        let url = documentURL(for: entry.filename)
        try? FileManager.default.removeItem(at: url)
        documents.removeAll { $0.id == entry.id }
    }

    /// Gibt die URL einer Dokument-Datei zurück (iCloud oder lokaler Fallback).
    func documentURL(for filename: String) -> URL {
        let url = filesDirectory.appendingPathComponent(filename)
        // Selbstheilung: Datei wurde früher fälschlich lokal gespeichert → in den
        // richtigen Ordner kopieren, damit sie wieder auffindbar ist
        if !FileManager.default.fileExists(atPath: url.path) {
            let local = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
                .appendingPathComponent(filename)
            if local.standardizedFileURL != url.standardizedFileURL,
               FileManager.default.fileExists(atPath: local.path) {
                try? FileManager.default.copyItem(at: local, to: url)
            }
        }
        return url
    }

    // MARK: - Widget-Daten

    private func updateWidgetData() {
        guard let defaults = UserDefaults(suiteName: "group.com.hansruffin.arca") else { return }
        defaults.set(vaultItems.count, forKey: "widget_vaultCount")
        defaults.set(documents.count, forKey: "widget_docCount")
        defaults.set(notes.count,     forKey: "widget_noteCount")
        defaults.set(lists.count,     forKey: "widget_listCount")
        // Notfall-Widget: nur Anzahlen, keine Namen — ein Widget sieht jeder,
        // der auf den Bildschirm schaut.
        defaults.set(notfallEintraege.filter { $0.art == .wichtig }.count,     forKey: "widget_notfallWichtig")
        defaults.set(notfallEintraege.filter { $0.art == .medikament }.count,  forKey: "widget_notfallMedikamente")
        defaults.set(notfallEintraege.filter { $0.art == .kontakt }.count,     forKey: "widget_notfallKontakte")
        defaults.set(UserDefaults.standard.string(forKey: "quickAccessTitle") ?? "", forKey: "widget_quickAccessTitle")
        defaults.set(UserDefaults.standard.string(forKey: "quickAccessKind")  ?? "", forKey: "widget_quickAccessKind")
        defaults.set(UserDefaults.standard.string(forKey: "quickAccessId")    ?? "", forKey: "widget_quickAccessId")
        WidgetCenter.shared.reloadAllTimelines()
    }

    // MARK: - Speichern

    private func saveVault() {
        // ALLE Felder erhalten (art, Karten-Felder, favoritePinned, geaendertAm …) —
        // nur das Passwort wandert ins Keychain, nicht in die JSON.
        let withoutPasswords = vaultItems.map { item -> VaultEntry in
            var e = item
            e.password = ""
            return e
        }
        saveJSON(withoutPasswords, key: "vaultItems")
        // Passwörter im iCloud Keychain (synchronizable: true → geräteübergreifend)
        for item in vaultItems {
            KeychainManager.shared.save(key: "vault_\(item.id)", value: item.password, synchronizable: true)
        }
        updateWidgetData()
    }

    private func saveDocuments() {
        saveJSON(documents, key: "documents")
        updateWidgetData()
    }

    private func saveNotes() {
        saveJSON(notes, key: "notes")
        updateWidgetData()
    }

    private func saveDocumentCategories() {
        saveJSON(documentCategories, key: "documentCategories")
    }

    private func saveCategoryColors() {
        saveJSON(categoryColors, key: "categoryColors")
    }

    private func saveCategoryIcons() {
        saveJSON(categoryIcons, key: "categoryIcons")
    }

    private func saveNotfall() {
        saveJSON(notfallEintraege, key: "notfallEintraege")
        updateWidgetData()
    }

    private func saveLists() {
        saveJSON(lists, key: "lists")
        updateWidgetData()
    }

    private func saveDocumentSubcategories() {
        saveJSON(documentSubcategories, key: "documentSubcategories")
    }

    private func saveHomeFolderQuickView() {
        saveJSON(homeFolderQuickView, key: "homeFolderQuickView")
    }

    // MARK: - Start-Schnellansicht (Ordner)

    func documentCount(in category: String) -> Int {
        documents.filter { $0.category == category }.count
    }

    func isInHomeFolderQuickView(_ category: String) -> Bool {
        homeFolderQuickView.contains(category)
    }

    func setHomeFolderQuickView(_ category: String, enabled: Bool) {
        if enabled {
            guard !homeFolderQuickView.contains(category) else { return }
            homeFolderQuickView.append(category)
        } else {
            homeFolderQuickView.removeAll { $0 == category }
        }
    }

    func toggleHomeFolderQuickView(_ category: String) {
        setHomeFolderQuickView(category, enabled: !isInHomeFolderQuickView(category))
    }

    /// Reihenfolge der sichtbaren Start-Ordner per Drag & Drop anpassen.
    func moveHomeFolderQuickView(visibleFrom source: IndexSet, visibleTo destination: Int) {
        var visible = visibleHomeQuickViewFolders()
        guard visible.count > 1 else { return }
        visible.move(fromOffsets: source, toOffset: destination)
        let hidden = homeFolderQuickView.filter { !visible.contains($0) }
        homeFolderQuickView = visible + hidden
    }

    /// Ordner für die Start-Schnellansicht: nur gewählte, nicht leere, in gespeicherter Reihenfolge.
    func visibleHomeQuickViewFolders() -> [String] {
        homeFolderQuickView.filter { cat in
            documentCategories.contains(cat) && documentCount(in: cat) > 0
        }
    }

    private func migrateHomeFolderQuickViewIfNeeded() {
        let path = dataURL("homeFolderQuickView")
        guard !FileManager.default.fileExists(atPath: path.path) else { return }
        guard !hasCloudPlaceholder(at: path) else { return }
        guard !hasPendingCloudDataDownloads() else { return }
        homeFolderQuickView = documentCategories.filter { documentCount(in: $0) > 0 }
    }

    // MARK: - Laden

    private func load() {
        // Selbstheilung: von iCloud abgespaltene Ordner-Kopien
        // („arcadata 2" …) einschmelzen, BEVOR wir kanonisch lesen.
        heileOrdnerGabelungen()
        // Grabsteine zuerst: sie entscheiden, was tot bleibt
        if let decoded = loadJSON([UUID: Date].self, key: "grabsteine") {
            let vereint = grabsteine.merging(decoded) { max($0, $1) }
            let limit = Date().addingTimeInterval(-90 * 86400)
            grabsteine = vereint.filter { $0.value > limit }
        }

        if var decoded = loadJSON([VaultEntry].self, key: "vaultItems") {
            for i in decoded.indices {
                // Passwort: zuerst sync Keychain, Fallback auf nicht-sync (alte Geräte)
                decoded[i].password =
                    KeychainManager.shared.load(key: "vault_\(decoded[i].id)", synchronizable: true)
                    ?? KeychainManager.shared.load(key: "vault_\(decoded[i].id)", synchronizable: false)
                    ?? ""
            }
            vaultItems = loeseKonflikte(
                fusioniereUndMerke(vaultItems, decoded, schluessel: "vaultItems"), key: "vaultItems")
        }
        if let decoded = loadJSON([DocumentEntry].self, key: "documents") {
            documents = loeseKonflikte(
                fusioniereUndMerke(documents, decoded, schluessel: "documents"), key: "documents")
        }
        if let decoded = loadJSON([NoteEntry].self, key: "notes") {
            notes = loeseKonflikte(
                fusioniereUndMerke(notes, decoded, schluessel: "notes"), key: "notes")
        }
        // Digitales Erbe
        if let decoded = loadJSON([ErbeEintrag].self, key: "erbeEintraege") {
            erbeEintraege = decoded
        }
        profilBildData = UserDefaults.standard.data(forKey: "profilBild")
        demoModusAktiv = UserDefaults.standard.bool(forKey: "arcaDemoModus")
        erbeVertrauensperson = UserDefaults.standard.string(forKey: "erbeVertrauensperson") ?? ""
        if let f = UserDefaults.standard.string(forKey: "erbeFrage"), !f.isEmpty { erbeFrage = f }
        if UserDefaults.standard.object(forKey: "erbeFristTage") != nil {
            erbeFristTage = UserDefaults.standard.integer(forKey: "erbeFristTage")
        }
        erbeAktiv = UserDefaults.standard.bool(forKey: "erbeAktiv")
        if let d = UserDefaults.standard.object(forKey: "erbeLetzteAktivitaet") as? Date {
            erbeLetzteAktivitaet = d
        }
        if let decoded = loadJSON([ListEntry].self, key: "lists") {
            lists = loeseKonflikte(
                fusioniereUndMerke(lists, decoded, schluessel: "lists"), key: "lists")
        }
        if let decoded = loadJSON([NotfallEintrag].self, key: "notfallEintraege") {
            notfallEintraege = loeseKonflikte(
                fusioniereUndMerke(notfallEintraege, decoded, schluessel: "notfallEintraege"),
                key: "notfallEintraege")
        }
        if let decoded = loadJSON([DeskItem].self, key: "deskItems") {
            deskItems = loeseKonflikte(
                fusioniereUndMerke(deskItems, decoded, schluessel: "deskItems"), key: "deskItems")
        }
        if let decoded = loadJSON([PinnBoard].self, key: "pinnBoards") {
            pinnBoards = loeseKonflikte(
                fusioniereUndMerke(pinnBoards, decoded, schluessel: "pinnBoards"), key: "pinnBoards")
        }
        if let decoded = loadJSON([Anschlag].self, key: "anschlaege") {
            anschlaege = loeseKonflikte(
                fusioniereUndMerke(anschlaege, decoded, schluessel: "anschlaege"), key: "anschlaege")
        }
        if let decoded = loadJSON(DeskFlaechenStil.self, key: "deskStil") {
            deskStil = decoded
        }
        if let decoded = loadJSON([String].self, key: "documentCategories") {
            documentCategories = vereinigeKategorien(documentCategories, decoded)
        } else if documentCategories.isEmpty,
                  !hasPendingCloudDataDownloads(),
                  !hasAnyExistingDataStore() {
            // Nur bei echtem Erststart — nie Defaults schreiben während iCloud noch lädt.
            documentCategories = AppStore.defaultCategories
        }
        if let decoded = loadJSON([String: Int].self, key: "categoryColors") {
            let vereint = categoryColors.merging(decoded) { _, wolke in wolke }
            if vereint != decoded { nachfusionSpeichern.insert("categoryColors") }
            categoryColors = vereint
        }
        if let decoded = loadJSON([String: String].self, key: "categoryIcons") {
            let vereint = categoryIcons.merging(decoded) { _, wolke in wolke }
            if vereint != decoded { nachfusionSpeichern.insert("categoryIcons") }
            categoryIcons = vereint
        }
        if let decoded = loadJSON([String: [String]].self, key: "documentSubcategories") {
            let vereint = documentSubcategories.merging(decoded) { _, wolke in wolke }
            if vereint != decoded { nachfusionSpeichern.insert("documentSubcategories") }
            documentSubcategories = vereint
        }
        if let decoded = loadJSON([String: [Double]].self, key: "pinnwandLayout") {
            let vereint = pinnwandLayout.merging(decoded) { _, wolke in wolke }
            if vereint != decoded { nachfusionSpeichern.insert("pinnwandLayout") }
            pinnwandLayout = vereint
        }
        if let decoded = loadJSON([String].self, key: "homeFolderQuickView") {
            homeFolderQuickView = decoded
        } else {
            migrateHomeFolderQuickViewIfNeeded()
        }
        // „Sonstiges" heißt jetzt „Unsortiert" — einmalige Umbenennung (04.08.);
        // der kurzlebige Zwischenname „Eingang" zieht ebenfalls um.
        if documentCategories.contains("Sonstiges"), !documentCategories.contains("Unsortiert") {
            renameCategory(from: "Sonstiges", to: "Unsortiert")
        }
        if documentCategories.contains("Eingang"), !documentCategories.contains("Unsortiert") {
            renameCategory(from: "Eingang", to: "Unsortiert")
        }
        // „Import" geht in „Unsortiert" auf (04.08.): Dokumente ziehen um,
        // die Gruppe verschwindet, künftige Importe landen in Unsortiert.
        if documentCategories.contains("Import") {
            if !documentCategories.contains("Unsortiert") {
                documentCategories.append("Unsortiert")
            }
            documents = documents.map { doc in
                var d = doc
                if d.category == "Import" { d.category = "Unsortiert"; d.subcategory = "" }
                return d
            }
            documentCategories.removeAll { $0 == "Import" }
            documentSubcategories.removeValue(forKey: "Import")
            homeFolderQuickView.removeAll { $0 == "Import" }
        }
        if importCategoryName == "Import" { importCategoryName = "Unsortiert" }
        migrateQuickAccessToFavorites()
        migriereAufAnschlaege()
        materialisiereIdeenWand()
        updateWidgetData()
    }

    // MARK: - Listen

    @discardableResult
    func addList(title: String, colorTag: Int = 0) -> UUID? {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        let neu = ListEntry(title: trimmed, colorTag: colorTag)
        lists.append(neu)
        haengeAufWand(.list, neu.id)
        return neu.id
    }

    func updateList(_ entry: ListEntry) {
        if let idx = lists.firstIndex(where: { $0.id == entry.id }) {
            lists[idx] = entry
        }
    }

    func updateNote(_ entry: NoteEntry) {
        if let idx = notes.firstIndex(where: { $0.id == entry.id }) {
            notes[idx] = entry
        }
    }

    // MARK: - Notiz-Anhänge (das Korkblatt: Fotos + verknüpfte Dokumente)

    func haengeFotoAnNotiz(_ noteID: UUID, bildData: Data) {
        let name = "notiz_\(UUID().uuidString).jpg"
        try? bildData.write(to: documentURL(for: name))
        if let i = notes.firstIndex(where: { $0.id == noteID }) {
            notes[i].fotos.append(name)
        }
    }
    func entferneFotoVonNotiz(_ name: String, notiz noteID: UUID) {
        if let i = notes.firstIndex(where: { $0.id == noteID }) {
            notes[i].fotos.removeAll { $0 == name }
        }
        try? FileManager.default.removeItem(at: documentURL(for: name))
    }
    func verknuepfeDokument(_ docID: UUID, mitNotiz noteID: UUID) {
        if let i = notes.firstIndex(where: { $0.id == noteID }),
           !notes[i].verknuepfteDokumente.contains(docID) {
            notes[i].verknuepfteDokumente.append(docID)
        }
    }
    func loeseDokumentVerknuepfung(_ docID: UUID, notiz noteID: UUID) {
        if let i = notes.firstIndex(where: { $0.id == noteID }) {
            notes[i].verknuepfteDokumente.removeAll { $0 == docID }
        }
    }

    func addQuickIdea(title: String, text: String) {
        let cleanTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanText  = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanTitle.isEmpty || !cleanText.isEmpty else { return }
        let neu = NoteEntry(title: cleanTitle, text: cleanText, isQuickIdea: true)
        notes.insert(neu, at: 0)
        haengeAufWand(.note, neu.id)
    }

    /// Was von einer Wand aus angelegt wurde, hängt hinterher dort.
    private func haengeAufWand(_ kind: FavoriteKind, _ refID: UUID) {
        guard let ziel = wandZiel else { return }
        let a = anpinnen(kind: kind, refID: refID, auf: ziel.board)
        if let p = ziel.platz, p.count == 2 {
            merkePlatz(anschlagID: a.id, x: p[0], y: p[1])
        }
        wandZiel = nil
    }

    func addNote(title: String, text: String, colorTag: Int = 0) {
        let cleanTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanTitle.isEmpty || !cleanText.isEmpty else { return }
        notes.append(NoteEntry(title: cleanTitle, text: cleanText, colorTag: colorTag))
    }

    func updateVaultEntry(_ entry: VaultEntry) {
        if let idx = vaultItems.firstIndex(where: { $0.id == entry.id }) {
            vaultItems[idx] = entry
        }
    }

    // MARK: - Favoriten (Stern auf jedem Eintrag; „fest" = ganz vorn)

    /// Die Favoriten-Reihe auf dem Start: alle Typen gemischt,
    /// festgepinnte zuerst, danach die jüngsten vorn.
    // MARK: - Die Wand: anpinnen statt Favorit
    //
    // Favoriten, Schreibtisch und Ideen-Pinnwand meinten immer dasselbe:
    // „das will ich vorne haben". Ab hier gibt es dafür EINEN Begriff —
    // den Anschlag an einer Wand. `isFavorite` in den Modellen ist damit
    // nur noch Altlast für die Migration; gelesen wird es nicht mehr.

    /// Die Standard-Wand, auf der alles landet, was ohne Nachfrage
    /// angepinnt wird. Tresor-Einträge gehen auf ihre eigene, unsichtbare
    /// Wand — Passwörter hängen nie öffentlich.
    func standardBoard(fuer kind: FavoriteKind) -> UUID {
        kind == .vault ? SystemBoard.tresor : SystemBoard.meineWand
    }

    /// Anschläge einer Wand — ohne die, deren Original es nicht mehr gibt.
    func anschlaege(auf boardID: UUID) -> [Anschlag] {
        anschlaege.filter { $0.boardID == boardID && originalExistiert($0) }
    }

    func originalExistiert(_ a: Anschlag) -> Bool {
        switch a.kind {
        case .document: return documents.contains { $0.id == a.refID }
        case .note:     return notes.contains { $0.id == a.refID }
        case .list:     return lists.contains { $0.id == a.refID }
        case .vault:    return vaultItems.contains { $0.id == a.refID }
        }
    }

    func istAngepinnt(kind: FavoriteKind, refID: UUID, auf boardID: UUID? = nil) -> Bool {
        let board = boardID ?? standardBoard(fuer: kind)
        return anschlaege.contains { $0.boardID == board && $0.kindRaw == kind.rawValue && $0.refID == refID }
    }

    @discardableResult
    func anpinnen(kind: FavoriteKind, refID: UUID, auf boardID: UUID? = nil,
                  festVorn: Bool = false) -> Anschlag {
        let board = boardID ?? standardBoard(fuer: kind)
        if let vorhanden = anschlaege.first(where: {
            $0.boardID == board && $0.kindRaw == kind.rawValue && $0.refID == refID }) {
            return vorhanden
        }
        // Neigung würfeln, aber aus der ID — dann sieht der Zettel auf
        // jedem Gerät gleich schief aus.
        let saat = refID.uuidString.unicodeScalars.reduce(0) { $0 + Int($1.value) }
        let neu = Anschlag(boardID: board, kind: kind, refID: refID,
                           drehung: Double(saat % 7 - 3) * 1.4,
                           festVorn: festVorn)
        anschlaege.append(neu)
        return neu
    }

    func abpinnen(kind: FavoriteKind, refID: UUID, von boardID: UUID? = nil) {
        let board = boardID ?? standardBoard(fuer: kind)
        anschlaege.removeAll { $0.boardID == board && $0.kindRaw == kind.rawValue && $0.refID == refID }
    }

    /// Alle Anschläge eines Originals — für „ganz von der Wand nehmen"
    /// und fürs Aufräumen nach dem Löschen.
    func abpinnenUeberall(refID: UUID) {
        anschlaege.removeAll { $0.refID == refID }
    }

    /// Platz auf der Wand merken (relative Koordinaten, 0…1).
    func merkePlatz(anschlagID: UUID, x: Double, y: Double) {
        guard let i = anschlaege.firstIndex(where: { $0.id == anschlagID }) else { return }
        anschlaege[i].x = min(max(x, 0), 1)
        anschlaege[i].y = min(max(y, 0), 1)
        anschlaege[i].platziert = true
    }

    // MARK: Die Startreihe (aus Anschlägen gebaut)

    var favoriteItems: [FavoriteItem] {
        var all: [FavoriteItem] = []
        for a in anschlaege where a.boardID == SystemBoard.meineWand || a.boardID == SystemBoard.tresor {
            switch a.kind {
            case .document:
                guard let d = documents.first(where: { $0.id == a.refID }) else { continue }
                all.append(FavoriteItem(id: d.id, kind: .document, title: d.title,
                                        subtitle: d.type.rawValue, pinned: a.festVorn, date: d.dateAdded))
            case .note:
                guard let n = notes.first(where: { $0.id == a.refID }) else { continue }
                all.append(FavoriteItem(id: n.id, kind: .note, title: n.title.isEmpty ? "Notiz" : n.title,
                                        subtitle: n.isQuickIdea ? "Blitzidee" : "Idee",
                                        pinned: a.festVorn, date: n.dateCreated))
            case .list:
                guard let l = lists.first(where: { $0.id == a.refID }) else { continue }
                let open = l.items.filter { !$0.isDone }.count
                all.append(FavoriteItem(id: l.id, kind: .list, title: l.title,
                                        subtitle: open > 0 ? "\(open) offen" : "Erledigt",
                                        pinned: a.festVorn, date: l.dateCreated))
            case .vault:
                guard let v = vaultItems.first(where: { $0.id == a.refID }), v.art != .karte else { continue }
                all.append(FavoriteItem(id: v.id, kind: .vault, title: v.title,
                                        subtitle: "Face ID", pinned: a.festVorn, date: v.dateCreated))
            }
        }
        return all.sorted { a, b in
            if a.pinned != b.pinned { return a.pinned }
            return a.date > b.date
        }
    }

    /// Alter Name, neue Mechanik — der Stern in der Oberfläche pinnt an.
    /// Legt mehrere Notizen zu einer zusammen.
    ///
    /// Beim Diktieren waechst ein Gedanke ueber zwei Aufnahmen: die erste
    /// ist danach ein Bruchstueck. Statt sie zu loeschen und neu zu
    /// sprechen, wandern die Texte zusammen.
    ///
    /// Zusammengelegt wird in die AELTESTE — sie ist der Keim, und ihre
    /// Identitaet bleibt erhalten. Das ist kein Detail: haengt an ihr ein
    /// Anschlag (angepinnt), ueberlebt der. Eine neue Notiz haette ihn
    /// verwaist zurueckgelassen.
    ///
    /// Fotos und Dokumentverknuepfungen ALLER Beteiligten wandern mit —
    /// ein Zusammenlegen, das Anhaenge verliert, waere schlimmer als keins.
    ///
    /// Gibt die ID der ueberlebenden Notiz zurueck.
    @discardableResult
    func legeNotizenZusammen(_ ids: [UUID]) -> UUID? {
        let beteiligte = notes.filter { ids.contains($0.id) }
            .sorted { $0.dateCreated < $1.dateCreated }
        guard beteiligte.count > 1, let keim = beteiligte.first,
              let keimIdx = notes.firstIndex(where: { $0.id == keim.id })
        else { return nil }

        // Texte in zeitlicher Reihenfolge. Der Titel einer angehaengten
        // Notiz geht nicht verloren — er wird ihre Ueberschrift im Text.
        var teile: [String] = []
        for (i, n) in beteiligte.enumerated() {
            let titel = n.title.trimmingCharacters(in: .whitespacesAndNewlines)
            let text  = n.text.trimmingCharacters(in: .whitespacesAndNewlines)
            if i == 0 {
                if !text.isEmpty { teile.append(text) }
            } else {
                if !titel.isEmpty, titel != keim.title { teile.append(titel) }
                if !text.isEmpty { teile.append(text) }
            }
        }

        var fotos = keim.fotos
        var dokumente = keim.verknuepfteDokumente
        for n in beteiligte.dropFirst() {
            for f in n.fotos where !fotos.contains(f) { fotos.append(f) }
            for d in n.verknuepfteDokumente where !dokumente.contains(d) { dokumente.append(d) }
        }

        notes[keimIdx].text = teile.joined(separator: "\n\n")
        notes[keimIdx].fotos = fotos
        notes[keimIdx].verknuepfteDokumente = dokumente
        notes[keimIdx].geaendertAm = Date()
        // Eine zusammengelegte Notiz ist keine fluechtige Blitzidee mehr.
        notes[keimIdx].isQuickIdea = false

        let wegfallend = Set(beteiligte.dropFirst().map(\.id))
        for id in wegfallend { abpinnen(kind: .note, refID: id) }
        notes.removeAll { wegfallend.contains($0.id) }

        return keim.id
    }

    func toggleFavorite(kind: FavoriteKind, id: UUID) {
        if istAngepinnt(kind: kind, refID: id) {
            abpinnen(kind: kind, refID: id)
        } else {
            anpinnen(kind: kind, refID: id)
        }
    }

    func toggleFavoritePin(kind: FavoriteKind, id: UUID) {
        let board = standardBoard(fuer: kind)
        guard let i = anschlaege.firstIndex(where: {
            $0.boardID == board && $0.kindRaw == kind.rawValue && $0.refID == id }) else { return }
        anschlaege[i].festVorn.toggle()
    }

    // MARK: Wände verwalten

    @discardableResult
    func neuesBoard(name: String, stil: WandStil = .korkNatur) -> PinnBoard {
        let sauber = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let hoechste = pinnBoards.filter { $0.art == .wand || $0.art == .ideen }
            .map(\.reihenfolge).max() ?? 0
        let board = PinnBoard(name: sauber.isEmpty ? "Neue Wand" : sauber,
                              art: .wand, stil: stil, reihenfolge: hoechste + 1)
        pinnBoards.append(board)
        return board
    }

    func benenneBoard(_ id: UUID, auf name: String) {
        let sauber = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !sauber.isEmpty, let i = pinnBoards.firstIndex(where: { $0.id == id }) else { return }
        pinnBoards[i].name = sauber
    }

    func setzeStil(_ id: UUID, _ stil: WandStil) {
        guard let i = pinnBoards.firstIndex(where: { $0.id == id }) else { return }
        pinnBoards[i].stilRaw = stil.rawValue
    }

    func setzeSymbol(_ id: UUID, _ symbol: WandSymbol) {
        guard let i = pinnBoards.firstIndex(where: { $0.id == id }) else { return }
        pinnBoards[i].symbolRaw = symbol.rawValue
    }

    func archiviereBoard(_ id: UUID, _ an: Bool = true) {
        guard let i = pinnBoards.firstIndex(where: { $0.id == id }) else { return }
        pinnBoards[i].archiviert = an
    }

    /// Eine Wand abreißen. Die Anschläge fallen mit — die Originale nicht.
    func loescheBoard(_ id: UUID) {
        anschlaege.removeAll { $0.boardID == id }
        pinnBoards.removeAll { $0.id == id }
    }

    // MARK: Migration auf die Wand

    /// Einmalig: Favoriten und das alte Ideen-Layout werden Anschläge.
    /// Läuft auf jedem Gerät für sich — die Anschlag-IDs sind aus
    /// (Wand, Art, Original) abgeleitet, deshalb kommen alle Geräte auf
    /// dasselbe Ergebnis und der Sync führt nichts doppelt zusammen.
    private func migriereAufAnschlaege() {
        // Die festen Wände anlegen, falls sie fehlen (auch nach einem Sync
        // von einem Gerät, das sie noch nicht kannte).
        let bekannt = Set(pinnBoards.map(\.id))
        let fehlende = SystemBoard.vorgaben.filter { !bekannt.contains($0.id) }
        if !fehlende.isEmpty {
            pinnBoards.append(contentsOf: fehlende)
            // Die Migration läuft mitten im Laden — da schweigt das didSet.
            // Also übers Nachfusions-Fach speichern lassen.
            nachfusionSpeichern.insert("pinnBoards")
        }

        guard !UserDefaults.standard.bool(forKey: "anschlaegeMigriert") else {
            raeumeToteAnschlaegeAuf()
            return
        }
        // Nicht migrieren, solange die Bestände noch aus iCloud tröpfeln —
        // sonst wandert nur die Hälfte und der Rest gilt als abgepinnt.
        guard !hasPendingCloudDataDownloads() else { return }

        var neue: [Anschlag] = []
        func pinne(_ kind: FavoriteKind, _ refID: UUID, fest: Bool, datum: Date) {
            let board = standardBoard(fuer: kind)
            let id = Anschlag.abgeleiteteID(board: board, kind: kind, ref: refID)
            // Ein Grabstein heißt: auf einem anderen Gerät schon abgepinnt.
            // Dann darf das alte `isFavorite` ihn nicht wiederbeleben.
            guard grabsteine[id] == nil,
                  !anschlaege.contains(where: { $0.id == id }),
                  !neue.contains(where: { $0.id == id }) else { return }
            let saat = refID.uuidString.unicodeScalars.reduce(0) { $0 + Int($1.value) }
            var a = Anschlag(boardID: board, kind: kind, refID: refID,
                             drehung: Double(saat % 7 - 3) * 1.4, festVorn: fest)
            a.geaendertAm = datum
            neue.append(a)
        }
        for d in documents  where d.isFavorite { pinne(.document, d.id, fest: d.favoritePinned, datum: d.geaendertAm) }
        for n in notes      where n.isFavorite { pinne(.note,     n.id, fest: n.favoritePinned, datum: n.geaendertAm) }
        for l in lists      where l.isFavorite { pinne(.list,     l.id, fest: l.favoritePinned, datum: l.geaendertAm) }
        for v in vaultItems where v.isFavorite { pinne(.vault,    v.id, fest: v.favoritePinned, datum: v.geaendertAm) }

        // Das alte Ideen-Layout: absolute Punkte gab es nur in Gerätemaßen.
        // Wir rechnen sie an einer angenommenen Wandgröße auf 0…1 um —
        // ungefähr richtig ist besser als ein Haufen auf der Startposition.
        let angenommeneBreite = 390.0, angenommeneHoehe = 780.0
        for (idText, xy) in pinnwandLayout where xy.count == 2 {
            guard let refID = UUID(uuidString: idText),
                  notes.contains(where: { $0.id == refID }) else { continue }
            let id = Anschlag.abgeleiteteID(board: SystemBoard.ideen, kind: .note, ref: refID)
            guard grabsteine[id] == nil,
                  !anschlaege.contains(where: { $0.id == id }),
                  !neue.contains(where: { $0.id == id }) else { continue }
            let saat = refID.uuidString.unicodeScalars.reduce(0) { $0 + Int($1.value) }
            neue.append(Anschlag(boardID: SystemBoard.ideen, kind: .note, refID: refID,
                                 x: min(max(xy[0] / angenommeneBreite, 0), 1),
                                 y: min(max(xy[1] / angenommeneHoehe, 0), 1),
                                 drehung: Double(saat % 7 - 3) * 1.4,
                                 platziert: true))
        }

        if !neue.isEmpty {
            anschlaege.append(contentsOf: neue)
            nachfusionSpeichern.insert("anschlaege")
        }
        UserDefaults.standard.set(true, forKey: "anschlaegeMigriert")
    }

    /// Die Ideen-Wand hat ihre Zettel früher nur gespiegelt — sie hingen
    /// ohne eigenen Anschlag da. Jetzt ist sie eine Wand wie jede andere,
    /// also bekommt jede Idee einen echten Anschlag. Ohne das verschwänden
    /// beim Umbau alle Zettel, die nie verschoben wurden.
    private func materialisiereIdeenWand() {
        guard !UserDefaults.standard.bool(forKey: "ideenWandMaterialisiert") else { return }
        guard !hasPendingCloudDataDownloads() else { return }
        guard !notes.isEmpty || pinnBoards.contains(where: { $0.id == SystemBoard.ideen }) else { return }

        let schonDa = Set(anschlaege.filter { $0.boardID == SystemBoard.ideen }.map(\.refID))
        var neue: [Anschlag] = []
        for n in notes where !schonDa.contains(n.id) {
            let id = Anschlag.abgeleiteteID(board: SystemBoard.ideen, kind: .note, ref: n.id)
            guard grabsteine[id] == nil else { continue }
            let saat = n.id.uuidString.unicodeScalars.reduce(0) { $0 + Int($1.value) }
            var a = Anschlag(boardID: SystemBoard.ideen, kind: .note, refID: n.id,
                             drehung: Double(saat % 7 - 3) * 1.4)
            a.geaendertAm = n.geaendertAm
            neue.append(a)
        }
        if !neue.isEmpty {
            anschlaege.append(contentsOf: neue)
            nachfusionSpeichern.insert("anschlaege")
        }
        // Aus dem Spiegel wird eine gewöhnliche Wand.
        if let i = pinnBoards.firstIndex(where: { $0.id == SystemBoard.ideen }),
           pinnBoards[i].art == .ideen {
            pinnBoards[i].artRaw = BoardArt.wand.rawValue
            nachfusionSpeichern.insert("pinnBoards")
        }
        UserDefaults.standard.set(true, forKey: "ideenWandMaterialisiert")
    }

    /// Anschläge wegräumen, deren Original nachweislich gelöscht wurde.
    /// Nur bei echtem Grabstein — ein noch nicht geladener Bestand darf
    /// niemals als „gelöscht" durchgehen.
    private func raeumeToteAnschlaegeAuf() {
        let tot = anschlaege.filter { grabsteine[$0.refID] != nil }
        guard !tot.isEmpty else { return }
        let ids = Set(tot.map(\.id))
        anschlaege.removeAll { ids.contains($0.id) }
        nachfusionSpeichern.insert("anschlaege")
    }

    /// Der alte Einzel-Schnellzugriff wird einmalig zum festgepinnten
    /// Favoriten (Dokument/Notiz) bzw. zur Ordner-Schnellansicht (Gruppe).
    private func migrateQuickAccessToFavorites() {
        let ud = UserDefaults.standard
        guard let kind = ud.string(forKey: "quickAccessKind"), !kind.isEmpty else { return }
        let idString = ud.string(forKey: "quickAccessId") ?? ""
        if kind == "doc", let id = UUID(uuidString: idString),
           let idx = documents.firstIndex(where: { $0.id == id }) {
            documents[idx].isFavorite = true
            documents[idx].favoritePinned = true
        } else if kind == "note", let id = UUID(uuidString: idString),
                  let idx = notes.firstIndex(where: { $0.id == id }) {
            notes[idx].isFavorite = true
            notes[idx].favoritePinned = true
        } else if kind == "category",
                  documentCategories.contains(idString),
                  !homeFolderQuickView.contains(idString) {
            homeFolderQuickView.append(idString)
        }
        ["quickAccessKind", "quickAccessId", "quickAccessTitle"].forEach { ud.removeObject(forKey: $0) }
    }

    func addVaultEntry(title: String, username: String, password: String, url: String = "",
                       sperrHotline: String = "", colorTag: Int = 0) {
        let cleanTitle    = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanUsername = username.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanPassword = password.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanURL      = url.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanHotline  = sperrHotline.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanTitle.isEmpty, !cleanPassword.isEmpty else { return }
        vaultItems.append(VaultEntry(title: cleanTitle, username: cleanUsername,
                                     password: cleanPassword, url: cleanURL,
                                     sperrHotline: cleanHotline, colorTag: colorTag))
    }

    /// Fügt einen fertig zusammengestellten Eintrag hinzu — auch unvollständig
    /// (für Kreditkarten: Hans darf speichern, bevor alle Felder gefüllt sind).
    func addVaultEntry(_ entry: VaultEntry) {
        vaultItems.append(entry)
    }

    /// Speichert ein eingescanntes Karten-Foto (JPEG) und liefert den Dateinamen.
    /// Foto einer Medikamentenpackung. Liegt neben den anderen Dateien und
    /// kommt ueber `gesicherteDateinamen` mit in die Sicherung.
    ///
    /// Beim Loeschen eines Eintrags bleibt die Datei bewusst liegen — wie bei
    /// Notizfotos. Ein verwaistes Bild kostet ein paar Kilobyte; eine Datei,
    /// die ein anderes Geraet waehrend des Abgleichs noch braucht, zu frueh
    /// zu loeschen, kostet das Bild.
    func speichereNotfallFoto(_ data: Data) -> String {
        let name = "notfall_\(UUID().uuidString).jpg"
        do { try data.write(to: documentURL(for: name), options: .atomic); return name }
        catch { return "" }
    }

    func speichereKartenBild(_ data: Data) -> String {
        let name = "karte_\(UUID().uuidString).jpg"
        let url = filesDirectory.appendingPathComponent(name)
        do { try data.write(to: url, options: .atomic); return name } catch { return "" }
    }
}
