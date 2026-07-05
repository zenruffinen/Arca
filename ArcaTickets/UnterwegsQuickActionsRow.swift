//
//  UnterwegsQuickActionsRow.swift
//  ArcaTickets
//
//  Entwickler: Hans zen Ruffinen
//

import SwiftUI

enum TravelQuickActionStyle {
    case card
    case chip
}

enum TravelQuickActionIconSize {
    case card
    case chip
}

struct UnterwegsQuickActionsRow: View {
    var body: some View {
        HStack(spacing: 12) {
            TaxiButtonView(style: .chip)
                .frame(maxWidth: .infinity)
            GolfButtonView(style: .chip)
                .frame(maxWidth: .infinity)
        }
    }
}
