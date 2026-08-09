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
                    Label {
                        Text(NoteColor.palette[idx].name + (aktuell == idx ? "  ✓" : ""))
                    } icon: {
                        // Echte Farbvorschau: Menüs färben Symbole sonst grau ein
                        Image(uiImage: kreisBild(UIColor(NoteColor.palette[idx].accent)))
                            .renderingMode(.original)
                    }
                }
            }
        } label: {
            Label("Farbe", systemImage: "paintpalette")
        }
    }

    /// Gefüllter Farbkreis als Bild — behält seine Farbe auch im Menü.
    static func kreisBild(_ farbe: UIColor) -> UIImage {
        let groesse = CGSize(width: 22, height: 22)
        return UIGraphicsImageRenderer(size: groesse).image { ctx in
            farbe.setFill()
            ctx.cgContext.fillEllipse(in: CGRect(origin: .zero, size: groesse).insetBy(dx: 1, dy: 1))
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
