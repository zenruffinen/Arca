//
//  ContentView.swift
//  Arca
//
//  ARCA 2.4.1
//  Entwickler: Hans zen Ruffinen
//  Ein lokaler Mini-Tresor für Passwörter, Dokumente und Notizen.
//  Erstellt mit SwiftUI.
//

import SwiftUI
import UniformTypeIdentifiers
import QuickLook
import QuickLookThumbnailing
import VisionKit
import Vision
import PhotosUI
import StoreKit

struct ContentView: View {
    @EnvironmentObject var store: AppStore
    var isUnlocked: Bool = true
    @State private var selectedSection: ArcaSection = .home
    @State private var screenHeight: CGFloat = 852   // vernünftiger Fallback, wird sofort überschrieben
    @State private var showRecoveryHint = false
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    // Reihenfolge der wischbaren Tabs
    private let swipeSections: [ArcaSection] = [.home, .settings]

    var body: some View {
        Group {
            if horizontalSizeClass == .regular {
                iPadLayout
            } else {
                iPhoneLayout
            }
        }
        .onChange(of: store.pendingSharedURL) { _, url in
            guard let url else { return }
            if store.isBackupCandidateURL(url) {
                store.pendingSharedURL = nil
                store.pendingBackupURL = url
                selectedSection = .settings
            } else {
                selectedSection = .documents
            }
        }
        .onChange(of: store.pendingBackupURL) { _, url in
            if url != nil { selectedSection = .settings }
        }
        .onChange(of: store.pendingSection) { _, section in
            guard let section else { return }
            if isUnlocked {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
                    selectedSection = section
                }
                store.pendingSection = nil
            }
            // Wenn gesperrt: pendingSection bleibt gesetzt und wird nach Entsperren verarbeitet
        }
        .onChange(of: isUnlocked) { _, unlocked in
            if unlocked, let section = store.pendingSection {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
                    selectedSection = section
                }
                store.pendingSection = nil
            }
            if unlocked, let url = store.pendingSharedURL, store.isBackupCandidateURL(url) {
                store.pendingSharedURL = nil
                store.pendingBackupURL = url
                selectedSection = .settings
            }
        }
        .onChange(of: selectedSection) { _, section in
            if section != .documents { store.pendingScrollCategory = nil }
        }
        .sheet(isPresented: $store.pendingQuickCapture, onDismiss: {
            store.quickCaptureAutoRecord = false
        }) {
            QuickCaptureSheet(autoRecord: store.quickCaptureAutoRecord) { title, text in
                store.addQuickIdea(title: title, text: text)
                UINotificationFeedbackGenerator().notificationOccurred(.success)
            }
            // Die schöne Idee-Karte: halbhoch, Glas, runde Ecken
            .presentationDetents([.medium, .large])
            .presentationCornerRadius(28)
            .presentationBackground(.ultraThinMaterial)
        }
        .sheet(isPresented: $store.zeigeNotfall) {
            NotfallView(karten: store.vaultItems.filter { !$0.sperrHotline.isEmpty })
        }
        // ── Tastaturkürzel (Mac & iPad mit Tastatur) ──
        // ⌘1–⌘6 Bereiche · ⌘N Neu (Blitzidee) · ⇧⌘N Diktat · ⌘F Suche
        .background {
            Group {
                Button("") { wechsleZu(.home) }.keyboardShortcut("1", modifiers: .command)
                Button("") { wechsleZu(.vault) }.keyboardShortcut("2", modifiers: .command)
                Button("") { wechsleZu(.documents) }.keyboardShortcut("3", modifiers: .command)
                Button("") { wechsleZu(.notes) }.keyboardShortcut("4", modifiers: .command)
                Button("") { wechsleZu(.lists) }.keyboardShortcut("5", modifiers: .command)
                Button("") { wechsleZu(.settings) }.keyboardShortcut("6", modifiers: .command)
                Button("") { store.pendingQuickCapture = true }
                    .keyboardShortcut("n", modifiers: .command)
                Button("") {
                    store.quickCaptureAutoRecord = true
                    store.pendingQuickCapture = true
                }
                .keyboardShortcut("n", modifiers: [.command, .shift])
                Button("") {
                    wechsleZu(.home)
                    store.sucheFokusSignal += 1
                }
                .keyboardShortcut("f", modifiers: .command)
            }
            .opacity(0)
            .frame(width: 0, height: 0)
            .accessibilityHidden(true)
        }
        .overlay(alignment: .top) {
            if store.isCloudSyncPending {
                CloudSyncBanner()
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .animation(.easeInOut(duration: 0.25), value: store.isCloudSyncPending)
        .onAppear { evaluateRecoveryHint(isFirstLaunch: true) }
        .onChange(of: store.isCloudSyncPending) { _, pending in
            if !pending { evaluateRecoveryHint() }
        }
        .alert("Daten fehlen?", isPresented: $showRecoveryHint) {
            Button("Verstanden") { store.markRecoveryHintShown() }
        } message: {
            Text("Falls Daten fehlen, versuche: (1) ein anderes Gerät, das noch nicht aktualisiert wurde, (2) Wiederherstellung aus einem Backup über Einstellungen → Daten wiederherstellen.")
        }
    }

    private func wechsleZu(_ ziel: ArcaSection) {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
            selectedSection = ziel
        }
    }

    private func evaluateRecoveryHint(isFirstLaunch: Bool = false) {
        guard store.shouldShowRecoveryHint else { return }
        if isFirstLaunch || store.isLikelyEmptyWithPendingCloud {
            showRecoveryHint = true
        }
    }

    // MARK: - iPhone Layout (unverändert)

    /// Welche externen Inhalte das Fenster annimmt: Mails und Dateien.
    /// (Interne Zieh-Aktionen nutzen Text-Payloads und bleiben unberührt.)
    private var externeAblageTypen: [UTType] { AppStore.externeAblageTypen }

    /// Mail oder Datei entgegennehmen, in den Bestand kopieren und
    /// als Dokument in „Unsortiert" anlegen — Mails als Mail markiert.
    private func importiereExterneAblage(_ anbieter: [NSItemProvider]) -> Bool {
        var genommen = false
        for provider in anbieter {
            let mailTyp = provider.registeredTypeIdentifiers.first {
                $0 == "com.apple.mail.email" || UTType($0)?.conforms(to: .emailMessage) == true
            }
            if let mailTyp {
                genommen = true
                provider.loadFileRepresentation(forTypeIdentifier: mailTyp) { url, _ in
                    guard let url else { return }
                    uebernehmeExterneDatei(von: url, alsMail: true)
                }
            } else if provider.canLoadObject(ofClass: URL.self) {
                genommen = true
                _ = provider.loadObject(ofClass: URL.self) { url, _ in
                    guard let url, url.isFileURL else { return }
                    let hatZugriff = url.startAccessingSecurityScopedResource()
                    uebernehmeExterneDatei(von: url, alsMail: false)
                    if hatZugriff { url.stopAccessingSecurityScopedResource() }
                }
            }
        }
        return genommen
    }

    private func uebernehmeExterneDatei(von url: URL, alsMail: Bool) {
        store.uebernimmExterneDatei(von: url, alsMail: alsMail)
    }

    private var iPhoneLayout: some View {
        ZStack(alignment: .bottom) {
            Group {
                switch selectedSection {
                case .home:      HomeView(selectedSection: $selectedSection)
                case .spaceHub:  SpaceHubView(selectedSection: $selectedSection)
                case .vault:     VaultView()
                case .documents: DocumentsView(isUnlocked: isUnlocked)
                case .notes:     NotesView()
                case .lists:     ListsView()
                case .settings:  SettingsView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            // Überall dieselbe warme Bühne wie auf dem Start —
            // kein Farbsprung beim Umschalten
            .background(ArcaWarm.hintergrund.ignoresSafeArea())
            .safeAreaInset(edge: .bottom) { Color.clear.frame(height: 104) }

            ArcaTabBar(selected: $selectedSection)
        }
        .ignoresSafeArea(edges: .bottom)
        .background(
            GeometryReader { geo in
                Color.clear.onAppear { screenHeight = geo.size.height }
                    .onChange(of: geo.size.height) { _, newHeight in screenHeight = newHeight }
            }
        )
        .gesture(
            DragGesture(minimumDistance: 20, coordinateSpace: .global)
                .onEnded { value in
                    // Nur reagieren wenn Wisch auf der Tab-Leiste selbst startete —
                    // sonst frisst die Geste das Wischen auf den untersten Listenzeilen
                    guard value.startLocation.y > screenHeight - 90 else { return }
                    // Klar horizontale Bewegung
                    guard abs(value.translation.width) > abs(value.translation.height) * 1.2 else { return }
                    guard let idx = swipeSections.firstIndex(of: selectedSection) else { return }
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
                        if value.translation.width < -20 {
                            selectedSection = swipeSections[min(idx + 1, swipeSections.count - 1)]
                        } else if value.translation.width > 20 {
                            selectedSection = swipeSections[max(idx - 1, 0)]
                        }
                    }
                }
        )
    }

    // MARK: - iPad Layout

    /// Die Seitenleiste startet eingeklappt — mehr Platz für den
    /// Arca Desktop; der Knopf oben links holt sie jederzeit zurück.
    @State private var spaltenSichtbarkeit: NavigationSplitViewVisibility = .detailOnly

    private var iPadLayout: some View {
        NavigationSplitView(columnVisibility: $spaltenSichtbarkeit) {
            ArcaIPadSidebar(selectedSection: $selectedSection)
                .navigationSplitViewColumnWidth(min: 200, ideal: 260, max: 310)
        } detail: {
            // Der Schreibtisch bleibt in JEDEM Bereich rechts stehen —
            // die App arbeitet links, das Pult liegt daneben.
            GeometryReader { geo in
                // Die App-Spalte endet an der Passwörter-Blase —
                // der Löwenanteil gehört dem Schreibtisch
                let inhaltsBreite: CGFloat = 410
                let zonenBreite = (geo.size.width - inhaltsBreite - 24) / 2
                let zeigtDesk = zonenBreite >= 165
                HStack(alignment: .top, spacing: 8) {
                    Group {
                        switch selectedSection {
                        case .home:      HomeView(selectedSection: $selectedSection)
                        case .spaceHub:  SpaceHubView(selectedSection: $selectedSection)
                        case .vault:     VaultView()
                        case .documents: DocumentsView(isUnlocked: isUnlocked)
                        case .notes:     NotesView()
                        case .lists:     ListsView()
                        case .settings:  SettingsView()
                        }
                    }
                    .frame(maxWidth: .infinity)
                    if zeigtDesk {
                        ArcaDeskRail(seite: "links",
                                     selectedSection: $selectedSection,
                                     breite: zonenBreite)
                        ArcaDeskRail(seite: "rechts",
                                     selectedSection: $selectedSection,
                                     breite: zonenBreite)
                            .padding(.trailing, 8)
                    }
                }
                // Überall dieselbe warme Bühne wie auf dem Start —
                // kein Farbsprung beim Umschalten
                .background(ArcaWarm.hintergrund.ignoresSafeArea())
                // Von außen hineingezogen (Mail, Finder-Datei) →
                // landet als Dokument in „Unsortiert"
                .onDrop(of: externeAblageTypen, isTargeted: nil) { anbieter in
                    importiereExterneAblage(anbieter)
                }
            }
        }
        .navigationSplitViewStyle(.balanced)
        // Der Plus fehlt sonst auf iPad und Mac — hier schwebt er unten rechts
        .overlay(alignment: .bottomTrailing) {
            ArcaPlusKnopf(selected: $selectedSection)
                .padding(.trailing, 28)
                .padding(.bottom, 24)
        }
    }
}



#Preview {
    ContentView()
        .environmentObject(AppStore())
}
