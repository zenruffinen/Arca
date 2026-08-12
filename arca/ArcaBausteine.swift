//
//  ArcaBausteine.swift
//  Arca
//
//  Geteilte Bausteine: Dokumenten-Scanner, Farb-Picker, Gruppen-Manager.
//  (Aus ContentView.swift herausgelöst — Code unverändert.)
//
//  Entwickler: Hans zen Ruffinen
//

import SwiftUI
import VisionKit
import Vision

// MARK: - Scanner

struct DocumentScannerView: UIViewControllerRepresentable {
    /// Liefert das fertige PDF und den erkannten Text (OCR, on-device)
    let onScan: (URL, String) -> Void

    func makeUIViewController(context: Context) -> VNDocumentCameraViewController {
        let scanner = VNDocumentCameraViewController()
        scanner.delegate = context.coordinator
        return scanner
    }

    func updateUIViewController(_ uiViewController: VNDocumentCameraViewController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(onScan: onScan)
    }

    class Coordinator: NSObject, VNDocumentCameraViewControllerDelegate {
        let onScan: (URL, String) -> Void

        init(onScan: @escaping (URL, String) -> Void) {
            self.onScan = onScan
        }

        /// OCR über eine Seite: liefert die erkannten Textzeilen samt Lage.
        private static func erkenneText(auf image: UIImage) -> [VNRecognizedTextObservation] {
            guard let cg = image.cgImage else { return [] }
            let request = VNRecognizeTextRequest()
            request.recognitionLevel = .accurate
            request.recognitionLanguages = ["de-DE", "fr-FR", "en-US"]
            request.usesLanguageCorrection = true
            let handler = VNImageRequestHandler(cgImage: cg, orientation: .up)
            try? handler.perform([request])
            return request.results ?? []
        }

        func documentCameraViewController(_ controller: VNDocumentCameraViewController, didFinishWith scan: VNDocumentCameraScan) {
            guard scan.pageCount > 0 else {
                controller.dismiss(animated: true)
                return
            }

            let bilder = (0..<scan.pageCount).map { scan.imageOfPage(at: $0) }
            let fertig = onScan

            // OCR ist Rechenarbeit — weg vom Haupt-Thread, Ergebnis kommt zurück
            DispatchQueue.global(qos: .userInitiated).async {
                let seitenTexte = bilder.map { Self.erkenneText(auf: $0) }

                // A4-Seiten, Bild proportional eingepasst (UIGraphicsPDFRenderer
                // berücksichtigt die Bildausrichtung korrekt)
                let pageRect = CGRect(x: 0, y: 0, width: 595, height: 842)
                let renderer = UIGraphicsPDFRenderer(bounds: pageRect)
                let pdfData = renderer.pdfData { ctx in
                    for (i, image) in bilder.enumerated() {
                        guard image.size.width > 0, image.size.height > 0 else { continue }
                        ctx.beginPage()
                        let scale = min(pageRect.width / image.size.width, pageRect.height / image.size.height)
                        let drawSize = CGSize(width: image.size.width * scale, height: image.size.height * scale)
                        let origin = CGPoint(x: (pageRect.width - drawSize.width) / 2,
                                             y: (pageRect.height - drawSize.height) / 2)
                        image.draw(in: CGRect(origin: origin, size: drawSize))

                        // Erkannter Text unsichtbar über das Bild gelegt —
                        // so ist das PDF auch in Dateien/Mail durchsuchbar
                        for beobachtung in seitenTexte[i] {
                            guard let kandidat = beobachtung.topCandidates(1).first else { continue }
                            let box = beobachtung.boundingBox   // normiert, Ursprung unten links
                            let zeilenHoehe = box.height * drawSize.height
                            guard zeilenHoehe > 1 else { continue }
                            let ort = CGRect(
                                x: origin.x + box.minX * drawSize.width,
                                y: origin.y + (1 - box.maxY) * drawSize.height,
                                width: box.width * drawSize.width,
                                height: zeilenHoehe)
                            (kandidat.string as NSString).draw(
                                in: ort,
                                withAttributes: [
                                    .font: UIFont.systemFont(ofSize: max(4, zeilenHoehe * 0.8)),
                                    .foregroundColor: UIColor.clear
                                ])
                        }
                    }
                }

                let vollText = seitenTexte
                    .map { seite in seite.compactMap { $0.topCandidates(1).first?.string }.joined(separator: "\n") }
                    .joined(separator: "\n")

                let url = FileManager.default.temporaryDirectory.appendingPathComponent("\(UUID().uuidString).pdf")
                DispatchQueue.main.async {
                    do {
                        try pdfData.write(to: url, options: .atomic)
                        fertig(url, vollText)
                    } catch {
                        controller.dismiss(animated: true)
                    }
                }
            }
        }

        func documentCameraViewControllerDidCancel(_ controller: VNDocumentCameraViewController) {
            controller.dismiss(animated: true)
        }

        func documentCameraViewController(_ controller: VNDocumentCameraViewController, didFailWithError error: Error) {
            controller.dismiss(animated: true)
        }
    }
}

// MARK: - Farb-Picker für Gruppen

struct CategoryColorPickerSheet: View {
    let categoryName: String
    let current: Int?
    let onSelect: (Int?) -> Void

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 16), count: 3)

    var body: some View {
        VStack(spacing: 0) {
            Text("Farbe für \"\(categoryName)\"")
                .font(.headline)
                .padding(.top, 20)
                .padding(.bottom, 16)

            LazyVGrid(columns: columns, spacing: 16) {
                ForEach(0..<NoteColor.palette.count, id: \.self) { idx in
                    let nc = NoteColor.for_(idx)
                    let isSelected = current == idx
                    Button { onSelect(idx) } label: {
                        VStack(spacing: 8) {
                            Circle()
                                .fill(nc.accent)
                                .frame(width: 48, height: 48)
                                .overlay {
                                    if isSelected {
                                        Image(systemName: "checkmark")
                                            .font(.system(size: 18, weight: .bold))
                                            .foregroundStyle(.white)
                                    }
                                }
                                .overlay {
                                    Circle()
                                        .strokeBorder(nc.accent, lineWidth: isSelected ? 3 : 0)
                                        .padding(-4)
                                }
                            Text(nc.name)
                                .font(.caption.weight(isSelected ? .semibold : .regular))
                                .foregroundStyle(isSelected ? nc.accent : .secondary)
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 24)

            if current != nil {
                Button(role: .destructive) { onSelect(nil) } label: {
                    Label("Farbe zurücksetzen", systemImage: "arrow.uturn.backward")
                        .font(.subheadline)
                }
                .padding(.top, 20)
            }

            Spacer()
        }
        .presentationDetents([.fraction(0.42)])
        .presentationDragIndicator(.visible)
    }
}

// MARK: - Icon-Wähler für Gruppen

/// Alle Arca-Symbole, die als Gruppen-Icon zur Wahl stehen — thematisch sortiert.
let arcaKategorieSymbole: [String] = [
    "ArcaFolder", "ArcaArchive", "ArcaDocument", "ArcaCard", "ArcaInvoice",
    "ArcaHome", "ArcaCar", "ArcaWallet", "ArcaChart", "ArcaShield",
    "ArcaHealth", "ArcaPerson", "ArcaHeart", "ArcaPaw", "ArcaBook",
    "ArcaGraduation", "ArcaBriefcase", "ArcaFood", "ArcaCart", "ArcaGift",
    "ArcaDumbbell", "ArcaMusic", "ArcaCamera", "ArcaLeaf", "ArcaTravel",
    "ArcaPlace", "ArcaGlobe", "ArcaCalendar", "ArcaClock", "ArcaMail",
    "ArcaPhone", "ArcaCloud", "ArcaKey", "ArcaLock", "ArcaStar",
    "ArcaFlag", "ArcaChecklist", "ArcaScan", "ArcaBolt", "ArcaIdee",
]

struct CategoryIconPickerSheet: View {
    let categoryName: String
    let current: String?          // nil = automatisch (nach Name)
    let farbe: NoteColor
    let onSelect: (String?) -> Void   // nil = zurück zur Automatik

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 12), count: 5)

    var body: some View {
        VStack(spacing: 0) {
            Text("Symbol für \(categoryName)")
                .font(.headline)
                .padding(.top, 20)
                .padding(.bottom, 6)

            Button {
                onSelect(nil)
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "wand.and.stars")
                    Text("Automatisch nach Name")
                }
                .font(.subheadline.weight(current == nil ? .semibold : .regular))
                .foregroundStyle(current == nil ? farbe.accent : .secondary)
                .padding(.vertical, 7)
                .padding(.horizontal, 14)
                .background(current == nil ? farbe.bg.opacity(0.5) : Color(.secondarySystemFill),
                            in: Capsule())
            }
            .buttonStyle(.plain)
            .padding(.bottom, 14)

            ScrollView {
                LazyVGrid(columns: columns, spacing: 12) {
                    ForEach(arcaKategorieSymbole, id: \.self) { sym in
                        let sel = current == sym
                        Button { onSelect(sym) } label: {
                            ArcaIcon(name: sym, groesse: 23)
                                .foregroundStyle(sel ? .white : farbe.accent)
                                .frame(width: 52, height: 52)
                                .background(sel ? farbe.accent : farbe.bg.opacity(0.45),
                                            in: RoundedRectangle(cornerRadius: 13))
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 28)
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }
}

// MARK: - Gruppen-Manager

/// Wählt ein passendes Arca-Symbol zum Gruppennamen (Stichwort-Erkennung,
/// damit auch selbst angelegte Gruppen ein sprechendes Icon bekommen).
/// Gibt IMMER einen Arca-Asset-Namen zurück — nie ein bares SF-Symbol.
func categoryIcon(_ name: String) -> String {
    let n = name.lowercased()
    func hat(_ teile: String...) -> Bool { teile.contains { n.contains($0) } }
    switch true {
    case hat("gesund", "arzt", "medizin", "health", "apotheke", "zahn", "impf"):        return "ArcaHealth"
    case hat("auto", "fahrzeug", "kfz", "wagen", "car", "motorrad", "velo", "bike"):     return "ArcaCar"
    case hat("finanz", "geld", "bank", "konto", "budget", "steuer", "lohn", "gehalt"):   return "ArcaWallet"
    case hat("versicher", "police", "garantie", "schutz", "schaden"):                    return "ArcaShield"
    case hat("rechnung", "beleg", "quittung", "invoice", "kassenbon"):                   return "ArcaInvoice"
    case hat("reise", "urlaub", "ferien", "travel", "flug", "hotel"):                    return "ArcaTravel"
    case hat("haus", "wohn", "miete", "immobil", "home", "garten", "strom"):             return "ArcaHome"
    case hat("passwort", "zugang", "schlüssel", "schluessel", "key", "login", "tresor", "safe"): return "ArcaKey"
    case hat("vertrag", "verträge", "vertraege", "abo"):                                 return "ArcaDocument"
    case hat("papier", "dokument", "urkunde", "zeugnis", "pass", "ausweis"):             return "ArcaCard"
    case hat("person", "privat", "persönl", "persoenl", "familie", "kontakt", "kind"):   return "ArcaPerson"
    case hat("termin", "kalender", "datum", "frist"):                                    return "ArcaCalendar"
    case hat("ort", "adresse", "place", "standort"):                                     return "ArcaPlace"
    case hat("foto", "bild", "scan", "gescannt"):                                        return "ArcaScan"
    case hat("aufgabe", "todo", "liste", "erledig", "check"):                            return "ArcaChecklist"
    case hat("favorit", "wichtig", "stern", "star"):                                     return "ArcaStar"
    case hat("sicher", "lock", "gesperrt", "geheim"):                                    return "ArcaLock"
    case hat("sonstig", "divers", "misc", "allgemein", "varia", "unsortiert", "eingang", "inbox"): return "ArcaArchive"
    default:                                                                             return "ArcaFolder"
    }
}

struct DocumentCategoryManagerRow: View {
    @EnvironmentObject var store: AppStore
    let category: String
    let onRename: () -> Void

    private var docCount: Int { store.documentCount(in: category) }
    private var inQuickView: Bool { store.isInHomeFolderQuickView(category) }

    var body: some View {
        HStack(spacing: 12) {
            Image(store.iconFor(category))
                .foregroundStyle(categoryColor(category, overrides: store.categoryColors).accent)
                .frame(width: 28)
            VStack(alignment: .leading, spacing: 2) {
                Text(category)
                if docCount > 0 {
                    Text("\(docCount) Dokument\(docCount == 1 ? "" : "e")")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    Text("Leer")
                        .font(.caption)
                        .foregroundStyle(.secondary.opacity(0.6))
                }
            }
            Spacer()
            Button { store.toggleHomeFolderQuickView(category) } label: {
                Image(systemName: inQuickView ? "house.fill" : "house")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(inQuickView ? Color.blue : (docCount > 0 ? Color.secondary : Color.secondary.opacity(0.5)))
                    .frame(width: 36, height: 36)
                    .background(Color(.secondarySystemFill), in: Circle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(inQuickView ? "Aus Start-Schnellansicht entfernen" : "In Start-Schnellansicht anzeigen")
            Button(action: onRename) {
                Image(systemName: "pencil")
                    .foregroundStyle(.blue)
            }
            .buttonStyle(.plain)
        }
    }
}

struct DocumentCategoryManagerView: View {
    @EnvironmentObject var store: AppStore
    @Environment(\.dismiss) var dismiss
    @State private var showAddAlert = false
    @State private var newCategoryName = ""
    @State private var renameTarget: String? = nil
    @State private var renameText = ""

    var body: some View {
        NavigationStack {
            List {
                ForEach(store.documentCategories, id: \.self) { cat in
                    DocumentCategoryManagerRow(category: cat) {
                        renameTarget = cat
                        renameText = cat
                    }
                }
                .onDelete { indexSet in
                    indexSet.forEach { store.deleteCategory(store.documentCategories[$0]) }
                }
                .onMove { from, to in
                    store.documentCategories.move(fromOffsets: from, toOffset: to)
                }
            }
            .navigationTitle("Gruppen verwalten")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { EditButton() }
                ToolbarItem(placement: .primaryAction) {
                    Button { showAddAlert = true } label: { Image(systemName: "plus") }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Fertig") { dismiss() }
                }
            }
            .alert("Neue Gruppe", isPresented: $showAddAlert) {
                TextField("Name", text: $newCategoryName)
                Button("Hinzufügen") {
                    let trimmed = newCategoryName.trimmingCharacters(in: .whitespacesAndNewlines)
                    if !trimmed.isEmpty && !store.documentCategories.contains(trimmed) {
                        store.documentCategories.append(trimmed)
                    }
                    newCategoryName = ""
                }
                Button("Abbrechen", role: .cancel) { newCategoryName = "" }
            }
            .alert("Gruppe umbenennen", isPresented: Binding(
                get: { renameTarget != nil },
                set: { if !$0 { renameTarget = nil } }
            )) {
                TextField("Name", text: $renameText)
                Button("Speichern") {
                    if let old = renameTarget { store.renameCategory(from: old, to: renameText) }
                    renameTarget = nil
                }
                Button("Abbrechen", role: .cancel) { renameTarget = nil }
            }
        }
    }
}
