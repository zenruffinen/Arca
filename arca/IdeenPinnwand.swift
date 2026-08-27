//
//  IdeenPinnwand.swift
//  Arca
//
//  Die Wand: eine Zusammenstellung von Dingen zu EINER Sache — Ideen als
//  Zettel, Dokumente als Blatt oder Polaroid, Aufgabenlisten als Klemmbrett.
//  Frei anordnen wie ein Brainstorm-Board, „das zu dem" gruppieren, und was
//  weg soll, in den Eimer knüllen.
//
//  Was hier hängt, sind Anschläge (siehe Models.swift) — nicht die Originale.
//  Etwas von der Wand nehmen löscht also nichts; nur eine Idee auf ihrer
//  eigenen Wand wird beim Knüllen wirklich gelöscht.
//
//  Entwickler: Hans zen Ruffinen
//

import SwiftUI
import QuickLook
import ARCAKit

/// Ein Stück an der Wand: der Anschlag samt dem, worauf er zeigt.
/// Ideen auf der Ideen-Wand hängen auch ohne eigenen Anschlag da (Spiegel) —
/// dann ist `anschlag` nil, bis man den Zettel einmal verschiebt.
private struct Wandstueck: Identifiable {
    let id: UUID          // die ID des Originals — pro Wand eindeutig
    let kind: FavoriteKind
    let refID: UUID
    let anschlag: Anschlag?
}

struct IdeenPinnwand: View {
    @EnvironmentObject var store: AppStore
    @Environment(\.horizontalSizeClass) private var groessenKlasse
    @State private var bearbeite: NoteEntry? = nil
    @State private var vorschauURL: URL? = nil
    @State private var bildURL: URL? = nil
    @State private var zugID: UUID? = nil
    @State private var zugOffset: CGSize = .zero
    @State private var ueberEimer = false
    @State private var zerknuellt: UUID? = nil
    @State private var boardID: UUID = SystemBoard.ideen
    @State private var benenneUm = false
    @State private var neuerName = ""
    @State private var zeigeStile = false
    @State private var neueWand = false
    @AppStorage("letzteWandID") private var letzteWandID: String = ""
    @State private var zeigeHinzufuegen = false
    @State private var neueListe = false
    @State private var listenName = ""
    @State private var zeigeAnpinnen = false
    /// Wo der Finger lag, als lang gedrückt wurde — dort landet das Neue.
    @State private var tippOrt: CGPoint? = nil
    @State private var wandGroesse: CGSize = .zero
    /// Aus welcher Richtung die nächste Wand hereinkommt (+1 rechts, -1 links).
    @State private var blaetterRichtung = 1

    private let zettelBreite: CGFloat = 150

    /// Oberer Sicherheitsabstand (Statusleiste/Notch) — die Pinnwand ignoriert
    /// die Safe Area, deshalb holen wir ihn direkt vom Fenster.
    private var randOben: CGFloat {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap { $0.windows }
            .first { $0.isKeyWindow }?.safeAreaInsets.top ?? 47
    }

    // MARK: Was hängt an dieser Wand?

    private var board: PinnBoard? { store.pinnBoards.first { $0.id == boardID } }
    private var stil: WandStil { board?.stil ?? .korkNatur }
    /// Schrift auf dieser Wand — auf Schiefer und Tafel hell statt dunkel.
    private var tinte: Color {
        stil.dunkel ? Color(white: 0.94) : Color(red: 0.35, green: 0.28, blue: 0.05)
    }

    /// Die Wände, zwischen denen man wechseln kann — Tresor und Pult
    /// tauchen hier nie auf.
    private var waehlbareBoards: [PinnBoard] {
        store.pinnBoards
            .filter { ($0.art == .wand || $0.art == .ideen) && !$0.archiviert }
            .sorted { $0.reihenfolge < $1.reihenfolge }
    }

    private var stuecke: [Wandstueck] {
        // Passwörter hängen an keiner sichtbaren Wand — nie.
        store.anschlaege
            .filter { $0.boardID == boardID && $0.kind != .vault && store.originalExistiert($0) }
            .map { Wandstueck(id: $0.refID, kind: $0.kind, refID: $0.refID, anschlag: $0) }
    }

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .topLeading) {
                KorkWand(stil: stil)
                    .contentShape(Rectangle())
                    // Lang auf die freie Wand drücken: hier kommt Neues hin.
                    // Erst der Druck, dann der Ort — als eine Geste, sonst
                    // knabbert der Zieh-Erkenner den Langdruck weg.
                    .gesture(
                        LongPressGesture(minimumDuration: 0.45)
                            .sequenced(before: DragGesture(minimumDistance: 0, coordinateSpace: .local))
                            .onEnded { wert in
                                guard case .second(true, let zug) = wert else { return }
                                tippOrt = zug?.startLocation
                                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                                zeigeHinzufuegen = true
                            }
                    )
                    // Wischen wechselt die Wand. Mindestweg 24, damit der
                    // Langdruck darüber unangetastet bleibt — ein Erkenner,
                    // der sofort greift, schluckt ihn (siehe oben).
                    .simultaneousGesture(
                        DragGesture(minimumDistance: 24)
                            .onEnded { wert in
                                let w = wert.translation.width
                                guard abs(w) > 60, abs(w) > abs(wert.translation.height) * 1.4
                                else { return }
                                blaettere(w < 0 ? 1 : -1)
                            }
                    )

                let alle = stuecke
                // Die Wand als Ganzes wechselt: die Marken schieben in
                // Wischrichtung heraus, die neuen kommen von der anderen
                // Seite herein. Der Belag darunter bleibt liegen.
                ZStack(alignment: .topLeading) {
                ForEach(Array(alle.enumerated()), id: \.element.id) { idx, stueck in
                    MarkeAnsicht(stueck: stueck, breite: zettelBreite)
                        .environmentObject(store)
                        .scaleEffect(zerknuellt == stueck.id ? 0.05 : 1)
                        .opacity(zerknuellt == stueck.id ? 0 : 1)
                        .rotationEffect(.degrees(zerknuellt == stueck.id ? 180 : neigung(stueck)))
                        .position(position(stueck, idx: idx, in: geo.size))
                        .offset(stueck.id == zugID ? zugOffset : .zero)
                        .zIndex(stueck.id == zugID ? 100 : 0)
                        .shadow(color: .black.opacity(stueck.id == zugID ? 0.25 : 0.12),
                                radius: stueck.id == zugID ? 12 : 4, x: 0, y: stueck.id == zugID ? 8 : 2)
                        .gesture(
                            DragGesture()
                                .onChanged { wert in
                                    zugID = stueck.id
                                    zugOffset = wert.translation
                                    let start = position(stueck, idx: idx, in: geo.size)
                                    let jetzt = CGPoint(x: start.x + wert.translation.width,
                                                        y: start.y + wert.translation.height)
                                    ueberEimer = eimerRahmen(geo.size).contains(jetzt)
                                }
                                .onEnded { wert in
                                    let start = position(stueck, idx: idx, in: geo.size)
                                    let ziel = CGPoint(x: start.x + wert.translation.width,
                                                       y: start.y + wert.translation.height)
                                    if eimerRahmen(geo.size).contains(ziel) {
                                        inDenEimer(stueck)
                                    } else {
                                        merkePosition(stueck, ziel, in: geo.size)
                                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                    }
                                    zugID = nil
                                    zugOffset = .zero
                                    ueberEimer = false
                                }
                        )
                        .onTapGesture { oeffne(stueck) }
                }
                }
                .id(boardID)
                .transition(.asymmetric(
                    insertion: .move(edge: blaetterRichtung > 0 ? .trailing : .leading)
                        .combined(with: .opacity),
                    removal: .move(edge: blaetterRichtung > 0 ? .leading : .trailing)
                        .combined(with: .opacity)))

                // Der Papierkorb — hier knüllt man Ideen hinein,
                // auf anderen Wänden nimmt man Dinge nur ab.
                eimer(in: geo.size)

                if alle.isEmpty { leerZustand }

                // Kopfzeile: Wand-Wähler · + Idee · (Vollbild)
                kopf

                // EXIT unten links — dort liegt der Daumen, wenn man das
                // Telefon hält. Oben rechts müsste man umgreifen.
                VStack {
                    Spacer()
                    HStack {
                        ExitKnopf {
                            withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                                store.zeigeIdeenPinnwand = false
                            }
                        }
                        Spacer()
                    }
                }
                .padding(.leading, 22)
                .padding(.bottom, 34)

            }
            .onAppear { wandGroesse = geo.size }
            .onChange(of: geo.size) { _, neu in wandGroesse = neu }
        }
        .sheet(item: $bearbeite) { note in
            NoteDetailView(note: note)
                .environmentObject(store)
                .presentationDetents([.large])
                .presentationCornerRadius(28)
        }
        .onDisappear {
            // Wer „Dokument oder Scan" abbricht, soll sein naechstes Dokument
            // nicht ungefragt an dieser Wand wiederfinden.
            if store.zeigeIdeenPinnwand == false { store.wandZiel = nil }
        }
        .onAppear {
            if let s = UUID(uuidString: letzteWandID),
               store.pinnBoards.contains(where: { $0.id == s && !$0.archiviert }) {
                boardID = s
            }
        }
        .alert("Wand umbenennen", isPresented: $benenneUm) {
            TextField("Name", text: $neuerName)
            Button("Sichern") { store.benenneBoard(boardID, auf: neuerName) }
            Button("Abbrechen", role: .cancel) { }
        }
        .alert("Neue Wand", isPresented: $neueWand) {
            TextField("Name, z. B. „Italien im Mai\u{201C}", text: $neuerName)
            Button("Anlegen") {
                let b = store.neuesBoard(name: neuerName)
                withAnimation(.spring(response: 0.32, dampingFraction: 0.86)) { boardID = b.id }
                letzteWandID = b.id.uuidString
            }
            Button("Abbrechen", role: .cancel) { }
        } message: {
            Text("Eine Mappe zu einer Sache — Dokumente, Ideen und Aufgaben an einem Ort.")
        }
        .confirmationDialog("An diese Wand", isPresented: $zeigeHinzufuegen, titleVisibility: .visible) {
            Button("Blitzidee") {
                store.wandZiel = (boardID, relativerPlatz())
                store.quickCaptureAutoRecord = false
                store.pendingQuickCapture = true
            }
            Button("Aufgabenliste") {
                listenName = ""
                neueListe = true
            }
            Button("Dokument oder Scan") {
                store.wandZiel = (boardID, relativerPlatz())
                store.pendingSection = .documents
                store.pendingNewEntry = .documents
                store.zeigeIdeenPinnwand = false
            }
            Button("Vorhandenes anpinnen") { zeigeAnpinnen = true }
            Button("Abbrechen", role: .cancel) { }
        }
        .alert("Neue Aufgabenliste", isPresented: $neueListe) {
            TextField("Wofür?", text: $listenName)
            Button("Anlegen") {
                store.wandZiel = (boardID, relativerPlatz())
                store.addList(title: listenName)
            }
            Button("Abbrechen", role: .cancel) { }
        }
        .sheet(isPresented: $zeigeAnpinnen) {
            AnpinnWahl(boardID: boardID, platz: relativerPlatz())
                .environmentObject(store)
                .presentationDetents([.medium, .large])
                .presentationCornerRadius(28)
        }
        .sheet(isPresented: $zeigeStile) {
            StilWahl(aktuell: stil,
                     aktuellesSymbol: board?.symbol ?? .zettelGelb,
                     name: board?.name ?? "Wand") { neu in
                store.setzeStil(boardID, neu)
            } waehleSymbol: { neu in
                store.setzeSymbol(boardID, neu)
            }
            .presentationDetents([.medium, .large])
            .presentationCornerRadius(28)
        }
        .quickLookPreview($vorschauURL)
        .fullScreenCover(isPresented: Binding(
            get: { bildURL != nil },
            set: { if !$0 { bildURL = nil } })) {
            if let url = bildURL { ImagePreviewView(url: url) }
        }
    }

    private var leerZustand: some View {
        VStack(spacing: 10) {
            Image(systemName: "pin")
                .font(.system(size: 40, weight: .semibold))
                .foregroundStyle(ArcaWarm.ideenGelb)
            Text("Diese Wand ist noch leer.\nTipp auf + für eine Blitzidee — oder pinne\netwas aus Dokumenten und Aufgaben an.")
                .font(.system(size: 14))
                .foregroundStyle(tinte.opacity(0.6))
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: Antippen und Wegnehmen

    private func oeffne(_ stueck: Wandstueck) {
        switch stueck.kind {
        case .note:
            if let n = store.notes.first(where: { $0.id == stueck.refID }) { bearbeite = n }
        case .document:
            guard let d = store.documents.first(where: { $0.id == stueck.refID }) else { return }
            let url = store.documentURL(for: d.filename)
            if d.type == .image { bildURL = url } else { vorschauURL = url }
        case .list:
            // Die Liste lebt in ihrem Bereich — die Wand tritt zur Seite.
            store.pendingSection = .lists
            store.zeigeIdeenPinnwand = false
        case .vault:
            break   // hängt nie an einer sichtbaren Wand
        }
    }

    /// Der Eimer nimmt von der Wand ab — er löscht nichts. Eine Idee lebt
    /// danach weiter im Ideen-Bereich, ein Dokument in seiner Gruppe.
    private func inDenEimer(_ stueck: Wandstueck) {
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        withAnimation(.easeIn(duration: 0.3)) { zerknuellt = stueck.id }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.31) {
            store.abpinnen(kind: stueck.kind, refID: stueck.refID, von: boardID)
            zerknuellt = nil
        }
    }

    // MARK: Kopf & Eimer

    private var kopf: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                Image(systemName: "pin.fill")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(ArcaWarm.terrakotta)
                VStack(alignment: .leading, spacing: 1) {
                    Text((board?.name ?? "Wand").uppercased())
                        .font(.system(size: 13, weight: .bold))
                        .tracking(0.8)
                        .foregroundStyle(tinte)
                        .lineLimit(1)
                    // Der Stand der Wand in einer Zeile — dafür ist sie da:
                    // sehen, wo ein Vorhaben steht, ohne durch vier Bereiche
                    // zu wandern.
                    if !wandBilanz.isEmpty {
                        Text(wandBilanz)
                            .font(.system(size: 10.5, weight: .medium))
                            .foregroundStyle(tinte.opacity(0.6))
                            .lineLimit(1)
                    }
                }
                Spacer()
                // Blitzidee — auf JEDER Wand, sie landet auf dieser hier
                Button {
                    store.quickCaptureAutoRecord = false
                    store.wandZiel = (boardID, nil)
                    store.pendingQuickCapture = true
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: 34, height: 34)
                        .background(ArcaWarm.terrakotta, in: Circle())
                }
                .buttonStyle(.plain)
                wandMenue
                if groessenKlasse == .regular {
                    Button {
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
                            store.ideenPinnwandGross.toggle()
                        }
                    } label: {
                        Image(systemName: store.ideenPinnwandGross
                              ? "arrow.down.right.and.arrow.up.left"
                              : "arrow.up.left.and.arrow.down.right")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(tinte)
                            .frame(width: 34, height: 34)
                            .background(.ultraThinMaterial, in: Circle())
                    }
                    .buttonStyle(.plain)
                }
            }
            wandWaehler
        }
        .padding(.horizontal, 16)
        .padding(.top, randOben + 8)   // unter die Statusleiste/Notch
    }

    /// Der gemerkte Platz in relativen Koordinaten — oder nichts, wenn
    /// das Neue über den Kopf statt über die Wand angelegt wurde.
    /// Eine Wand weiter oder zurück. An den Enden bleibt es stehen —
    /// ein Rundlauf verwirrt mehr, als er nützt.
    private func blaettere(_ richtung: Int) {
        let waende = waehlbareBoards
        guard let jetzt = waende.firstIndex(where: { $0.id == boardID }) else { return }
        let ziel = jetzt + richtung
        guard waende.indices.contains(ziel) else {
            UIImpactFeedbackGenerator(style: .rigid).impactOccurred()
            return
        }
        blaetterRichtung = richtung
        withAnimation(.spring(response: 0.36, dampingFraction: 0.85)) {
            boardID = waende[ziel].id
        }
        letzteWandID = waende[ziel].id.uuidString
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }

    private func relativerPlatz() -> [Double]? {
        guard let ort = tippOrt, wandGroesse.width > 0, wandGroesse.height > 0 else { return nil }
        let g = begrenze(ort, in: wandGroesse)
        return [Double(g.x) / Double(wandGroesse.width),
                Double(g.y) / Double(wandGroesse.height)]
    }

    /// „3 Dokumente · 2 Listen · 4 offen · 6 Ideen" — der Stand eines
    /// Vorhabens auf einen Blick, quer über alle Bereiche.
    private var wandBilanz: String {
        let s = stuecke
        var teile: [String] = []
        let docs = s.filter { $0.kind == .document }.count
        if docs > 0 { teile.append("\(docs) Dokument\(docs == 1 ? "" : "e")") }
        let listen = s.filter { $0.kind == .list }
        if !listen.isEmpty {
            let offen = listen
                .compactMap { st in store.lists.first { $0.id == st.refID } }
                .flatMap(\.items).filter { !$0.isDone }.count
            teile.append("\(listen.count) Liste\(listen.count == 1 ? "" : "n")")
            if offen > 0 { teile.append("\(offen) offen") }
        }
        let ideen = s.filter { $0.kind == .note }.count
        if ideen > 0 { teile.append("\(ideen) Idee\(ideen == 1 ? "" : "n")") }
        return teile.joined(separator: " · ")
    }

    private var wandMenue: some View {
        Menu {
            Button {
                neuerName = board?.name ?? ""
                benenneUm = true
            } label: { Label("Wand umbenennen", systemImage: "pencil") }
            Button {
                zeigeStile = true
            } label: { Label("Aussehen ändern", systemImage: "paintpalette") }
            Divider()
            Button {
                neuerName = ""
                neueWand = true
            } label: { Label("Neue Wand", systemImage: "plus.rectangle.on.rectangle") }
            if let b = board, !istSystemWand(b.id) {
                Divider()
                Button(role: .destructive) {
                    let weg = b.id
                    boardID = waehlbareBoards.first(where: { $0.id != weg })?.id ?? SystemBoard.meineWand
                    store.loescheBoard(weg)
                } label: { Label("Wand abreißen", systemImage: "trash") }
            }
        } label: {
            Image(systemName: "ellipsis")
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(tinte)
                .frame(width: 34, height: 34)
                .background(.ultraThinMaterial, in: Circle())
        }
    }

    /// „Meine Wand" und „Ideen" bleiben stehen — sie tragen den Bestand
    /// aus der Zeit vor den Wänden.
    private func istSystemWand(_ id: UUID) -> Bool {
        id == SystemBoard.meineWand || id == SystemBoard.ideen
    }

    /// Zwischen den Wänden wechseln — die Mappen zu den Vorhaben.
    private var wandWaehler: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 7) {
                ForEach(waehlbareBoards) { b in
                    let aktiv = b.id == boardID
                    Button {
                        // Auch der Tipp auf einen Reiter schiebt in die
                        // richtige Richtung — sonst fühlen sich Wischen und
                        // Tippen wie zwei verschiedene Sachen an.
                        let jetzt = waehlbareBoards.firstIndex { $0.id == boardID } ?? 0
                        let ziel = waehlbareBoards.firstIndex { $0.id == b.id } ?? 0
                        blaetterRichtung = ziel >= jetzt ? 1 : -1
                        withAnimation(.spring(response: 0.36, dampingFraction: 0.85)) {
                            boardID = b.id
                        }
                        letzteWandID = b.id.uuidString
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    } label: {
                        Text(b.name)
                            .font(.system(size: 12.5, weight: aktiv ? .bold : .medium))
                            .foregroundStyle(aktiv ? .white : tinte)
                            .padding(.horizontal, 13)
                            .padding(.vertical, 7)
                            .background {
                                if aktiv { Capsule().fill(ArcaWarm.terrakotta) }
                                else { Capsule().fill(.ultraThinMaterial) }
                            }
                            .overlay(Capsule().strokeBorder(.black.opacity(aktiv ? 0 : 0.07), lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                }
                Button {
                    neuerName = ""
                    neueWand = true
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(tinte.opacity(0.7))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 7)
                        .background(Capsule().fill(.ultraThinMaterial))
                        .overlay(Capsule().strokeBorder(.black.opacity(0.07), lineWidth: 1))
                }
                .buttonStyle(.plain)
            }
            .padding(.trailing, 16)
        }
        .scrollClipDisabled()
    }

    private func eimer(in size: CGSize) -> some View {
        let r = eimerRahmen(size)
        // Der Eimer nimmt ab, er löscht nicht — das Symbol sagt das auch.
        let symbol = ueberEimer ? "pin.slash.fill" : "pin.slash"
        return ZStack {
            Circle()
                .fill(ueberEimer ? Color.red.opacity(0.18) : Color.black.opacity(0.06))
                .overlay(Circle().strokeBorder(
                    ueberEimer ? Color.red : tinte.opacity(0.4),
                    style: StrokeStyle(lineWidth: 1.6, dash: ueberEimer ? [] : [5, 4])))
            Image(systemName: symbol)
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(ueberEimer ? .red : tinte.opacity(0.75))
        }
        .frame(width: r.width, height: r.height)
        .scaleEffect(ueberEimer ? 1.2 : 1)
        .animation(.spring(response: 0.25, dampingFraction: 0.7), value: ueberEimer)
        .position(x: r.midX, y: r.midY)
    }

    private func eimerRahmen(_ size: CGSize) -> CGRect {
        CGRect(x: size.width - 78, y: size.height - 78, width: 58, height: 58)
    }

    // MARK: Positionen

    private func neigung(_ stueck: Wandstueck) -> Double {
        if let a = stueck.anschlag { return a.drehung }
        let s = stueck.refID.uuidString.unicodeScalars.reduce(0) { $0 + Int($1.value) }
        return Double(s % 7 - 3) * 1.4
    }

    private func position(_ stueck: Wandstueck, idx: Int, in size: CGSize) -> CGPoint {
        // Relative Koordinaten (0…1): dieselbe Wand sieht auf iPhone und
        // iPad gleich aus — absolute Punkte taten das nie.
        if let a = stueck.anschlag, a.platziert {
            return begrenze(CGPoint(x: a.x * size.width, y: a.y * size.height), in: size)
        }
        // Automatische Streuung, bis man sie verschiebt
        let spalten = max(1, Int((size.width - 40) / (zettelBreite + 24)))
        let col = idx % spalten, row = idx / spalten
        let s = stueck.refID.uuidString.unicodeScalars.reduce(0) { $0 + Int($1.value) }
        let jx = CGFloat(s % 21 - 10), jy = CGFloat((s / 3) % 21 - 10)
        return begrenze(CGPoint(x: 100 + CGFloat(col) * (zettelBreite + 24) + jx,
                                y: randOben + 180 + CGFloat(row) * 165 + jy), in: size)
    }

    /// Nichts darf unter den Kopf mit dem Wand-Wähler rutschen — eine
    /// Marke ist bis zu ~200 hoch, ihre Mitte muss also tief genug sitzen.
    private func begrenze(_ p: CGPoint, in size: CGSize) -> CGPoint {
        CGPoint(x: min(max(p.x, zettelBreite / 2 + 8), size.width - zettelBreite / 2 - 8),
                y: min(max(p.y, randOben + 130), size.height - 60))
    }

    private func merkePosition(_ stueck: Wandstueck, _ p: CGPoint, in size: CGSize) {
        let g = begrenze(p, in: size)
        guard size.width > 0, size.height > 0 else { return }
        let a = stueck.anschlag
            ?? store.anpinnen(kind: stueck.kind, refID: stueck.refID, auf: boardID)
        store.merkePlatz(anschlagID: a.id,
                         x: Double(g.x) / Double(size.width),
                         y: Double(g.y) / Double(size.height))
    }

}

/// Wo die echten Korkbilder liegen. Aus Hans' Vorlage geschnitten:
/// die ganze Platte für die kleine Kachel, eine nahtlose Kachel der
/// Innenfläche für die große Wand.
private extension WandStil {
    var platteBild: String {
        switch self {
        case .korkNatur:   return "KorkNaturPlatte"
        case .korkDunkel:  return "KorkDunkelPlatte"
        case .korkHell:    return "KorkHellPlatte"
        case .korkVintage: return "KorkVintagePlatte"
        }
    }
    var texturBild: String {
        switch self {
        case .korkNatur:   return "KorkNaturTextur"
        case .korkDunkel:  return "KorkDunkelTextur"
        case .korkHell:    return "KorkHellTextur"
        case .korkVintage: return "KorkVintageTextur"
        }
    }
}

/// Der Wandbelag: eine echte Korkplatte hinter Glas, an vier Schrauben.
///
/// Kleine Kachel: die ganze Platte aus der Vorlage, Glas und Schrauben sind
/// im Bild. Große Wand: nur die Körnung, nahtlos gekachelt — dafür sitzen
/// Glanz und Schrauben gezeichnet obendrauf und bleiben bei jeder
/// Bildschirmgröße an ihrem Platz.
struct KorkWand: View {
    var stil: WandStil = .korkNatur
    var klein = false

    var body: some View {
        ZStack {
            belag
            if !klein && stil != .korkVintage {
                Glanz(klein: klein)
                Schrauben(dunkel: stil.dunkel, rand: 16)
            }
        }
        .ignoresSafeArea()
    }

    @ViewBuilder
    private var belag: some View {
        if klein {
            Image(stil.platteBild)
                .resizable()
                .aspectRatio(contentMode: .fill)
        } else if stil == .korkVintage {
            // Die alte Tafel lebt von ihrer Komposition — die kachelt nicht.
            // Sie wird auf die Wand gezogen, damit ihre Ecken Ecken bleiben.
            Image(stil.platteBild)
                .resizable()
        } else {
            Image(stil.texturBild)
                .resizable(resizingMode: .tile)
        }
    }
}

/// Die Glasscheibe über dem Kork: ein schräger Lichtschliff und ein Rand.
private struct Glanz: View {
    var klein = false
    var body: some View {
        ZStack {
            LinearGradient(colors: [.white.opacity(0.22), .clear, .clear,
                                    .white.opacity(0.07)],
                           startPoint: .topLeading, endPoint: .bottomTrailing)
            GeometryReader { geo in
                // zwei diagonale Lichtbahnen wie auf einer Scheibe
                Path { p in
                    p.move(to: CGPoint(x: -geo.size.height * 0.2, y: 0))
                    p.addLine(to: CGPoint(x: geo.size.width * 0.34, y: 0))
                    p.addLine(to: CGPoint(x: geo.size.width * 0.10, y: geo.size.height))
                    p.addLine(to: CGPoint(x: -geo.size.height * 0.5, y: geo.size.height))
                    p.closeSubpath()
                }
                .fill(.white.opacity(0.07))
                Path { p in
                    p.move(to: CGPoint(x: geo.size.width * 0.44, y: 0))
                    p.addLine(to: CGPoint(x: geo.size.width * 0.56, y: 0))
                    p.addLine(to: CGPoint(x: geo.size.width * 0.30, y: geo.size.height))
                    p.addLine(to: CGPoint(x: geo.size.width * 0.18, y: geo.size.height))
                    p.closeSubpath()
                }
                .fill(.white.opacity(0.05))
            }
            RoundedRectangle(cornerRadius: klein ? 10 : 0, style: .continuous)
                .strokeBorder(.white.opacity(0.28), lineWidth: klein ? 1 : 1.5)
        }
        .allowsHitTesting(false)
    }
}

/// Vier Schrauben, die die Scheibe halten.
private struct Schrauben: View {
    let dunkel: Bool
    var rand: CGFloat = 16
    /// In der kleinen Mappe nur die zwei oberen — die unteren säßen sonst
    /// mitten im Namen.
    var klein = false

    private var groesse: CGFloat { klein ? 10 : 15 }

    var body: some View {
        GeometryReader { geo in
            ForEach(0..<(klein ? 2 : 4), id: \.self) { i in
                schraube
                    .position(x: i % 2 == 0 ? rand : geo.size.width - rand,
                              y: i < 2 ? rand : geo.size.height - rand)
            }
        }
        .allowsHitTesting(false)
    }

    private var schraube: some View {
        ZStack {
            Circle()
                .fill(RadialGradient(
                    colors: dunkel
                        ? [Color(white: 0.55), Color(white: 0.26), Color(white: 0.12)]
                        : [Color(white: 0.98), Color(white: 0.72), Color(white: 0.45)],
                    center: .init(x: 0.34, y: 0.28), startRadius: 0, endRadius: groesse * 0.75))
                .frame(width: groesse, height: groesse)
            Capsule()
                .fill(.black.opacity(0.35))
                .frame(width: groesse * 0.53, height: klein ? 1.2 : 1.6)
                .rotationEffect(.degrees(28))
            Circle()
                .strokeBorder(.black.opacity(0.25), lineWidth: 0.6)
                .frame(width: groesse, height: groesse)
        }
        .shadow(color: .black.opacity(0.4), radius: klein ? 1.2 : 2, x: 0, y: klein ? 1 : 1.5)
    }
}

/// Das Aussehen einer Wand wählen: Belag der Wand und ihr Zeichen
/// auf dem Start.
private struct StilWahl: View {
    let aktuell: WandStil
    let aktuellesSymbol: WandSymbol
    let name: String
    let waehle: (WandStil) -> Void
    let waehleSymbol: (WandSymbol) -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Text("Belag der Wand")
                    .font(.system(size: 17, weight: .bold))
                    .padding(.top, 22)
                // Hochkant wie die Wand selbst — quer zeigte vom Efeu nur
                // einen Ausschnitt und log über das Seitenverhältnis.
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 100), spacing: 14)], spacing: 14) {
                    ForEach(WandStil.allCases) { s in
                        Button { waehle(s) } label: {
                            VStack(spacing: 7) {
                                KorkWand(stil: s, klein: true)
                                    .frame(width: 96, height: 150)
                                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                                    .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous)
                                        .strokeBorder(s == aktuell ? ArcaWarm.terrakotta : .black.opacity(0.1),
                                                      lineWidth: s == aktuell ? 2.5 : 1))
                                Text(s.label)
                                    .font(.system(size: 12, weight: s == aktuell ? .bold : .medium))
                                    .foregroundStyle(s == aktuell ? ArcaWarm.terrakotta : .secondary)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }

                Text("Zeichen auf dem Start")
                    .font(.system(size: 17, weight: .bold))
                    .padding(.top, 4)
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 86), spacing: 12)], spacing: 14) {
                    ForEach(WandSymbol.allCases) { s in
                        Button { waehleSymbol(s) } label: {
                            VStack(spacing: 6) {
                                WandSymbolBild(symbol: s, kante: 62, beschriftung: name)
                                    .padding(5)
                                    .background {
                                        if s == aktuellesSymbol {
                                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                                .strokeBorder(ArcaWarm.terrakotta, lineWidth: 2.5)
                                        }
                                    }
                                Text(s.label)
                                    .font(.system(size: 11, weight: s == aktuellesSymbol ? .bold : .medium))
                                    .foregroundStyle(s == aktuellesSymbol ? ArcaWarm.terrakotta : .secondary)
                                    .lineLimit(1)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
                Spacer(minLength: 20)
            }
            .padding(.horizontal, 22)
        }
    }
}

// MARK: - Die Marken
//
// Der Reiz einer echten Pinnwand ist, dass nicht alles gleich aussieht.
// Eine Quittung ist kein Notizzettel ist kein Foto. Gleiche Familie
// (Papier, warmes Licht, Zwecke), unterschiedliche Gestalt.

private struct MarkeAnsicht: View {
    @EnvironmentObject var store: AppStore
    let stueck: Wandstueck
    let breite: CGFloat

    var body: some View {
        switch stueck.kind {
        case .note:
            if let n = store.notes.first(where: { $0.id == stueck.refID }) {
                ZettelKarte(note: n, breite: breite)
            }
        case .document:
            if let d = store.documents.first(where: { $0.id == stueck.refID }) {
                DokumentMarke(doc: d, breite: breite,
                              datei: store.filesDirectory.appendingPathComponent(d.filename))
            }
        case .list:
            if let l = store.lists.first(where: { $0.id == stueck.refID }) {
                KlemmbrettMarke(liste: l, breite: breite)
            }
        case .vault:
            EmptyView()
        }
    }
}

/// Ein einzelner Ideen-Zettel mit plastischer Reißzwecke.
private struct ZettelKarte: View {
    let note: NoteEntry
    let breite: CGFloat

    private var papier: NoteColor { NoteColor.for_(note.colorTag) }

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            if !note.title.isEmpty {
                Text(note.title)
                    .font(.system(size: 12.5, weight: .bold))
                    .lineLimit(2)
            }
            Text(note.text.isEmpty ? "…" : note.text)
                .font(.system(size: 11))
                .foregroundStyle(.black.opacity(0.72))
                .lineLimit(5)
            // Anhänge-Andeutung (Foto/Dokument) — zeigt: die Idee ist ein Blatt
            if !note.fotos.isEmpty || !note.verknuepfteDokumente.isEmpty {
                HStack(spacing: 8) {
                    if !note.fotos.isEmpty {
                        Label("\(note.fotos.count)", systemImage: "photo")
                            .font(.system(size: 9, weight: .semibold))
                    }
                    if !note.verknuepfteDokumente.isEmpty {
                        Label("\(note.verknuepfteDokumente.count)", systemImage: "doc.text")
                            .font(.system(size: 9, weight: .semibold))
                    }
                }
                .foregroundStyle(.black.opacity(0.45))
                .padding(.top, 2)
            }
        }
        .frame(width: breite, alignment: .topLeading)
        .frame(minHeight: 96, alignment: .topLeading)
        .padding(11)
        .padding(.top, 16)   // Platz für die Reißzwecke — kein Kollidieren mit dem Text
        // Papierner Verlauf statt flacher Fläche
        .background(
            LinearGradient(colors: [papier.bg.opacity(0.97), papier.bg],
                           startPoint: .top, endPoint: .bottom)
        )
        // Sanfter Lichtschein oben (wie Licht auf Papier)
        .overlay(alignment: .top) {
            LinearGradient(colors: [.white.opacity(0.35), .clear],
                           startPoint: .top, endPoint: .center)
                .allowsHitTesting(false)
        }
        .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 5, style: .continuous)
            .strokeBorder(.black.opacity(0.06), lineWidth: 0.7))
        // Plastische Reißzwecke — ganz auf dem Zettel, oben mittig
        .overlay(alignment: .top) { Reisszwecke().offset(y: 10) }
        .contentShape(RoundedRectangle(cornerRadius: 5))
    }
}

/// Ein Dokument an der Wand. Ein Scan ist ein Polaroid in Fotoecken,
/// ein PDF ein Blatt mit Eselsohr an der Büroklammer, eine Mail eine Karte.
private struct DokumentMarke: View {
    let doc: DocumentEntry
    let breite: CGFloat
    let datei: URL

    private var istBild: Bool { doc.type == .image || doc.type == .video }

    var body: some View {
        if istBild { polaroid } else { blatt }
    }

    // MARK: Polaroid — für Scans und Fotos

    private var polaroid: some View {
        VStack(spacing: 0) {
            DocThumbnail(url: datei, type: doc.type, gross: true)
                .frame(width: breite - 16, height: breite - 16)
                .clipped()
                .background(Color.black.opacity(0.06))
            Text(doc.title)
                .font(.system(size: 11.5, weight: .medium, design: .serif))
                .foregroundStyle(.black.opacity(0.7))
                .lineLimit(1)
                .frame(width: breite - 16, alignment: .center)
                .padding(.vertical, 9)
        }
        .padding(8)
        .padding(.bottom, 2)
        .background(
            LinearGradient(colors: [.white, Color(white: 0.955)],
                           startPoint: .top, endPoint: .bottom)
        )
        .clipShape(RoundedRectangle(cornerRadius: 3, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 3, style: .continuous)
            .strokeBorder(.black.opacity(0.07), lineWidth: 0.7))
        // Fotoecken statt Zwecke — ein Abzug wird nicht durchbohrt
        .overlay(alignment: .topLeading)     { Fotoecke().rotationEffect(.degrees(0)) }
        .overlay(alignment: .topTrailing)    { Fotoecke().rotationEffect(.degrees(90)) }
        .overlay(alignment: .bottomTrailing) { Fotoecke().rotationEffect(.degrees(180)) }
        .overlay(alignment: .bottomLeading)  { Fotoecke().rotationEffect(.degrees(270)) }
        .contentShape(RoundedRectangle(cornerRadius: 3))
    }

    // MARK: Blatt — für PDF, Text und Mail

    private var blatt: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Image(systemName: symbol)
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(docTypeColor(doc.type))
                Text(doc.type.rawValue.uppercased())
                    .font(.system(size: 8.5, weight: .heavy))
                    .tracking(0.7)
                    .foregroundStyle(.black.opacity(0.35))
            }
            Text(doc.title)
                .font(.system(size: 12.5, weight: .bold))
                .foregroundStyle(.black.opacity(0.82))
                .lineLimit(3)
            Spacer(minLength: 0)
            Text(doc.category)
                .font(.system(size: 9, weight: .semibold))
                .foregroundStyle(.black.opacity(0.32))
                .lineLimit(1)
        }
        .frame(width: breite, alignment: .topLeading)
        .frame(minHeight: 104, alignment: .topLeading)
        .padding(11)
        .padding(.top, 12)
        .background(
            ZStack {
                LinearGradient(colors: [.white, Color(white: 0.97)],
                               startPoint: .top, endPoint: .bottom)
                // die Linien eines Briefbogens, ganz zart
                VStack(spacing: 13) {
                    ForEach(0..<7, id: \.self) { _ in
                        Rectangle().fill(Color(red: 0.35, green: 0.45, blue: 0.7).opacity(0.05))
                            .frame(height: 0.7)
                    }
                }
                .padding(.top, 34)
            }
        )
        .clipShape(BlattMitEselsohr(ohr: 16))
        .overlay(BlattMitEselsohr(ohr: 16).stroke(.black.opacity(0.07), lineWidth: 0.7))
        // Das umgeschlagene Eck sitzt auf dem Blatt, nicht darin
        .overlay(alignment: .topTrailing) { Eselsohr(kante: 16) }
        // Büroklammer statt Zwecke — Papier wird geklemmt, nicht durchstochen
        .overlay(alignment: .topLeading) { Bueroklammer().offset(x: 14, y: -9) }
        .contentShape(Rectangle())
    }

    private var symbol: String {
        switch doc.type {
        case .pdf:   return "doc.fill"
        case .text:  return "doc.text.fill"
        case .mail:  return "envelope.fill"
        case .image: return "photo"
        case .video: return "video.fill"
        }
    }
}

/// Eine Aufgabenliste als Klemmbrett: Metallklammer, die ersten Punkte
/// mit echten Häkchen, und wie weit man ist.
private struct KlemmbrettMarke: View {
    let liste: ListEntry
    let breite: CGFloat

    private var erledigt: Int { liste.items.filter(\.isDone).count }

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(liste.title)
                .font(.system(size: 12.5, weight: .bold))
                .foregroundStyle(.black.opacity(0.82))
                .lineLimit(2)
            VStack(alignment: .leading, spacing: 5) {
                ForEach(liste.items.prefix(3)) { punkt in
                    HStack(spacing: 6) {
                        Image(systemName: punkt.isDone ? "checkmark.square.fill" : "square")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(punkt.isDone
                                             ? NoteColor.for_(liste.colorTag).accent
                                             : .black.opacity(0.3))
                        Text(punkt.text)
                            .font(.system(size: 10.5))
                            .strikethrough(punkt.isDone, color: .black.opacity(0.3))
                            .foregroundStyle(.black.opacity(punkt.isDone ? 0.38 : 0.7))
                            .lineLimit(1)
                    }
                }
                if liste.items.count > 3 {
                    Text("+ \(liste.items.count - 3) weitere")
                        .font(.system(size: 9, weight: .medium))
                        .foregroundStyle(.black.opacity(0.3))
                }
            }
            if !liste.items.isEmpty {
                Text("\(erledigt)/\(liste.items.count)")
                    .font(.system(size: 9.5, weight: .heavy))
                    .monospacedDigit()
                    .foregroundStyle(erledigt == liste.items.count
                                     ? Color.green.opacity(0.75) : .black.opacity(0.35))
            }
        }
        .frame(width: breite, alignment: .topLeading)
        .frame(minHeight: 96, alignment: .topLeading)
        .padding(11)
        .padding(.top, 18)   // Platz für die Klammer
        .background(
            ZStack {
                // kariertes Papier
                Color(red: 0.995, green: 0.99, blue: 0.97)
                GeometryReader { geo in
                    let s: CGFloat = 11
                    Path { p in
                        var x: CGFloat = 0
                        while x < geo.size.width { p.move(to: .init(x: x, y: 0)); p.addLine(to: .init(x: x, y: geo.size.height)); x += s }
                        var y: CGFloat = 0
                        while y < geo.size.height { p.move(to: .init(x: 0, y: y)); p.addLine(to: .init(x: geo.size.width, y: y)); y += s }
                    }
                    .stroke(Color(red: 0.4, green: 0.5, blue: 0.7).opacity(0.07), lineWidth: 0.6)
                }
            }
        )
        .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
        // das Brett darunter
        .background(
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(LinearGradient(colors: [Color(red: 0.66, green: 0.49, blue: 0.31),
                                              Color(red: 0.52, green: 0.37, blue: 0.22)],
                                     startPoint: .top, endPoint: .bottom))
                .padding(-4)
        )
        .overlay(alignment: .top) { Metallklammer().offset(y: -7) }
        .contentShape(Rectangle())
    }
}

// MARK: - Kleinteile

/// Glasige, plastische Reißzwecke mit Glanzpunkt und Schlagschatten.
private struct Reisszwecke: View {
    var body: some View {
        ZStack {
            Ellipse()
                .fill(.black.opacity(0.16))
                .frame(width: 15, height: 5)
                .offset(y: 8)
                .blur(radius: 1.5)
            Circle()
                .fill(RadialGradient(
                    colors: [Color(red: 1.0, green: 0.56, blue: 0.52),
                             Color(red: 0.86, green: 0.14, blue: 0.12),
                             Color(red: 0.52, green: 0.03, blue: 0.03)],
                    center: .init(x: 0.34, y: 0.30), startRadius: 0, endRadius: 10))
                .frame(width: 16, height: 16)
                .overlay(
                    Circle().fill(.white.opacity(0.9))
                        .frame(width: 4, height: 4)
                        .offset(x: -2.6, y: -3)
                        .blur(radius: 0.4)
                )
                .overlay(Circle().strokeBorder(.black.opacity(0.15), lineWidth: 0.5))
                .shadow(color: .black.opacity(0.35), radius: 2, x: 0, y: 2)
        }
    }
}

/// Die schwarze Ecke, in der ein Abzug im Album steckt.
private struct Fotoecke: View {
    var body: some View {
        Path { p in
            p.move(to: .init(x: 0, y: 0))
            p.addLine(to: .init(x: 15, y: 0))
            p.addLine(to: .init(x: 0, y: 15))
            p.closeSubpath()
        }
        .fill(LinearGradient(colors: [Color(white: 0.32), Color(white: 0.16)],
                             startPoint: .topLeading, endPoint: .bottomTrailing))
        .frame(width: 15, height: 15)
        .shadow(color: .black.opacity(0.2), radius: 1, x: 0, y: 1)
    }
}

/// Ein Blatt, dem oben rechts die Ecke umgeschlagen ist.
private struct BlattMitEselsohr: Shape {
    let ohr: CGFloat
    func path(in r: CGRect) -> Path {
        var p = Path()
        p.move(to: .init(x: r.minX + 3, y: r.minY))
        p.addLine(to: .init(x: r.maxX - ohr, y: r.minY))
        p.addLine(to: .init(x: r.maxX, y: r.minY + ohr))
        p.addLine(to: .init(x: r.maxX, y: r.maxY - 3))
        p.addQuadCurve(to: .init(x: r.maxX - 3, y: r.maxY), control: .init(x: r.maxX, y: r.maxY))
        p.addLine(to: .init(x: r.minX + 3, y: r.maxY))
        p.addQuadCurve(to: .init(x: r.minX, y: r.maxY - 3), control: .init(x: r.minX, y: r.maxY))
        p.addLine(to: .init(x: r.minX, y: r.minY + 3))
        p.addQuadCurve(to: .init(x: r.minX + 3, y: r.minY), control: .init(x: r.minX, y: r.minY))
        return p
    }
}

/// Das umgeschlagene Eck selbst — liegt sichtbar auf dem Blatt.
private struct Eselsohr: View {
    let kante: CGFloat
    var body: some View {
        Path { p in
            p.move(to: .init(x: 0, y: 0))
            p.addLine(to: .init(x: kante, y: kante))
            p.addLine(to: .init(x: 0, y: kante))
            p.closeSubpath()
        }
        .fill(LinearGradient(colors: [Color(white: 0.86), Color(white: 0.95)],
                             startPoint: .topTrailing, endPoint: .bottomLeading))
        .frame(width: kante, height: kante)
        .shadow(color: .black.opacity(0.12), radius: 1, x: -1, y: 1)
    }
}

/// Eine Büroklammer über der oberen Kante.
private struct Bueroklammer: View {
    var body: some View {
        ZStack {
            Capsule()
                .strokeBorder(
                    LinearGradient(colors: [Color(white: 0.78), Color(white: 0.52)],
                                   startPoint: .leading, endPoint: .trailing),
                    lineWidth: 2.2)
                .frame(width: 13, height: 32)
            Capsule()
                .strokeBorder(Color(white: 0.62), lineWidth: 1.6)
                .frame(width: 6, height: 22)
                .offset(y: 3)
        }
        .rotationEffect(.degrees(9))
        .shadow(color: .black.opacity(0.22), radius: 1.5, x: 0, y: 1.5)
    }
}

/// Die Metallklammer eines Klemmbretts.
private struct Metallklammer: View {
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 3, style: .continuous)
                .fill(LinearGradient(colors: [Color(white: 0.88), Color(white: 0.58)],
                                     startPoint: .top, endPoint: .bottom))
                .frame(width: 48, height: 15)
            RoundedRectangle(cornerRadius: 2, style: .continuous)
                .fill(Color(white: 0.42).opacity(0.55))
                .frame(width: 30, height: 4)
                .offset(y: -2)
        }
        .overlay(RoundedRectangle(cornerRadius: 3).strokeBorder(.black.opacity(0.18), lineWidth: 0.6)
            .frame(width: 48, height: 15))
        .shadow(color: .black.opacity(0.3), radius: 2, x: 0, y: 2)
    }
}

/// Vorhandenes an die Wand holen: Dokumente, Aufgabenlisten, Ideen.
/// Passwörter stehen hier bewusst nicht — sie hängen an keiner Wand.
private struct AnpinnWahl: View {
    @EnvironmentObject var store: AppStore
    @Environment(\.dismiss) private var dismiss
    let boardID: UUID
    let platz: [Double]?

    @State private var suche = ""
    @State private var art: FavoriteKind = .document

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Picker("", selection: $art) {
                    Text("Dokumente").tag(FavoriteKind.document)
                    Text("Aufgaben").tag(FavoriteKind.list)
                    Text("Ideen").tag(FavoriteKind.note)
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)

                List {
                    ForEach(treffer, id: \.id) { eintrag in
                        Button {
                            pinne(eintrag.id)
                        } label: {
                            HStack(spacing: 12) {
                                Image(systemName: symbol)
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundStyle(ArcaWarm.terrakotta)
                                    .frame(width: 24)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(eintrag.titel)
                                        .font(.system(size: 15, weight: .medium))
                                        .foregroundStyle(.primary)
                                        .lineLimit(1)
                                    if !eintrag.unter.isEmpty {
                                        Text(eintrag.unter)
                                            .font(.system(size: 12))
                                            .foregroundStyle(.secondary)
                                            .lineLimit(1)
                                    }
                                }
                                Spacer()
                                Image(systemName: "pin")
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                    if treffer.isEmpty {
                        Text("Hier hängt schon alles — oder es gibt noch nichts.")
                            .font(.system(size: 14))
                            .foregroundStyle(.secondary)
                    }
                }
                .listStyle(.plain)
            }
            .searchable(text: $suche, prompt: "Suchen")
            .navigationTitle("Anpinnen")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Fertig") { dismiss() }
                }
            }
        }
    }

    private struct Zeile { let id: UUID; let titel: String; let unter: String }

    private var symbol: String {
        switch art {
        case .document: return "doc.fill"
        case .list:     return "checkmark.square.fill"
        case .note:     return "lightbulb.fill"
        case .vault:    return "lock.fill"
        }
    }

    /// Was noch nicht an dieser Wand hängt — und zur Suche passt.
    private var treffer: [Zeile] {
        let dran = Set(store.anschlaege.filter { $0.boardID == boardID }.map(\.refID))
        let s = suche.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        func passt(_ text: String) -> Bool { s.isEmpty || text.lowercased().contains(s) }

        switch art {
        case .document:
            return store.documents
                .filter { !dran.contains($0.id) && $0.category != "Top Secret" && passt($0.title) }
                .sorted { $0.dateAdded > $1.dateAdded }
                .map { Zeile(id: $0.id, titel: $0.title, unter: "\($0.type.rawValue) · \($0.category)") }
        case .list:
            return store.lists
                .filter { !dran.contains($0.id) && passt($0.title) }
                .sorted { $0.dateCreated > $1.dateCreated }
                .map { l in
                    let offen = l.items.filter { !$0.isDone }.count
                    return Zeile(id: l.id, titel: l.title,
                                 unter: l.items.isEmpty ? "leer" : "\(offen) von \(l.items.count) offen")
                }
        case .note:
            return store.notes
                .filter { !dran.contains($0.id) && (passt($0.title) || passt($0.text)) }
                .sorted { $0.dateCreated > $1.dateCreated }
                .map { Zeile(id: $0.id,
                             titel: $0.title.isEmpty ? ($0.text.isEmpty ? "Notiz" : $0.text) : $0.title,
                             unter: $0.isQuickIdea ? "Blitzidee" : "") }
        case .vault:
            return []
        }
    }

    private func pinne(_ refID: UUID) {
        let a = store.anpinnen(kind: art, refID: refID, auf: boardID)
        if let p = platz, p.count == 2 {
            store.merkePlatz(anschlagID: a.id, x: p[0], y: p[1])
        }
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }
}

// MARK: - Die Zettel-Zeichen der Wände
//
// Aus dem Aufkleber-Blatt, obere Reihe des zweiten Blocks: gelber Zettel
// mit Zwecke, blauer und rosa Zettel mit Klebeband, ein Notizblock und ein
// Foto-Abzug. Sie stehen auf dem Start für die Wände.

struct WandSymbolBild: View {
    let symbol: WandSymbol
    var kante: CGFloat = 76
    /// Was auf dem Zettel steht — der Name der Wand.
    var beschriftung: String? = nil

    var body: some View {
        ZStack {
            Image(bild)
                .resizable()
                .aspectRatio(contentMode: .fit)
            if let beschriftung, !beschriftung.isEmpty {
                Text(beschriftung)
                    .font(.custom("Marker Felt", size: kante * 0.15,
                                  relativeTo: .caption).weight(.medium))
                    .foregroundStyle(schriftFarbe)
                    .shadow(color: symbol == .polaroid ? .black.opacity(0.6) : .clear,
                            radius: 2)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .minimumScaleFactor(0.55)
                    .frame(width: kante * 0.62)
                    .offset(y: textVersatz)
            }
        }
        .frame(width: kante, height: kante)
    }

    private var bild: String {
        switch symbol {
        case .zettelGelb:  return "WandZettelGelb"
        case .zettelBlau:  return "WandZettelBlau"
        case .zettelRosa:  return "WandZettelRosa"
        case .notizblock:  return "WandNotizblock"
        case .polaroid:    return "WandPolaroid"
        }
    }

    /// Wohin die Schrift auf dem jeweiligen Blatt gehört.
    private var textVersatz: CGFloat {
        switch symbol {
        case .polaroid:   return kante * 0.06
        case .notizblock: return kante * 0.11
        // Bei den Haftzetteln sitzt oben die Zwecke bzw. das Klebeband —
        // die Schrift muss darunter beginnen, sonst schreibt man dagegen.
        default:          return kante * 0.16
        }
    }

    private var schriftFarbe: Color {
        symbol == .polaroid ? .white : .black.opacity(0.72)
    }
}

/// Der EXIT-Knopf vom Blatt: rote Glaskuppel mit weißem Kreuz und einem
/// kühlen Lichtring. Er schließt die Wand — unten links, wo der Daumen liegt.
struct ExitKnopf: View {
    let tippe: () -> Void

    var body: some View {
        Button(action: tippe) {
            ZStack {
                Circle()
                    .strokeBorder(
                        AngularGradient(colors: [Color(red: 0.65, green: 0.85, blue: 1.0),
                                                 Color(white: 0.85),
                                                 Color(red: 0.55, green: 0.78, blue: 0.98),
                                                 Color(white: 0.92),
                                                 Color(red: 0.65, green: 0.85, blue: 1.0)],
                                        center: .center),
                        lineWidth: 2.4)
                    .frame(width: 44, height: 44)
                    .shadow(color: Color(red: 0.45, green: 0.75, blue: 1.0).opacity(0.55),
                            radius: 5)
                Circle()
                    .fill(RadialGradient(
                        colors: [Color(red: 0.98, green: 0.38, blue: 0.36),
                                 Color(red: 0.84, green: 0.13, blue: 0.14),
                                 Color(red: 0.52, green: 0.04, blue: 0.06)],
                        center: .init(x: 0.34, y: 0.26), startRadius: 1, endRadius: 26))
                    .frame(width: 38, height: 38)
                Ellipse()
                    .fill(LinearGradient(colors: [.white.opacity(0.65), .white.opacity(0.05)],
                                         startPoint: .top, endPoint: .bottom))
                    .frame(width: 22, height: 11)
                    .offset(y: -9)
                    .blur(radius: 0.6)
                VStack(spacing: 0) {
                    Image(systemName: "xmark")
                        .font(.system(size: 13, weight: .heavy))
                        .foregroundStyle(.white)
                        .shadow(color: .black.opacity(0.35), radius: 1, y: 1)
                    Text("EXIT")
                        .font(.system(size: 6.5, weight: .heavy))
                        .tracking(0.7)
                        .foregroundStyle(.white.opacity(0.95))
                }
                .offset(y: 1)
            }
            .frame(width: 46, height: 46)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Wand schließen")
    }
}
