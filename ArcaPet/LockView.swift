//
//  LockView.swift
//  ArcaPet
//

import SwiftUI
import LocalAuthentication
import CryptoKit

struct PetLockView: View {
    @Binding var isUnlocked: Bool

    private var hasPIN: Bool {
        KeychainManager.shared.load(key: PetStore.pinHashKey) != nil
    }

    var body: some View {
        ZStack {
            Color(.systemBackground)
                .ignoresSafeArea()
            if hasPIN {
                PetPINEntryView(isUnlocked: $isUnlocked)
            } else {
                PetPINSetupView(isUnlocked: $isUnlocked)
            }
        }
    }
}

struct PetPINSetupView: View {
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
            ArcaPetAppIcon(size: 92)
            VStack(spacing: 8) {
                Text("Arca Pet schützen")
                    .font(.title.bold())
                Text(step == .create ? "Erstelle deine 4-stellige PIN" : "PIN zur Bestätigung wiederholen")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            pinDots(count: step == .create ? pin.count : confirmPin.count)
                .offset(x: shake ? -10 : 0)
                .animation(shake ? .default.repeatCount(4, autoreverses: true).speed(6) : .default, value: shake)
            if !errorMessage.isEmpty {
                Text(errorMessage).font(.caption).foregroundStyle(.red)
            }
            PetPINPad(onDigit: handleInput, onDelete: handleDelete)
            Spacer()
        }
        .padding()
    }

    private func pinDots(count: Int) -> some View {
        HStack(spacing: 20) {
            ForEach(0..<4, id: \.self) { i in
                Circle()
                    .fill(i < count ? Color.accentColor : Color.secondary.opacity(0.3))
                    .frame(width: 18, height: 18)
            }
        }
    }

    private func handleInput(_ digit: String) {
        if step == .create {
            guard pin.count < 4 else { return }
            pin += digit
            if pin.count == 4 {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                    step = .confirm
                    errorMessage = ""
                }
            }
        } else {
            guard confirmPin.count < 4 else { return }
            confirmPin += digit
            if confirmPin.count == 4 {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                    if pin == confirmPin {
                        savePIN(pin)
                        isUnlocked = true
                    } else {
                        errorMessage = "PINs stimmen nicht überein."
                        confirmPin = ""
                        pin = ""
                        step = .create
                        shake = true
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { shake = false }
                    }
                }
            }
        }
    }

    private func handleDelete() {
        if step == .create {
            if !pin.isEmpty { pin.removeLast() }
        } else if !confirmPin.isEmpty {
            confirmPin.removeLast()
        }
    }

    private func savePIN(_ pin: String) {
        let hash = SHA256.hash(data: Data(pin.utf8))
        let hashString = hash.compactMap { String(format: "%02x", $0) }.joined()
        KeychainManager.shared.save(key: PetStore.pinHashKey, value: hashString)
    }
}

struct PetPINEntryView: View {
    @Binding var isUnlocked: Bool
    @EnvironmentObject private var store: PetStore
    @State private var pin = ""
    @State private var errorMessage = ""
    @State private var shake = false
    @State private var attempts = 0
    @State private var showResetWarning = false
    @State private var showResetConfirm = false

    var body: some View {
        VStack(spacing: 32) {
            Spacer()
            VStack(spacing: 14) {
                ArcaPetAppIcon(size: 96)
                Text("Arca Pet")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
            }
            Text("PIN eingeben")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            HStack(spacing: 20) {
                ForEach(0..<4, id: \.self) { i in
                    Circle()
                        .fill(i < pin.count ? Color.accentColor : Color.secondary.opacity(0.3))
                        .frame(width: 18, height: 18)
                }
            }
            .offset(x: shake ? -10 : 0)
            .animation(shake ? .default.repeatCount(4, autoreverses: true).speed(6) : .default, value: shake)
            if !errorMessage.isEmpty {
                Text(errorMessage).font(.caption).foregroundStyle(.red)
            }
            PetPINPad(
                onDigit: { digit in
                    guard pin.count < 4 else { return }
                    pin += digit
                    if pin.count == 4 {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { checkPIN() }
                    }
                },
                onDelete: { if !pin.isEmpty { pin.removeLast() } }
            )
            Button { authenticateWithBiometrics() } label: {
                Label("Face ID / Touch ID", systemImage: "faceid")
                    .font(.subheadline)
                    .foregroundStyle(.accent)
            }
            Button { showResetWarning = true } label: {
                Text("PIN vergessen?")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .underline()
            }
            .padding(.top, -12)
            Spacer()
        }
        .padding()
        .onAppear { authenticateWithBiometrics() }
        .alert("PIN vergessen", isPresented: $showResetWarning) {
            Button("Weiter", role: .destructive) { showResetConfirm = true }
            Button("Abbrechen", role: .cancel) {}
        } message: {
            Text("Alle Tierdaten werden gelöscht. Das kann nicht rückgängig gemacht werden.")
        }
        .alert("Wirklich zurücksetzen?", isPresented: $showResetConfirm) {
            Button("Alle Daten löschen", role: .destructive) {
                store.resetAllData()
                isUnlocked = true
            }
            Button("Abbrechen", role: .cancel) {}
        } message: {
            Text("Alle gespeicherten Daten werden unwiderruflich gelöscht.")
        }
    }

    private func checkPIN() {
        let hash = SHA256.hash(data: Data(pin.utf8))
        let hashString = hash.compactMap { String(format: "%02x", $0) }.joined()
        let saved = KeychainManager.shared.load(key: PetStore.pinHashKey) ?? ""
        if hashString == saved {
            isUnlocked = true
        } else {
            attempts += 1
            pin = ""
            shake = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { shake = false }
            errorMessage = attempts >= 3 ? "Falsche PIN (\(attempts) Versuch)" : "Falsche PIN"
        }
    }

    private func authenticateWithBiometrics() {
        let context = LAContext()
        var error: NSError?
        guard context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) else { return }
        context.evaluatePolicy(.deviceOwnerAuthenticationWithBiometrics,
                               localizedReason: "Arca Pet entsperren") { success, _ in
            DispatchQueue.main.async {
                if success { isUnlocked = true }
            }
        }
    }
}

struct PetPINPad: View {
    let onDigit: (String) -> Void
    let onDelete: () -> Void

    private let digits = [
        ["1", "2", "3"],
        ["4", "5", "6"],
        ["7", "8", "9"],
        ["", "0", "⌫"]
    ]

    var body: some View {
        VStack(spacing: 16) {
            ForEach(digits, id: \.self) { row in
                HStack(spacing: 24) {
                    ForEach(row, id: \.self) { key in
                        if key.isEmpty {
                            Circle().fill(Color.clear).frame(width: 72, height: 72)
                        } else if key == "⌫" {
                            Button(action: onDelete) {
                                Image(systemName: "delete.left")
                                    .font(.title2)
                                    .frame(width: 72, height: 72)
                                    .background(Color.secondary.opacity(0.1))
                                    .clipShape(Circle())
                            }
                            .foregroundStyle(.primary)
                        } else {
                            Button { onDigit(key) } label: {
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
