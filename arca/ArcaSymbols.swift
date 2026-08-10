//
//  ArcaSymbols.swift
//  Arca
//
//  Eigene, skalierbare Icon-Familie mit dem Arca-Bogen als Form-DNA.
//

import SwiftUI

enum ArcaSymbol: String, CaseIterable, Identifiable {
    case archive = "ArcaArchive"
    case key = "ArcaKey"
    case bolt = "ArcaBolt"
    case document = "ArcaDocument"
    case checklist = "ArcaChecklist"
    case note = "ArcaNote"
    case folder = "ArcaFolder"
    case lock = "ArcaLock"
    case done = "ArcaDone"
    case search = "ArcaSearch"
    case place = "ArcaPlace"
    case calendar = "ArcaCalendar"
    case star = "ArcaStar"
    case home = "ArcaHome"
    case card = "ArcaCard"
    case travel = "ArcaTravel"
    case health = "ArcaHealth"
    case invoice = "ArcaInvoice"
    case settings = "ArcaSettings"
    case scan = "ArcaScan"

    var id: String { rawValue }
}

struct ArcaSymbolImage: View {
    let symbol: ArcaSymbol
    var size: CGFloat = 24
    var color: Color = ArcaWarm.terrakotta

    var body: some View {
        Image(symbol.rawValue)
            .resizable()
            .renderingMode(.template)
            .scaledToFit()
            .foregroundStyle(color)
            .frame(width: size, height: size)
            .accessibilityHidden(true)
    }
}

#Preview("Arca Icon Family") {
    LazyVGrid(columns: [.init(.adaptive(minimum: 76))], spacing: 24) {
        ForEach(ArcaSymbol.allCases) { symbol in
            VStack(spacing: 8) {
                ArcaSymbolImage(symbol: symbol, size: 30)
                Text(symbol.rawValue.dropFirst(4))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
    }
    .padding(24)
    .background(ArcaWarm.hintergrund)
}
