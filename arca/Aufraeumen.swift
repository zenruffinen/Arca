//
//  Aufraeumen.swift
//  Arca
//
//  Der Aufräum-Modus: Unsortiert wird zum Stapel auf dem Pult.
//  Karte für Karte entscheiden — Gruppe, Pinnwand, erledigt oder später.
//  Bei null gibt es den Jubel. Ordnung machen soll Spaß machen.
//
//  Entwickler: Hans zen Ruffinen
//

import SwiftUI
import QuickLook

struct AufraeumModus: View {
    @EnvironmentObject var store: AppStore
    @Environment(\.dismiss) private var dismiss
    @Environment(\.horizontalSizeClass) private var groessenKlasse

    /// Die Warteschlange: alles, was beim Start in „Unsortiert" lag.
    @State private var schlange: [UUID] = []
    @State private var gesamt = 0
    @State private var previewURL: URL? = nil
    @State private var geladen = false

    private var aktuellesDok: DocumentEntry? {
        guard let id = schlange.first else { return nil }
        return store.documents.first { $0.id == id }
    }

    private var zielGruppen: [String] {
        store.documentCategories.filter { $0 != "Unsortiert" && $0 != "Erledigt" }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                ArcaWarm.hintergrund.ignoresSafeArea()

                if let doc = aktuellesDok {
                    arbeitsAnsicht(doc)
                } else if geladen {
                    jubel
                }
            }
            .navigationTitle("Aufräumen")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                            .font(.title3)
                    }
                }
            }
            .onAppear {
                if !geladen {
                    schlange = store.documents
                        .filter { $0.category == "Unsortiert" }
                        .sorted { $0.dateAdded > $1.dateAdded }
                        .map(\.id)
                    gesamt = schlange.count
                    geladen = true
                }
            }
            .quickLookPreview($previewURL)
        }
    }

    // MARK: Die Arbeits-Ansicht: eine Karte, alle Entscheidungen

    @ViewBuilder
    private func arbeitsAnsicht(_ doc: DocumentEntry) -> some View {
        VStack(spacing: 14) {
            // Zähler + Fortschritt
            VStack(spacing: 6) {
                Text(schlange.count == 1 ? "Noch 1 Dokument" : "Noch \(schlange.count) Dokumente")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.secondary)
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule().fill(ArcaWarm.terrakotta.opacity(0.15))
                        Capsule().fill(ArcaWarm.terrakotta)
                            .frame(width: geo.size.width *
                                   CGFloat(gesamt - schlange.count) / CGFloat(max(gesamt, 1)))
                    }
                }
                .frame(width: 180, height: 5)
                .animation(.spring(response: 0.4, dampingFraction: 0.8), value: schlange.count)
            }
            .padding(.top, 6)

            Spacer(minLength: 0)

            // Die Karte vom Stapel — Post-it-Stil, Tipp öffnet die Vollansicht
            VStack(spacing: 0) {
                DocThumbnail(url: store.documentURL(for: doc.filename), type: doc.type,
                             passendEinpassen: true, gross: true)
                    .frame(maxHeight: 380)
                    .frame(maxWidth: .infinity)
                Text(doc.title)
                    .font(.system(size: 14, weight: .semibold))
                    .lineLimit(1)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .padding(.horizontal, 10)
                    .background(Color.white.opacity(0.93))
            }
            .frame(maxWidth: 430)
            .background(ArcaWarm.karte)
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(ArcaWarm.haarlinie, lineWidth: 1))
            .shadow(color: .black.opacity(0.15), radius: 9, x: 0, y: 5)
            .rotationEffect(.degrees(-1.2))
            .padding(.horizontal, 24)
            .contentShape(Rectangle())
            .onTapGesture {
                previewURL = store.documentURL(for: doc.filename)
            }
            .id(doc.id)
            .transition(.asymmetric(
                insertion: .scale(scale: 0.92).combined(with: .opacity),
                removal: .move(edge: .trailing).combined(with: .opacity)))

            Spacer(minLength: 0)

            // Wohin damit? Die Gruppen als Sortier-Chips
            VStack(alignment: .leading, spacing: 8) {
                Text("IN GRUPPE EINSORTIEREN")
                    .font(.system(size: 11, weight: .bold))
                    .tracking(0.7)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 24)
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(zielGruppen, id: \.self) { gruppe in
                            let farben = categoryColor(gruppe, overrides: store.categoryColors)
                            Button {
                                sortiere(doc, nach: gruppe)
                            } label: {
                                HStack(spacing: 6) {
                                    Image(systemName: categoryIcon(gruppe))
                                        .font(.system(size: 12, weight: .semibold))
                                    Text(gruppe)
                                        .font(.system(size: 13, weight: .semibold))
                                }
                                .foregroundStyle(farben.accent)
                                .padding(.horizontal, 13)
                                .padding(.vertical, 9)
                                .background(farben.bg.opacity(0.8), in: Capsule())
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 24)
                }
            }

            // Die vier großen Entscheidungen
            HStack(spacing: 10) {
                entscheidung("Zu erledigen", symbol: "pin.fill", farbe: ArcaWarm.terrakotta) {
                    pinne(doc, seite: "links")
                }
                entscheidung("Schnellzugriff", symbol: "bolt.fill", farbe: .orange) {
                    pinne(doc, seite: "rechts")
                }
                entscheidung("Erledigt", symbol: "checkmark.circle.fill", farbe: .green) {
                    erledige(doc)
                }
                entscheidung("Später", symbol: "arrow.uturn.right", farbe: .secondary) {
                    weiter()
                }
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 18)
        }
    }

    private func entscheidung(_ titel: String, symbol: String, farbe: Color,
                              aktion: @escaping () -> Void) -> some View {
        Button(action: aktion) {
            VStack(spacing: 5) {
                Image(systemName: symbol)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(farbe)
                Text(titel)
                    .font(.system(size: 10.5, weight: .semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 11)
            .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 13))
        }
        .buttonStyle(.plain)
    }

    // MARK: Der Jubel

    private var jubel: some View {
        VStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(Color.green.opacity(0.12))
                    .frame(width: 120, height: 120)
                Image(systemName: "checkmark.seal.fill")
                    .font(.system(size: 62))
                    .foregroundStyle(.green)
                    .symbolEffect(.bounce, value: geladen)
            }
            Text("Alles aufgeräumt!")
                .font(.system(size: 26, weight: .bold, design: .rounded))
            Text(gesamt == 0
                 ? "Unsortiert war schon leer — vorbildlich."
                 : "\(gesamt) Dokumente behandelt. Dein Space dankt.")
                .font(.system(size: 14))
                .foregroundStyle(.secondary)
            Button {
                dismiss()
            } label: {
                Text("Fertig")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 34)
                    .padding(.vertical, 12)
                    .background(ArcaWarm.terrakotta, in: Capsule())
            }
            .buttonStyle(.plain)
            .padding(.top, 8)
        }
    }

    // MARK: Entscheidungen

    private func sortiere(_ doc: DocumentEntry, nach gruppe: String) {
        if let idx = store.documents.firstIndex(where: { $0.id == doc.id }) {
            store.documents[idx].category = gruppe
            store.documents[idx].subcategory = ""
        }
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        weiter()
    }

    private func pinne(_ doc: DocumentEntry, seite: String) {
        if let idx = store.deskItems.firstIndex(where: { $0.refID == doc.id }) {
            store.deskItems[idx].seite = seite
        } else {
            store.deskItems.append(DeskItem(kind: .document, refID: doc.id, seite: seite))
        }
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        weiter()
    }

    private func erledige(_ doc: DocumentEntry) {
        if !store.documentCategories.contains("Erledigt") {
            store.documentCategories.append("Erledigt")
        }
        if let idx = store.documents.firstIndex(where: { $0.id == doc.id }) {
            store.documents[idx].category = "Erledigt"
            store.documents[idx].subcategory = ""
        }
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        weiter()
    }

    private func weiter() {
        withAnimation(.spring(response: 0.38, dampingFraction: 0.8)) {
            if !schlange.isEmpty { schlange.removeFirst() }
        }
    }
}
