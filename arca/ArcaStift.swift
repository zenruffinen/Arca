//
//  ArcaStift.swift
//  Arca
//
//  Arca Pad: der Stift zieht ein. Eine PencilKit-Seite für Hand-
//  notizen und Zeichnungen — gesichert als PDF in „Unsortiert"
//  (durchsuchbar über die Handschrift-Erkennung) oder auf Wunsch
//  umgewandelt in eine Text-Notiz.
//
//  24.11.: vom Pergament-Zettel zur Seite. Weisses Blatt, das beim
//  Schreiben nach unten waechst, mit A4-Seitengrenzen; Sichern legt
//  ein mehrseitiges PDF ab statt eines Bildes. Erreichbar über
//  „Neues Dokument" → „Stift" auf dem iPad.
//
//  Entwickler: Hans zen Ruffinen
//

import SwiftUI
import PencilKit
import ARCAKit

// MARK: - Die Seite (UIKit)

/// PencilKit-Leinwand, die wie ein Stapel A4-Blätter funktioniert:
/// so breit wie der Bildschirm, so hoch wie nötig. Nähert sich die
/// Schrift dem unteren Rand, kommt ein Blatt dazu.
final class ArcaSeitenLeinwand: PKCanvasView {

    /// Höhe einer Seite in Leinwand-Punkten — folgt dem A4-Verhältnis.
    var seitenHoehe: CGFloat {
        bounds.width * ARCASpacing.a4Seite.height / ARCASpacing.a4Seite.width
    }
    private(set) var seiten = 1
    private let grenzen = CAShapeLayer()

    override init(frame: CGRect) {
        super.init(frame: frame)
        grenzen.strokeColor = UIColor.black.withAlphaComponent(0.12).cgColor
        grenzen.lineDashPattern = [6, 6]
        grenzen.lineWidth = 1
        layer.insertSublayer(grenzen, at: 0)
    }
    required init?(coder: NSCoder) { fatalError() }

    /// Genug Blätter für die Schrift plus eines Luft.
    func passeSeitenAn() {
        guard seitenHoehe > 0 else { return }
        let unten = drawing.strokes.isEmpty ? 0 : drawing.bounds.maxY
        let noetig = max(1, Int(ceil((unten + seitenHoehe * 0.35) / seitenHoehe)))
        if noetig > seiten { seiten = noetig }
        setNeedsLayout()
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        let hoehe = max(bounds.height, seitenHoehe * CGFloat(seiten))
        if contentSize.width != bounds.width || contentSize.height != hoehe {
            contentSize = CGSize(width: bounds.width, height: hoehe)
        }
        // Gestrichelte Seitengrenzen — sie scrollen mit dem Inhalt.
        let pfad = UIBezierPath()
        for i in 1..<seiten {
            let y = seitenHoehe * CGFloat(i)
            pfad.move(to: CGPoint(x: 0, y: y))
            pfad.addLine(to: CGPoint(x: bounds.width, y: y))
        }
        grenzen.frame = CGRect(origin: .zero, size: contentSize)
        grenzen.path = pfad.cgPath
    }
}

struct StiftLeinwand: UIViewRepresentable {
    @Binding var zeichnung: PKDrawing
    /// Wird beim Erzeugen gesetzt, damit die Notiz die Seitenhöhe kennt.
    var leinwandGefunden: (ArcaSeitenLeinwand) -> Void = { _ in }

    func makeUIView(context: Context) -> ArcaSeitenLeinwand {
        let leinwand = ArcaSeitenLeinwand(frame: .zero)
        leinwand.drawing = zeichnung
        // .default folgt der Systemeinstellung „Nur mit Apple Pencil
        // zeichnen": mit Pencil scrollt der Finger, ohne Pencil zeichnet er.
        leinwand.drawingPolicy = .default
        leinwand.backgroundColor = .white
        leinwand.isOpaque = true
        leinwand.alwaysBounceVertical = true
        // Papier ist weiss — auch im Dunkelmodus. Sonst kehrt PencilKit
        // die Tinte um, und schwarze Schrift wird auf dem PDF unsichtbar.
        leinwand.overrideUserInterfaceStyle = .light
        leinwand.delegate = context.coordinator
        leinwand.tool = PKInkingTool(.pen, color: .black, width: 3)

        // Apples Werkzeugkasten: Stifte, Marker, Radierer, Lineal, Farben
        let kasten = PKToolPicker()
        kasten.colorUserInterfaceStyle = .light
        context.coordinator.kasten = kasten
        kasten.setVisible(true, forFirstResponder: leinwand)
        kasten.addObserver(leinwand)
        DispatchQueue.main.async {
            leinwand.becomeFirstResponder()
            leinwandGefunden(leinwand)
        }
        return leinwand
    }

    func updateUIView(_ leinwand: ArcaSeitenLeinwand, context: Context) {}

    func makeCoordinator() -> Koordinator { Koordinator(self) }

    class Koordinator: NSObject, PKCanvasViewDelegate {
        let elternteil: StiftLeinwand
        var kasten: PKToolPicker?   // festhalten, sonst verschwindet er

        init(_ elternteil: StiftLeinwand) { self.elternteil = elternteil }

        func canvasViewDrawingDidChange(_ leinwand: PKCanvasView) {
            elternteil.zeichnung = leinwand.drawing
            (leinwand as? ArcaSeitenLeinwand)?.passeSeitenAn()
        }
    }
}

// MARK: - Die Handnotiz

struct ArcaStiftNotiz: View {
    @EnvironmentObject var store: AppStore
    @Environment(\.dismiss) private var dismiss
    @State private var zeichnung = PKDrawing()
    @State private var leinwand: ArcaSeitenLeinwand? = nil
    @State private var arbeitet = false
    @State private var hinweis: String? = nil
    @State private var verwerfenFragen = false

    private var leer: Bool { zeichnung.strokes.isEmpty }

    var body: some View {
        NavigationStack {
            StiftLeinwand(zeichnung: $zeichnung) { leinwand = $0 }
                .ignoresSafeArea(edges: .bottom)
                .overlay {
                    if arbeitet {
                        ProgressView("Wird gesichert …")
                            .padding(18)
                            .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 14))
                    }
                }
                .navigationTitle("Handnotiz")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button {
                            if leer { dismiss() } else { verwerfenFragen = true }
                        } label: {
                            Image(systemName: "xmark")
                        }
                        .accessibilityLabel("Schliessen")
                    }
                    ToolbarItemGroup(placement: .confirmationAction) {
                        Button {
                            wandleInText()
                        } label: {
                            Label("In Text", systemImage: "text.viewfinder")
                        }
                        .disabled(leer || arbeitet)
                        Button {
                            sichereAlsPDF()
                        } label: {
                            Label("Als PDF sichern", systemImage: "checkmark")
                                .fontWeight(.semibold)
                        }
                        .disabled(leer || arbeitet)
                    }
                }
                .confirmationDialog("Handnotiz verwerfen?", isPresented: $verwerfenFragen,
                                    titleVisibility: .visible) {
                    Button("Als PDF sichern") { sichereAlsPDF() }
                    Button("Verwerfen", role: .destructive) { dismiss() }
                    Button("Weiterschreiben", role: .cancel) {}
                }
                .alert("Nichts erkannt", isPresented: Binding(
                    get: { hinweis != nil },
                    set: { if !$0 { hinweis = nil } }
                )) {
                    Button("OK") { hinweis = nil }
                } message: {
                    Text(hinweis ?? "")
                }
        }
    }

    // MARK: Seiten

    /// Breite der Leinwand beim Schreiben — Grundlage der Seitenteilung.
    private var leinwandBreite: CGFloat { max(leinwand?.bounds.width ?? 0, 1) }
    private var seitenHoehe: CGFloat {
        leinwandBreite * ARCASpacing.a4Seite.height / ARCASpacing.a4Seite.width
    }

    /// Die beschriebenen Seiten als Bilder, Tinte immer hell gerendert.
    private func seitenBilder() -> [UIImage] {
        guard !leer else { return [] }
        let anzahl = max(1, Int(ceil(zeichnung.bounds.maxY / seitenHoehe)))
        // Etwa 216 dpi auf A4 — scharf beim Drucken, klein genug als Datei.
        let skala = ARCASpacing.a4Seite.width * 3 / leinwandBreite
        var bilder: [UIImage] = []
        UITraitCollection(userInterfaceStyle: .light).performAsCurrent {
            for i in 0..<anzahl {
                let rahmen = CGRect(x: 0, y: CGFloat(i) * seitenHoehe,
                                    width: leinwandBreite, height: seitenHoehe)
                bilder.append(zeichnung.image(from: rahmen, scale: skala))
            }
        }
        return bilder
    }

    // MARK: Sichern

    /// Als PDF in „Unsortiert" — einsortiert wird später, wie bei jedem
    /// anderen Neuzugang. Die Handschrift wird gelesen: die erste Zeile
    /// wird der Titel, der ganze Text macht das PDF durchsuchbar.
    private func sichereAlsPDF() {
        let bilder = seitenBilder()
        guard !bilder.isEmpty else { return }
        arbeitet = true
        Task.detached(priority: .userInitiated) {
            let seite = CGRect(origin: .zero, size: ARCASpacing.a4Seite)
            let daten = UIGraphicsPDFRenderer(bounds: seite).pdfData { ctx in
                for bild in bilder {
                    ctx.beginPage()
                    UIColor.white.setFill()
                    ctx.fill(seite)
                    bild.draw(in: seite)
                }
            }
            let erkannt = bilder.map(ArcaTextLeser.erkenne).joined(separator: "\n")
            await MainActor.run {
                let name = UUID().uuidString + ".pdf"
                do {
                    try daten.write(to: store.documentURL(for: name), options: .atomic)
                } catch {
                    arbeitet = false
                    hinweis = "Die Handnotiz konnte nicht gesichert werden: \(error.localizedDescription)"
                    return
                }
                let ersteZeile = erkannt.components(separatedBy: .newlines)
                    .map { $0.trimmingCharacters(in: .whitespaces) }
                    .first { $0.count >= 3 }
                store.addDocument(
                    title: ersteZeile.map { String($0.prefix(50)) }
                        ?? "Handnotiz \(Date().formatted(date: .abbreviated, time: .shortened))",
                    type: .pdf, filename: name,
                    category: store.ensureImportCategoryExists(),
                    ocrText: String(erkannt.prefix(ArcaTextLeser.maxZeichen)))
                UINotificationFeedbackGenerator().notificationOccurred(.success)
                dismiss()
            }
        }
    }

    /// Auf Wunsch: Handschrift → Text, gespeichert als Arca-Notiz.
    private func wandleInText() {
        let bilder = seitenBilder()
        guard !bilder.isEmpty else { return }
        arbeitet = true
        Task.detached(priority: .userInitiated) {
            let text = bilder.map(ArcaTextLeser.erkenne).joined(separator: "\n")
            await MainActor.run {
                arbeitet = false
                let sauber = text.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !sauber.isEmpty else {
                    hinweis = "Die Handschrift konnte nicht gelesen werden — probier es etwas größer und in Druckschrift."
                    return
                }
                let ersteZeile = sauber.components(separatedBy: .newlines)
                    .map { $0.trimmingCharacters(in: .whitespaces) }
                    .first { !$0.isEmpty } ?? "Stift-Notiz"
                store.notes.insert(
                    NoteEntry(title: String(ersteZeile.prefix(50)), text: sauber),
                    at: 0)
                UINotificationFeedbackGenerator().notificationOccurred(.success)
                dismiss()
            }
        }
    }
}
