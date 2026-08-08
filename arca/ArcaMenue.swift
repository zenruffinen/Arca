//
//  ArcaMenue.swift
//  Arca
//
//  Der eine Menü-Bausatz für alle Kontextmenüs (ARCAKit-Geist):
//  gleiche Reihenfolge, gleiche Worte, gleiche Symbole — überall.
//
//  Die Arca-Ordnung:
//    1. Favorit  (+ Fest anpinnen, wenn Favorit)
//    2. ────────
//    3. Umbenennen
//    4. Farbe
//    5. Typ-Extras (Verschieben, Umwandeln, Punkt, Senden, Drucken …)
//    6. ────────
//    7. Löschen (rot)
//
//  Entwickler: Hans zen Ruffinen
//

import SwiftUI

enum ArcaMenue {

    @ViewBuilder
    static func favorit(ist: Bool, aktion: @escaping () -> Void) -> some View {
        Button(action: aktion) {
            Label(ist ? "Aus Favoriten entfernen" : "Zu Favoriten",
                  systemImage: ist ? "star.slash" : "star.fill")
        }
    }

    @ViewBuilder
    static func fest(aktion: @escaping () -> Void) -> some View {
        Button(action: aktion) {
            Label("Fest anpinnen / lösen", systemImage: "pin.fill")
        }
    }

    @ViewBuilder
    static func umbenennen(aktion: @escaping () -> Void) -> some View {
        Button(action: aktion) {
            Label("Umbenennen", systemImage: "pencil")
        }
    }

    @ViewBuilder
    static func farbe(aktuell: Int?, aktion: @escaping (Int) -> Void) -> some View {
        Menu {
            ForEach(0..<NoteColor.palette.count, id: \.self) { idx in
                Button { aktion(idx) } label: {
                    Label(NoteColor.palette[idx].name,
                          systemImage: aktuell == idx ? "checkmark.circle.fill" : "circle.fill")
                }
            }
        } label: {
            Label("Farbe", systemImage: "paintpalette")
        }
    }

    @ViewBuilder
    static func loeschen(_ titel: String = "Löschen", aktion: @escaping () -> Void) -> some View {
        Divider()
        Button(role: .destructive, action: aktion) {
            Label(titel, systemImage: "trash")
        }
    }
}
