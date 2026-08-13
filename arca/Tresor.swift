//
//  Tresor.swift
//  Arca
//
//  Passwörter: Liste, Detail, neuer Eintrag, Generator.
//  (Aus ContentView.swift herausgelöst — Code unverändert.)
//
//  Entwickler: Hans zen Ruffinen
//

import SwiftUI
import UniformTypeIdentifiers
import VisionKit
import Vision

// MARK: - Vault

// MARK: - Quick-Templates für Passwörter

struct VaultTemplate: Identifiable {
    let id = UUID()
    let emoji: String
    let label: String
    let colorTag: Int

    static let all: [VaultTemplate] = [
        VaultTemplate(emoji: "🌐", label: "Webseite", colorTag: 2),  // Blau
        VaultTemplate(emoji: "📧", label: "E-Mail",   colorTag: 5),  // Pfirsich
        VaultTemplate(emoji: "🏦", label: "Bank",     colorTag: 3),  // Grün
        VaultTemplate(emoji: "📱", label: "App",      colorTag: 4),  // Lila
        VaultTemplate(emoji: "🛒", label: "Shop",     colorTag: 1),  // Rosa
        VaultTemplate(emoji: "🔑", label: "Sonstiges", colorTag: 0), // Gelb
    ]
}

struct VaultView: View {
    @EnvironmentObject var store: AppStore
    @State private var selectedItem: VaultEntry? = nil
    @State private var showNewEntry = false
    @State private var searchText = ""
    @State private var copiedItemID: UUID? = nil
    @State private var renamingItem: VaultEntry? = nil
    @State private var showSecurityAlert = false
    @State private var renameItemText = ""
    @AppStorage("vaultSortOption") private var sortOption: String = "newest"
    @AppStorage("vaultFilterColor") private var filterColor: Int = -1

    private var filteredItems: [VaultEntry] {
        var items = searchText.isEmpty ? store.vaultItems : store.vaultItems.filter {
            $0.title.localizedCaseInsensitiveContains(searchText) ||
            $0.username.localizedCaseInsensitiveContains(searchText)
        }
        if filterColor >= 0 {
            items = items.filter { $0.colorTag == filterColor }
        }
        switch sortOption {
        case "oldest":   items.sort { $0.dateCreated < $1.dateCreated }
        case "az":       items.sort { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
        case "color":    items.sort { $0.colorTag < $1.colorTag }
        case "weak":     items.sort { $0.password.count < $1.password.count }
        default:         items.sort { $0.dateCreated > $1.dateCreated }
        }
        items.sort { $0.isFavorite && !$1.isFavorite }
        return items
    }

    var body: some View {
        vaultBody
    }

    // Einspaltiges Layout — auf iPhone wie iPad (in der Detailspalte der Sidebar-SplitView).
    // Bewusst keine eigene Master-Detail-HStack mehr: die führte auf dem iPad zu einer
    // dritten, zu engen Spalte (Guideline 4 "crowded interface").
    private var vaultBody: some View {
        NavigationStack {
            VStack(spacing: 0) {
                AddTriggerButton(
                    label: "Neues Passwort",
                    subtitle: "Kategorie · Zugangsdaten · Passwort",
                    icon: "plus"
                ) { showNewEntry = true }
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .padding(.bottom, 4)
                vaultList
            }
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Image(systemName: "key.fill")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(.secondary)
                }
                ToolbarItem(placement: .navigationBarTrailing) { vaultTrailingToolbar }
            }
            .sheet(isPresented: $showNewEntry, onDismiss: {
                // Abgebrochen? Dann bleibt die Quell-Notiz unangetastet.
                store.vaultVorbefuellung = nil
                store.notizNachTresorUmwandlung = nil
            }) { vaultNewEntrySheet }
            // Erfassen vom Start: „Neu"-Blatt direkt öffnen
            .onAppear {
                if store.pendingNewEntry == .vault {
                    store.pendingNewEntry = nil
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { showNewEntry = true }
                }
            }
            .onChange(of: store.pendingNewEntry) { _, wert in
                // Plus gedrückt, während der Bereich schon offen ist
                if wert == .vault {
                    store.pendingNewEntry = nil
                    showNewEntry = true
                }
            }
            .sheet(item: $selectedItem) { item in VaultDetailView(item: item) }
        }
    }

    private var vaultTrailingToolbar: some View {
        HStack(spacing: 6) {
            let weakCount = store.vaultItems.filter { $0.password.count < 8 }.count
            let passwords = store.vaultItems.map { $0.password }
            let dupeCount = passwords.count - Set(passwords).count
            let total = weakCount + dupeCount
            if total > 0 {
                Button { showSecurityAlert = true } label: {
                    Label("\(total)", systemImage: "exclamationmark.shield.fill")
                        .font(.caption.bold())
                        .foregroundStyle(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.red)
                        .clipShape(Capsule())
                }
                .alert("Sicherheitshinweis", isPresented: $showSecurityAlert) {
                    Button("OK") {}
                } message: {
                    let weakCount = store.vaultItems.filter { $0.password.count < 8 }.count
                    let passwords = store.vaultItems.map { $0.password }
                    let dupeCount = passwords.count - Set(passwords).count
                    let lines = [
                        weakCount > 0 ? "• \(weakCount) schwache\(weakCount == 1 ? "s" : "") Passwort\(weakCount == 1 ? "" : "wörter") (kürzer als 8 Zeichen)" : nil,
                        dupeCount > 0 ? "• \(dupeCount) mehrfach verwendete\(dupeCount == 1 ? "s" : "") Passwort\(dupeCount == 1 ? "" : "wörter")" : nil
                    ].compactMap { $0 }
                    Text(lines.joined(separator: "\n"))
                }
            }
            sortFilterMenu
        }
    }

    @ViewBuilder
    private var vaultNewEntrySheet: some View {
        NewVaultEntrySheet(startTitel: store.vaultVorbefuellung ?? "") { entry in
            store.addVaultEntry(entry)
            // Blitzidee → Passwort: die Quell-Notiz ist jetzt einsortiert
            if let notizID = store.notizNachTresorUmwandlung {
                store.notes.removeAll { $0.id == notizID }
            }
            store.vaultVorbefuellung = nil
            store.notizNachTresorUmwandlung = nil
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            showNewEntry = false
        }
        .environmentObject(store)
    }

    // MARK: Vault List

    private var vaultList: some View {
        List {
            if filteredItems.isEmpty {
                Text(store.vaultItems.isEmpty ? "Noch keine Einträge vorhanden." : "Keine Treffer.")
                    .foregroundStyle(.secondary)
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
            } else {
                ForEach(filteredItems) { item in
                    VaultRow(item: item, copiedItemID: $copiedItemID)
                        .contentShape(Rectangle())
                        .onTapGesture { selectedItem = item }
                        .listRowBackground(Color(.secondarySystemBackground))
                        .listRowSeparator(.visible)
                        .listRowSeparatorTint(Color.primary.opacity(0.06))
                        .listRowInsets(EdgeInsets(top: 0, leading: 16, bottom: 0, trailing: 12))
                        .contextMenu {
                            ArcaMenue.favorit(ist: item.isFavorite) {
                                if let idx = store.vaultItems.firstIndex(where: { $0.id == item.id }) {
                                    store.vaultItems[idx].isFavorite.toggle()
                                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                }
                            }
                            Divider()
                            ArcaMenue.umbenennen {
                                renameItemText = item.title
                                renamingItem = item
                            }
                            ArcaMenue.farbe(aktuell: item.colorTag) { idx in
                                if let i = store.vaultItems.firstIndex(where: { $0.id == item.id }) {
                                    store.vaultItems[i].colorTag = idx
                                }
                            }
                            ArcaMenue.loeschen {
                                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                                store.vaultItems.removeAll { $0.id == item.id }
                            }
                        }
                        .swipeActions(edge: .leading) {
                            Button {
                                if let idx = store.vaultItems.firstIndex(where: { $0.id == item.id }) {
                                    store.vaultItems[idx].isFavorite.toggle()
                                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                }
                            } label: {
                                Label(item.isFavorite ? "Aus Favoriten" : "Favorit",
                                      systemImage: item.isFavorite ? "star.slash" : "star.fill")
                            }
                            .tint(.orange)
                            Button {
                                renameItemText = item.title
                                renamingItem = item
                            } label: {
                                Label("Umbenennen", systemImage: "pencil")
                            }
                            .tint(.blue)
                        }
                }
                .onDelete { indexSet in
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                    let toDelete = indexSet.map { filteredItems[$0] }
                    store.vaultItems.removeAll { item in toDelete.contains { $0.id == item.id } }
                }
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .searchable(text: $searchText, prompt: "Suchen…")
        .alert("Eintrag umbenennen", isPresented: Binding(
            get: { renamingItem != nil },
            set: { if !$0 { renamingItem = nil } }
        )) {
            TextField("Neuer Name", text: $renameItemText)
            Button("Speichern") {
                if let item = renamingItem {
                    let trimmed = renameItemText.trimmingCharacters(in: .whitespacesAndNewlines)
                    if !trimmed.isEmpty,
                       let idx = store.vaultItems.firstIndex(where: { $0.id == item.id }) {
                        store.vaultItems[idx].title = trimmed
                    }
                }
                renamingItem = nil
            }
            Button("Abbrechen", role: .cancel) { renamingItem = nil }
        }
    }

    // MARK: Sort & Filter Menu

    private var sortFilterMenu: some View {
        Menu {
            Picker("Sortierung", selection: $sortOption) {
                Label("Neueste zuerst", systemImage: "arrow.down").tag("newest")
                Label("Älteste zuerst", systemImage: "arrow.up").tag("oldest")
                Label("A–Z", systemImage: "textformat").tag("az")
                Label("Nach Farbe", systemImage: "paintpalette.fill").tag("color")
                Label("Schwache zuerst", systemImage: "exclamationmark.shield.fill").tag("weak")
            }
            Divider()
            Menu {
                Button {
                    filterColor = -1
                } label: {
                    Label("Alle Farben", systemImage: filterColor == -1 ? "checkmark" : "circle")
                }
                ForEach(0..<NoteColor.palette.count, id: \.self) { idx in
                    Button {
                        filterColor = idx
                    } label: {
                        Label(NoteColor.palette[idx].name,
                              systemImage: filterColor == idx ? "checkmark" : "circle.fill")
                    }
                }
            } label: {
                Label(filterColor == -1 ? "Filter: Alle" : "Filter: \(NoteColor.for_(filterColor).name)",
                      systemImage: "line.3.horizontal.decrease.circle")
            }
        } label: {
            Image(systemName: filterColor == -1 ? "arrow.up.arrow.down.circle"
                                                : "line.3.horizontal.decrease.circle.fill")
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(filterColor == -1 ? Color.primary : NoteColor.for_(filterColor).accent)
        }
    }
}

// MARK: - New Vault Entry Sheet

// MARK: - Kreditkarten-Optik

// Karten-Scanner (VisionKit schneidet die Karte automatisch zu + OCR)
struct ArcaKartenScanner: UIViewControllerRepresentable {
    let onScan: (UIImage, String) -> Void
    let onCancel: () -> Void

    func makeUIViewController(context: Context) -> VNDocumentCameraViewController {
        let s = VNDocumentCameraViewController()
        s.delegate = context.coordinator
        return s
    }
    func updateUIViewController(_ c: VNDocumentCameraViewController, context: Context) {}
    func makeCoordinator() -> Coordinator { Coordinator(onScan: onScan, onCancel: onCancel) }

    final class Coordinator: NSObject, VNDocumentCameraViewControllerDelegate {
        let onScan: (UIImage, String) -> Void
        let onCancel: () -> Void
        init(onScan: @escaping (UIImage, String) -> Void, onCancel: @escaping () -> Void) {
            self.onScan = onScan; self.onCancel = onCancel
        }
        func documentCameraViewController(_ controller: VNDocumentCameraViewController, didFinishWith scan: VNDocumentCameraScan) {
            guard scan.pageCount > 0 else { onCancel(); return }
            let bild = scan.imageOfPage(at: 0)
            var text = ""
            if let cg = bild.cgImage {
                let req = VNRecognizeTextRequest()
                req.recognitionLevel = .accurate
                req.recognitionLanguages = ["en-US", "de-DE", "fr-FR"]
                req.usesLanguageCorrection = false   // Ziffern nicht „verbessern"
                let ausrichtung = CGImagePropertyOrientation(bild.imageOrientation)
                try? VNImageRequestHandler(cgImage: cg, orientation: ausrichtung).perform([req])
                text = (req.results ?? []).compactMap { $0.topCandidates(1).first?.string }.joined(separator: "\n")
            }
            onScan(bild, text)
        }
        func documentCameraViewControllerDidCancel(_ c: VNDocumentCameraViewController) { onCancel() }
        func documentCameraViewController(_ c: VNDocumentCameraViewController, didFailWithError error: Error) { onCancel() }
    }
}

extension CGImagePropertyOrientation {
    init(_ o: UIImage.Orientation) {
        switch o {
        case .up: self = .up
        case .down: self = .down
        case .left: self = .left
        case .right: self = .right
        case .upMirrored: self = .upMirrored
        case .downMirrored: self = .downMirrored
        case .leftMirrored: self = .leftMirrored
        case .rightMirrored: self = .rightMirrored
        @unknown default: self = .up
        }
    }
}

/// Luhn-Prüfsumme — echte Kartennummern erfüllen sie.
private func luhnGueltig(_ s: String) -> Bool {
    let ziffern = s.compactMap { $0.wholeNumberValue }
    guard ziffern.count >= 12 else { return false }
    var summe = 0
    for (i, v) in ziffern.reversed().enumerated() {
        if i % 2 == 1 { let t = v * 2; summe += t > 9 ? t - 9 : t } else { summe += v }
    }
    return summe % 10 == 0
}

private func regexTreffer(_ muster: String, in text: String) -> [String] {
    guard let re = try? NSRegularExpression(pattern: muster) else { return [] }
    let ns = text as NSString
    return re.matches(in: text, range: NSRange(location: 0, length: ns.length))
        .map { ns.substring(with: $0.range) }
}

/// Best-effort-Erkennung von Nummer / Gültigkeit / Inhaber aus dem OCR-Text.
func parseKarte(_ text: String) -> (nummer: String, ablauf: String, inhaber: String) {
    let zeilen = text.split(separator: "\n").map(String.init)

    // Nummer: alle Zifferngruppen in Lesereihenfolge zusammensetzen — die OCR
    // liefert die vier Vierergruppen oft als EINZELNE Blöcke/Zeilen.
    let tokens = text.split(whereSeparator: { !$0.isNumber }).map(String.init).filter { !$0.isEmpty }
    func nummerAusFenster(pruefeLuhn: Bool) -> String? {
        for i in tokens.indices {
            var acc = ""
            for j in i..<tokens.count {
                acc += tokens[j]
                if acc.count > 19 { break }
                if (13...19).contains(acc.count) && (!pruefeLuhn || luhnGueltig(acc)) { return acc }
            }
        }
        return nil
    }
    let nummer = nummerAusFenster(pruefeLuhn: true)
        ?? tokens.first(where: { (13...19).contains($0.count) })
        ?? nummerAusFenster(pruefeLuhn: false)
        ?? ""

    // Gültigkeit MM/JJ (auch „VALID THRU 12/28")
    var ablauf = ""
    let flach = text.replacingOccurrences(of: " ", with: "")
    if let r = flach.range(of: #"(0[1-9]|1[0-2])/[0-9]{2}"#, options: .regularExpression) {
        ablauf = String(flach[r])
    }

    // Inhaber: GROSSBUCHSTABEN-Zeile mit 2+ Wörtern, ohne Ziffern/Schlüsselwörter
    var inhaber = ""
    let stop = ["VALID", "THRU", "MONTH", "GOOD", "CARD", "BANK", "VISA", "MASTERCARD",
                "MAESTRO", "DEBIT", "CREDIT", "EXPIRES", "MEMBER", "SINCE", "WORLD", "PLATINUM", "GOLD"]
    for z in zeilen {
        let t = z.trimmingCharacters(in: .whitespaces)
        if t.count < 6 || t.contains(where: \.isNumber) { continue }
        let up = t.uppercased()
        if stop.contains(where: { up.contains($0) }) { continue }
        if t != up || t.split(separator: " ").count < 2 { continue }
        inhaber = t; break
    }
    return (nummer, ablauf, inhaber)
}

// MARK: - Kreditkarten-Optik (Vorder-/Rückseite mit Umblättern)

struct ArcaKreditkarte: View {
    var nummer: String = ""
    var inhaber: String = ""
    var ablauf: String = ""
    var cvv: String = ""
    var farbe: NoteColor
    var maskiert: Bool = false
    var vorneBild: UIImage? = nil
    var hintenBild: UIImage? = nil
    var applePay: Bool = false
    @State private var hinten = false

    private var netzwerk: String {
        let d = nummer.filter(\.isNumber)
        if d.hasPrefix("4") { return "VISA" }
        if let z = Int(d.prefix(2)), (51...55).contains(z) || (22...27).contains(z) { return "Mastercard" }
        if d.hasPrefix("34") || d.hasPrefix("37") { return "AMEX" }
        return "Karte"
    }
    private var nummerAnzeige: String {
        var stellen = Array(nummer.filter(\.isNumber))
        if maskiert && stellen.count > 4 {
            stellen = Array(repeating: "•", count: stellen.count - 4) + Array(stellen.suffix(4))
        }
        while stellen.count < 16 { stellen.append("•") }
        return stride(from: 0, to: stellen.count, by: 4)
            .map { String(stellen[$0..<min($0 + 4, stellen.count)]) }
            .joined(separator: "  ")
    }

    var body: some View {
        ZStack {
            vorderseite.opacity(hinten ? 0 : 1)
            rueckseite.opacity(hinten ? 1 : 0).rotation3DEffect(.degrees(180), axis: (0, 1, 0))
        }
        .frame(maxWidth: .infinity)
        .frame(height: 200)
        .rotation3DEffect(.degrees(hinten ? 180 : 0), axis: (0, 1, 0))
        .shadow(color: farbe.accent.opacity(0.35), radius: 12, x: 0, y: 6)
        .contentShape(RoundedRectangle(cornerRadius: 20))
        .onTapGesture {
            withAnimation(.spring(response: 0.55, dampingFraction: 0.85)) { hinten.toggle() }
        }
    }

    @ViewBuilder private var vorderseite: some View {
        if let vorneBild {
            fotoSeite(vorneBild, applePayBadge: applePay)
        } else {
            generierteVorderseite
        }
    }
    @ViewBuilder private var rueckseite: some View {
        if let hintenBild {
            fotoSeite(hintenBild, applePayBadge: false)
        } else {
            generierteRueckseite
        }
    }

    private func fotoSeite(_ bild: UIImage, applePayBadge zeigen: Bool) -> some View {
        Image(uiImage: bild)
            .resizable().scaledToFill()
            .frame(maxWidth: .infinity).frame(height: 200)
            .clipShape(RoundedRectangle(cornerRadius: 20))
            .overlay(RoundedRectangle(cornerRadius: 20).strokeBorder(.white.opacity(0.18), lineWidth: 1))
            .overlay(alignment: .topTrailing) { if zeigen { applePayPille.padding(10) } }
            .overlay(alignment: .bottomTrailing) { flipHinweis.padding(10) }
    }

    private var generierteVorderseite: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top) {
                RoundedRectangle(cornerRadius: 5)
                    .fill(LinearGradient(colors: [Color(white: 0.95), Color(white: 0.72)],
                                         startPoint: .topLeading, endPoint: .bottomTrailing))
                    .frame(width: 40, height: 30)
                    .overlay(
                        VStack(spacing: 4) {
                            ForEach(0..<3, id: \.self) { _ in
                                Rectangle().fill(.black.opacity(0.12)).frame(height: 0.8)
                            }
                        }.padding(.horizontal, 6))
                    .overlay(RoundedRectangle(cornerRadius: 5).strokeBorder(.white.opacity(0.5), lineWidth: 0.5))
                Spacer()
                Text(netzwerk)
                    .font(.system(size: 16, weight: .heavy, design: .rounded)).italic()
                    .foregroundStyle(.white)
            }
            Spacer(minLength: 16)
            Text(nummerAnzeige)
                .font(.system(size: 19, weight: .semibold, design: .monospaced))
                .foregroundStyle(.white).lineLimit(1).minimumScaleFactor(0.7)
            Spacer(minLength: 16)
            HStack(alignment: .bottom) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("KARTENINHABER").font(.system(size: 7, weight: .semibold)).kerning(0.5).foregroundStyle(.white.opacity(0.65))
                    Text(inhaber.isEmpty ? "—" : inhaber.uppercased()).font(.system(size: 12, weight: .semibold)).foregroundStyle(.white).lineLimit(1)
                }
                Spacer()
                VStack(alignment: .leading, spacing: 2) {
                    Text("GÜLTIG").font(.system(size: 7, weight: .semibold)).kerning(0.5).foregroundStyle(.white.opacity(0.65))
                    Text(ablauf.isEmpty ? "MM/JJ" : ablauf).font(.system(size: 12, weight: .semibold, design: .monospaced)).foregroundStyle(.white)
                }
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity).frame(height: 200)
        .background { kartenGrund }
        .overlay(RoundedRectangle(cornerRadius: 20).strokeBorder(.white.opacity(0.18), lineWidth: 1))
        .overlay(alignment: .topTrailing) { if applePay { applePayPille.padding(10) } }
        .overlay(alignment: .bottomTrailing) { flipHinweis.padding(10) }
    }

    private var generierteRueckseite: some View {
        VStack(spacing: 0) {
            Spacer().frame(height: 22)
            Rectangle().fill(.black.opacity(0.85)).frame(height: 40)
            Spacer().frame(height: 18)
            HStack {
                Spacer()
                RoundedRectangle(cornerRadius: 3).fill(.white.opacity(0.9))
                    .frame(width: 130, height: 28)
                    .overlay(alignment: .trailing) {
                        Text(cvv.isEmpty ? "•••" : (maskiert ? "•••" : cvv))
                            .font(.system(size: 13, weight: .semibold, design: .monospaced))
                            .foregroundStyle(.black).padding(.trailing, 8)
                    }
            }
            .padding(.horizontal, 18)
            Spacer()
            Text("CVV").font(.system(size: 8, weight: .semibold))
                .foregroundStyle(.white.opacity(0.6))
                .frame(maxWidth: .infinity, alignment: .trailing).padding(.horizontal, 22)
        }
        .frame(maxWidth: .infinity).frame(height: 200)
        .background { kartenGrund }
        .overlay(RoundedRectangle(cornerRadius: 20).strokeBorder(.white.opacity(0.18), lineWidth: 1))
        .overlay(alignment: .bottomTrailing) { flipHinweis.padding(10) }
    }

    private var kartenGrund: some View {
        ZStack {
            LinearGradient(colors: [farbe.accent, farbe.accent.opacity(0.65), Color.black.opacity(0.4)],
                           startPoint: .topLeading, endPoint: .bottomTrailing)
            Circle().fill(.white.opacity(0.10)).frame(width: 230).blur(radius: 34).offset(x: 100, y: -80)
        }
        .clipShape(RoundedRectangle(cornerRadius: 20))
    }

    private var applePayPille: some View {
        HStack(spacing: 3) {
            Image(systemName: "applelogo").font(.system(size: 10))
            Text("Pay").font(.system(size: 11, weight: .semibold))
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 8).padding(.vertical, 4)
        .background(.black.opacity(0.28), in: Capsule())
        .overlay(Capsule().strokeBorder(.white.opacity(0.3), lineWidth: 0.5))
    }

    private var flipHinweis: some View {
        Image(systemName: "arrow.2.circlepath")
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(.white.opacity(0.55))
    }
}

struct NewVaultEntrySheet: View {
    let onSave: (VaultEntry) -> Void

    init(startTitel: String = "", onSave: @escaping (VaultEntry) -> Void) {
        self.onSave = onSave
        _title = State(initialValue: startTitel)
    }

    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var store: AppStore
    @State private var art: VaultArt = .passwort
    @State private var title = ""
    @State private var sperrHotline = ""
    @State private var username = ""
    @State private var password = ""
    @State private var url = ""
    // Kreditkarte
    @State private var kartennummer = ""
    @State private var karteninhaber = ""
    @State private var ablauf = ""
    @State private var pruefnummer = ""
    @State private var pin = ""
    @State private var vorneBild: UIImage?
    @State private var hintenBild: UIImage?
    @State private var inApplePay = false
    @State private var showScanner = false
    @State private var scanRueckseite = false
    @State private var selectedColor = 2
    @State private var showPassword = false
    @State private var showGenerator = false
    @FocusState private var focusedField: VaultField?

    enum VaultField { case title, username, password, url, nummer, inhaber, ablauf, cvv, pin }

    // Speichern ist immer erlaubt — auch unvollständig (Hans' Wunsch)
    private var canSave: Bool { true }
    private var color: NoteColor { NoteColor.for_(selectedColor) }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {

                    // Art: Passwort oder Kreditkarte
                    Picker("Art", selection: $art) {
                        Text("Passwort").tag(VaultArt.passwort)
                        Text("Kreditkarte").tag(VaultArt.karte)
                    }
                    .pickerStyle(.segmented)

                    // Live-Vorschau der Karte (tippen dreht sie um)
                    if art == .karte {
                        ArcaKreditkarte(nummer: kartennummer, inhaber: karteninhaber,
                                        ablauf: ablauf, cvv: pruefnummer, farbe: color,
                                        vorneBild: vorneBild, hintenBild: hintenBild,
                                        applePay: inApplePay)
                    }

                    // Kategorie / Vorlage (nur bei Passwörtern)
                    if art == .passwort {
                    VStack(alignment: .leading, spacing: 10) {
                        HomeSectionLabel("Kategorie")
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(VaultTemplate.all) { template in
                                    Button {
                                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                        withAnimation(.spring(response: 0.25)) {
                                            selectedColor = template.colorTag
                                            let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
                                            if !trimmed.hasPrefix(template.emoji) {
                                                title = trimmed.isEmpty ? "\(template.emoji) " : "\(template.emoji) \(trimmed)"
                                            }
                                        }
                                        focusedField = .title
                                    } label: {
                                        HStack(spacing: 5) {
                                            Text(template.emoji)
                                            Text(template.label)
                                                .font(.system(size: 13, weight: .medium))
                                        }
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 7)
                                        .background(NoteColor.for_(template.colorTag).bg.opacity(0.85))
                                        .foregroundStyle(.primary)
                                        .clipShape(Capsule())
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            .padding(.vertical, 2)
                        }
                    }
                    }

                    // Felder
                    VStack(spacing: 12) {
                        // Titel / Bezeichnung
                        VaultFieldRow(label: art == .karte ? "Bezeichnung (z. B. Bank)" : "Titel",
                                      placeholder: "") {
                            TextField(art == .karte ? "z. B. Neon Mastercard" : "z. B. Gmail, Netflix…", text: $title)
                                .focused($focusedField, equals: .title)
                                .autocorrectionDisabled()
                        }

                        if art == .passwort {

                        // Benutzername
                        VaultFieldRow(label: "Benutzername / E-Mail", placeholder: "") {
                            TextField("Benutzername oder E-Mail", text: $username)
                                .focused($focusedField, equals: .username)
                                .autocorrectionDisabled()
                                .textInputAutocapitalization(.never)
                        }

                        // Passwort
                        VaultFieldRow(label: "Passwort", placeholder: "") {
                            HStack(spacing: 10) {
                                Group {
                                    if showPassword {
                                        TextField("Passwort", text: $password)
                                    } else {
                                        SecureField("Passwort", text: $password)
                                    }
                                }
                                .focused($focusedField, equals: .password)
                                .autocorrectionDisabled()
                                .textInputAutocapitalization(.never)
                                .font(.system(.body, design: .monospaced))

                                Button {
                                    showPassword.toggle()
                                } label: {
                                    Image(systemName: showPassword ? "eye.slash" : "eye")
                                        .font(.system(size: 15))
                                        .foregroundStyle(.secondary)
                                }
                                .buttonStyle(.plain)

                                Button {
                                    showGenerator = true
                                } label: {
                                    Image(systemName: "wand.and.stars")
                                        .font(.system(size: 15))
                                        .foregroundStyle(color.accent)
                                }
                                .buttonStyle(.plain)
                            }
                        }

                        // Passwortstärke
                        if !password.isEmpty {
                            PasswordStrengthBar(password: password)
                                .padding(.horizontal, 2)
                                .transition(.opacity.combined(with: .move(edge: .top)))
                        }

                        // Website
                        VaultFieldRow(label: "Website (optional)", placeholder: "") {
                            TextField("https://…", text: $url)
                                .focused($focusedField, equals: .url)
                                .autocorrectionDisabled()
                                .textInputAutocapitalization(.never)
                                .keyboardType(.URL)
                        }

                        }   // Ende: nur bei Passwörtern

                        if art == .karte {
                            // Foto-Scan (schneidet die Karte automatisch zu, füllt Felder vor)
                            HStack(spacing: 10) {
                                Button {
                                    scanRueckseite = false; showScanner = true
                                } label: {
                                    Label(vorneBild == nil ? "Vorderseite" : "Vorderseite ✓",
                                          systemImage: "camera.viewfinder")
                                        .font(.system(size: 13, weight: .medium))
                                        .frame(maxWidth: .infinity).padding(.vertical, 9)
                                        .background(color.bg.opacity(0.7), in: RoundedRectangle(cornerRadius: 10))
                                }
                                .buttonStyle(.plain)
                                Button {
                                    scanRueckseite = true; showScanner = true
                                } label: {
                                    Label(hintenBild == nil ? "Rückseite" : "Rückseite ✓",
                                          systemImage: "camera.viewfinder")
                                        .font(.system(size: 13, weight: .medium))
                                        .frame(maxWidth: .infinity).padding(.vertical, 9)
                                        .background(color.bg.opacity(0.7), in: RoundedRectangle(cornerRadius: 10))
                                }
                                .buttonStyle(.plain)
                            }

                            Toggle(isOn: $inApplePay) {
                                Label("Zu Apple Pay hinzugefügt", systemImage: "applelogo")
                                    .font(.system(size: 14))
                            }
                            .tint(color.accent)
                            .padding(.vertical, 2)

                            VaultFieldRow(label: "Karteninhaber", placeholder: "") {
                                TextField("Name auf der Karte", text: $karteninhaber)
                                    .focused($focusedField, equals: .inhaber)
                                    .textInputAutocapitalization(.words)
                            }
                            VaultFieldRow(label: "Kartennummer", placeholder: "") {
                                TextField("1234 5678 9012 3456", text: $kartennummer)
                                    .focused($focusedField, equals: .nummer)
                                    .keyboardType(.numberPad)
                                    .font(.system(.body, design: .monospaced))
                            }
                            HStack(spacing: 12) {
                                VaultFieldRow(label: "Gültig (MM/JJ)", placeholder: "") {
                                    TextField("MM/JJ", text: $ablauf)
                                        .focused($focusedField, equals: .ablauf)
                                        .keyboardType(.numbersAndPunctuation)
                                }
                                VaultFieldRow(label: "CVV", placeholder: "") {
                                    SecureField("•••", text: $pruefnummer)
                                        .focused($focusedField, equals: .cvv)
                                        .keyboardType(.numberPad)
                                }
                            }
                            VaultFieldRow(label: "PIN (optional)", placeholder: "") {
                                SecureField("••••", text: $pin)
                                    .focused($focusedField, equals: .pin)
                                    .keyboardType(.numberPad)
                            }
                        }

                        // Sperr-Hotline (Notfall-Bereich, v. a. für Karten)
                        VaultFieldRow(label: "Sperr-Hotline (optional)", placeholder: "") {
                            TextField("z.B. +41 44 123 45 67", text: $sperrHotline)
                                .keyboardType(.phonePad)
                        }
                    }

                    // Farbauswahl
                    VStack(alignment: .leading, spacing: 10) {
                        HomeSectionLabel("Farbe")
                        HStack(spacing: 12) {
                            ForEach(0..<NoteColor.palette.count, id: \.self) { idx in
                                Button {
                                    withAnimation(.spring(response: 0.25, dampingFraction: 0.7)) {
                                        selectedColor = idx
                                    }
                                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                } label: {
                                    Circle()
                                        .fill(NoteColor.palette[idx].accent)
                                        .frame(width: 26, height: 26)
                                        .overlay(
                                            Circle()
                                                .stroke(Color.primary.opacity(0.8), lineWidth: selectedColor == idx ? 2.5 : 0)
                                                .padding(2)
                                        )
                                        .scaleEffect(selectedColor == idx ? 1.15 : 1.0)
                                }
                                .buttonStyle(.plain)
                            }
                            Spacer()
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)
                .padding(.bottom, 40)
                .animation(.easeInOut(duration: 0.2), value: password.isEmpty)
            }
            .navigationTitle(art == .karte ? "Neue Kreditkarte" : "Neues Passwort")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Abbrechen") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        let t = title.trimmingCharacters(in: .whitespacesAndNewlines)
                        let titel = t.isEmpty ? (art == .karte ? "Kreditkarte" : "Eintrag") : t
                        let vName = vorneBild.flatMap { $0.jpegData(compressionQuality: 0.8) }
                            .map { store.speichereKartenBild($0) } ?? ""
                        let hName = hintenBild.flatMap { $0.jpegData(compressionQuality: 0.8) }
                            .map { store.speichereKartenBild($0) } ?? ""
                        let entry = VaultEntry(
                            title: titel,
                            username: username.trimmingCharacters(in: .whitespacesAndNewlines),
                            password: password.trimmingCharacters(in: .whitespacesAndNewlines),
                            url: url.trimmingCharacters(in: .whitespacesAndNewlines),
                            sperrHotline: sperrHotline.trimmingCharacters(in: .whitespacesAndNewlines),
                            colorTag: selectedColor,
                            art: art,
                            kartennummer: kartennummer.filter { $0.isNumber },
                            karteninhaber: karteninhaber.trimmingCharacters(in: .whitespacesAndNewlines),
                            ablauf: ablauf.trimmingCharacters(in: .whitespacesAndNewlines),
                            pruefnummer: pruefnummer.trimmingCharacters(in: .whitespacesAndNewlines),
                            pin: pin.trimmingCharacters(in: .whitespacesAndNewlines),
                            kartenBildVorne: vName,
                            kartenBildHinten: hName,
                            inApplePay: inApplePay)
                        onSave(entry)
                    } label: {
                        Text("Sichern")
                            .fontWeight(.semibold)
                    }
                    .disabled(!canSave)
                }
            }
            .sheet(isPresented: $showGenerator) {
                PasswordGeneratorView { generated in
                    password = generated
                    showPassword = true
                }
            }
            .fullScreenCover(isPresented: $showScanner) {
                ArcaKartenScanner(onScan: { bild, text in
                    if scanRueckseite {
                        hintenBild = bild
                    } else {
                        vorneBild = bild
                        let p = parseKarte(text)
                        if kartennummer.isEmpty { kartennummer = p.nummer }
                        if ablauf.isEmpty { ablauf = p.ablauf }
                        if karteninhaber.isEmpty { karteninhaber = p.inhaber }
                    }
                    showScanner = false
                }, onCancel: { showScanner = false })
                .ignoresSafeArea()
            }
        }
    }
}

// Einheitliche Feld-Zeile
struct VaultFieldRow<Content: View>: View {
    let label: String
    let placeholder: String
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(Color.primary.opacity(0.45))
                .tracking(0.3)
            content()
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .background(Color(.secondarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }
}

// MARK: - VaultRow

struct VaultRow: View {
    let item: VaultEntry
    @Binding var copiedItemID: UUID?

    private var color: NoteColor { NoteColor.for_(item.colorTag) }
    private var isCopied: Bool { copiedItemID == item.id }

    var body: some View {
        HStack(spacing: 12) {
            // Karte: Kreditkarten-Icon, sonst Farbpunkt
            if item.art == .karte {
                Image(systemName: "creditcard.fill")
                    .font(.system(size: 13))
                    .foregroundStyle(color.accent)
            } else {
                Circle()
                    .fill(color.accent)
                    .frame(width: 8, height: 8)
            }

            // Nur Titel
            Text(item.title)
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(.primary)
                .lineLimit(1)

            // Favorit
            if item.isFavorite {
                Image(systemName: "star.fill")
                    .font(.system(size: 9))
                    .foregroundStyle(.orange.opacity(0.8))
            }

            Spacer()

            // Kopier-Icon — dezent, kein Label (Karte: Nummer, sonst Passwort)
            Button {
                UIPasteboard.general.string = item.art == .karte ? item.kartennummer : item.password
                UINotificationFeedbackGenerator().notificationOccurred(.success)
                withAnimation(.spring(response: 0.3)) { copiedItemID = item.id }
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                    withAnimation { if copiedItemID == item.id { copiedItemID = nil } }
                }
            } label: {
                Image(systemName: isCopied ? "checkmark" : "doc.on.doc")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(isCopied ? .green : Color.primary.opacity(0.3))
                    .frame(width: 28, height: 28)
                    .background(
                        isCopied
                            ? Color.green.opacity(0.12)
                            : Color.primary.opacity(0.05),
                        in: RoundedRectangle(cornerRadius: 7)
                    )
                    .animation(.easeInOut(duration: 0.2), value: isCopied)
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 4)
        .padding(.horizontal, 2)
    }
}

struct VaultDetailView: View {
    let item: VaultEntry
    @EnvironmentObject var store: AppStore
    @Environment(\.dismiss) var dismiss

    @State private var isEditing = false
    @State private var editTitle = ""
    @State private var editUsername = ""
    @State private var editPassword = ""
    @State private var editURL = ""
    @State private var editSperrHotline = ""
    @State private var editColor = 0
    @State private var showPassword = false
    @State private var showGenerator = false
    // Kreditkarte
    @State private var editKartennummer = ""
    @State private var editKarteninhaber = ""
    @State private var editAblauf = ""
    @State private var editPruefnummer = ""
    @State private var editPin = ""
    @State private var editInApplePay = false
    @State private var showSecret = false
    @State private var vorneBild: UIImage?
    @State private var hintenBild: UIImage?
    @State private var editVorneBild: UIImage?
    @State private var editHintenBild: UIImage?
    @State private var showScanner = false
    @State private var scanRueckseite = false

    private var displayColor: NoteColor {
        NoteColor.for_(isEditing ? editColor : item.colorTag)
    }

    private func ladeKartenbild(_ name: String) -> UIImage? {
        guard !name.isEmpty else { return nil }
        _ = store.ensureFileDownloaded(name)
        return UIImage(contentsOfFile: store.documentURL(for: name).path)
    }
    private func ladeBilder() {
        vorneBild = ladeKartenbild(item.kartenBildVorne)
        hintenBild = ladeKartenbild(item.kartenBildHinten)
    }

    // MARK: Karten-Detail (Anzeige + Bearbeiten)
    @ViewBuilder private var kartenDetail: some View {
        if isEditing {
            Section {
                ArcaKreditkarte(nummer: editKartennummer, inhaber: editKarteninhaber,
                                ablauf: editAblauf, cvv: editPruefnummer, farbe: NoteColor.for_(editColor),
                                vorneBild: editVorneBild ?? vorneBild,
                                hintenBild: editHintenBild ?? hintenBild,
                                applePay: editInApplePay)
                    .listRowInsets(EdgeInsets(top: 8, leading: 8, bottom: 8, trailing: 8))
                    .listRowBackground(Color.clear)
            }
            Section {
                HStack {
                    Button { scanRueckseite = false; showScanner = true } label: {
                        Label("Vorderseite", systemImage: "camera.viewfinder")
                    }
                    .buttonStyle(.borderless)
                    Spacer()
                    Button { scanRueckseite = true; showScanner = true } label: {
                        Label("Rückseite", systemImage: "camera.viewfinder")
                    }
                    .buttonStyle(.borderless)
                }
                Toggle(isOn: $editInApplePay) {
                    Label("Zu Apple Pay hinzugefügt", systemImage: "applelogo")
                }
            } header: {
                Text("Foto & Apple Pay")
            }
            Section("Bezeichnung") {
                TextField("z. B. Neon Mastercard", text: $editTitle)
            }
            Section("Karteninhaber") {
                TextField("Name auf der Karte", text: $editKarteninhaber)
                    .textInputAutocapitalization(.words)
            }
            Section("Kartennummer") {
                TextField("1234 5678 9012 3456", text: $editKartennummer)
                    .keyboardType(.numberPad)
                    .font(.system(.body, design: .monospaced))
            }
            Section("Gültig / CVV") {
                HStack {
                    TextField("MM/JJ", text: $editAblauf)
                        .keyboardType(.numbersAndPunctuation)
                    Divider()
                    SecureField("CVV", text: $editPruefnummer)
                        .keyboardType(.numberPad)
                }
            }
            Section("PIN (optional)") {
                SecureField("••••", text: $editPin)
                    .keyboardType(.numberPad)
            }
            Section {
                TextField("z.B. +41 44 123 45 67", text: $editSperrHotline)
                    .keyboardType(.phonePad)
            } header: {
                Text("Sperr-Hotline (optional)")
            } footer: {
                Text("Erscheint mit Anruf-Knopf im Notfall-Bereich (Mehr → Notfall).")
            }
        } else {
            Section {
                ArcaKreditkarte(nummer: item.kartennummer, inhaber: item.karteninhaber,
                                ablauf: item.ablauf, cvv: item.pruefnummer, farbe: displayColor,
                                maskiert: !showSecret, vorneBild: vorneBild, hintenBild: hintenBild,
                                applePay: item.inApplePay)
                    .listRowInsets(EdgeInsets(top: 8, leading: 8, bottom: 8, trailing: 8))
                    .listRowBackground(Color.clear)
            }
            Section {
                Toggle(isOn: $showSecret) {
                    Label(showSecret ? "Nummer & Codes verbergen" : "Nummer & Codes zeigen",
                          systemImage: showSecret ? "eye.slash" : "eye")
                }
            }
            if !item.kartennummer.isEmpty {
                Section("Kartennummer") {
                    HStack {
                        Text(showSecret
                             ? item.kartennummer
                             : "•••• " + String(item.kartennummer.suffix(4)))
                            .font(.system(.body, design: .monospaced))
                        Spacer()
                        Button {
                            UIPasteboard.general.string = item.kartennummer
                            UINotificationFeedbackGenerator().notificationOccurred(.success)
                        } label: {
                            Image(systemName: "doc.on.doc").foregroundStyle(.blue)
                        }
                        .buttonStyle(.borderless)
                    }
                }
            }
            if !item.ablauf.isEmpty {
                Section("Gültig bis") { Text(item.ablauf).font(.system(.body, design: .monospaced)) }
            }
            if !item.pruefnummer.isEmpty {
                Section("CVV") { Text(showSecret ? item.pruefnummer : "•••").font(.system(.body, design: .monospaced)) }
            }
            if !item.pin.isEmpty {
                Section("PIN") { Text(showSecret ? item.pin : "••••").font(.system(.body, design: .monospaced)) }
            }
            if !item.sperrHotline.isEmpty {
                Section("Sperr-Hotline") {
                    HStack {
                        Text(item.sperrHotline).font(.system(.body, design: .rounded))
                        Spacer()
                        Button {
                            let nummer = item.sperrHotline.filter { "0123456789+".contains($0) }
                            if let url = URL(string: "tel:\(nummer)") { UIApplication.shared.open(url) }
                        } label: {
                            Image(systemName: "phone.arrow.up.right").foregroundStyle(.red)
                        }
                        .buttonStyle(.borderless)
                    }
                }
            }
            Section("Erstellt am") {
                Text(item.dateCreated.formatted(date: .abbreviated, time: .shortened))
                    .foregroundStyle(.secondary)
            }
        }
    }

    var body: some View {
        NavigationStack {
            List {
                if item.art == .karte {
                    kartenDetail
                } else if isEditing {
                    Section("Titel") {
                        TextField("Titel", text: $editTitle)
                    }
                    Section("Benutzername") {
                        TextField("Benutzername", text: $editUsername)
                            .autocorrectionDisabled()
                            .textInputAutocapitalization(.never)
                    }
                    Section("Passwort") {
                        HStack {
                            if showPassword {
                                TextField("Passwort", text: $editPassword)
                                    .autocorrectionDisabled()
                                    .textInputAutocapitalization(.never)
                                    .font(.system(.body, design: .monospaced))
                            } else {
                                SecureField("Passwort", text: $editPassword)
                                    .font(.system(.body, design: .monospaced))
                            }
                            Button {
                                showPassword.toggle()
                            } label: {
                                Image(systemName: showPassword ? "eye.slash" : "eye")
                                    .foregroundStyle(.blue)
                            }
                            .buttonStyle(.borderless)
                            Button {
                                showGenerator = true
                            } label: {
                                Image(systemName: "wand.and.stars")
                                    .foregroundStyle(.blue)
                            }
                            .buttonStyle(.borderless)
                        }
                        if !editPassword.isEmpty {
                            PasswordStrengthBar(password: editPassword)
                        }
                    }
                    .sheet(isPresented: $showGenerator) {
                        PasswordGeneratorView { generated in
                            editPassword = generated
                            showPassword = true
                        }
                    }
                    Section("Website (optional)") {
                        TextField("https://...", text: $editURL)
                            .autocorrectionDisabled()
                            .textInputAutocapitalization(.never)
                            .keyboardType(.URL)
                    }
                    Section {
                        TextField("z.B. +41 44 123 45 67", text: $editSperrHotline)
                            .keyboardType(.phonePad)
                    } header: {
                        Text("Sperr-Hotline (optional)")
                    } footer: {
                        Text("Für Karten: erscheint mit Anruf-Knopf im Notfall-Bereich (Mehr → Notfall).")
                    }
                } else {
                    Section("Titel") {
                        Text(item.title)
                    }
                    Section("Benutzername") {
                        HStack {
                            Text(item.username.isEmpty ? "–" : item.username)
                            Spacer()
                            if !item.username.isEmpty {
                                Button {
                                    UIPasteboard.general.string = item.username
                                } label: {
                                    Image(systemName: "doc.on.doc").foregroundStyle(.blue)
                                }
                                .buttonStyle(.borderless)
                            }
                        }
                    }
                    Section("Passwort") {
                        HStack {
                            Text(showPassword ? item.password : "••••••••")
                                .font(.system(.body, design: .monospaced))
                            Spacer()
                            Button {
                                showPassword.toggle()
                            } label: {
                                Image(systemName: showPassword ? "eye.slash" : "eye")
                                    .foregroundStyle(.blue)
                            }
                            .buttonStyle(.borderless)
                            Button {
                                UIPasteboard.general.string = item.password
                            } label: {
                                Image(systemName: "doc.on.doc").foregroundStyle(.blue)
                            }
                            .buttonStyle(.borderless)
                        }
                    }
                    if !item.sperrHotline.isEmpty {
                        Section("Sperr-Hotline") {
                            HStack {
                                Text(item.sperrHotline)
                                    .font(.system(.body, design: .rounded))
                                Spacer()
                                Button {
                                    let nummer = item.sperrHotline.filter { "0123456789+".contains($0) }
                                    if let url = URL(string: "tel:\(nummer)") {
                                        UIApplication.shared.open(url)
                                    }
                                } label: {
                                    Image(systemName: "phone.arrow.up.right")
                                        .foregroundStyle(.red)
                                }
                                .buttonStyle(.borderless)
                            }
                        }
                    }
                    if !item.url.isEmpty {
                        Section("Website") {
                            HStack {
                                Text(item.url)
                                    .foregroundStyle(.blue)
                                    .lineLimit(1)
                                Spacer()
                                Button {
                                    var urlStr = item.url
                                    if !urlStr.hasPrefix("http") { urlStr = "https://" + urlStr }
                                    if let u = URL(string: urlStr) { UIApplication.shared.open(u) }
                                } label: {
                                    Image(systemName: "safari").foregroundStyle(.blue)
                                }
                                .buttonStyle(.borderless)
                            }
                        }
                    }
                    Section("Erstellt am") {
                        Text(item.dateCreated.formatted(date: .abbreviated, time: .shortened))
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle(isEditing ? "Bearbeiten" : item.title)
            .navigationBarTitleDisplayMode(.inline)
            .onAppear { if item.art == .karte { ladeBilder() } }
            .fullScreenCover(isPresented: $showScanner) {
                ArcaKartenScanner(onScan: { bild, text in
                    if scanRueckseite {
                        editHintenBild = bild
                    } else {
                        editVorneBild = bild
                        let p = parseKarte(text)
                        if editKartennummer.isEmpty { editKartennummer = p.nummer }
                        if editAblauf.isEmpty { editAblauf = p.ablauf }
                        if editKarteninhaber.isEmpty { editKarteninhaber = p.inhaber }
                    }
                    showScanner = false
                }, onCancel: { showScanner = false })
                .ignoresSafeArea()
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    if isEditing {
                        Button("Abbrechen") {
                            isEditing = false
                            showPassword = false
                        }
                    } else {
                        Button("Fertig") { dismiss() }
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    if isEditing {
                        Button("Speichern") {
                            UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                            let t = editTitle.trimmingCharacters(in: .whitespacesAndNewlines)
                            let vName = editVorneBild.flatMap { $0.jpegData(compressionQuality: 0.8) }
                                .map { store.speichereKartenBild($0) } ?? item.kartenBildVorne
                            let hName = editHintenBild.flatMap { $0.jpegData(compressionQuality: 0.8) }
                                .map { store.speichereKartenBild($0) } ?? item.kartenBildHinten
                            var updated = VaultEntry(
                                id: item.id,
                                title: t.isEmpty ? (item.art == .karte ? "Kreditkarte" : "Eintrag") : t,
                                username: editUsername.trimmingCharacters(in: .whitespacesAndNewlines),
                                password: editPassword.trimmingCharacters(in: .whitespacesAndNewlines),
                                url: editURL.trimmingCharacters(in: .whitespacesAndNewlines),
                                sperrHotline: editSperrHotline.trimmingCharacters(in: .whitespacesAndNewlines),
                                isFavorite: item.isFavorite,
                                dateCreated: item.dateCreated,
                                colorTag: editColor,
                                art: item.art,
                                kartennummer: editKartennummer.filter { $0.isNumber },
                                karteninhaber: editKarteninhaber.trimmingCharacters(in: .whitespacesAndNewlines),
                                ablauf: editAblauf.trimmingCharacters(in: .whitespacesAndNewlines),
                                pruefnummer: editPruefnummer.trimmingCharacters(in: .whitespacesAndNewlines),
                                pin: editPin.trimmingCharacters(in: .whitespacesAndNewlines),
                                kartenBildVorne: vName,
                                kartenBildHinten: hName,
                                inApplePay: editInApplePay
                            )
                            // Die „fest"-Nadel überlebt das Bearbeiten
                            updated.favoritePinned = item.favoritePinned
                            store.updateVaultEntry(updated)
                            isEditing = false
                            showPassword = false
                            dismiss()
                        }
                        // Speichern immer erlaubt — auch unvollständig (nur leerer Passwort-Titel wird geblockt)
                        .disabled(item.art == .passwort &&
                                  editTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    } else {
                        Button("Bearbeiten") {
                            editTitle = item.title
                            editUsername = item.username
                            editPassword = item.password
                            editURL = item.url
                            editSperrHotline = item.sperrHotline
                            editColor = item.colorTag
                            editKartennummer = item.kartennummer
                            editKarteninhaber = item.karteninhaber
                            editAblauf = item.ablauf
                            editPruefnummer = item.pruefnummer
                            editPin = item.pin
                            editInApplePay = item.inApplePay
                            editVorneBild = nil
                            editHintenBild = nil
                            showPassword = false
                            isEditing = true
                        }
                    }
                }
                ToolbarItem(placement: .navigationBarLeading) {
                    if isEditing {
                        Menu {
                            ForEach(0..<NoteColor.palette.count, id: \.self) { idx in
                                Button {
                                    withAnimation(.easeInOut(duration: 0.25)) { editColor = idx }
                                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                } label: {
                                    Label(NoteColor.palette[idx].name,
                                          systemImage: editColor == idx ? "checkmark.circle.fill" : "circle.fill")
                                        .foregroundStyle(NoteColor.palette[idx].accent)
                                }
                            }
                        } label: {
                            Image(systemName: "paintpalette.fill")
                                .foregroundStyle(displayColor.accent)
                        }
                    }
                }
            }
            // Verhindert versehentliches Wegwischen während des Bearbeitens
            .interactiveDismissDisabled(isEditing)
        }
    }
}

// MARK: - Password Generator

struct PasswordGeneratorView: View {
    let onUse: (String) -> Void
    @Environment(\.dismiss) var dismiss

    @State private var length: Double = 16
    @State private var useUppercase = true
    @State private var useNumbers = true
    @State private var useSymbols = true
    @State private var generated = ""

    private let lower = "abcdefghijklmnopqrstuvwxyz"
    private let upper = "ABCDEFGHIJKLMNOPQRSTUVWXYZ"
    private let numbers = "0123456789"
    private let symbols = "!@#$%^&*()-_=+[]{}|;:,.<>?"

    var body: some View {
        NavigationStack {
            Form {
                Section("Generiertes Passwort") {
                    HStack {
                        Text(generated)
                            .font(.system(.body, design: .monospaced))
                            .lineLimit(2)
                            .minimumScaleFactor(0.7)
                            .foregroundStyle(.primary)
                        Spacer()
                        Button {
                            UIPasteboard.general.string = generated
                        } label: {
                            Image(systemName: "doc.on.doc")
                                .foregroundStyle(.blue)
                        }
                    }
                    PasswordStrengthBar(password: generated)
                    Button {
                        generate()
                    } label: {
                        Label("Neu generieren", systemImage: "arrow.clockwise")
                    }
                }

                Section("Optionen") {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text("Länge: \(Int(length)) Zeichen")
                            Spacer()
                        }
                        Slider(value: $length, in: 8...32, step: 1)
                            .onChange(of: length) { _, _ in generate() }
                    }
                    Toggle("Grossbuchstaben (A-Z)", isOn: $useUppercase)
                        .onChange(of: useUppercase) { _, _ in generate() }
                    Toggle("Zahlen (0-9)", isOn: $useNumbers)
                        .onChange(of: useNumbers) { _, _ in generate() }
                    Toggle("Sonderzeichen (!@#...)", isOn: $useSymbols)
                        .onChange(of: useSymbols) { _, _ in generate() }
                }
            }
            .navigationTitle("Passwort-Generator")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Abbrechen") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Übernehmen") {
                        onUse(generated)
                        dismiss()
                    }
                    .bold()
                }
            }
            .onAppear { generate() }
        }
    }

    private func generate() {
        var charset = lower
        if useUppercase { charset += upper }
        if useNumbers   { charset += numbers }
        if useSymbols   { charset += symbols }
        guard !charset.isEmpty else { generated = ""; return }
        generated = String((0..<Int(length)).map { _ in charset.randomElement()! })
    }
}

// MARK: - Password Strength Bar

struct PasswordStrengthBar: View {
    let password: String

    private var strength: (label: String, color: Color, fraction: Double) {
        var score = 0
        if password.count >= 8  { score += 1 }
        if password.count >= 12 { score += 1 }
        if password.count >= 16 { score += 1 }
        if password.rangeOfCharacter(from: .uppercaseLetters) != nil { score += 1 }
        if password.rangeOfCharacter(from: .decimalDigits) != nil    { score += 1 }
        let special = CharacterSet(charactersIn: "!@#$%^&*()-_=+[]{}|;:,.<>?")
        if password.rangeOfCharacter(from: special) != nil { score += 1 }
        switch score {
        case 0...2: return ("Schwach",    .red,    Double(score) / 6.0)
        case 3...4: return ("Mittel",     .orange, Double(score) / 6.0)
        default:    return ("Stark",      .green,  Double(score) / 6.0)
        }
    }

    var body: some View {
        HStack(spacing: 8) {
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color.secondary.opacity(0.2))
                        .frame(height: 6)
                    RoundedRectangle(cornerRadius: 3)
                        .fill(strength.color)
                        .frame(width: geo.size.width * strength.fraction, height: 6)
                        .animation(.easeInOut(duration: 0.3), value: strength.fraction)
                }
            }
            .frame(height: 6)
            Text(strength.label)
                .font(.caption)
                .foregroundStyle(strength.color)
                .frame(width: 50, alignment: .trailing)
        }
        .padding(.vertical, 2)
    }
}

