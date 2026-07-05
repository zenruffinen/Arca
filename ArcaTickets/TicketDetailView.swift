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
    @State private var showRenewal = false
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

    private var canRenew: Bool {
        ticket.isExpired && !ticket.isArchived
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                if canRenew {
                    Button {
                        showRenewal = true
                    } label: {
                        Label("Erneuern", systemImage: "arrow.triangle.2.circlepath")
                            .font(.system(size: 16, weight: .semibold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .foregroundStyle(.white)
                            .background(Color.orange, in: RoundedRectangle(cornerRadius: ArcaTicketsDesign.cornerRadius, style: .continuous))
                    }
                    .buttonStyle(.plain)
                }

                if canShowQR {
                    TicketsPrimaryButton(title: "Am Schalter zeigen", icon: "qrcode.viewfinder") {
                        TicketsHaptics.mediumImpact()
                        showQRFullscreen = true
                    }
                }

                if ticket.isArchived {
                    Label("Archiviert — durch Erneuerung ersetzt", systemImage: "archivebox.fill")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(12)
                        .ticketsCardBackground(tint: .gray, cornerRadius: 12)
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
                HStack(spacing: 16) {
                    Button {
                        store.togglePin(for: ticket)
                        syncTicketFromStore()
                    } label: {
                        Image(systemName: ticket.isPinned ? "pin.fill" : "pin")
                            .foregroundStyle(ticket.isPinned ? ArcaTicketsDesign.travelSunset : .primary)
                    }
                    .accessibilityLabel(ticket.isPinned ? "Von Unterwegs lösen" : "Auf Unterwegs anheften")

                    Button("Bearbeiten") { isEditing = true }
                }
            }
        }
        .sheet(isPresented: $isEditing) {
            EditTicketView(ticket: $ticket)
        }
        .sheet(isPresented: $showRenewal) {
            AddTicketView(preselectedFolder: ticket.folder, renewalSource: ticket)
        }
        .fullScreenCover(isPresented: $showQRFullscreen) {
            QRFullscreenView(imageURL: fileURL)
        }
        .onAppear {
            fileMissing = !store.ensureFileDownloaded(ticket.fileName)
                && !FileManager.default.fileExists(atPath: fileURL.path)
            syncTicketFromStore()
        }
        .onChange(of: ticket) { _, updated in
            store.updateTicket(updated)
        }
        .onChange(of: store.tickets) { _, _ in
            syncTicketFromStore()
        }
    }

    private func syncTicketFromStore() {
        if let current = store.tickets.first(where: { $0.id == ticket.id }) {
            ticket = current
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
            if ticket.hasTravelDetails {
                VStack(alignment: .leading, spacing: 8) {
                    Label("Reisedetails", systemImage: "airplane")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(ArcaTicketsDesign.travelOcean)

                    if let flight = ticket.flightNumber, !flight.isEmpty {
                        detailRow(title: "Flugnummer", value: flight)
                    }
                    if let seat = ticket.seatNumber, !seat.isEmpty {
                        detailRow(title: "Sitzplatz", value: seat)
                    }
                    if let boarding = ticket.boardingTime {
                        detailRow(title: "Boarding", value: boarding.formatted(date: .abbreviated, time: .shortened))
                    }
                    if let gate = ticket.gate, !gate.isEmpty {
                        detailRow(title: "Gate", value: gate)
                    }
                }
            }

            detailRow(title: "Ordner", value: ticket.folder)
            if let expiry = ticket.expiryDate {
                detailRow(title: "Gültig bis", value: expiry.formatted(date: .long, time: .shortened))
                if let countdown = ticket.expiryCountdownText {
                    detailRow(title: "Status", value: countdown)
                } else if ticket.isExpired {
                    detailRow(title: "Status", value: "Abgelaufen")
                }
            } else {
                detailRow(title: "Gültig bis", value: "Nicht gesetzt")
            }
            if let usesText = ticket.usesCountdownText {
                detailRow(title: "Eintritte", value: usesText)
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
    @State private var hasUses = false
    @State private var remainingUses = 10
    @State private var totalUses = 10
    @State private var flightNumber = ""
    @State private var seatNumber = ""
    @State private var gate = ""
    @State private var hasBoarding = false
    @State private var boardingTime = Date()
    @State private var isPinned = false

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
                    Toggle("Auf Unterwegs anheften", isOn: $isPinned)
                }
                Section("Reise") {
                    TextField("Flugnummer", text: $flightNumber)
                        .textInputAutocapitalization(.characters)
                    TextField("Sitzplatz", text: $seatNumber)
                        .textInputAutocapitalization(.characters)
                    TextField("Gate (optional)", text: $gate)
                        .textInputAutocapitalization(.characters)
                    Toggle("Boarding-Zeit", isOn: $hasBoarding)
                    if hasBoarding {
                        DatePicker("Boarding", selection: $boardingTime, displayedComponents: [.date, .hourAndMinute])
                    }
                }
                Section("Gültigkeit") {
                    Toggle("Ablaufdatum", isOn: $hasExpiry)
                    if hasExpiry {
                        DatePicker("Gültig bis", selection: $expiryDate, displayedComponents: [.date, .hourAndMinute])
                    }
                }
                Section("Mehrfachkarte") {
                    Toggle("Eintritte zählen", isOn: $hasUses)
                    if hasUses {
                        Stepper("Verbleibend: \(remainingUses)", value: $remainingUses, in: 0...999)
                        Stepper("Gesamt: \(totalUses)", value: $totalUses, in: 1...999)
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
                if ticket.remainingUses != nil {
                    hasUses = true
                    remainingUses = ticket.remainingUses ?? 0
                    totalUses = ticket.totalUses ?? remainingUses
                }
                flightNumber = ticket.flightNumber ?? ""
                seatNumber = ticket.seatNumber ?? ""
                gate = ticket.gate ?? ""
                if let boarding = ticket.boardingTime {
                    hasBoarding = true
                    boardingTime = boarding
                }
                isPinned = ticket.isPinned
            }
        }
    }

    private func save() {
        ticket.title = title.trimmingCharacters(in: .whitespacesAndNewlines)
        ticket.folder = folder
        ticket.expiryDate = hasExpiry ? expiryDate : nil
        let trimmedNotes = notes.trimmingCharacters(in: .whitespacesAndNewlines)
        ticket.notes = trimmedNotes.isEmpty ? nil : trimmedNotes
        if hasUses {
            ticket.remainingUses = remainingUses
            ticket.totalUses = totalUses
        } else {
            ticket.remainingUses = nil
            ticket.totalUses = nil
        }
        let trimmedFlight = flightNumber.trimmingCharacters(in: .whitespacesAndNewlines)
        ticket.flightNumber = trimmedFlight.isEmpty ? nil : trimmedFlight
        let trimmedSeat = seatNumber.trimmingCharacters(in: .whitespacesAndNewlines)
        ticket.seatNumber = trimmedSeat.isEmpty ? nil : trimmedSeat
        let trimmedGate = gate.trimmingCharacters(in: .whitespacesAndNewlines)
        ticket.gate = trimmedGate.isEmpty ? nil : trimmedGate
        ticket.boardingTime = hasBoarding ? boardingTime : nil
        ticket.isPinned = isPinned
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
