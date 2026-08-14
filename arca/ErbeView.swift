//
//  ErbeView.swift
//  Arca
//
//  Digitales Erbe — die Nachlass-Mappe mit Totmannschalter.
//  Besitzer verwaltet Inhalte + Freigabe; Angehörige öffnen im Ernstfall
//  per Freigabe-Frage (Standard: Geburtsort).
//
//  Entwickler: Hans zen Ruffinen
//

import SwiftUI

// MARK: - Verwaltung (Besitzer)

struct ErbeView: View {
    @EnvironmentObject var store: AppStore
    @Environment(\.dismiss) private var dismiss

    @State private var entwurf: ErbeEintrag? = nil
    @State private var zeigeVorschau = false
    @State private var antwortEingabe = ""

    private let fristOptionen = [30, 60, 90, 180, 365]

    var body: some View {
        NavigationStack {
            List {
                statusSection
                inhaltSection
                schalterSection
                erklaerung
            }
            .navigationTitle("Digitales Erbe")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button { entwurf = ErbeEintrag() } label: {
                        Image(systemName: "plus")
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Fertig") { dismiss() }
                }
            }
            .sheet(item: $entwurf) { e in
                ErbeEntrySheet(entwurf: e).environmentObject(store)
            }
            .sheet(isPresented: $zeigeVorschau) {
                NavigationStack {
                    ErbeAngehoerigeView(vorschau: true).environmentObject(store)
                }
            }
        }
    }

    // ── Status des Totmannschalters ──
    private var statusSection: some View {
        Section {
            if store.erbeAktiv && store.erbeHatAntwort {
                HStack(spacing: 12) {
                    Image(systemName: "checkmark.shield.fill")
                        .font(.system(size: 22))
                        .foregroundStyle(.green)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Totmannschalter ist scharf")
                            .font(.system(size: 15, weight: .semibold))
                        Text("Freigabe für \(store.erbeVertrauensperson.isEmpty ? "die Vertrauensperson" : store.erbeVertrauensperson) in \(store.erbeTageBisFreigabe) Tagen ohne Nutzung")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }
                Button {
                    store.erbeAktivitaetBestaetigen()
                    UINotificationFeedbackGenerator().notificationOccurred(.success)
                } label: {
                    Label("Ich lebe – jetzt bestätigen", systemImage: "hand.wave.fill")
                }
            } else {
                HStack(spacing: 12) {
                    Image(systemName: "shield.slash.fill")
                        .font(.system(size: 22))
                        .foregroundStyle(.secondary)
                    Text("Noch nicht scharf. Lege unten eine Vertrauensperson und eine Freigabe-Antwort fest, dann aktiviere den Schalter.")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
        } header: {
            Text("Status")
        }
    }

    // ── Inhalte der Mappe ──
    private var inhaltSection: some View {
        Section {
            if store.erbeEintraege.isEmpty {
                Text("Noch nichts abgelegt. Mit ＋ oben Abos, Konten, Dokument-Hinweise oder eine persönliche Nachricht hinzufügen.")
                    .font(.system(size: 14))
                    .foregroundStyle(.secondary)
            } else {
                ForEach(store.erbeEintraege) { e in
                    Button { entwurf = e } label: {
                        HStack(spacing: 12) {
                            Image(systemName: e.kategorie.symbol)
                                .font(.system(size: 15))
                                .foregroundStyle(ArcaWarm.terrakotta)
                                .frame(width: 26)
                            VStack(alignment: .leading, spacing: 1) {
                                Text(e.titel.isEmpty ? "Ohne Titel" : e.titel)
                                    .font(.system(size: 15, weight: .medium))
                                    .foregroundStyle(.primary)
                                Text(e.kategorie.label)
                                    .font(.caption).foregroundStyle(.secondary)
                            }
                            Spacer()
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
                .onDelete { idx in
                    idx.map { store.erbeEintraege[$0].id }.forEach { store.loescheErbeEintrag($0) }
                }
            }
        } header: {
            Text("Inhalt der Mappe")
        }
    }

    // ── Konfiguration des Schalters ──
    private var schalterSection: some View {
        Section {
            TextField("Name der Vertrauensperson", text: $store.erbeVertrauensperson)
                .textInputAutocapitalization(.words)

            TextField("Freigabe-Frage", text: $store.erbeFrage)
                .textInputAutocapitalization(.sentences)

            // Antwort setzen / geändert
            HStack {
                SecureField(store.erbeHatAntwort ? "Antwort ändern" : "Antwort festlegen", text: $antwortEingabe)
                if store.erbeHatAntwort && antwortEingabe.isEmpty {
                    Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
                }
                if !antwortEingabe.isEmpty {
                    Button("Speichern") {
                        store.erbeAntwortSetzen(antwortEingabe)
                        antwortEingabe = ""
                        UINotificationFeedbackGenerator().notificationOccurred(.success)
                    }
                    .buttonStyle(.borderless)
                }
            }

            Picker("Frist ohne Nutzung", selection: $store.erbeFristTage) {
                ForEach(fristOptionen, id: \.self) { t in
                    Text("\(t) Tage").tag(t)
                }
            }

            Toggle(isOn: $store.erbeAktiv) {
                Label("Totmannschalter aktiv", systemImage: "shield.lefthalf.filled")
            }
            .disabled(store.erbeVertrauensperson.isEmpty || !store.erbeHatAntwort)

            Button {
                zeigeVorschau = true
            } label: {
                Label("Vorschau für Angehörige", systemImage: "eye")
            }
        } header: {
            Text("Freigabe / Totmannschalter")
        } footer: {
            Text("Die Antwort wird nur verschlüsselt (als Prüfsumme) gespeichert — nie im Klartext.")
        }
    }

    private var erklaerung: some View {
        Section {
            VStack(alignment: .leading, spacing: 8) {
                erklaerZeile("1", "Du legst hier alles ab, was deinen Angehörigen hilft: Abos zum Kündigen, Konten, wo wichtige Dokumente liegen, eine persönliche Nachricht.")
                erklaerZeile("2", "Solange du Arca benutzt, bleibt das Fach verschlossen. Jedes Entsperren ist ein Lebenszeichen.")
                erklaerZeile("3", "Wird Arca \(store.erbeFristTage) Tage nicht geöffnet, gibt der Schalter das Fach frei — deine Vertrauensperson öffnet es dann über den Sperrbildschirm mit der Freigabe-Antwort.")
            }
            .padding(.vertical, 4)
        } header: {
            Text("So funktioniert es")
        }
    }

    private func erklaerZeile(_ n: String, _ text: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Text(n)
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 20, height: 20)
                .background(ArcaWarm.terrakotta, in: Circle())
            Text(text).font(.system(size: 13)).foregroundStyle(.secondary)
        }
    }
}

// MARK: - Eintrag anlegen / bearbeiten

struct ErbeEntrySheet: View {
    @EnvironmentObject var store: AppStore
    @Environment(\.dismiss) private var dismiss

    @State var entwurf: ErbeEintrag

    var body: some View {
        NavigationStack {
            Form {
                Picker("Art", selection: $entwurf.kategorie) {
                    ForEach(ErbeKategorie.allCases) { k in
                        Label(k.label, systemImage: k.symbol).tag(k)
                    }
                }
                Section("Titel") {
                    TextField("z. B. Netflix, Sparkonto, Testament", text: $entwurf.titel)
                }
                Section("Details") {
                    TextField("Wo, wie, was zu tun ist …", text: $entwurf.inhalt, axis: .vertical)
                        .lineLimit(4...12)
                }
            }
            .navigationTitle("Eintrag")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Abbrechen") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Sichern") {
                        if let i = store.erbeEintraege.firstIndex(where: { $0.id == entwurf.id }) {
                            store.erbeEintraege[i] = entwurf
                        } else {
                            store.addErbeEintrag(entwurf)
                        }
                        dismiss()
                    }
                    .disabled(entwurf.titel.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }
}

// MARK: - Freigabe für Angehörige (vom Sperrbildschirm)

struct ErbeUnlockView: View {
    @EnvironmentObject var store: AppStore
    @Environment(\.dismiss) private var dismiss

    @State private var antwort = ""
    @State private var freigegeben = false
    @State private var fehler = false

    var body: some View {
        NavigationStack {
            Group {
                if freigegeben {
                    ErbeAngehoerigeView(vorschau: false).environmentObject(store)
                } else if store.erbeAusgeloest {
                    freigabeFrage
                } else {
                    nochVerschlossen
                }
            }
            .navigationTitle("Digitales Erbe")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Schließen") { dismiss() }
                }
            }
        }
    }

    private var freigabeFrage: some View {
        VStack(spacing: 24) {
            Spacer()
            Image(systemName: "heart.text.square.fill")
                .font(.system(size: 48))
                .foregroundStyle(ArcaWarm.terrakotta)
            VStack(spacing: 8) {
                Text("Zugang für Angehörige")
                    .font(.title3.bold())
                Text(store.erbeVertrauensperson.isEmpty
                     ? "Bitte die hinterlegte Freigabe-Antwort eingeben."
                     : "Für \(store.erbeVertrauensperson) freigegeben. Bitte die Freigabe-Antwort eingeben.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            VStack(alignment: .leading, spacing: 8) {
                Text(store.erbeFrage)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.secondary)
                SecureField("Antwort", text: $antwort)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit(pruefen)
                if fehler {
                    Text("Antwort stimmt nicht. Bitte erneut versuchen.")
                        .font(.caption).foregroundStyle(.red)
                }
            }
            .padding(.horizontal, 8)
            Button(action: pruefen) {
                Text("Öffnen")
                    .font(.system(size: 16, weight: .semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(ArcaWarm.terrakotta, in: RoundedRectangle(cornerRadius: 12))
                    .foregroundStyle(.white)
            }
            .disabled(antwort.isEmpty)
            Spacer()
        }
        .padding(24)
    }

    private var nochVerschlossen: some View {
        VStack(spacing: 20) {
            Spacer()
            Image(systemName: "lock.shield.fill")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
            Text("Dieses Fach ist verschlossen")
                .font(.title3.bold())
            Text("Das Digitale Erbe öffnet sich erst, wenn Arca über einen längeren Zeitraum nicht benutzt wurde. Bis dahin bleibt es privat.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Spacer()
        }
        .padding(24)
    }

    private func pruefen() {
        if store.erbePruefeAntwort(antwort) {
            withAnimation { freigegeben = true }
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        } else {
            fehler = true
            antwort = ""
            UINotificationFeedbackGenerator().notificationOccurred(.error)
        }
    }
}

// MARK: - Read-only Ansicht der Mappe (Angehörige & Vorschau)

struct ErbeAngehoerigeView: View {
    @EnvironmentObject var store: AppStore
    var vorschau: Bool

    private var gruppen: [(ErbeKategorie, [ErbeEintrag])] {
        ErbeKategorie.allCases.compactMap { k in
            let items = store.erbeEintraege.filter { $0.kategorie == k }
            return items.isEmpty ? nil : (k, items)
        }
    }

    var body: some View {
        List {
            if vorschau {
                Section {
                    Label("Vorschau — so sehen es deine Angehörigen.", systemImage: "eye")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
            if store.erbeEintraege.isEmpty {
                Text("Die Mappe ist noch leer.")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(gruppen, id: \.0) { kategorie, items in
                    Section {
                        ForEach(items) { e in
                            VStack(alignment: .leading, spacing: 4) {
                                Text(e.titel.isEmpty ? "Ohne Titel" : e.titel)
                                    .font(.system(size: 15, weight: .semibold))
                                if !e.inhalt.isEmpty {
                                    Text(e.inhalt)
                                        .font(.system(size: 14))
                                        .foregroundStyle(.secondary)
                                        .textSelection(.enabled)
                                }
                            }
                            .padding(.vertical, 2)
                        }
                    } header: {
                        Label(kategorie.label, systemImage: kategorie.symbol)
                    }
                }
            }
        }
        .navigationTitle(vorschau ? "Vorschau" : "Digitales Erbe")
        .navigationBarTitleDisplayMode(.inline)
    }
}
