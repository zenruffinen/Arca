//
//  AddTicketView.swift
//  ArcaTickets
//
//  Entwickler: Hans zen Ruffinen
//

import SwiftUI
import PhotosUI
import UniformTypeIdentifiers

struct AddTicketView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var store: TicketStore

    var preselectedFolder: String = TicketStore.defaultFolders.first ?? "Sonstiges"
    var importURL: URL?
    var renewalSource: TicketEntry?

    @State private var title = ""
    @State private var folder: String
    @State private var notes = ""
    @State private var hasExpiry = false
    @State private var expiryDate = Date().addingTimeInterval(86400)
    @State private var hasUses = false
    @State private var remainingUses = 10
    @State private var totalUses = 10
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var showDocumentPicker = false
    @State private var showCamera = false
    @State private var pendingFileURL: URL?
    @State private var pendingData: Data?
    @State private var pendingExtension = "jpg"
    @State private var errorMessage = ""

    init(
        preselectedFolder: String = TicketStore.defaultFolders.first ?? "Sonstiges",
        importURL: URL? = nil,
        renewalSource: TicketEntry? = nil
    ) {
        self.preselectedFolder = preselectedFolder
        self.importURL = importURL
        self.renewalSource = renewalSource
        _folder = State(initialValue: renewalSource?.folder ?? preselectedFolder)
        _title = State(initialValue: renewalSource?.title ?? "")
        _notes = State(initialValue: renewalSource?.notes ?? "")
        if let source = renewalSource {
            _hasUses = State(initialValue: source.remainingUses != nil)
            _remainingUses = State(initialValue: source.remainingUses ?? 10)
            _totalUses = State(initialValue: source.totalUses ?? source.remainingUses ?? 10)
        }
    }

    private var isRenewal: Bool { renewalSource != nil }

    var body: some View {
        NavigationStack {
            Form {
                if isRenewal {
                    Section {
                        Label("Erneuertes Ticket — neues Dokument und neues Ablaufdatum wählen.", systemImage: "arrow.triangle.2.circlepath")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Section("Quelle") {
                    PhotosPicker(selection: $selectedPhoto, matching: .images) {
                        Label("Aus Fotos wählen", systemImage: "photo.on.rectangle")
                    }
                    Button {
                        showDocumentPicker = true
                    } label: {
                        Label("PDF importieren", systemImage: "doc.fill")
                    }
                    Button {
                        showCamera = true
                    } label: {
                        Label("Kamera", systemImage: "camera.fill")
                    }
                }

                if pendingFileURL != nil || pendingData != nil {
                    Section("Vorschau") {
                        previewRow
                    }
                }

                Section("Details") {
                    TextField("Titel", text: $title)
                    Picker("Ordner", selection: $folder) {
                        ForEach(store.folders, id: \.self) { name in
                            Text(name).tag(name)
                        }
                    }
                    Toggle("Ablaufdatum", isOn: $hasExpiry)
                    if hasExpiry {
                        DatePicker("Gültig bis", selection: $expiryDate, displayedComponents: [.date, .hourAndMinute])
                    }
                    Toggle("Mehrfachkarte", isOn: $hasUses)
                    if hasUses {
                        Stepper("Verbleibend: \(remainingUses)", value: $remainingUses, in: 0...999)
                        Stepper("Gesamt: \(totalUses)", value: $totalUses, in: 1...999)
                    }
                    TextField("Notizen (optional)", text: $notes, axis: .vertical)
                        .lineLimit(2...4)
                }

                if !errorMessage.isEmpty {
                    Section {
                        Text(errorMessage)
                            .foregroundStyle(.red)
                            .font(.caption)
                    }
                }
            }
            .navigationTitle(isRenewal ? "Ticket erneuern" : "Ticket hinzufügen")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Abbrechen") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(isRenewal ? "Erneuern" : "Speichern") { saveTicket() }
                        .disabled(!canSave)
                }
            }
            .onChange(of: selectedPhoto) { _, item in
                Task { await loadPhoto(item) }
            }
            .fileImporter(
                isPresented: $showDocumentPicker,
                allowedContentTypes: [.pdf, .image],
                allowsMultipleSelection: false
            ) { result in
                switch result {
                case .success(let urls):
                    guard let url = urls.first else { return }
                    pendingFileURL = url
                    pendingData = nil
                    pendingExtension = url.pathExtension.isEmpty ? "pdf" : url.pathExtension
                    if title.isEmpty {
                        title = url.deletingPathExtension().lastPathComponent
                    }
                case .failure(let error):
                    errorMessage = error.localizedDescription
                }
            }
            .fullScreenCover(isPresented: $showCamera) {
                CameraPicker { image in
                    if let data = image.jpegData(compressionQuality: 0.92) {
                        pendingData = data
                        pendingFileURL = nil
                        pendingExtension = "jpg"
                        if title.isEmpty { title = "Ticket \(Date().formatted(date: .abbreviated, time: .omitted))" }
                    }
                }
                .ignoresSafeArea()
            }
            .onAppear {
                if let url = importURL {
                    pendingFileURL = url
                    pendingData = nil
                    pendingExtension = url.pathExtension.isEmpty ? "jpg" : url.pathExtension
                    if title.isEmpty {
                        title = url.deletingPathExtension().lastPathComponent
                    }
                }
            }
        }
    }

    private var canSave: Bool {
        (pendingFileURL != nil || pendingData != nil) && !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    @ViewBuilder
    private var previewRow: some View {
        if let url = pendingFileURL,
           url.pathExtension.lowercased() == "pdf" {
            Label(url.lastPathComponent, systemImage: "doc.richtext.fill")
        } else if let url = pendingFileURL,
                  let image = loadImage(from: url) {
            Image(uiImage: image)
                .resizable()
                .scaledToFit()
                .frame(maxHeight: 180)
        } else if let data = pendingData, let image = UIImage(data: data) {
            Image(uiImage: image)
                .resizable()
                .scaledToFit()
                .frame(maxHeight: 180)
        } else {
            Label("Datei ausgewählt", systemImage: "checkmark.circle.fill")
        }
    }

    private func loadImage(from url: URL) -> UIImage? {
        let accessing = url.startAccessingSecurityScopedResource()
        defer { if accessing { url.stopAccessingSecurityScopedResource() } }
        return UIImage(contentsOfFile: url.path) ?? UIImage(data: (try? Data(contentsOf: url)) ?? Data())
    }

    private func loadPhoto(_ item: PhotosPickerItem?) async {
        guard let item else { return }
        do {
            if let data = try await item.loadTransferable(type: Data.self) {
                pendingData = data
                pendingFileURL = nil
                pendingExtension = "jpg"
                if title.isEmpty { title = "Ticket \(Date().formatted(date: .abbreviated, time: .omitted))" }
            }
        } catch {
            await MainActor.run { errorMessage = error.localizedDescription }
        }
    }

    private func saveTicket() {
        let cleanTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanTitle.isEmpty else { return }

        let entry: TicketEntry?
        if let url = pendingFileURL {
            entry = store.importFile(from: url, suggestedTitle: cleanTitle, folder: folder)
        } else if let data = pendingData {
            entry = store.importData(data, fileExtension: pendingExtension, title: cleanTitle, folder: folder)
        } else {
            entry = nil
        }

        guard var saved = entry else {
            errorMessage = "Import fehlgeschlagen."
            return
        }

        saved.expiryDate = hasExpiry ? expiryDate : nil
        let trimmedNotes = notes.trimmingCharacters(in: .whitespacesAndNewlines)
        saved.notes = trimmedNotes.isEmpty ? nil : trimmedNotes
        if hasUses {
            saved.remainingUses = remainingUses
            saved.totalUses = totalUses
        }
        store.updateTicket(saved)

        if let source = renewalSource {
            store.archiveTicket(source)
        }

        TicketsHaptics.success()
        dismiss()
    }
}

struct CameraPicker: UIViewControllerRepresentable {
    let onImage: (UIImage) -> Void
    @Environment(\.dismiss) private var dismiss

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(onImage: onImage, dismiss: dismiss)
    }

    final class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let onImage: (UIImage) -> Void
        let dismiss: DismissAction

        init(onImage: @escaping (UIImage) -> Void, dismiss: DismissAction) {
            self.onImage = onImage
            self.dismiss = dismiss
        }

        func imagePickerController(_ picker: UIImagePickerController,
                                   didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            if let image = info[.originalImage] as? UIImage {
                onImage(image)
            }
            dismiss()
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            dismiss()
        }
    }
}
