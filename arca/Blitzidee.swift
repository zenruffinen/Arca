//
//  Blitzidee.swift
//  Arca
//
//  Die Idee-Karte: Diktat, Ziel-Erkennung (Notiz/Aufgabe/Passwort).
//  (Aus ContentView.swift herausgelöst — Code unverändert.)
//
//  Entwickler: Hans zen Ruffinen
//

import SwiftUI

// MARK: - QuickCaptureSheet

struct QuickCaptureSheet: View {
    var autoRecord: Bool = false
    let onSave: (String, String) -> Void
    @EnvironmentObject var store: AppStore

    /// Wohin mit dem Gesprochenen? Schlüsselwörter schlagen vor,
    /// die drei Knöpfe entscheiden — Stufe 1 der schlauen Spracheingabe.
    enum ErfassungsZiel { case notiz, aufgabe, passwort }

    private let blitzOrange = Color(red: 1.00, green: 0.45, blue: 0.10)

    @Environment(\.dismiss) private var dismiss
    @StateObject private var speech = SpeechManager()
    @State private var transcribedText = ""
    @State private var savedIdeas: [String] = []
    @State private var hasStarted = false
    @State private var justSaved = false
    @State private var closeTimer: Timer? = nil
    @State private var erkanntesZiel: ErfassungsZiel = .notiz
    @State private var wartetAufZiel = false
    @State private var zielTimer: Timer? = nil

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {

                // Gespeicherte Ideen
                if !savedIdeas.isEmpty {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 8) {
                            ForEach(Array(savedIdeas.enumerated()), id: \.offset) { idx, idea in
                                HStack(alignment: .top, spacing: 10) {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundStyle(.green)
                                        .font(.callout)
                                    Text(idea)
                                        .font(.callout)
                                        .foregroundStyle(.primary)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                }
                                .padding(.horizontal)
                                .padding(.vertical, 4)
                            }
                        }
                        .padding(.vertical, 12)
                    }
                    .frame(maxHeight: 180)
                    .background(Color(.secondarySystemBackground))
                    Divider()
                }

                Spacer()

                // Mic-Button
                ZStack {
                    Circle()
                        .fill(speech.isRecording ? blitzOrange.opacity(0.12) : Color.secondary.opacity(0.07))
                        .frame(width: 130, height: 130)
                        .scaleEffect(speech.isRecording ? 1.08 : 1.0)
                        .animation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true), value: speech.isRecording)

                    Image(systemName: speech.isRecording ? "waveform" : "mic.fill")
                        .font(.system(size: 54, weight: .medium))
                        .foregroundStyle(speech.isRecording ? blitzOrange : .secondary)
                        .contentTransition(.symbolEffect(.replace))
                }
                .onTapGesture {
                    zielTimer?.invalidate()
                    zielTimer = nil
                    wartetAufZiel = false
                    if speech.isRecording {
                        speech.stopRecording()
                    } else {
                        beginRecording()
                    }
                    closeTimer?.invalidate()
                    closeTimer = nil
                }
                .padding(.bottom, 16)

                // Status
                Group {
                    if justSaved {
                        Label("Gespeichert", systemImage: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                    } else if speech.isRecording {
                        Text("Sprich deine Idee…")
                            .foregroundStyle(blitzOrange)
                    } else if transcribedText.isEmpty {
                        Text(savedIdeas.isEmpty ? "Tippen zum Starten" : "Tippen für eine weitere Idee")
                            .foregroundStyle(.secondary)
                    } else if wartetAufZiel {
                        Text(zielHinweis)
                            .foregroundStyle(blitzOrange)
                    } else {
                        Text("Tippen zum erneuten Aufnehmen")
                            .foregroundStyle(.secondary)
                    }
                }
                .font(.subheadline)
                .multilineTextAlignment(.center)
                .padding(.bottom, 12)

                // Aktueller Text
                if !transcribedText.isEmpty {
                    Text(transcribedText)
                        .font(.body)
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(blitzOrange.opacity(0.07))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .padding(.horizontal)
                        .padding(.bottom, 8)
                }

                // Wohin damit? Drei Ziele, das erkannte ist vorgewählt
                if wartetAufZiel && !transcribedText.isEmpty {
                    HStack(spacing: 8) {
                        zielKnopf(.notiz,    titel: "Idee",     symbol: "lightbulb.fill")
                        zielKnopf(.aufgabe,  titel: "Aufgabe",  symbol: "checkmark.square")
                        zielKnopf(.passwort, titel: "Passwort", symbol: "key.fill")
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 8)
                }

                Spacer()

                // Was mit dem Gesprochenen passiert — gut sichtbar erklärt
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: "bolt.fill")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(ArcaWarm.terrakotta)
                        .padding(.top, 1)
                    Text("Deine Blitzidee wird **unverändert bei deinen Ideen gespeichert**. Beginnst du mit „Aufgabe“ oder „Passwort“, landet sie gleich am richtigen Ort.")
                        .font(.system(size: 13))
                        .foregroundStyle(.primary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(ArcaWarm.terrakotta.opacity(0.09),
                            in: RoundedRectangle(cornerRadius: 12))
                .overlay(RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(ArcaWarm.terrakotta.opacity(0.25), lineWidth: 1))
                .padding(.horizontal, 16)
                .padding(.bottom, 14)
            }
            .onAppear {
                // „Halten = Diktat": Aufnahme startet sofort
                if autoRecord && !speech.isRecording { beginRecording() }
            }
            .navigationTitle("Idee?")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button {
                        // Abbrechen heißt verwerfen: Timer töten und Text
                        // leeren, BEVOR der Aufnahme-Stopp den Ziel-
                        // Automaten weckt — sonst speichert er posthum.
                        zielTimer?.invalidate()
                        zielTimer = nil
                        wartetAufZiel = false
                        transcribedText = ""
                        speech.stopRecording()
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                            .font(.title3)
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        zielTimer?.invalidate()
                        zielTimer = nil
                        if wartetAufZiel {
                            fuehreAus(erkanntesZiel)
                        } else {
                            saveCurrentIfNeeded()
                            transcribedText = ""
                            wartetAufZiel = false
                            speech.stopRecording()
                            dismiss()
                        }
                    } label: {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(canFinish ? blitzOrange : .secondary)
                            .font(.title3)
                    }
                    .disabled(!canFinish)
                }
            }
            // Aufnahme stoppt → Ziel erkennen; Notiz/Aufgabe speichern
            // nach kurzer Einspruchsfrist von selbst, Passwort nur per Tipp
            .onChange(of: speech.isRecording) { _, recording in
                guard !recording else { return }
                let text = transcribedText.trimmingCharacters(in: .whitespacesAndNewlines)
                if !text.isEmpty {
                    erkanntesZiel = analysiereZiel(text)
                    wartetAufZiel = true
                    if erkanntesZiel != .passwort {
                        zielTimer?.invalidate()
                        zielTimer = Timer.scheduledTimer(withTimeInterval: 2.5, repeats: false) { _ in
                            fuehreAus(erkanntesZiel)
                        }
                    }
                } else {
                    startCloseTimer()
                }
            }
            .onAppear { startIfReady() }
            .onChange(of: speech.permissionGranted) { _, granted in
                guard granted else { return }
                startIfReady()
            }
        }
    }

    private var canFinish: Bool {
        !savedIdeas.isEmpty || !transcribedText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private func startIfReady() {
        guard speech.permissionGranted, !hasStarted else { return }
        hasStarted = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { beginRecording() }
    }

    private func beginRecording() {
        closeTimer?.invalidate()
        closeTimer = nil
        transcribedText = ""
        justSaved = false
        speech.toggle(appendingTo: "") { updated in transcribedText = updated }
    }

    private func startCloseTimer() {
        closeTimer?.invalidate()
        closeTimer = Timer.scheduledTimer(withTimeInterval: 5, repeats: false) { _ in
            DispatchQueue.main.async { dismiss() }
        }
    }

    private var zielHinweis: String {
        switch erkanntesZiel {
        case .notiz:    return "Wird gleich als Idee gespeichert — oder wähle ein Ziel"
        case .aufgabe:  return "Klingt nach Aufgaben — wird gleich zur Liste"
        case .passwort: return "Klingt nach einem Passwort — Tipp öffnet den Tresor"
        }
    }

    /// Schlüsselwort-Erkennung (Stufe 1, ohne KI, offline):
    /// „Aufgabe/Liste/Einkauf …" → Aufgabenliste, „Passwort …" → Tresor.
    private func analysiereZiel(_ text: String) -> ErfassungsZiel {
        let anfang = text.lowercased().prefix(30)
        if anfang.hasPrefix("passwort") || anfang.hasPrefix("zugang") { return .passwort }
        for wort in ["aufgabe", "aufgaben", "liste", "einkauf", "todo", "to do", "besorgen"] {
            if anfang.hasPrefix(wort) { return .aufgabe }
        }
        return .notiz
    }

    /// Führendes Schlüsselwort samt Trennzeichen entfernen.
    private func ohneSchluesselwort(_ text: String) -> String {
        var rest = text
        let woerter = ["aufgabenliste", "aufgaben", "aufgabe", "liste", "einkaufsliste",
                       "passwort", "zugang", "todo", "to do"]
        let klein = rest.lowercased()
        for wort in woerter where klein.hasPrefix(wort) {
            rest = String(rest.dropFirst(wort.count))
            break
        }
        return rest.trimmingCharacters(in: CharacterSet(charactersIn: " :,.–-"))
    }

    @ViewBuilder
    private func zielKnopf(_ ziel: ErfassungsZiel, titel: String, symbol: String) -> some View {
        let gewaehlt = erkanntesZiel == ziel
        Button {
            zielTimer?.invalidate()
            fuehreAus(ziel)
        } label: {
            HStack(spacing: 6) {
                Image(systemName: symbol)
                    .font(.system(size: 12, weight: .semibold))
                Text(titel)
                    .font(.system(size: 13, weight: .semibold))
            }
            .foregroundStyle(gewaehlt ? .white : .primary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 9)
            .background(gewaehlt ? blitzOrange : Color.secondary.opacity(0.12), in: Capsule())
        }
        .buttonStyle(.plain)
    }

    private func fuehreAus(_ ziel: ErfassungsZiel) {
        zielTimer?.invalidate()
        zielTimer = nil
        let text = transcribedText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        wartetAufZiel = false
        switch ziel {
        case .notiz:
            saveCurrentIfNeeded()
            transcribedText = ""
            justSaved = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { dismiss() }
        case .aufgabe:
            let inhalt = ohneSchluesselwort(text)
            var zeilen = inhalt
                .components(separatedBy: .newlines)
                .map { $0.trimmingCharacters(in: .whitespaces) }
                .filter { !$0.isEmpty }
            if zeilen.count <= 1 {
                // Eine gesprochene Zeile: an Kommas und „und" auftrennen
                zeilen = inhalt
                    .replacingOccurrences(of: " und ", with: ",")
                    .components(separatedBy: ",")
                    .map { $0.trimmingCharacters(in: .whitespaces) }
                    .filter { !$0.isEmpty }
            }
            let titel = zeilen.count == 1 ? "Aufgaben" : "Aufgaben \(Date().formatted(date: .abbreviated, time: .omitted))"
            let punkte = zeilen.map { ChecklistItem(text: $0.prefix(1).uppercased() + $0.dropFirst()) }
            store.lists.insert(ListEntry(title: titel, items: punkte, colorTag: 3), at: 0)
            store.homeStreamFilter = .tasks
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            transcribedText = ""
            savedIdeas.append("☑︎ \(inhalt)")
            justSaved = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { dismiss() }
        case .passwort:
            let titel = ohneSchluesselwort(text)
            store.vaultVorbefuellung = titel.isEmpty ? nil : String(titel.prefix(40))
            store.pendingNewEntry = .vault
            store.pendingSection = .vault
            speech.stopRecording()
            dismiss()
        }
    }

    private func saveCurrentIfNeeded() {
        let text = transcribedText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, savedIdeas.last != text else { return }
        onSave(String(text.prefix(50)), text)
        savedIdeas.append(text)
        // Haptisches Feedback: kurze Erfolgs-Vibration
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }
}
