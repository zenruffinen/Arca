//
//  SettingsRoute.swift
//  ArcaTickets
//
//  Entwickler: Hans zen Ruffinen
//

import Foundation

/// Ziel innerhalb der Einstellungen (für Deep-Link aus Klecks-Sheets).
enum SettingsRoute: String, Hashable, Identifiable {
    case reiseSetup
    case taxi
    case boarding
    case tickets
    case wichtigeNummern
    case notizen
    case pass
    case kofferPIN
    case golf

    var id: String { rawValue }
}

