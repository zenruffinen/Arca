//
//  ArcaSchreibtisch.swift
//  Arca
//
//  Der Arca-Schreibtisch (iPad/Mac): frei positionierbare Post-it-Karten
//  auf den Flächen links und rechts des Space — Verweise, keine Kopien.
//
//  Entwickler: Hans zen Ruffinen
//

import SwiftUI
import UniformTypeIdentifiers
import QuickLook

// MARK: - Die Schreibtisch-Fläche

/// Eine freie Fläche des Schreibtischs: Karten hineinziehen, mit der Maus
/// oder dem Finger frei anordnen, antippen zum Öffnen.
struct ArcaDeskRail: View {
    let seite: String
    @Binding var selectedSection: ArcaSection
    var breite: CGFloat = 158
    @EnvironmentObject var store: AppStore

    @State private var previewURL: URL? = nil
    @State private var zielt = false
    @State private var zugID: UUID? = nil
    @State private var zugVersatz: CGSize = .zero
    @State private var umbenennenItem: DeskItem? = nil
    @State private var umbenennenText = ""
    @State private var titelBearbeiten = false
    @State private var titelText = ""

    private var kartenBreite: CGFloat { breite - 16 }

    /// Jede Fläche hat einen Namen: links „Zu erledigen",
    /// rechts „Schnellzugriff" — beides umbenennbar.
    private var standardTitel: String { seite == "links" ? "Zu erledigen" : "Schnellzugriff" }
    private var titelSymbol: String { seite == "links" ? "checkmark.circle" : "bolt.fill" }
    private var flaechenTitel: String {
        UserDefaults.standard.string(forKey: "arcaDeskTitel_" + seite) ?? standardTitel
    }

    /// Nur Karten, deren Original noch existiert.
    private var items: [DeskItem] {
        store.deskItems.filter { $0.seite == seite && existiert($0) }
    }

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .top) {
                Color.clear

                // Das Titel-Schild der Fläche
                HStack(spacing: 6) {
                    Image(systemName: titelSymbol)
                        .font(.system(size: 10, weight: .bold))
                    Text(flaechenTitel)
                        .font(.system(size: 11, weight: .semibold))
                        .textCase(.uppercase)
                        .tracking(0.8)
                        .lineLimit(1)
                }
                .foregroundStyle(ArcaWarm.terrakotta)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .glassEffect(.regular, in: Capsule())
                .padding(.top, 10)
                .contextMenu {
                    ArcaMenue.umbenennen {
                        titelText = flaechenTitel
                        titelBearbeiten = true
                    }
                }
                .alert("Fläche umbenennen", isPresented: $titelBearbeiten) {
                    TextField("Name", text: $titelText)
                    Button("Sichern") {
                        let name = titelText.trimmingCharacters(in: .whitespacesAndNewlines)
                        UserDefaults.standard.set(name.isEmpty ? standardTitel : name,
                                                  forKey: "arcaDeskTitel_" + seite)
                    }
                    Button("Abbrechen", role: .cancel) {}
                }
                .zIndex(20)

                // Leerzustand / Ziel-Rahmen
                if items.isEmpty || zielt {
                    RoundedRectangle(cornerRadius: 14)
                        .strokeBorder(zielt ? ArcaWarm.terrakotta : ArcaWarm.terrakotta.opacity(0.25),
                                      style: StrokeStyle(lineWidth: 1.5, dash: [5, 4]))
                        .frame(width: kartenBreite, height: 90)
                        .overlay {
                            VStack(spacing: 6) {
                                Image(systemName: "tray.and.arrow.down")
                                    .font(.system(size: 17, weight: .semibold))
                                Text("Hierher ziehen")
                                    .font(.system(size: 10, weight: .medium))
                            }
                            .foregroundStyle(zielt ? ArcaWarm.terrakotta : .secondary)
                        }
                        .padding(.top, 48)
                }

                ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                    ArcaDeskCard(item: item) {
                        oeffne(item)
                    }
                    .frame(width: kartenBreite)
                    .position(position(item, index: index, in: geo.size))
                    .offset(item.id == zugID ? zugVersatz : .zero)
                    .shadow(color: .black.opacity(item.id == zugID ? 0.22 : 0),
                            radius: 10, x: 0, y: 5)
                    .zIndex(item.id == zugID ? 10 : 0)
                    // Frei verschieben: greifen und ablegen — die Stelle wird gemerkt
                    .gesture(
                        DragGesture(minimumDistance: 4)
                            .onChanged { wert in
                                zugID = item.id
                                zugVersatz = wert.translation
                            }
                            .onEnded { wert in
                                let start = position(item, index: index, in: geo.size)
                                let ziel = CGPoint(x: start.x + wert.translation.width,
                                                   y: start.y + wert.translation.height)
                                if let idx = store.deskItems.firstIndex(where: { $0.id == item.id }) {
                                    store.deskItems[idx].posX = Double(min(max(ziel.x, kartenBreite / 2 + 4),
                                                                           geo.size.width - kartenBreite / 2 - 4))
                                    store.deskItems[idx].posY = Double(min(max(ziel.y, 70),
                                                                           geo.size.height - 70))
                                }
                                zugID = nil
                                zugVersatz = .zero
                                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                            }
                    )
                    .contextMenu {
                        ArcaMenue.umbenennen {
                            umbenennenText = titel(von: item)
                            umbenennenItem = item
                        }
                        ArcaMenue.farbe(aktuell: item.colorTag) { farbIdx in
                            if let idx = store.deskItems.firstIndex(where: { $0.id == item.id }) {
                                store.deskItems[idx].colorTag = farbIdx
                            }
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        }
                        Button {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                if let idx = store.deskItems.firstIndex(where: { $0.id == item.id }) {
                                    store.deskItems[idx].seite = seite == "links" ? "rechts" : "links"
                                }
                            }
                        } label: {
                            Label("Auf die andere Seite", systemImage: "arrow.left.arrow.right")
                        }
                        ArcaMenue.loeschen("Vom Schreibtisch nehmen") {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                store.deskItems.removeAll { $0.id == item.id }
                            }
                        }
                    }
                }
            }
            .contentShape(Rectangle())
            // Neues landet dort, wo man es fallen lässt
            .dropDestination(for: String.self) { werte, ort in
                legeAb(werte, an: ort, in: geo.size)
            } isTargeted: { drueber in
                withAnimation(.easeInOut(duration: 0.15)) { zielt = drueber }
            }
        }
        .frame(width: breite)
        .quickLookPreview($previewURL)
        // Umbenennen wirkt auf das Original — überall, auf allen Geräten
        .alert("Umbenennen", isPresented: Binding(
            get: { umbenennenItem != nil },
            set: { if !$0 { umbenennenItem = nil } }
        )) {
            TextField("Titel", text: $umbenennenText)
            Button("Sichern") {
                if let item = umbenennenItem { benenneUm(item, in: umbenennenText) }
                umbenennenItem = nil
            }
            Button("Abbrechen", role: .cancel) { umbenennenItem = nil }
        }
    }

    // MARK: Helfer

    private func existiert(_ item: DeskItem) -> Bool {
        switch item.kind {
        case .document: return store.documents.contains { $0.id == item.refID }
        case .note:     return store.notes.contains { $0.id == item.refID }
        case .list:     return store.lists.contains { $0.id == item.refID }
        case .vault:    return false
        }
    }

    /// Gemerkte Stelle — oder Stapel-Ordnung, solange nie verschoben wurde.
    private func position(_ item: DeskItem, index: Int, in groesse: CGSize) -> CGPoint {
        if let x = item.posX, let y = item.posY {
            return CGPoint(x: min(max(CGFloat(x), kartenBreite / 2 + 4), groesse.width - kartenBreite / 2 - 4),
                           y: min(max(CGFloat(y), 70), max(groesse.height - 70, 70)))
        }
        return CGPoint(x: groesse.width / 2, y: 150 + CGFloat(index) * 170)
    }

    private func titel(von item: DeskItem) -> String {
        switch item.kind {
        case .document: return store.documents.first(where: { $0.id == item.refID })?.title ?? ""
        case .note:     return store.notes.first(where: { $0.id == item.refID })?.title ?? ""
        case .list:     return store.lists.first(where: { $0.id == item.refID })?.title ?? ""
        case .vault:    return ""
        }
    }

    private func benenneUm(_ item: DeskItem, in neu: String) {
        let name = neu.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return }
        switch item.kind {
        case .document:
            if let idx = store.documents.firstIndex(where: { $0.id == item.refID }) {
                store.documents[idx].title = name
            }
        case .note:
            if let idx = store.notes.firstIndex(where: { $0.id == item.refID }) {
                store.notes[idx].title = name
            }
        case .list:
            if let idx = store.lists.firstIndex(where: { $0.id == item.refID }) {
                store.lists[idx].title = name
            }
        case .vault:
            break
        }
    }

    /// Abgelegtes an der Wurfstelle einsortieren; Doppelte wandern nur.
    private func legeAb(_ werte: [String], an ort: CGPoint, in groesse: CGSize) -> Bool {
        guard let wert = werte.first, let uuid = UUID(uuidString: wert) else { return false }
        let art: FavoriteKind?
        if store.documents.contains(where: { $0.id == uuid }) { art = .document }
        else if store.notes.contains(where: { $0.id == uuid }) { art = .note }
        else if store.lists.contains(where: { $0.id == uuid }) { art = .list }
        else { art = nil }
        guard let art else { return false }
        let x = Double(min(max(ort.x, kartenBreite / 2 + 4), groesse.width - kartenBreite / 2 - 4))
        let y = Double(min(max(ort.y, 70), max(groesse.height - 70, 70)))
        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
            if let idx = store.deskItems.firstIndex(where: { $0.refID == uuid }) {
                store.deskItems[idx].seite = seite
                store.deskItems[idx].posX = x
                store.deskItems[idx].posY = y
            } else {
                var neu = DeskItem(kind: art, refID: uuid, seite: seite)
                neu.posX = x
                neu.posY = y
                store.deskItems.append(neu)
            }
        }
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        return true
    }

    private func oeffne(_ item: DeskItem) {
        switch item.kind {
        case .document:
            if let doc = store.documents.first(where: { $0.id == item.refID }) {
                previewURL = store.documentURL(for: doc.filename)
            }
        case .note:  selectedSection = .notes
        case .list:  selectedSection = .lists
        case .vault: selectedSection = .vault
        }
    }
}

// MARK: - Die Post-it-Karte

/// Eine Schreibtisch-Karte: Dokument mit formatfüllender Vorschau,
/// Notiz als Zettel, Aufgabenliste mit den obersten Punkten.
struct ArcaDeskCard: View {
    let item: DeskItem
    let onTap: () -> Void
    @EnvironmentObject var store: AppStore

    /// Farbiger Rand, wenn gewählt — sonst die feine Haarlinie.
    private var randFarbe: Color {
        item.colorTag.map { NoteColor.for_($0).accent } ?? ArcaWarm.haarlinie
    }
    private var randStaerke: CGFloat { item.colorTag != nil ? 2.5 : 1 }

    var body: some View {
        Group {
            switch item.kind {
            case .document:
                if let doc = store.documents.first(where: { $0.id == item.refID }) {
                    ZStack(alignment: .bottom) {
                        // Formatfüllend: die Seite füllt das ganze Post-it
                        DocThumbnail(url: store.documentURL(for: doc.filename), type: doc.type,
                                     gross: true)
                            .frame(height: 150)
                            .frame(maxWidth: .infinity)
                            .clipped()
                        Text(doc.title)
                            .font(.system(size: 12, weight: .semibold))
                            .lineLimit(1)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 6)
                            .padding(.horizontal, 8)
                            .background(.ultraThinMaterial)
                    }
                }
            case .note:
                if let notiz = store.notes.first(where: { $0.id == item.refID }) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(notiz.title)
                            .font(.system(size: 12, weight: .semibold))
                            .lineLimit(2)
                        Text(notiz.text)
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                            .lineLimit(7)
                        Spacer(minLength: 0)
                    }
                    .frame(maxWidth: .infinity, minHeight: 96, alignment: .topLeading)
                    .padding(10)
                    .background(NoteColor.for_(notiz.colorTag).bg.opacity(0.5))
                }
            case .list:
                if let liste = store.lists.first(where: { $0.id == item.refID }) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(liste.title)
                            .font(.system(size: 12, weight: .semibold))
                            .lineLimit(1)
                        ForEach(liste.items.prefix(4)) { punkt in
                            HStack(spacing: 5) {
                                Image(systemName: punkt.isDone ? "checkmark.square.fill" : "square")
                                    .font(.system(size: 10))
                                    .foregroundStyle(punkt.isDone ? .green : .secondary)
                                Text(punkt.text)
                                    .font(.system(size: 11))
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                            }
                        }
                        if liste.items.count > 4 {
                            Text("+\(liste.items.count - 4) weitere")
                                .font(.system(size: 9))
                                .foregroundStyle(.tertiary)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(9)
                    .background(NoteColor.for_(3).bg.opacity(0.35))
                }
            case .vault:
                EmptyView()
            }
        }
        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 10))
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(randFarbe, lineWidth: randStaerke))
        // Klebestreifen oben — wie aufs Pult geklebt
        .overlay(alignment: .top) {
            RoundedRectangle(cornerRadius: 3)
                .fill(Color.white.opacity(0.5))
                .overlay(RoundedRectangle(cornerRadius: 3)
                    .strokeBorder(Color.black.opacity(0.08), lineWidth: 0.8))
                .frame(width: 46, height: 15)
                .rotationEffect(.degrees(-4))
                .offset(y: -7)
                .shadow(color: .black.opacity(0.08), radius: 1, x: 0, y: 1)
        }
        .shadow(color: .black.opacity(0.13), radius: 5, x: 0, y: 3)
        .rotationEffect(.degrees(neigung))
        .contentShape(RoundedRectangle(cornerRadius: 10))
        .onTapGesture(perform: onTap)
    }

    /// Leichte, pro Karte feste Neigung (-2,4° … +2,4°) — Post-it-Charme.
    private var neigung: Double {
        let summe = item.refID.uuidString.unicodeScalars.reduce(0) { $0 + Int($1.value) }
        return Double(summe % 5 - 2) * 1.2
    }
}
