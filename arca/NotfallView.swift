//
//  NotfallView.swift
//  Arca
//
//  Der Notfallkoffer: das Wichtigste (Herzschrittmacher, Allergien …), die
//  Notfallkontakte, die Notrufnummern, die eigenen Medikamente und die
//  Sperr-Hotlines der Karten.
//  Erreichbar aus dem roten Koffer und vom Sperrbildschirm — dort zeigt er
//  Medikamente und Kontakte nur, wenn man das ausdruecklich einschaltet.
//
//  Entwickler: Hans zen Ruffinen
//

import SwiftUI
import PhotosUI

struct NotfallView: View {
    /// Karten mit hinterlegter Sperr-Hotline (leer im gesperrten Zustand)
    var karten: [VaultEntry] = []
    /// Vom Sperrbildschirm: nur öffentliche Nummern, Hinweis auf Entsperren
    var nurOeffentlich: Bool = false

    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var store: AppStore

    /// Medikamente und Kontakte auch ohne Entsperren zeigen?
    ///
    /// Standard AUS. Wer einschaltet, macht die Liste fuer Rettungskraefte
    /// lesbar — und damit fuer jeden, der das Telefon in der Hand haelt.
    /// Pro Geraet gespeichert (AppStorage, nicht iCloud): ob der
    /// Sperrbildschirm etwas preisgibt, entscheidet man je Telefon.
    @AppStorage("notfallAufSperrbildschirm") private var aufSperrbildschirm = false

    @State private var bearbeite: NotfallEintrag? = nil
    @State private var fotoGross: URL? = nil

    private var wichtiges: [NotfallEintrag] {
        store.notfallEintraege.filter { $0.art == .wichtig }
            .sorted { ($0.reihenfolge, $0.name) < ($1.reihenfolge, $1.name) }
    }
    private var medikamente: [NotfallEintrag] {
        store.notfallEintraege.filter { $0.art == .medikament }
            .sorted { ($0.reihenfolge, $0.name) < ($1.reihenfolge, $1.name) }
    }
    private var kontakte: [NotfallEintrag] {
        store.notfallEintraege.filter { $0.art == .kontakt }
            .sorted { ($0.reihenfolge, $0.name) < ($1.reihenfolge, $1.name) }
    }
    /// „Beloc Zok, Aspirin und 2 weitere" — sagt, was auf dem Blatt steht,
    /// ohne es aufzuschlagen.
    private var medikamenteUntertitel: String {
        let namen = medikamente.map(\.name).filter { !$0.isEmpty }
        switch namen.count {
        case 0:  return "Noch keine eingetragen"
        case 1:  return namen[0]
        case 2:  return "\(namen[0]) und \(namen[1])"
        default: return "\(namen[0]), \(namen[1]) und \(namen.count - 2) weitere"
        }
    }

    /// Darf dieser Aufruf die persoenlichen Eintraege zeigen?
    private var persoenlichSichtbar: Bool { !nurOeffentlich || aufSperrbildschirm }

    struct Notrufnummer: Identifiable {
        let id: String
        let name: String
        let nummer: String
        let symbol: String
    }

    private let notrufnummern: [Notrufnummer] = [
        Notrufnummer(id: "117",  name: "Polizei",             nummer: "117",  symbol: "shield.lefthalf.filled"),
        Notrufnummer(id: "144",  name: "Sanität / Ambulanz",  nummer: "144",  symbol: "cross.case.fill"),
        Notrufnummer(id: "118",  name: "Feuerwehr",           nummer: "118",  symbol: "flame.fill"),
        Notrufnummer(id: "1414", name: "Rega (Rettungsflug)", nummer: "1414", symbol: "helicopter"),
        Notrufnummer(id: "112",  name: "Europäischer Notruf", nummer: "112",  symbol: "globe.europe.africa.fill"),
        Notrufnummer(id: "145",  name: "Tox Info (Vergiftung)", nummer: "145", symbol: "pills.fill"),
    ]

    private func anrufen(_ nummer: String) {
        let bereinigt = nummer.filter { "0123456789+".contains($0) }
        guard let url = URL(string: "tel:\(bereinigt)"), !bereinigt.isEmpty else { return }
        UIApplication.shared.open(url)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {

                    // Vom Sperrbildschirm ohne Freigabe steht nur der Notruf da:
                    // wer das Telefon findet, soll nicht erst an einem
                    // „erscheint nach dem Entsperren" vorbei muessen.
                    if persoenlichSichtbar {
                        // ── Wichtig: das Erste, was ein Sanitaeter wissen muss ──
                        VStack(alignment: .leading, spacing: 10) {
                            sektionsKopf("Wichtig", icon: "heart.text.square.fill", art: .wichtig)
                            if wichtiges.isEmpty {
                                leerHinweis("Herzschrittmacher, Allergien, Blutgruppe — was Rettungskräfte zuerst wissen müssen.")
                            } else {
                                ForEach(wichtiges) { wichtigZeile($0) }
                            }
                        }

                        // ── Notfallkontakte ──
                        VStack(alignment: .leading, spacing: 10) {
                            sektionsKopf("Notfallkontakte", icon: "person.2.fill", art: .kontakt)
                            if kontakte.isEmpty {
                                leerHinweis("Wer soll angerufen werden, wenn dir etwas passiert?")
                            } else {
                                ForEach(kontakte) { kontaktZeile($0) }
                            }
                        }

                        // ── Notruf Schweiz: eine Zeile, die Nummern auf eigener Seite ──
                        notrufZeile

                        // ── Meine Medikamente: eine Zeile, dahinter das Blatt ──
                        NavigationLink {
                            MedikamentenSeite(nurLesen: nurOeffentlich)
                        } label: {
                            HStack(spacing: 12) {
                                Image(systemName: "pills.fill")
                                    .font(.system(size: 15, weight: .semibold))
                                    .foregroundStyle(.red)
                                    .frame(width: 36, height: 36)
                                    .background(Color.red.opacity(0.10), in: RoundedRectangle(cornerRadius: 10))
                                VStack(alignment: .leading, spacing: 1) {
                                    Text("Meine Medikamente")
                                        .font(.system(size: 15, weight: .semibold))
                                        .foregroundStyle(.primary)
                                    Text(medikamenteUntertitel)
                                        .font(.system(size: 12))
                                        .foregroundStyle(.secondary)
                                        .lineLimit(1)
                                }
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundStyle(.secondary)
                            }
                            .padding(.horizontal, 14)
                            .padding(.vertical, 10)
                            .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 14))
                        }
                        .buttonStyle(.plain)
                    } else {
                        notrufZeile
                    }

                    if !persoenlichSichtbar {
                        leerHinweis("Wichtige Hinweise, Medikamente und Notfallkontakte erscheinen erst mit deinem Code.")
                    }

                    // ── Sperrbildschirm-Freigabe (nur entsperrt einstellbar) ──
                    if !nurOeffentlich {
                        Toggle(isOn: $aufSperrbildschirm) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Auch ohne Code zeigen")
                                    .font(.system(size: 14, weight: .semibold))
                                Text(aufSperrbildschirm
                                     ? "Über den Notfall-Knopf bei der Code-Eingabe sieht man Medikamente und Kontakte ohne deinen Code — Rettungskräfte, aber auch jeder andere."
                                     : "Aus: Ohne Code zeigt der Notfall-Knopf nur die Notrufnummern.")
                                    .font(.system(size: 11))
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .tint(.red)
                        .padding(14)
                        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 14))
                    }

                    // ── Karten sperren ──
                    VStack(alignment: .leading, spacing: 10) {
                        ArcaSectionTitle(title: "Karten sperren", icon: "creditcard.fill")
                        if nurOeffentlich {
                            Text("Deine hinterlegten Sperr-Hotlines erscheinen hier nach dem Entsperren der App.")
                                .font(.system(size: 13))
                                .foregroundStyle(.secondary)
                                .padding(14)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 14))
                        } else if karten.isEmpty {
                            Text("Noch keine Sperr-Hotline hinterlegt. Öffne im Tresor den Eintrag deiner Karte und trage unter „Sperr-Hotline“ die Notfallnummer deiner Bank ein — sie erscheint dann hier.")
                                .font(.system(size: 13))
                                .foregroundStyle(.secondary)
                                .padding(14)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 14))
                        } else {
                            ForEach(karten) { karte in
                                Button {
                                    anrufen(karte.sperrHotline)
                                } label: {
                                    HStack(spacing: 12) {
                                        Image(systemName: "creditcard.fill")
                                            .font(.system(size: 14, weight: .semibold))
                                            .foregroundStyle(.blue)
                                            .frame(width: 36, height: 36)
                                            .background(Color.blue.opacity(0.10), in: RoundedRectangle(cornerRadius: 10))
                                        VStack(alignment: .leading, spacing: 1) {
                                            Text(karte.title)
                                                .font(.system(size: 15, weight: .medium))
                                                .foregroundStyle(.primary)
                                            Text(karte.sperrHotline)
                                                .font(.system(size: 12, weight: .semibold, design: .rounded))
                                                .foregroundStyle(.secondary)
                                        }
                                        Spacer()
                                        Text("Sperren")
                                            .font(.system(size: 13, weight: .bold))
                                            .foregroundStyle(.white)
                                            .padding(.horizontal, 14)
                                            .padding(.vertical, 7)
                                            .background(Color.red, in: Capsule())
                                    }
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 10)
                                    .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 14))
                                }
                                .buttonStyle(.plain)
                            }
                            Text("Kartennummer zum Vorlesen: im Tresor-Eintrag der Karte.")
                                .font(.system(size: 12))
                                .foregroundStyle(.secondary)
                                .padding(.horizontal, 4)
                        }
                    }
                }
                .padding(20)
            }
            .background(ArcaWarm.hintergrund)
            .sheet(item: $bearbeite) { eintrag in
                NotfallEintragBlatt(eintrag: eintrag)
                    .environmentObject(store)
            }
            .arcaVorschau($fotoGross)
            .navigationTitle(nurOeffentlich ? "Notfall" : "Notfallkoffer")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Image(systemName: "cross.case.fill")
                        .foregroundStyle(.red)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Fertig") { dismiss() }
                }
            }
        }
    }

    // MARK: Bausteine

    private var notrufZeile: some View {
        NavigationLink {
            NotrufSeite(nummern: notrufnummern, anrufen: anrufen)
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "phone.fill")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.red)
                    .frame(width: 36, height: 36)
                    .background(Color.red.opacity(0.10), in: RoundedRectangle(cornerRadius: 10))
                VStack(alignment: .leading, spacing: 1) {
                    Text("Notruf Schweiz")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.primary)
                    Text("Polizei, Sanität, Feuerwehr, Rega · 112 in ganz Europa")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.85)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 14))
        }
        .buttonStyle(.plain)
    }

    private func sektionsKopf(_ titel: String, icon: String, art: NotfallEintrag.Art) -> some View {
        HStack {
            ArcaSectionTitle(title: titel, icon: icon)
            Spacer()
            if !nurOeffentlich {
                Button {
                    let naechste = (store.notfallEintraege.filter { $0.art == art }
                        .map(\.reihenfolge).max() ?? -1) + 1
                    bearbeite = NotfallEintrag(art: art, name: "", reihenfolge: naechste)
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 20))
                        .foregroundStyle(.red)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(art == .medikament ? "Medikament hinzufügen"
                                    : art == .kontakt ? "Kontakt hinzufügen" : "Wichtigen Hinweis hinzufügen")
            }
        }
    }

    private func leerHinweis(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 13))
            .foregroundStyle(.secondary)
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 14))
    }

    private func kontaktZeile(_ k: NotfallEintrag) -> some View {
        Button {
            anrufen(k.zusatz)
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "person.fill")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.red)
                    .frame(width: 36, height: 36)
                    .background(Color.red.opacity(0.10), in: RoundedRectangle(cornerRadius: 10))
                VStack(alignment: .leading, spacing: 1) {
                    Text(k.name.isEmpty ? "Ohne Namen" : k.name)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.primary)
                    Text([k.detail, k.zusatz].filter { !$0.isEmpty }.joined(separator: " · "))
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundStyle(.secondary)
                    if !k.hinweis.isEmpty {
                        Text(k.hinweis)
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer()
                Image(systemName: "phone.arrow.up.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(k.zusatz.isEmpty ? Color.secondary.opacity(0.4) : .red)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 14))
        }
        .buttonStyle(.plain)
        .disabled(k.zusatz.isEmpty)
        .contextMenu { if !nurOeffentlich { eintragMenue(k) } }
    }

    /// Eine Zeile „Wichtig": gross und rot genug, dass man sie nicht uebersieht.
    /// Antippen bearbeitet; das Kamera-Symbol zeigt den Ausweis.
    private func wichtigZeile(_ w: NotfallEintrag) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "heart.fill")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.red)
                .frame(width: 36, height: 36)
                .background(Color.red.opacity(0.10), in: RoundedRectangle(cornerRadius: 10))
            VStack(alignment: .leading, spacing: 1) {
                Text(w.name.isEmpty ? "Ohne Namen" : w.name)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.primary)
                if !w.detail.isEmpty {
                    Text(w.detail)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.secondary)
                }
                if !w.hinweis.isEmpty {
                    Text(w.hinweis)
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                        .italic()
                }
            }
            Spacer()
            if !w.fotoDatei.isEmpty {
                Button {
                    fotoGross = store.documentURL(for: w.fotoDatei)
                } label: {
                    Image(systemName: "camera.fill")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                        .frame(width: 28, height: 28)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Foto ansehen")
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 14))
        .contentShape(Rectangle())
        .onTapGesture { if !nurOeffentlich { bearbeite = w } }
        .contextMenu { if !nurOeffentlich { eintragMenue(w) } }
    }

    @ViewBuilder
    private func eintragMenue(_ e: NotfallEintrag) -> some View {
        Button { bearbeite = e } label: { Label("Bearbeiten", systemImage: "pencil") }
        Button(role: .destructive) {
            store.notfallEintraege.removeAll { $0.id == e.id }
        } label: { Label("Löschen", systemImage: "trash") }
    }
}

// MARK: - Medikamenten-Seite

/// Der Medikamentenplan: ein Blatt, eine Zeile pro Medikament.
///
/// Links der Name, rechts die Dosierung, darunter klein der Wirkstoff —
/// genau in der Reihenfolge, in der ein Arzt fragt. Keine Kacheln: bei
/// vier, fuenf, sechs Medikamenten soll alles auf einen Blick passen.
struct MedikamentenSeite: View {
    @EnvironmentObject var store: AppStore
    /// Vom Sperrbildschirm: nur lesen, nicht bearbeiten.
    let nurLesen: Bool

    @State private var bearbeite: NotfallEintrag? = nil
    @State private var fotoGross: URL? = nil

    private var medikamente: [NotfallEintrag] {
        store.notfallEintraege.filter { $0.art == .medikament }
            .sorted { ($0.reihenfolge, $0.name) < ($1.reihenfolge, $1.name) }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                if medikamente.isEmpty {
                    Text("Trag ein, was du regelmäßig nimmst — Name, Dosierung und am besten den Wirkstoff. Beim Arzt oder in einer Apotheke im Ausland hast du es dann sofort zur Hand.")
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                        .padding(14)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 14))
                } else {
                    // Das Blatt: eine Flaeche, duenne Linien dazwischen
                    VStack(spacing: 0) {
                        ForEach(Array(medikamente.enumerated()), id: \.element.id) { i, m in
                            if i > 0 {
                                Divider().overlay(Color.primary.opacity(0.06))
                                    .padding(.leading, 14)
                            }
                            zeile(m)
                        }
                    }
                    .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 16))

                    Text(nurLesen ? "Stand: \(stand)" : "Antippen zum Bearbeiten · Stand: \(stand)")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 6)
                }
            }
            .padding(20)
        }
        .background(ArcaWarm.hintergrund)
        .navigationTitle("Meine Medikamente")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if !nurLesen {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        let naechste = (medikamente.map(\.reihenfolge).max() ?? -1) + 1
                        bearbeite = NotfallEintrag(art: .medikament, name: "", reihenfolge: naechste)
                    } label: {
                        Image(systemName: "plus")
                    }
                    .accessibilityLabel("Medikament hinzufügen")
                }
            }
        }
        .sheet(item: $bearbeite) { eintrag in
            NotfallEintragBlatt(eintrag: eintrag)
                .environmentObject(store)
        }
        .arcaVorschau($fotoGross)
    }

    /// Wann zuletzt etwas geaendert wurde — ein Arzt will wissen, wie aktuell
    /// ein Medikamentenplan ist.
    private var stand: String {
        (medikamente.map(\.geaendertAm).max() ?? Date())
            .formatted(date: .abbreviated, time: .omitted)
    }

    private func zeile(_ m: NotfallEintrag) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text(m.name.isEmpty ? "Ohne Namen" : m.name)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.primary)
                if !m.detail.isEmpty {
                    Text(m.detail)
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                }
                if !m.hinweis.isEmpty {
                    Text(m.hinweis)
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                        .italic()
                }
            }
            Spacer(minLength: 8)
            if !m.zusatz.isEmpty {
                Text(m.zusatz)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.trailing)
            }
            if !m.fotoDatei.isEmpty {
                // Die Packung gross — Wirkstoff und Staerke stehen lesbar drauf
                Button {
                    fotoGross = store.documentURL(for: m.fotoDatei)
                } label: {
                    Image(systemName: "camera.fill")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                        .frame(width: 28, height: 28)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Foto der Packung")
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 11)
        .contentShape(Rectangle())
        .onTapGesture { if !nurLesen { bearbeite = m } }
        .contextMenu {
            if !nurLesen {
                Button { bearbeite = m } label: { Label("Bearbeiten", systemImage: "pencil") }
                Button(role: .destructive) {
                    store.notfallEintraege.removeAll { $0.id == m.id }
                } label: { Label("Löschen", systemImage: "trash") }
            }
        }
    }
}

// MARK: - Notruf-Seite

/// Die einzelnen Notrufnummern auf eigener Seite — im Koffer steht dafuer
/// eine Zeile. Jede Nummer ein Anruf-Knopf.
struct NotrufSeite: View {
    let nummern: [NotfallView.Notrufnummer]
    let anrufen: (String) -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 10) {
                ForEach(nummern) { eintrag in
                    Button {
                        anrufen(eintrag.nummer)
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: eintrag.symbol)
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(.red)
                                .frame(width: 36, height: 36)
                                .background(Color.red.opacity(0.10), in: RoundedRectangle(cornerRadius: 10))
                            Text(eintrag.name)
                                .font(.system(size: 15, weight: .medium))
                                .foregroundStyle(.primary)
                            Spacer()
                            Text(eintrag.nummer)
                                .font(.system(size: 17, weight: .bold, design: .rounded))
                                .foregroundStyle(.red)
                            Image(systemName: "phone.arrow.up.right")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(.secondary)
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 14))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(20)
        }
        .background(ArcaWarm.hintergrund)
        .navigationTitle("Notruf Schweiz")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Eintrag bearbeiten

/// Anlegen und Aendern eines Medikaments oder Kontakts. Das Feld-Layout
/// folgt der Art — dieselben drei Felder heissen je nach Art anders.
struct NotfallEintragBlatt: View {
    @EnvironmentObject var store: AppStore
    @Environment(\.dismiss) private var dismiss

    @State private var e: NotfallEintrag
    @State private var zeigeBildQuelle = false
    @State private var zeigeKamera = false
    @State private var zeigeMediathek = false
    @State private var mediathekAuswahl: PhotosPickerItem? = nil
    @State private var fragLoeschen = false

    private let istNeu: Bool

    init(eintrag: NotfallEintrag) {
        _e = State(initialValue: eintrag)
        istNeu = eintrag.name.isEmpty
    }

    private var istMedikament: Bool { e.art == .medikament }
    private var istWichtig: Bool { e.art == .wichtig }

    var body: some View {
        NavigationStack {
            Form {
                if istMedikament || istWichtig {
                    Section {
                        fotoFeld
                    } footer: {
                        Text(istWichtig
                             ? "Zum Beispiel der Schrittmacher-Ausweis oder der Allergiepass."
                             : "Auf der Packung stehen Wirkstoff und Stärke — das Foto hilft, wenn der Markenname im Ausland anders heißt.")
                    }
                }
                Section {
                    if istWichtig {
                        TextField("Was? (z. B. Herzschrittmacher, Penicillin-Allergie)", text: $e.name)
                        TextField("Genauer (z. B. wegen Bradykardie, seit 2019)", text: $e.detail)
                    } else {
                        TextField(istMedikament ? "Name (z. B. Beloc Zok)" : "Name", text: $e.name)
                            .textInputAutocapitalization(.words)
                        TextField(istMedikament ? "Wirkstoff und Stärke (z. B. Metoprolol 50 mg)" : "Wer ist das? (z. B. Tochter, Hausarzt)",
                                  text: $e.detail)
                        TextField(istMedikament ? "Dosierung (z. B. 1 Tablette morgens)" : "Telefon",
                                  text: $e.zusatz)
                            .keyboardType(istMedikament ? .default : .phonePad)
                    }
                }
                Section {
                    TextField(istWichtig ? "Hinweis (z. B. kein MRT, Ausweis im Portemonnaie)"
                              : istMedikament ? "Hinweis (z. B. zum Essen, Allergie)" : "Hinweis (z. B. erreichbar ab 8 Uhr)",
                              text: $e.hinweis, axis: .vertical)
                        .lineLimit(1...4)
                }
                if !istNeu {
                    Section {
                        Button("Eintrag löschen", role: .destructive) { fragLoeschen = true }
                    }
                }
            }
            .navigationTitle(istWichtig ? (istNeu ? "Neuer Hinweis" : "Wichtig")
                             : istNeu ? (istMedikament ? "Neues Medikament" : "Neuer Kontakt")
                             : (istMedikament ? "Medikament" : "Kontakt"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Abbrechen") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Sichern") { sichern() }
                        .disabled(e.name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .confirmationDialog(istWichtig ? "Foto" : "Packungsfoto", isPresented: $zeigeBildQuelle, titleVisibility: .visible) {
                if KameraAufnahme.verfuegbar {
                    Button("Foto aufnehmen") { zeigeKamera = true }
                }
                Button("Aus der Mediathek") { zeigeMediathek = true }
                if !e.fotoDatei.isEmpty {
                    Button("Foto entfernen", role: .destructive) { e.fotoDatei = "" }
                }
                Button("Abbrechen", role: .cancel) { }
            }
            .photosPicker(isPresented: $zeigeMediathek, selection: $mediathekAuswahl, matching: .images)
            .onChange(of: mediathekAuswahl) { _, neu in
                guard let neu else { return }
                Task {
                    if let data = try? await neu.loadTransferable(type: Data.self),
                       let bild = UIImage(data: data),
                       let jpg = bild.jpegData(compressionQuality: 0.8) {
                        let name = store.speichereNotfallFoto(jpg)
                        if !name.isEmpty { e.fotoDatei = name }
                    }
                    mediathekAuswahl = nil
                }
            }
            .fullScreenCover(isPresented: $zeigeKamera) {
                // Rueckkamera — wir fotografieren eine Packung, kein Gesicht.
                PackungsKamera { bild in
                    if let jpg = bild.jpegData(compressionQuality: 0.8) {
                        let name = store.speichereNotfallFoto(jpg)
                        if !name.isEmpty { e.fotoDatei = name }
                    }
                    zeigeKamera = false
                } onAbbruch: { zeigeKamera = false }
                .ignoresSafeArea()
            }
            .alert("Eintrag löschen?", isPresented: $fragLoeschen) {
                Button("Löschen", role: .destructive) {
                    store.notfallEintraege.removeAll { $0.id == e.id }
                    dismiss()
                }
                Button("Abbrechen", role: .cancel) { }
            }
        }
    }

    private var fotoFeld: some View {
        Button {
            zeigeBildQuelle = true
        } label: {
            HStack(spacing: 14) {
                if !e.fotoDatei.isEmpty {
                    DocThumbnail(url: store.documentURL(for: e.fotoDatei), type: .image,
                                 groesse: CGSize(width: 64, height: 64))
                } else {
                    Image(systemName: "camera.fill")
                        .font(.system(size: 22))
                        .foregroundStyle(.red)
                        .frame(width: 64, height: 64)
                        .background(Color.red.opacity(0.10), in: RoundedRectangle(cornerRadius: 12))
                }
                Text(!e.fotoDatei.isEmpty ? "Foto ändern"
                     : istWichtig ? "Ausweis fotografieren" : "Packung fotografieren")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(.primary)
                Spacer()
            }
        }
        .buttonStyle(.plain)
    }

    private func sichern() {
        var fertig = e
        fertig.name    = fertig.name.trimmingCharacters(in: .whitespacesAndNewlines)
        fertig.detail  = fertig.detail.trimmingCharacters(in: .whitespacesAndNewlines)
        fertig.zusatz  = fertig.zusatz.trimmingCharacters(in: .whitespacesAndNewlines)
        fertig.hinweis = fertig.hinweis.trimmingCharacters(in: .whitespacesAndNewlines)
        if let i = store.notfallEintraege.firstIndex(where: { $0.id == fertig.id }) {
            store.notfallEintraege[i] = fertig
        } else {
            store.notfallEintraege.append(fertig)
        }
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        dismiss()
    }
}

/// Kamera fuer Packungen: Rueckkamera, ohne Zuschnitt.
/// KameraAufnahme ist aufs Profilbild eingestellt (Frontkamera, quadratisch).
struct PackungsKamera: UIViewControllerRepresentable {
    let onFoto: (UIImage) -> Void
    let onAbbruch: () -> Void

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.cameraDevice = .rear
        picker.allowsEditing = false
        picker.delegate = context.coordinator
        return picker
    }
    func updateUIViewController(_ vc: UIImagePickerController, context: Context) {}
    func makeCoordinator() -> Coordinator { Coordinator(self) }

    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let eltern: PackungsKamera
        init(_ eltern: PackungsKamera) { self.eltern = eltern }
        func imagePickerController(_ picker: UIImagePickerController,
                                   didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            if let bild = info[.originalImage] as? UIImage { eltern.onFoto(bild) } else { eltern.onAbbruch() }
        }
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) { eltern.onAbbruch() }
    }
}
