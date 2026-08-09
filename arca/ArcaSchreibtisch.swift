//
//  ArcaSchreibtisch.swift
//  Arca
//
//  Der Arca-Schreibtisch: Ablage-Spuren und Post-it-Karten (iPad/Mac).
//  (Aus ContentView.swift herausgelöst — Code unverändert.)
//
//  Entwickler: Hans zen Ruffinen
//

import SwiftUI
import UniformTypeIdentifiers
import QuickLook

// MARK: - Arca-Schreibtisch (iPad/Mac)

/// Welche Schreibtisch-Karte gerade gezogen wird — spurübergreifend.
enum DeskZug {
    static var gezogen: UUID? = nil
}

/// Klick-und-Ziehen auf dem Schreibtisch: beim Darüberziehen rückt die
/// Karte live an die neue Stelle — auch über die Seiten hinweg.
struct DeskTauschDelegate: DropDelegate {
    let ziel: DeskItem
    let store: AppStore

    func dropEntered(info: DropInfo) {
        guard let g = DeskZug.gezogen, g != ziel.id,
              let von = store.deskItems.firstIndex(where: { $0.id == g }),
              let nach = store.deskItems.firstIndex(where: { $0.id == ziel.id }) else { return }
        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
            store.deskItems[von].seite = ziel.seite
            store.deskItems.move(fromOffsets: IndexSet(integer: von),
                                 toOffset: nach > von ? nach + 1 : nach)
        }
    }

    func dropUpdated(info: DropInfo) -> DropProposal? {
        DropProposal(operation: .move)
    }

    func performDrop(info: DropInfo) -> Bool {
        DeskZug.gezogen = nil
        return true
    }
}

/// Eine Ablage-Spur des Schreibtischs: kleine Karten-Verweise auf
/// Dokumente, Notizen und Aufgabenlisten — hineinziehen, antippen, fertig.
struct ArcaDeskRail: View {
    let seite: String
    @Binding var selectedSection: ArcaSection
    var breite: CGFloat = 158
    @EnvironmentObject var store: AppStore
    @State private var previewURL: URL? = nil
    @State private var zielt = false

    private var items: [DeskItem] {
        store.deskItems.filter { $0.seite == seite }
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 10) {
                ForEach(items) { item in
                    ArcaDeskCard(item: item) {
                        oeffne(item)
                    }
                    .onDrag {
                        DeskZug.gezogen = item.id
                        return NSItemProvider(object: ("desk:" + item.id.uuidString) as NSString)
                    }
                    .onDrop(of: [.text], delegate: DeskTauschDelegate(ziel: item, store: store))
                    .contextMenu {
                        Button {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                if let idx = store.deskItems.firstIndex(of: item) {
                                    store.deskItems[idx].seite = seite == "links" ? "rechts" : "links"
                                }
                            }
                        } label: {
                            Label("Auf die andere Seite", systemImage: "arrow.left.arrow.right")
                        }
                        Divider()
                        Button(role: .destructive) {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                store.deskItems.removeAll { $0.id == item.id }
                            }
                        } label: {
                            Label("Vom Schreibtisch nehmen", systemImage: "pin.slash")
                        }
                    }
                }

                // Leerzustand / Ziel-Rahmen
                if items.isEmpty || zielt {
                    RoundedRectangle(cornerRadius: 14)
                        .strokeBorder(zielt ? ArcaWarm.terrakotta : ArcaWarm.terrakotta.opacity(0.25),
                                      style: StrokeStyle(lineWidth: 1.5, dash: [5, 4]))
                        .frame(height: 90)
                        .overlay {
                            VStack(spacing: 6) {
                                Image(systemName: "tray.and.arrow.down")
                                    .font(.system(size: 17, weight: .semibold))
                                Text("Hierher ziehen")
                                    .font(.system(size: 10, weight: .medium))
                            }
                            .foregroundStyle(zielt ? ArcaWarm.terrakotta : .secondary)
                        }
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 14)
        }
        .frame(width: breite)
        .contentShape(Rectangle())
        .dropDestination(for: String.self) { werte, _ in
            legeAb(werte)
        } isTargeted: { drueber in
            withAnimation(.easeInOut(duration: 0.15)) { zielt = drueber }
        }
        .quickLookPreview($previewURL)
    }

    /// Abgelegtes einsortieren: UUID auflösen, Doppelte wandern statt doppeln.
    private func legeAb(_ werte: [String]) -> Bool {
        guard let wert = werte.first else { return false }
        // Eine Schreibtisch-Karte selbst? Dann nur die Seite wechseln.
        if wert.hasPrefix("desk:"), let kartenID = UUID(uuidString: String(wert.dropFirst(5))) {
            if let idx = store.deskItems.firstIndex(where: { $0.id == kartenID }) {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                    store.deskItems[idx].seite = seite
                }
            }
            DeskZug.gezogen = nil
            return true
        }
        guard let uuid = UUID(uuidString: wert) else { return false }
        let art: FavoriteKind?
        if store.documents.contains(where: { $0.id == uuid }) { art = .document }
        else if store.notes.contains(where: { $0.id == uuid }) { art = .note }
        else if store.lists.contains(where: { $0.id == uuid }) { art = .list }
        else { art = nil }
        guard let art else { return false }
        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
            if let idx = store.deskItems.firstIndex(where: { $0.refID == uuid }) {
                store.deskItems[idx].seite = seite
            } else {
                store.deskItems.append(DeskItem(kind: art, refID: uuid, seite: seite))
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

/// Eine kleine Schreibtisch-Karte: Dokument mit Vorschau,
/// Notiz als Zettel, Aufgabenliste mit den obersten Punkten.
struct ArcaDeskCard: View {
    let item: DeskItem
    let onTap: () -> Void
    @EnvironmentObject var store: AppStore

    var body: some View {
        Group {
            switch item.kind {
            case .document:
                if let doc = store.documents.first(where: { $0.id == item.refID }) {
                    ZStack(alignment: .bottom) {
                        DocThumbnail(url: store.documentURL(for: doc.filename), type: doc.type,
                                     passendEinpassen: true)
                            .frame(height: 170)
                            .frame(maxWidth: .infinity)
                            .clipped()
                            .padding(.bottom, 24)
                        // Titel-Etikett auf dem Post-it
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
                    .frame(maxWidth: .infinity, minHeight: 120, alignment: .topLeading)
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
        .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(ArcaWarm.haarlinie, lineWidth: 1))
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

