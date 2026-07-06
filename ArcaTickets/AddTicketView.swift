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
    var forHolidayBoarding: Bool = false

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
    @State private var flightNumber = ""
    @State private var seatNumber = ""
    @State private var gate = ""
    @State private var hasBoarding = false
    @State private var boardingTime = Date()
    @State private var pinOnAdd = false
    @State private var showTravelDetails = false
    @State private var showNewFolderSheet = false
    @State private var newFolderName = ""
    @State private var newFolderError = ""

    private enum FolderPicker {
        static let createNew = "___CREATE_NEW_FOLDER___"
    }

    init(
        preselectedFolder: String = TicketStore.defaultFolders.first ?? "Sonstiges",
        importURL: URL? = nil,
        renewalSource: TicketEntry? = nil,
        forHolidayBoarding: Bool = false
    ) {
        self.preselectedFolder = preselectedFolder
        self.importURL = importURL
        self.renewalSource = renewalSource
        self.forHolidayBoarding = forHolidayBoarding
        _folder = State(initialValue: renewalSource?.folder ?? preselectedFolder)
        _title = State(initialValue: renewalSource?.title ?? "")
        _notes = State(initialValue: renewalSource?.notes ?? "")
        _pinOnAdd = State(initialValue: forHolidayBoarding)
        _showTravelDetails = State(initialValue: forHolidayBoarding)
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
                        Label("Erneuerts Ticket — neus Dokument und neus Ablaufdatum wähle.", systemImage: "arrow.triangle.2.circlepath")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Section {
                    PhotosPicker(selection: $selectedPhoto, matching: .images) {
                        Label("Us Foto wähle", systemImage: "photo.on.rectangle")
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
                } header: {
                    Text("Quelle")
                } footer: {
                    Text(forHolidayBoarding
                         ? "PDF us Mail, Foto vo Wallet oder Kamera — alles geit."
                         : "Tipp: In Mail oder Safari uf Teile tippen → Arca Tickets.")
                        .font(.caption)
                }

                if pendingFileURL != nil || pendingData != nil {
                    Section("Vorschau") {
                        previewRow
                    }
                }

                Section {
                    TextField("Titel", text: $title)
                    if !forHolidayBoarding {
                        Picker("Ordner", selection: Binding(
                            get: { folder },
                            set: { new in
                                if new == FolderPicker.createNew {
                                    newFolderName = ""
                                    newFolderError = ""
                                    showNewFolderSheet = true
                                } else {
                                    folder = new
                                }
                            }
                        )) {
                            ForEach(store.folders, id: \.self) { name in
                                Text(name).tag(name)
                            }
                            Text("Neue Ordner…").tag(FolderPicker.createNew)
                        }
                        Toggle(ArcaTicketsStrings.pinOnUnterwegs, isOn: $pinOnAdd)
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
                    TextField("Notize (optional)", text: $notes, axis: .vertical)
                        .lineLimit(2...4)
                } header: {
                    Text("Details")
                }

                Section {
                    DisclosureGroup(isExpanded: $showTravelDetails) {
                        TextField("Flugnummer", text: $flightNumber)
                            .textInputAutocapitalization(.characters)
                        TextField("Sitzplatz", text: $seatNumber)
                            .textInputAutocapitalization(.characters)
                        TextField("Gate", text: $gate)
                            .textInputAutocapitalization(.characters)
                        Toggle("Boarding-Zeit", isOn: $hasBoarding)
                        if hasBoarding {
                            DatePicker("Boarding", selection: $boardingTime, displayedComponents: [.date, .hourAndMinute])
                        }
                    } label: {
                        Label("Reisedetail (optional)", systemImage: "airplane")
                    }
                } footer: {
                    Text("Flug, Sitz und Gate — nur wenn du sie bruchsch. Alles spöter änderbar.")
                        .font(.caption)
                }

                if !errorMessage.isEmpty {
                    Section {
                        Text(errorMessage)
                            .foregroundStyle(.red)
                            .font(.caption)
                    }
                }
            }
            .navigationTitle(
                isRenewal ? "Ticket erneuere"
                : forHolidayBoarding ? ArcaTicketsStrings.addBoardingPass
                : "Neus Ticket"
            )
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(ArcaTicketsStrings.cancel) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(isRenewal ? ArcaTicketsStrings.renew : ArcaTicketsStrings.save) { saveTicket() }
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
                case .failure:
                    errorMessage = ArcaTicketsStrings.didNotWork + " — no einisch probiere?"
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
            .sheet(isPresented: $showNewFolderSheet) {
                NavigationStack {
                    Form {
                        Section {
                            TextField("Ordnername", text: $newFolderName)
                                .textInputAutocapitalization(.words)
                        } footer: {
                            if !newFolderError.isEmpty {
                                Text(newFolderError)
                                    .foregroundStyle(.red)
                            } else {
                                Text("De Ordner wird gspeicheret und für das Ticket usgwählt.")
                            }
                        }
                    }
                    .navigationTitle("Neuer Ordner")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button(ArcaTicketsStrings.cancel) {
                                newFolderName = ""
                                newFolderError = ""
                                showNewFolderSheet = false
                            }
                        }
                        ToolbarItem(placement: .confirmationAction) {
                            Button(ArcaTicketsStrings.create) { createNewFolder() }
                                .disabled(newFolderName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        }
                    }
                }
                .presentationDetents([.height(220)])
                .presentationDragIndicator(.visible)
            }
        }
    }

    private func createNewFolder() {
        let trimmed = newFolderName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        if store.folders.contains(where: { $0.caseInsensitiveCompare(trimmed) == .orderedSame }) {
            newFolderError = "En Ordner mit dem Name git scho."
            return
        }
        guard store.addFolder(named: trimmed) else {
            newFolderError = "De Ordner het nöd chönne erstellt werde."
            return
        }
        folder = trimmed
        newFolderName = ""
        newFolderError = ""
        showNewFolderSheet = false
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
            Label("Datei usgwählt", systemImage: "checkmark.circle.fill")
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
            await MainActor.run { errorMessage = ArcaTicketsStrings.didNotWork + " — no einisch probiere?" }
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
            errorMessage = ArcaTicketsStrings.didNotWork + " — no einisch probiere?"
            return
        }

        saved.expiryDate = hasExpiry ? expiryDate : nil
        let trimmedNotes = notes.trimmingCharacters(in: .whitespacesAndNewlines)
        saved.notes = trimmedNotes.isEmpty ? nil : trimmedNotes
        if hasUses {
            saved.remainingUses = remainingUses
            saved.totalUses = totalUses
        }
        let trimmedFlight = flightNumber.trimmingCharacters(in: .whitespacesAndNewlines)
        saved.flightNumber = trimmedFlight.isEmpty ? nil : trimmedFlight
        let trimmedSeat = seatNumber.trimmingCharacters(in: .whitespacesAndNewlines)
        saved.seatNumber = trimmedSeat.isEmpty ? nil : trimmedSeat
        let trimmedGate = gate.trimmingCharacters(in: .whitespacesAndNewlines)
        saved.gate = trimmedGate.isEmpty ? nil : trimmedGate
        saved.boardingTime = hasBoarding ? boardingTime : nil
        saved.isPinned = pinOnAdd
        store.updateTicket(saved)

        if let source = renewalSource {
            store.archiveTicket(source)
        }

        TicketsHaptics.success()
        let hasFlight = !(saved.flightNumber?.isEmpty ?? true)
        if forHolidayBoarding {
            store.showToast("Boarding Pass debii ✈️")
        } else if pinOnAdd {
            store.showToast("Uf Unterwägs agheftet ✈️")
        } else if hasFlight {
            store.showToast("Guete Flug! ✈️")
        } else if isRenewal {
            store.showToast("Ticket erneuert — gueti Fahrt!")
        } else {
            store.showToast("Alles gspeicheret — gueti Reise!")
        }
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
