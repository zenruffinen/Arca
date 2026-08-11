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

    private let kennungen = ["trinkgeld.espresso", "trinkgeld.gipfeli", "trinkgeld.gross"]

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
    }

    func kaufe(_ produkt: Product) async {
        guard let ergebnis = try? await produkt.purchase() else { return }
        if case .success(let pruefung) = ergebnis,
           case .verified(let transaktion) = pruefung {
            await transaktion.finish()
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            dankeSichtbar = true
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

            if glas.produkte.isEmpty {
                // Ohne App-Store-Produkte (oder vor der 3.0): leiser Hinweis
                Label("Das Trinkgeld-Glas öffnet mit Version 3.0 im App Store.",
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
        .alert("Merci vielmal! ❤️", isPresented: $glas.dankeSichtbar) {
            Button("Gern geschehen") {}
        } message: {
            Text("Dein Trinkgeld ist angekommen — es fliesst direkt in die Weiterentwicklung von Arca. Danke!")
        }
    }
}
