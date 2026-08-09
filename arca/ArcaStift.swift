//
//  ArcaStift.swift
//  Arca
//
//  Arca Pad: der Stift zieht ein. Eine PencilKit-Leinwand für
//  Stift-Notizen — speichern als Skizze (durchsuchbar) oder auf
//  Wunsch per Handschrift-Erkennung umgewandelt in eine Text-Notiz.
//
//  Entwickler: Hans zen Ruffinen
//

import SwiftUI
import PencilKit
import Vision

// MARK: - Die Leinwand

struct StiftLeinwand: UIViewRepresentable {
    @Binding var zeichnung: PKDrawing

    func makeUIView(context: Context) -> PKCanvasView {
        let leinwand = PKCanvasView()
        leinwand.drawing = zeichnung
        leinwand.drawingPolicy = .anyInput   // Pencil, Finger und Maus (Mac)
        leinwand.backgroundColor = .clear    // das Pergament liegt darunter
        leinwand.isOpaque = false
        leinwand.delegate = context.coordinator
        leinwand.tool = PKInkingTool(.pen, color: .black, width: 3)

        // Apples Werkzeugkasten: Stifte, Marker, Radierer, Lineal
        let kasten = PKToolPicker()
        context.coordinator.kasten = kasten
        kasten.setVisible(true, forFirstResponder: leinwand)
        kasten.addObserver(leinwand)
        DispatchQueue.main.async { leinwand.becomeFirstResponder() }
        return leinwand
    }

    func updateUIView(_ leinwand: PKCanvasView, context: Context) {}

    func makeCoordinator() -> Koordinator { Koordinator(self) }

    class Koordinator: NSObject, PKCanvasViewDelegate {
        let elternteil: StiftLeinwand
        var kasten: PKToolPicker?   // festhalten, sonst verschwindet er

        init(_ elternteil: StiftLeinwand) { self.elternteil = elternteil }

        func canvasViewDrawingDidChange(_ leinwand: PKCanvasView) {
            elternteil.zeichnung = leinwand.drawing
        }
    }
}

// MARK: - Das Pergament

/// Ein altes Pergament als Schreibgrund: warmer Grundton, dunkle,
/// unregelmäßige Ränder und ein paar Altersflecken — deterministisch
/// gezeichnet, damit es auf jedem Gerät gleich aussieht.
struct PergamentHintergrund: View {
    var body: some View {
        ZStack {
            // Grundton
            Color(red: 0.93, green: 0.87, blue: 0.74)

            // Leichtes Farbspiel in der Fläche
            LinearGradient(
                colors: [Color(red: 0.96, green: 0.91, blue: 0.79).opacity(0.9),
                         Color(red: 0.90, green: 0.82, blue: 0.66).opacity(0.9)],
                startPoint: .topLeading, endPoint: .bottomTrailing)

            // Altersflecken
            GeometryReader { geo in
                let flecken: [(x: CGFloat, y: CGFloat, r: CGFloat, a: Double)] = [
                    (0.18, 0.22, 130, 0.10), (0.78, 0.15, 90, 0.08),
                    (0.65, 0.62, 160, 0.09), (0.25, 0.78, 110, 0.10),
                    (0.88, 0.85, 80, 0.08), (0.45, 0.40, 200, 0.05)
                ]
                ForEach(0..<flecken.count, id: \.self) { i in
                    let f = flecken[i]
                    Circle()
                        .fill(Color(red: 0.62, green: 0.50, blue: 0.32).opacity(f.a))
                        .frame(width: f.r, height: f.r)
                        .blur(radius: f.r * 0.35)
                        .position(x: geo.size.width * f.x, y: geo.size.height * f.y)
                }
            }

            // Dunkle, gealterte Ränder (Vignette)
            RadialGradient(
                colors: [.clear, .clear, Color(red: 0.48, green: 0.36, blue: 0.20).opacity(0.28)],
                center: .center, startRadius: 100, endRadius: 700)
        }
        .ignoresSafeArea()
    }
}

// MARK: - Die Stift-Notiz

struct ArcaStiftNotiz: View {
    @EnvironmentObject var store: AppStore
    @Environment(\.dismiss) private var dismiss
    @State private var zeichnung = PKDrawing()
    @State private var arbeitet = false
    @State private var hinweis: String? = nil

    private var leer: Bool { zeichnung.strokes.isEmpty }

    var body: some View {
        NavigationStack {
            ZStack {
                PergamentHintergrund()
                StiftLeinwand(zeichnung: $zeichnung)
            }
                .ignoresSafeArea(edges: .bottom)
                .overlay {
                    if arbeitet {
                        ProgressView("Handschrift wird gelesen …")
                            .padding(18)
                            .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 14))
                    }
                }
                .navigationTitle("Stift-Notiz")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button {
                            dismiss()
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(.secondary)
                        }
                    }
                    ToolbarItemGroup(placement: .confirmationAction) {
                        Button {
                            wandleInText()
                        } label: {
                            Label("In Text", systemImage: "text.viewfinder")
                        }
                        .disabled(leer || arbeitet)
                        Button {
                            sichereSkizze()
                        } label: {
                            Label("Sichern", systemImage: "checkmark")
                                .fontWeight(.semibold)
                        }
                        .disabled(leer || arbeitet)
                    }
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

    /// Die Zeichnung als Bild (weißer Grund, großzügiger Rand).
    private func bild() -> UIImage? {
        guard !leer else { return nil }
        let rahmen = zeichnung.bounds.insetBy(dx: -24, dy: -24)
        let strich = zeichnung.image(from: rahmen, scale: 2)
        return UIGraphicsImageRenderer(size: strich.size).image { _ in
            UIColor(red: 0.93, green: 0.87, blue: 0.74, alpha: 1).setFill()
            UIBezierPath(rect: CGRect(origin: .zero, size: strich.size)).fill()
            strich.draw(at: .zero)
        }
    }

    /// Handschrift lesen (on-device, offline).
    private func erkenneHandschrift(_ bild: UIImage) -> String {
        guard let cg = bild.cgImage else { return "" }
        let anfrage = VNRecognizeTextRequest()
        anfrage.recognitionLevel = .accurate
        anfrage.recognitionLanguages = ["de-DE", "fr-FR", "en-US"]
        anfrage.usesLanguageCorrection = true
        try? VNImageRequestHandler(cgImage: cg, orientation: .up).perform([anfrage])
        return (anfrage.results ?? [])
            .compactMap { $0.topCandidates(1).first?.string }
            .joined(separator: "\n")
    }

    /// Als Skizze sichern: Bild-Dokument in „Unsortiert" —
    /// die stille Handschrift-Erkennung macht es durchsuchbar.
    private func sichereSkizze() {
        guard let skizze = bild(), let daten = skizze.pngData() else { return }
        arbeitet = true
        DispatchQueue.global(qos: .userInitiated).async {
            let erkannt = erkenneHandschrift(skizze)
            DispatchQueue.main.async {
                let name = UUID().uuidString + ".png"
                try? daten.write(to: store.documentURL(for: name), options: .atomic)
                let ersteZeile = erkannt.components(separatedBy: .newlines)
                    .map { $0.trimmingCharacters(in: .whitespaces) }
                    .first { $0.count >= 3 }
                store.addDocument(
                    title: ersteZeile.map { String($0.prefix(50)) }
                        ?? "Skizze \(Date().formatted(date: .abbreviated, time: .shortened))",
                    type: .image, filename: name,
                    category: store.ensureImportCategoryExists(),
                    ocrText: erkannt)
                UINotificationFeedbackGenerator().notificationOccurred(.success)
                dismiss()
            }
        }
    }

    /// Auf Wunsch: Handschrift → Text, gespeichert als Arca-Notiz.
    private func wandleInText() {
        guard let skizze = bild() else { return }
        arbeitet = true
        DispatchQueue.global(qos: .userInitiated).async {
            let text = erkenneHandschrift(skizze)
            DispatchQueue.main.async {
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
