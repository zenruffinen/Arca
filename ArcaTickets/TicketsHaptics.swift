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

    static func lightImpact() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }

    static func pin() {
        UIImpactFeedbackGenerator(style: .rigid).impactOccurred()
    }

    static func delete() {
        UINotificationFeedbackGenerator().notificationOccurred(.warning)
    }
}
