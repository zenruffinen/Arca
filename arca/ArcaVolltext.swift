//
//  ArcaVolltext.swift
//  Arca
//
//  Volltext für die Suche (seit 24.11.).
//
//  Bis dahin wurde nur beim Kamera-Scan und beim Stift Text erkannt —
//  PDFs aus „Dateien", Fotos aus der Mediathek und alles, was über
//  „Teilen" hereinkam, fand die Suche nur über den Titel. Jetzt liest
//  Arca jedes Dokument einmal: den eingebetteten Text eines PDFs, sonst
//  per Texterkennung (Vision). Alles auf dem Gerät, ohne Netz.
//
//  Der Leser läuft als Warteschlange im Hintergrund: nach jedem neuen
//  Dokument und einmal beim Start für den Bestand. Was gelesen wurde
//  (auch ohne Ergebnis), wird gemerkt und nicht erneut versucht.
//

import Foundation
import PDFKit
import Vision
import UIKit

// MARK: - Der Leser

nonisolated enum ArcaTextLeser {

    /// Höchstens so viele Zeichen werden gespeichert — reicht für die
    /// Suche und hält die Dokumentliste klein.
    static let maxZeichen = 20_000
    /// So viele PDF-Seiten werden höchstens per Texterkennung gelesen,
    /// wenn das PDF keinen eingebetteten Text hat (Scan als PDF).
    static let maxOCRSeiten = 8

    /// Liest den Text eines Dokuments. Läuft synchron — nur im Hintergrund aufrufen.
    static func lies(_ url: URL, typ: DocumentType) -> String {
        let text: String
        switch typ {
        case .pdf:   text = liesPDF(url)
        case .image: text = UIImage(contentsOfFile: url.path).map(erkenne) ?? ""
        case .text, .mail:
            text = (try? String(contentsOf: url, encoding: .utf8))
                ?? (try? String(contentsOf: url, encoding: .isoLatin1)) ?? ""
        case .video: text = ""
        }
        let sauber = text.trimmingCharacters(in: .whitespacesAndNewlines)
        return String(sauber.prefix(maxZeichen))
    }

    private static func liesPDF(_ url: URL) -> String {
        guard let pdf = PDFDocument(url: url) else { return "" }
        let eingebettet = (pdf.string ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        // Ein paar Zeichen sind oft nur Kopfzeile oder Seitenzahl eines
        // gescannten PDFs — dann lieber die Seiten selbst lesen.
        if eingebettet.count >= 40 { return eingebettet }
        var zeilen: [String] = []
        for i in 0..<min(pdf.pageCount, maxOCRSeiten) {
            guard let seite = pdf.page(at: i) else { continue }
            autoreleasepool {
                let bild = seite.thumbnail(of: CGSize(width: 1700, height: 1700), for: .mediaBox)
                zeilen.append(erkenne(bild))
            }
        }
        let erkannt = zeilen.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
        return erkannt.count > eingebettet.count ? erkannt : eingebettet
    }

    /// Texterkennung auf einem Bild (Deutsch, Französisch, Englisch).
    static func erkenne(_ bild: UIImage) -> String {
        guard let cg = aufPapier(bild).cgImage else { return "" }
        let anfrage = VNRecognizeTextRequest()
        anfrage.recognitionLevel = .accurate
        anfrage.recognitionLanguages = ["de-DE", "fr-FR", "en-US"]
        anfrage.usesLanguageCorrection = true
        let handler = VNImageRequestHandler(cgImage: cg, orientation: .up)
        try? handler.perform([anfrage])
        return (anfrage.results ?? [])
            .compactMap { $0.topCandidates(1).first?.string }
            .joined(separator: "\n")
    }

    /// Legt das Bild auf weisses Papier, richtet es auf und bringt es auf
    /// eine lesbare Groesse.
    ///
    /// Am 24.11. im Test gefunden: ein PNG mit durchsichtigem Grund ergab
    /// gar keinen Text — Vision sah schwarze Schrift auf „schwarzem" Nichts.
    /// Bildschirmfotos und exportierte PNGs haben das oft. Auf Weiss
    /// gelegt, las Vision jede Zeile. Kleine Bilder werden dabei
    /// vergroessert (kleine Schrift), riesige Fotos verkleinert (Speicher).
    private static func aufPapier(_ bild: UIImage) -> UIImage {
        let laengste = max(bild.size.width, bild.size.height)
        guard laengste > 0 else { return bild }
        let faktor: CGFloat = laengste < 1200 ? 2 : (laengste > 3000 ? 3000 / laengste : 1)
        let groesse = CGSize(width: bild.size.width * faktor, height: bild.size.height * faktor)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true
        return UIGraphicsImageRenderer(size: groesse, format: format).image { ctx in
            UIColor.white.setFill()
            ctx.fill(CGRect(origin: .zero, size: groesse))
            bild.draw(in: CGRect(origin: .zero, size: groesse))   // richtet zugleich auf
        }
    }
}

// MARK: - Die Warteschlange

/// Zustand der Warteschlange — nur auf dem Main-Thread angefasst.
private enum VolltextZustand {
    static var laeuft = false
    static var nochmal = false
    static let versuchtSchluessel = "volltextVersucht"
}

extension AppStore {

    /// Liest alle Dokumente ohne Text, die noch nicht versucht wurden.
    ///
    /// Aufruf ist billig und darf oft kommen: läuft schon ein Durchgang,
    /// wird nur ein weiterer vorgemerkt. Top Secret bleibt aussen vor —
    /// dessen Inhalt soll nicht als Klartext in der Dokumentliste landen.
    /// Dateien, die iCloud noch nicht heruntergeladen hat, werden
    /// übersprungen und beim nächsten Durchgang erneut versucht.
    func volltextNachholen() {
        guard !VolltextZustand.laeuft else { VolltextZustand.nochmal = true; return }
        let versucht = Set(UserDefaults.standard.stringArray(forKey: VolltextZustand.versuchtSchluessel) ?? [])
        let offen: [(id: UUID, url: URL, typ: DocumentType)] = documents
            .filter { $0.ocrText.isEmpty && $0.type != .video && $0.category != "Top Secret"
                      && !versucht.contains($0.id.uuidString) }
            .map { ($0.id, documentURL(for: $0.filename), $0.type) }
        guard !offen.isEmpty else { return }

        VolltextZustand.laeuft = true
        // Die Schleife lebt auf dem Main-Actor (dort wohnt der Store);
        // nur das Lesen selbst geht pro Dokument in den Hintergrund.
        Task { @MainActor [weak self] in
            for eintrag in offen {
                let url = eintrag.url, typ = eintrag.typ
                // Noch nicht aus iCloud geladen: später nochmal.
                let text: String? = await Task.detached(priority: .background) {
                    guard FileManager.default.fileExists(atPath: url.path) else { return nil }
                    return ArcaTextLeser.lies(url, typ: typ)
                }.value
                guard let self else { break }
                guard let text else { continue }
                if !text.isEmpty,
                   let i = self.documents.firstIndex(where: { $0.id == eintrag.id }),
                   self.documents[i].ocrText.isEmpty {
                    self.documents[i].ocrText = text
                }
                var liste = UserDefaults.standard.stringArray(forKey: VolltextZustand.versuchtSchluessel) ?? []
                liste.append(eintrag.id.uuidString)
                UserDefaults.standard.set(liste, forKey: VolltextZustand.versuchtSchluessel)
            }
            VolltextZustand.laeuft = false
            if VolltextZustand.nochmal {
                VolltextZustand.nochmal = false
                self?.volltextNachholen()
            }
        }
    }
}
