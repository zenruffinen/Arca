//
//  TicketsHaptics.swift
//  ArcaTickets
//
//  Entwickler: Hans zen Ruffinen
//

import UIKit

enum TicketsHaptics {
    static func success() {
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }

    static func mediumImpact() {
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
    }
}
