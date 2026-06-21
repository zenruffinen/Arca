//
//  KeychainManager.swift
//  Arca
//
//  Entwickler: Hans zen Ruffinen
//

import Foundation
import Security

final class KeychainManager {
    static let shared = KeychainManager()
    private init() {}

    /// Speichert einen Wert im Keychain.
    /// - Parameter synchronizable: `true` → iCloud Keychain (geräteübergreifend).
    ///   Vault-Passwörter nutzen `true`; PIN-Hash bleibt `false` (gerätespezifisch).
    @discardableResult
    func save(key: String, value: String, synchronizable: Bool = false) -> Bool {
        guard let data = value.data(using: .utf8) else { return false }

        // Erst alle vorhandenen Einträge für diesen Key löschen (sync + nicht-sync)
        let deleteQuery: [String: Any] = [
            kSecClass as String:                kSecClassGenericPassword,
            kSecAttrAccount as String:          key,
            kSecAttrSynchronizable as String:   kSecAttrSynchronizableAny
        ]
        SecItemDelete(deleteQuery as CFDictionary)

        let addQuery: [String: Any] = [
            kSecClass as String:                kSecClassGenericPassword,
            kSecAttrAccount as String:          key,
            kSecValueData as String:            data,
            // synchronizable Items müssen AfterFirstUnlock sein (kein ThisDeviceOnly)
            kSecAttrAccessible as String:       synchronizable
                                                    ? kSecAttrAccessibleAfterFirstUnlock
                                                    : kSecAttrAccessibleWhenUnlockedThisDeviceOnly,
            kSecAttrSynchronizable as String:   synchronizable
        ]
        return SecItemAdd(addQuery as CFDictionary, nil) == errSecSuccess
    }

    /// Lädt einen Wert aus dem Keychain.
    func load(key: String, synchronizable: Bool = false) -> String? {
        let query: [String: Any] = [
            kSecClass as String:                kSecClassGenericPassword,
            kSecAttrAccount as String:          key,
            kSecReturnData as String:           true,
            kSecMatchLimit as String:           kSecMatchLimitOne,
            kSecAttrSynchronizable as String:   synchronizable
        ]
        var result: AnyObject?
        SecItemCopyMatching(query as CFDictionary, &result)
        guard let data = result as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    /// Löscht einen Eintrag – entfernt sowohl sync als auch nicht-sync Variante.
    @discardableResult
    func delete(key: String) -> Bool {
        let query: [String: Any] = [
            kSecClass as String:                kSecClassGenericPassword,
            kSecAttrAccount as String:          key,
            kSecAttrSynchronizable as String:   kSecAttrSynchronizableAny
        ]
        let status = SecItemDelete(query as CFDictionary)
        return status == errSecSuccess || status == errSecItemNotFound
    }
}
