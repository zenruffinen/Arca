//
//  ArcaTrinkgeld.swift
//  Arca
//
//  Das Trinkgeld-Glas: Arca ist kostenlos und werbefrei — wer mag,
//  gibt dem Entwickler einen Kafi aus. StoreKit 2, drei Stufen.
//
//  Entwickler: Hans zen Ruffinen
//

import SwiftUI
import Combine
import StoreKit

@MainActor
final class TrinkgeldGlas: ObservableObject {
    static let shared = TrinkgeldGlas()

    @Published var produkte: [Product] = []
    @Published var dankeSichtbar = false
    @Published var laedt = false
    /// Einmal geladen — danach heisst „leer" wirklich „nicht erreichbar",
    /// nicht „noch nicht geschaut".
    @Published var geladen = false
    /// Etwas ging schief oder wartet (Ask to Buy) — eine Zeile fuer den
    /// Nutzer statt Schweigen.
    @Published var hinweis: String? = nil

    private let kennungen = ["trinkgeld.espresso", "trinkgeld.gipfeli", "trinkgeld.gross"]
    private var lauscher: Task<Void, Never>? = nil

    private init() {
        // Ein Kauf, den die App nicht mehr abschliessen konnte (Absturz,
        // Anruf, Ask-to-Buy spaeter genehmigt), kommt hier an. Ohne diesen
        // Lauscher bliebe er offen — bezahlt, aber nie bedankt.
        lauscher = Task { [weak self] in
            for await pruefung in Transaction.updates {
                guard let self, case .verified(let t) = pruefung else { continue }
                await t.finish()
                self.dankeSichtbar = true
            }
        }
    }

    /// Symbol je Stufe — der Kafi-Dreiklang.
    func symbol(fuer produkt: Product) -> String {
        switch produkt.id {
        case "trinkgeld.espresso": return "☕️"
        case "trinkgeld.gipfeli":  return "🥐"
        default:                   return "🎉"
        }
    }

    func lade() async {
        guard produkte.isEmpty, !laedt else { return }
        laedt = true
        produkte = ((try? await Product.products(for: kennungen)) ?? [])
            .sorted { $0.price < $1.price }
        laedt = false
        geladen = true
        // Beim Start noch offene Kaeufe abschliessen
        for await pruefung in Transaction.unfinished {
            if case .verified(let t) = pruefung { await t.finish() }
        }
    }

    func kaufe(_ produkt: Product) async {
        let ergebnis: Product.PurchaseResult
        do {
            ergebnis = try await produkt.purchase()
        } catch {
            hinweis = "Das hat gerade nicht geklappt. Versuch es später nochmal."
            return
        }
        switch ergebnis {
        case .success(let pruefung):
            guard case .verified(let transaktion) = pruefung else {
                hinweis = "Der Kauf liess sich nicht bestätigen."
                return
            }
            await transaktion.finish()
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            dankeSichtbar = true
        case .pending:
            // Ask to Buy: die Freigabe kommt spaeter — dann meldet sich
            // der Lauscher oben.
            hinweis = "Der Kauf wartet auf Freigabe. Sobald sie da ist, bedankt sich Arca."
        case .userCancelled:
            break
        @unknown default:
            break
        }
    }
}

/// Die Trinkgeld-Zeile für die Einstellungen: drei warme Knöpfe.
struct TrinkgeldKarte: View {
    @ObservedObject private var glas = TrinkgeldGlas.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Arca ist kostenlos, werbefrei und sammelt nichts über dich. Wenn dir die App Freude macht, freut sich der Entwickler über einen Kafi. ❤️")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)

            if glas.laedt || !glas.geladen {
                HStack(spacing: 8) {
                    ProgressView().controlSize(.small)
                    Text("Trinkgeld-Glas wird geholt …")
                        .font(.system(size: 12))
                        .foregroundStyle(.tertiary)
                }
            } else if glas.produkte.isEmpty {
                // Erst nach dem Laden: dann heisst leer „nicht erreichbar" —
                // kein Netz, oder die Produkte fehlen noch in App Store
                // Connect. „Oeffnet mit 3.0" stand hier vorher; DAS ist 3.0.
                Label("Das Trinkgeld-Glas ist gerade nicht erreichbar.",
                      systemImage: "cup.and.saucer")
                    .font(.system(size: 12))
                    .foregroundStyle(.tertiary)
            } else {
                HStack(spacing: 8) {
                    ForEach(glas.produkte) { produkt in
                        Button {
                            Task { await glas.kaufe(produkt) }
                        } label: {
                            VStack(spacing: 4) {
                                Text(glas.symbol(fuer: produkt))
                                    .font(.system(size: 22))
                                Text(produkt.displayName)
                                    .font(.system(size: 11, weight: .semibold))
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.7)
                                Text(produkt.displayPrice)
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundStyle(ArcaWarm.terrakotta)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(ArcaWarm.terrakotta.opacity(0.08),
                                        in: RoundedRectangle(cornerRadius: 12))
                            .overlay(RoundedRectangle(cornerRadius: 12)
                                .strokeBorder(ArcaWarm.terrakotta.opacity(0.3), lineWidth: 1))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .padding(.vertical, 4)
        .task { await glas.lade() }
        .alert("Trinkgeld", isPresented: Binding(
            get: { glas.hinweis != nil },
            set: { if !$0 { glas.hinweis = nil } }
        )) {
            Button("OK") { glas.hinweis = nil }
        } message: {
            Text(glas.hinweis ?? "")
        }
        .alert("Merci vielmal! ❤️", isPresented: $glas.dankeSichtbar) {
            Button("Gern geschehen") {}
        } message: {
            Text("Dein Trinkgeld ist angekommen — es fliesst direkt in die Weiterentwicklung von Arca. Danke!")
        }
    }
}
