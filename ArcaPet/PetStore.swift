//
//  PetStore.swift
//  ArcaPet
//

import SwiftUI
import Combine

final class PetStore: ObservableObject {
    private var isLoadingData = false

    @Published var profile: PetProfile = .placeholder {
        didSet { guard !isLoadingData else { return }; saveProfile() }
    }
    @Published var documents: [PetDocument] = [] {
        didSet { guard !isLoadingData else { return }; saveDocuments() }
    }
    @Published var quickContacts: [QuickContact] = [] {
        didSet { guard !isLoadingData else { return }; saveQuickContacts() }
    }
    @Published private(set) var iCloudStatus: ICloudStatus = .unavailable
    @Published var toastMessage: String?
    @Published var pendingSheet: ArcaPetSheet?

    enum ICloudStatus: String {
        case unavailable = "Nicht verfügbar"
        case connected = "iCloud: verbunden"
        case synced = "Synchronisiert"
    }

    static let pinHashKey = "arcapet_pin_hash"
    private let cloudContainerID = "iCloud.com.hansruffin.ArcaPet"

    private var cloudContainer: URL? {
        FileManager.default.url(forUbiquityContainerIdentifier: cloudContainerID)
    }

    private var dataDirectory: URL {
        if let c = cloudContainer {
            let dir = c.appendingPathComponent("Documents/arcapetdata")
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            return dir
        }
        let dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("arcapetdata")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    var isICloudAvailable: Bool { cloudContainer != nil }

    init() {
        loadAll()
        updateICloudStatus()
    }

    func reloadFromCloud() {
        loadAll()
        updateICloudStatus()
    }

    func showToast(_ message: String) {
        toastMessage = message
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) { [weak self] in
            if self?.toastMessage == message {
                self?.toastMessage = nil
            }
        }
    }

    func resetAllData() {
        isLoadingData = true
        profile = .placeholder
        documents = []
        quickContacts = PetContactDefaults.seedContacts()
        isLoadingData = false
        KeychainManager.shared.delete(key: Self.pinHashKey)
        for key in ["profile", "documents", "contacts"] {
            try? FileManager.default.removeItem(at: dataURL(key))
        }
        saveAll()
    }

    func documents(for category: PetDocumentCategory) -> [PetDocument] {
        documents.filter { $0.category == category }
    }

    private func dataURL(_ key: String) -> URL {
        dataDirectory.appendingPathComponent("\(key).json")
    }

    private func loadAll() {
        isLoadingData = true
        profile = load(PetProfile.self, key: "profile") ?? .placeholder
        documents = load([PetDocument].self, key: "documents") ?? []
        quickContacts = load([QuickContact].self, key: "contacts") ?? PetContactDefaults.seedContacts()
        isLoadingData = false
    }

    private func saveAll() {
        saveProfile()
        saveDocuments()
        saveQuickContacts()
    }

    private func saveProfile() { save(profile, key: "profile") }
    private func saveDocuments() { save(documents, key: "documents") }
    private func saveQuickContacts() { save(quickContacts, key: "contacts") }

    private func load<T: Decodable>(_ type: T.Type, key: String) -> T? {
        let url = dataURL(key)
        guard let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(type, from: data)
    }

    private func save<T: Encodable>(_ value: T, key: String) {
        guard let data = try? JSONEncoder().encode(value) else { return }
        try? data.write(to: dataURL(key), options: .atomic)
        updateICloudStatus()
    }

    private func updateICloudStatus() {
        iCloudStatus = isICloudAvailable ? .synced : .unavailable
    }
}
