//
//  TicketDetailView.swift
//  ArcaTickets
//
//  Entwickler: Hans zen Ruffinen
//

import SwiftUI
import PDFKit

struct TicketDetailView: View {
    @EnvironmentObject private var store: TicketStore
    @State private var ticket: TicketEntry
    @State private var showQRFullscreen = false
    @State private var isEditing = false
    @State private var fileMissing = false

    init(ticket: TicketEntry) {
        _ticket = State(initialValue: ticket)
    }

    private var fileURL: URL {
        store.fileURL(for: ticket.fileName)
    }

    private var canShowQR: Bool {
        ticket.fileKind == .image
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                if canShowQR {
                    TicketsPrimaryButton(title: "Am Schalter zeigen", icon: "qrcode.viewfinder") {
                        TicketsHaptics.mediumImpact()
                        showQRFullscreen = true
                    }
                }

                previewSection

                metadataSection
            }
            .padding(16)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle(ticket.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Bearbeiten") { isEditing = true }
            }
        }
        .sheet(isPresented: $isEditing) {
            EditTicketView(ticket: $ticket)
        }
        .fullScreenCover(isPresented: $showQRFullscreen) {
            QRFullscreenView(imageURL: fileURL)
        }
        .onAppear {
            fileMissing = !store.ensureFileDownloaded(ticket.fileName)
                && !FileManager.default.fileExists(atPath: fileURL.path)
        }
        .onChange(of: ticket) { _, updated in
            store.updateTicket(updated)
        }
    }

    @ViewBuilder
    private var previewSection: some View {
        if fileMissing {
            ContentUnavailableView("Datei wird geladen", systemImage: "icloud.and.arrow.down")
        } else if ticket.fileKind == .pdf {
            PDFKitView(url: fileURL)
                .frame(minHeight: 360)
                .clipShape(RoundedRectangle(cornerRadius: ArcaTicketsDesign.cornerRadius, style: .continuous))
        } else if let uiImage = UIImage(contentsOfFile: fileURL.path) {
            Image(uiImage: uiImage)
                .resizable()
                .scaledToFit()
                .frame(maxWidth: .infinity)
                .clipShape(RoundedRectangle(cornerRadius: ArcaTicketsDesign.cornerRadius, style: .continuous))
                .onTapGesture {
                    if canShowQR { showQRFullscreen = true }
                }
        } else {
            ContentUnavailableView("Vorschau nicht verfügbar", systemImage: "exclamationmark.triangle")
        }
    }

    private var metadataSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            detailRow(title: "Ordner", value: ticket.folder)
            if let expiry = ticket.expiryDate {
                detailRow(title: "Gültig bis", value: expiry.formatted(date: .long, time: .shortened))
                if let countdown = ticket.expiryCountdownText {
                    detailRow(title: "Status", value: countdown)
                }
            } else {
                detailRow(title: "Gültig bis", value: "Nicht gesetzt")
            }
            detailRow(title: "Hinzugefügt", value: ticket.createdAt.formatted(date: .abbreviated, time: .shortened))
            if let notes = ticket.notes, !notes.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Notizen")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                    Text(notes)
                        .font(.body)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(12)
                .ticketsCardBackground(tint: .gray)
            }
        }
    }

    private func detailRow(title: String, value: String) -> some View {
        HStack {
            Text(title)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .multilineTextAlignment(.trailing)
        }
        .font(.subheadline)
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .ticketsCardBackground(tint: .blue, cornerRadius: 12)
    }
}

struct EditTicketView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var store: TicketStore
    @Binding var ticket: TicketEntry
    @State private var title: String = ""
    @State private var notes: String = ""
    @State private var folder: String = ""
    @State private var hasExpiry = false
    @State private var expiryDate = Date()

    var body: some View {
        NavigationStack {
            Form {
                Section("Ticket") {
                    TextField("Titel", text: $title)
                    Picker("Ordner", selection: $folder) {
                        ForEach(store.folders, id: \.self) { name in
                            Text(name).tag(name)
                        }
                    }
                }
                Section("Gültigkeit") {
                    Toggle("Ablaufdatum", isOn: $hasExpiry)
                    if hasExpiry {
                        DatePicker("Gültig bis", selection: $expiryDate, displayedComponents: [.date, .hourAndMinute])
                    }
                }
                Section("Notizen") {
                    TextField("Optionale Notizen", text: $notes, axis: .vertical)
                        .lineLimit(3...6)
                }
            }
            .navigationTitle("Bearbeiten")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Abbrechen") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Speichern") { save() }
                }
            }
            .onAppear {
                title = ticket.title
                notes = ticket.notes ?? ""
                folder = ticket.folder
                if let expiry = ticket.expiryDate {
                    hasExpiry = true
                    expiryDate = expiry
                }
            }
        }
    }

    private func save() {
        ticket.title = title.trimmingCharacters(in: .whitespacesAndNewlines)
        ticket.folder = folder
        ticket.expiryDate = hasExpiry ? expiryDate : nil
        let trimmedNotes = notes.trimmingCharacters(in: .whitespacesAndNewlines)
        ticket.notes = trimmedNotes.isEmpty ? nil : trimmedNotes
        store.updateTicket(ticket)
        dismiss()
    }
}

struct PDFKitView: UIViewRepresentable {
    let url: URL

    func makeUIView(context: Context) -> PDFView {
        let view = PDFView()
        view.autoScales = true
        view.displayMode = .singlePageContinuous
        view.document = PDFDocument(url: url)
        return view
    }

    func updateUIView(_ uiView: PDFView, context: Context) {
        uiView.document = PDFDocument(url: url)
    }
}
