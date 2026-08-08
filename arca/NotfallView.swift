//
//  NotfallView.swift
//  Arca
//
//  Der Notfall-Bereich: offizielle Schweizer Notrufnummern und die
//  Sperr-Hotlines der eigenen Karten — jede Nummer ein Anruf-Knopf.
//  Erreichbar aus dem Mehr-Menü und (nur öffentliche Nummern) vom
//  Sperrbildschirm, denn im Notfall zählt jede Sekunde.
//
//  Entwickler: Hans zen Ruffinen
//

import SwiftUI

struct NotfallView: View {
    /// Karten mit hinterlegter Sperr-Hotline (leer im gesperrten Zustand)
    var karten: [VaultEntry] = []
    /// Vom Sperrbildschirm: nur öffentliche Nummern, Hinweis auf Entsperren
    var nurOeffentlich: Bool = false

    @Environment(\.dismiss) private var dismiss

    private struct Notrufnummer: Identifiable {
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

                    // ── Offizielle Notrufnummern (Schweiz) ──
                    VStack(alignment: .leading, spacing: 10) {
                        ArcaSectionTitle(title: "Notruf Schweiz", icon: "phone.fill")
                        ForEach(notrufnummern) { eintrag in
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
            .navigationTitle("Notfall")
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
}
