//
//  SettingsView.swift
//  ArcaPet
//

import SwiftUI
import ARCAKit

struct PetSettingsView: View {
    @EnvironmentObject private var store: PetStore
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Name", text: $store.profile.name)
                    TextField("Art (Hund, Katze, …)", text: $store.profile.species)
                    TextField("Rasse", text: Binding(
                        get: { store.profile.breed ?? "" },
                        set: { store.profile.breed = $0.isEmpty ? nil : $0 }
                    ))
                    TextField("Chip-Nummer", text: Binding(
                        get: { store.profile.chipNumber ?? "" },
                        set: { store.profile.chipNumber = $0.isEmpty ? nil : $0 }
                    ))
                } header: {
                    Text("Pet Setup")
                } footer: {
                    Text("Grunddaten deines Tieres — erscheinen im Begrüssungs-Badge.")
                }

                Section {
                    TextField("Tierarzt", text: Binding(
                        get: { store.profile.vetName ?? "" },
                        set: { store.profile.vetName = $0.isEmpty ? nil : $0 }
                    ))
                    TextField("Telefon Tierarzt", text: Binding(
                        get: { store.profile.vetPhone ?? "" },
                        set: { store.profile.vetPhone = $0.isEmpty ? nil : $0 }
                    ))
                        .keyboardType(.phonePad)
                } header: {
                    Text("Tierarzt")
                }

                Section {
                    HStack {
                        Label("iCloud", systemImage: "icloud.fill")
                        Spacer()
                        Text(store.iCloudStatus.rawValue)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                } footer: {
                    Text(store.isICloudAvailable
                         ? "Deine Tierdaten werden über iCloud synchronisiert."
                         : "iCloud ist nicht verfügbar — Daten werden lokal gespeichert.")
                }

                Section {
                    HStack {
                        Text("Version")
                        Spacer()
                        Text(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0")
                            .foregroundStyle(.secondary)
                    }
                } header: {
                    Text("Über Arca Pet")
                }

                Section {
                    NavigationLink {
                        ARCAKitDemoView()
                            .toolbarBackground(.hidden, for: .navigationBar)
                    } label: {
                        Label("ARCAKit-Demo", systemImage: "shippingbox.fill")
                    }
                } header: {
                    Text("Entwickler")
                } footer: {
                    Text("Integrationstest: zeigt die extrahierte ARCA-DNA aus dem ARCAKit-Package. Keine produktive Funktion.")
                }
            }
            .scrollContentBackground(.hidden)
            .petScreenBackground()
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
