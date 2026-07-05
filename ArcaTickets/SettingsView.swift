//
//  SettingsView.swift
//  ArcaTickets
//
//  Entwickler: Hans zen Ruffinen
//

import SwiftUI

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var store: TicketStore

    var body: some View {
        NavigationStack {
            Form {
                Section("Synchronisation") {
                    LabeledContent("iCloud", value: store.iCloudStatus.rawValue)
                    if store.isICloudAvailable {
                        Text("Tickets und Dateien werden über iCloud Drive synchronisiert.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else {
                        Text("iCloud ist nicht verfügbar. Daten werden lokal gespeichert.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Section("App") {
                    LabeledContent("Version", value: "1.0.0 (1)")
                    LabeledContent("Tickets", value: "\(store.tickets.count)")
                }

                Section("Erinnerungen") {
                    Text("Du wirst einen Tag vor Ablauf an gültige Tickets erinnert.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Section("Sicherheit") {
                    Text("PIN und Face ID schützen den Zugriff auf deine Tickets.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Einstellungen")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Fertig") { dismiss() }
                }
            }
        }
    }
}
