import SwiftUI
import LocalAuthentication
import CryptoKit

// MARK: - LockView (Einstiegspunkt)

struct LockView: View {
    @Binding var isUnlocked: Bool

    private var hasPIN: Bool {
        KeychainManager.shared.load(key: "arca_pin_hash") != nil
    }

    var body: some View {
        ZStack {
            // Undurchsichtiger Hintergrund: verdeckt die ContentView dahinter vollständig.
            // Ohne ihn scheint – besonders auf dem iPad (großer Schirm, kein sofortiges
            // Face ID) – der gesamte App-Inhalt durch den Sperrbildschirm. Das sieht
            // überladen/kaputt aus und gibt geschützte Daten preis.
            Color(.systemBackground)
                .ignoresSafeArea()
            if hasPIN {
                PINEntryView(isUnlocked: $isUnlocked)
            } else {
                PINSetupView(isUnlocked: $isUnlocked)
            }
        }
    }
}

// MARK: - PIN Setup (Erster Start)

struct PINSetupView: View {
    @Binding var isUnlocked: Bool
    @State private var pin = ""
    @State private var confirmPin = ""
    @State private var step: SetupStep = .create
    @State private var errorMessage = ""
    @State private var shake = false

    enum SetupStep { case create, confirm }

    var body: some View {
        VStack(spacing: 32) {
            Spacer()

            Image(systemName: "lock.shield.fill")
                .font(.system(size: 64))
                .foregroundStyle(.blue)

            VStack(spacing: 8) {
                Text("Arca schützen")
                    .font(.title.bold())
                Text(step == .create ? "Erstelle deinen 4-stelligen PIN" : "PIN wiederholen zur Bestätigung")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            // PIN Punkte
            HStack(spacing: 20) {
                ForEach(0..<4, id: \.self) { i in
                    let filled = step == .create ? i < pin.count : i < confirmPin.count
                    Circle()
                        .fill(filled ? Color.blue : Color.secondary.opacity(0.3))
                        .frame(width: 18, height: 18)
                        .scaleEffect(filled ? 1.1 : 1.0)
                        .animation(.spring(response: 0.2), value: filled)
                }
            }
            .offset(x: shake ? -10 : 0)
            .animation(shake ? .default.repeatCount(4, autoreverses: true).speed(6) : .default, value: shake)

            if !errorMessage.isEmpty {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundStyle(.red)
            }

            // Ziffernfeld
            PINPad { digit in
                handleInput(digit)
            } onDelete: {
                handleDelete()
            }

            Spacer()
        }
        .padding()
    }

    func handleInput(_ digit: String) {
        let current = step == .create ? pin : confirmPin
        guard current.count < 4 else { return }

        if step == .create {
            pin += digit
            if pin.count == 4 {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                    step = .confirm
                    errorMessage = ""
                }
            }
        } else {
            confirmPin += digit
            if confirmPin.count == 4 {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                    if pin == confirmPin {
                        savePIN(pin)
                        isUnlocked = true
                    } else {
                        errorMessage = "PINs stimmen nicht überein. Bitte neu versuchen."
                        confirmPin = ""
                        pin = ""
                        step = .create
                        shake = true
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { shake = false }
                        UINotificationFeedbackGenerator().notificationOccurred(.error)
                    }
                }
            }
        }
    }

    func handleDelete() {
        if step == .create {
            if !pin.isEmpty { pin.removeLast() }
        } else {
            if !confirmPin.isEmpty { confirmPin.removeLast() }
        }
    }

    func savePIN(_ pin: String) {
        let hash = SHA256.hash(data: Data(pin.utf8))
        let hashString = hash.compactMap { String(format: "%02x", $0) }.joined()
        KeychainManager.shared.save(key: "arca_pin_hash", value: hashString)
    }
}

// MARK: - PIN Eingabe (Entsperren)

struct PINEntryView: View {
    @Binding var isUnlocked: Bool
    @State private var pin = ""
    @State private var errorMessage = ""
    @State private var shake = false
    @State private var attempts = 0
    @State private var lockedUntil: Date? = nil

    // Reset Flow
    @State private var showResetWarning = false
    @State private var showResetConfirm = false

    var body: some View {
        VStack(spacing: 32) {
            Spacer()

            Image(systemName: "lock.shield.fill")
                .font(.system(size: 64))
                .foregroundStyle(.blue)

            VStack(spacing: 8) {
                Text("Arca")
                    .font(.title.bold())
                Text("PIN eingeben")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            // PIN Punkte
            HStack(spacing: 20) {
                ForEach(0..<4, id: \.self) { i in
                    let filled = i < pin.count
                    Circle()
                        .fill(filled ? Color.blue : Color.secondary.opacity(0.3))
                        .frame(width: 18, height: 18)
                        .scaleEffect(filled ? 1.1 : 1.0)
                        .animation(.spring(response: 0.2), value: filled)
                }
            }
            .offset(x: shake ? -10 : 0)
            .animation(shake ? .default.repeatCount(4, autoreverses: true).speed(6) : .default, value: shake)

            if !errorMessage.isEmpty {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.center)
            }

            // Ziffernfeld
            PINPad { digit in
                handleInput(digit)
            } onDelete: {
                if !pin.isEmpty { pin.removeLast() }
            }
            .disabled(lockedUntil != nil)

            // Face ID Button
            Button {
                authenticateWithBiometrics()
            } label: {
                Label("Face ID / Touch ID", systemImage: "faceid")
                    .font(.subheadline)
                    .foregroundStyle(.blue)
            }

            // PIN vergessen
            Button {
                showResetWarning = true
            } label: {
                Text("PIN vergessen?")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .underline()
            }
            .padding(.top, -12)

            Spacer()
        }
        .padding()
        .onAppear {
            authenticateWithBiometrics()
        }
        // Schritt 1: Hinweis auf Backup
        .alert("PIN vergessen", isPresented: $showResetWarning) {
            Button("Weiter", role: .destructive) {
                showResetConfirm = true
            }
            Button("Abbrechen", role: .cancel) {}
        } message: {
            Text("Wenn du deinen PIN nicht mehr kennst, kannst du Arca zurücksetzen. Dabei werden alle gespeicherten Daten gelöscht.\n\nFalls du ein Backup hast, kannst du deine Daten danach in den Einstellungen wiederherstellen.")
        }
        // Schritt 2: Letzte Bestätigung
        .alert("Wirklich zurücksetzen?", isPresented: $showResetConfirm) {
            Button("Alle Daten löschen", role: .destructive) {
                resetApp()
            }
            Button("Abbrechen", role: .cancel) {}
        } message: {
            Text("Diese Aktion kann nicht rückgängig gemacht werden. Alle Passwörter, Dokumente, Notizen und Aufgaben werden unwiderruflich gelöscht.")
        }
    }

    func handleInput(_ digit: String) {
        if let until = lockedUntil {
            if Date() < until { return }
            lockedUntil = nil
        }
        guard pin.count < 4 else { return }
        pin += digit
        if pin.count == 4 {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                checkPIN()
            }
        }
    }

    func checkPIN() {
        let hash = SHA256.hash(data: Data(pin.utf8))
        let hashString = hash.compactMap { String(format: "%02x", $0) }.joined()
        let saved = KeychainManager.shared.load(key: "arca_pin_hash") ?? ""

        if hashString == saved {
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            isUnlocked = true
        } else {
            attempts += 1
            pin = ""
            shake = true
            UINotificationFeedbackGenerator().notificationOccurred(.error)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { shake = false }

            let lockoutSeconds: Double
            switch attempts {
            case 5...6:  lockoutSeconds = 30
            case 7...8:  lockoutSeconds = 60
            default:     lockoutSeconds = attempts >= 9 ? 300 : 0
            }

            if lockoutSeconds > 0 {
                lockedUntil = Date().addingTimeInterval(lockoutSeconds)
                let mins = lockoutSeconds >= 60 ? "\(Int(lockoutSeconds / 60)) Min." : "\(Int(lockoutSeconds)) Sek."
                errorMessage = "Zu viele Versuche – bitte \(mins) warten"
                DispatchQueue.main.asyncAfter(deadline: .now() + lockoutSeconds) {
                    lockedUntil = nil
                    errorMessage = ""
                }
            } else {
                errorMessage = attempts >= 3 ? "Falscher PIN (\(attempts) Versuche)" : "Falscher PIN"
            }
        }
    }

    func authenticateWithBiometrics() {
        let context = LAContext()
        var error: NSError?
        guard context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) else { return }
        context.evaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, localizedReason: "Arca entsperren") { success, _ in
            DispatchQueue.main.async {
                if success { isUnlocked = true }
            }
        }
    }

    func resetApp() {
        // 1. Vault-Passwörter aus Keychain löschen (IDs vorher lesen)
        if let data = UserDefaults.standard.data(forKey: "vaultItems") {
            struct MinEntry: Decodable { let id: UUID }
            if let items = try? JSONDecoder().decode([MinEntry].self, from: data) {
                items.forEach { KeychainManager.shared.delete(key: "vault_\($0.id)") }
            }
        }

        // 2. PIN löschen
        KeychainManager.shared.delete(key: "arca_pin_hash")

        // 3. Alle UserDefaults löschen
        if let bundleID = Bundle.main.bundleIdentifier {
            UserDefaults.standard.removePersistentDomain(forName: bundleID)
        }

        // 4. Dokument-Dateien löschen
        let docsDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        if let files = try? FileManager.default.contentsOfDirectory(at: docsDir, includingPropertiesForKeys: nil) {
            files.forEach { try? FileManager.default.removeItem(at: $0) }
        }

        // 5. App entsperren (zeigt leere App — PIN neu einrichten)
        isUnlocked = true
    }
}

// MARK: - PIN Pad

struct PINPad: View {
    let onDigit: (String) -> Void
    let onDelete: () -> Void

    private let digits = [
        ["1","2","3"],
        ["4","5","6"],
        ["7","8","9"],
        ["","0","⌫"]
    ]

    var body: some View {
        VStack(spacing: 16) {
            ForEach(digits, id: \.self) { row in
                HStack(spacing: 24) {
                    ForEach(row, id: \.self) { key in
                        if key == "" {
                            Circle()
                                .fill(Color.clear)
                                .frame(width: 72, height: 72)
                        } else if key == "⌫" {
                            Button {
                                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                onDelete()
                            } label: {
                                Image(systemName: "delete.left")
                                    .font(.title2)
                                    .frame(width: 72, height: 72)
                                    .background(Color.secondary.opacity(0.1))
                                    .clipShape(Circle())
                            }
                            .foregroundStyle(.primary)
                        } else {
                            Button {
                                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                onDigit(key)
                            } label: {
                                Text(key)
                                    .font(.title.bold())
                                    .frame(width: 72, height: 72)
                                    .background(Color.secondary.opacity(0.1))
                                    .clipShape(Circle())
                            }
                            .foregroundStyle(.primary)
                        }
                    }
                }
            }
        }
    }
}
