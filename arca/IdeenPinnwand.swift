//
//  IdeenPinnwand.swift
//  Arca
//
//  Die Ideen-Pinnwand: alle Ideen als gelbe Zettel auf einer Kork-Wand —
//  frei anordnen wie ein Brainstorm-Board, „das zu dem" gruppieren, und
//  was weg soll, in den Eimer knüllen. Rechts angedockt; der Space bleibt
//  links sichtbar.
//
//  Entwickler: Hans zen Ruffinen
//

import SwiftUI

struct IdeenPinnwand: View {
    @EnvironmentObject var store: AppStore
    @State private var bearbeite: NoteEntry? = nil
    @State private var zugID: UUID? = nil
    @State private var zugOffset: CGSize = .zero
    @State private var ueberEimer = false
    @State private var zerknuellt: UUID? = nil

    private let zettelBreite: CGFloat = 150

    private var ideen: [NoteEntry] { store.notes }

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .topLeading) {
                KorkWand()

                // Die Zettel
                ForEach(Array(ideen.enumerated()), id: \.element.id) { idx, note in
                    ZettelKarte(note: note, breite: zettelBreite)
                        .scaleEffect(zerknuellt == note.id ? 0.05 : 1)
                        .opacity(zerknuellt == note.id ? 0 : 1)
                        .rotationEffect(.degrees(zerknuellt == note.id ? 180 : neigung(note)))
                        .position(position(note, idx: idx, in: geo.size))
                        .offset(note.id == zugID ? zugOffset : .zero)
                        .zIndex(note.id == zugID ? 100 : 0)
                        .shadow(color: .black.opacity(note.id == zugID ? 0.25 : 0.12),
                                radius: note.id == zugID ? 12 : 4, x: 0, y: note.id == zugID ? 8 : 2)
                        .gesture(
                            DragGesture()
                                .onChanged { wert in
                                    zugID = note.id
                                    zugOffset = wert.translation
                                    let start = position(note, idx: idx, in: geo.size)
                                    let jetzt = CGPoint(x: start.x + wert.translation.width,
                                                        y: start.y + wert.translation.height)
                                    ueberEimer = eimerRahmen(geo.size).contains(jetzt)
                                }
                                .onEnded { wert in
                                    let start = position(note, idx: idx, in: geo.size)
                                    let ziel = CGPoint(x: start.x + wert.translation.width,
                                                       y: start.y + wert.translation.height)
                                    if eimerRahmen(geo.size).contains(ziel) {
                                        knuelleInEimer(note)
                                    } else {
                                        merkePosition(note, ziel, in: geo.size)
                                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                    }
                                    zugID = nil
                                    zugOffset = .zero
                                    ueberEimer = false
                                }
                        )
                        .onTapGesture { bearbeite = note }
                }

                // Der Papierkorb — hier knüllt man Ideen hinein
                eimer(in: geo.size)

                // Leerzustand
                if ideen.isEmpty {
                    VStack(spacing: 10) {
                        Image(systemName: "lightbulb")
                            .font(.system(size: 40, weight: .semibold))
                            .foregroundStyle(ArcaWarm.ideenGelb)
                        Text("Noch keine Ideen an der Wand.\nTipp auf + und lass es dir einfallen.")
                            .font(.system(size: 14))
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }

                // Kopfzeile: Titel · + Idee · Schließen
                kopf
            }
        }
        .sheet(item: $bearbeite) { note in
            NoteDetailView(note: note)
                .environmentObject(store)
                .presentationDetents([.medium, .large])
                .presentationCornerRadius(28)
                .presentationBackground(.ultraThinMaterial)
        }
    }

    // MARK: Kopf & Eimer

    private var kopf: some View {
        HStack(spacing: 10) {
            Image(systemName: "pin.fill")
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(ArcaWarm.terrakotta)
            Text("IDEEN-PINNWAND")
                .font(.system(size: 13, weight: .bold))
                .tracking(0.8)
                .foregroundStyle(Color(red: 0.35, green: 0.28, blue: 0.05))
            Spacer()
            Button {
                store.quickCaptureAutoRecord = false
                store.pendingQuickCapture = true
            } label: {
                Image(systemName: "plus")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 34, height: 34)
                    .background(ArcaWarm.terrakotta, in: Circle())
            }
            .buttonStyle(.plain)
            Button {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                    store.zeigeIdeenPinnwand = false
                }
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(Color(red: 0.35, green: 0.28, blue: 0.05))
                    .frame(width: 34, height: 34)
                    .background(.ultraThinMaterial, in: Circle())
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
        .padding(.top, 14)
    }

    private func eimer(in size: CGSize) -> some View {
        let r = eimerRahmen(size)
        return ZStack {
            Circle()
                .fill(ueberEimer ? Color.red.opacity(0.18) : Color.black.opacity(0.06))
                .overlay(Circle().strokeBorder(
                    ueberEimer ? Color.red : Color(red: 0.5, green: 0.4, blue: 0.15).opacity(0.4),
                    style: StrokeStyle(lineWidth: 1.6, dash: ueberEimer ? [] : [5, 4])))
            Image(systemName: ueberEimer ? "trash.fill" : "trash")
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(ueberEimer ? .red : Color(red: 0.5, green: 0.4, blue: 0.15))
        }
        .frame(width: r.width, height: r.height)
        .scaleEffect(ueberEimer ? 1.2 : 1)
        .animation(.spring(response: 0.25, dampingFraction: 0.7), value: ueberEimer)
        .position(x: r.midX, y: r.midY)
    }

    private func eimerRahmen(_ size: CGSize) -> CGRect {
        CGRect(x: size.width - 78, y: size.height - 78, width: 58, height: 58)
    }

    // MARK: Positionen

    private func neigung(_ note: NoteEntry) -> Double {
        let s = note.id.uuidString.unicodeScalars.reduce(0) { $0 + Int($1.value) }
        return Double(s % 7 - 3) * 1.4
    }

    private func position(_ note: NoteEntry, idx: Int, in size: CGSize) -> CGPoint {
        if let p = store.pinnwandLayout[note.id.uuidString], p.count == 2 {
            return begrenze(CGPoint(x: p[0], y: p[1]), in: size)
        }
        // Automatische Streuung, bis man sie verschiebt
        let spalten = max(1, Int((size.width - 40) / (zettelBreite + 24)))
        let col = idx % spalten, row = idx / spalten
        let s = note.id.uuidString.unicodeScalars.reduce(0) { $0 + Int($1.value) }
        let jx = CGFloat(s % 21 - 10), jy = CGFloat((s / 3) % 21 - 10)
        return begrenze(CGPoint(x: 100 + CGFloat(col) * (zettelBreite + 24) + jx,
                                y: 150 + CGFloat(row) * 150 + jy), in: size)
    }

    private func begrenze(_ p: CGPoint, in size: CGSize) -> CGPoint {
        CGPoint(x: min(max(p.x, zettelBreite / 2 + 8), size.width - zettelBreite / 2 - 8),
                y: min(max(p.y, 70), size.height - 60))
    }

    private func merkePosition(_ note: NoteEntry, _ p: CGPoint, in size: CGSize) {
        let g = begrenze(p, in: size)
        store.pinnwandLayout[note.id.uuidString] = [Double(g.x), Double(g.y)]
    }

    private func knuelleInEimer(_ note: NoteEntry) {
        UINotificationFeedbackGenerator().notificationOccurred(.warning)
        withAnimation(.easeIn(duration: 0.35)) { zerknuellt = note.id }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.36) {
            store.notes.removeAll { $0.id == note.id }
            store.pinnwandLayout.removeValue(forKey: note.id.uuidString)
            zerknuellt = nil
        }
    }
}

/// Der Kork-/Papier-Hintergrund in warmem Gelb.
private struct KorkWand: View {
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color(red: 0.99, green: 0.93, blue: 0.66),
                         Color(red: 0.96, green: 0.86, blue: 0.52)],
                startPoint: .topLeading, endPoint: .bottomTrailing)
            // Feine Tupfer für Kork-Anmutung
            GeometryReader { geo in
                let s: CGFloat = 26
                let cols = Int(geo.size.width / s) + 1
                let rows = Int(geo.size.height / s) + 1
                ForEach(0..<(cols * rows), id: \.self) { i in
                    let c = i % cols, r = i / cols
                    Circle()
                        .fill(Color(red: 0.6, green: 0.45, blue: 0.15)
                            .opacity((c + r).isMultiple(of: 2) ? 0.05 : 0.03))
                        .frame(width: 3, height: 3)
                        .position(x: CGFloat(c) * s + 6, y: CGFloat(r) * s + 6)
                }
            }
        }
        .ignoresSafeArea()
    }
}

/// Ein einzelner Ideen-Zettel mit Reißzwecke.
private struct ZettelKarte: View {
    let note: NoteEntry
    let breite: CGFloat

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            if !note.title.isEmpty {
                Text(note.title)
                    .font(.system(size: 12.5, weight: .bold))
                    .lineLimit(2)
            }
            Text(note.text.isEmpty ? "…" : note.text)
                .font(.system(size: 11))
                .foregroundStyle(.black.opacity(0.7))
                .lineLimit(5)
        }
        .frame(width: breite, alignment: .topLeading)
        .frame(minHeight: 96, alignment: .topLeading)
        .padding(11)
        .padding(.top, 4)
        .background(NoteColor.for_(note.colorTag).bg)
        .overlay(alignment: .top) {
            // Reißzwecke
            Circle()
                .fill(RadialGradient(colors: [.white.opacity(0.9), Color.red, Color(red: 0.6, green: 0, blue: 0)],
                                     center: .init(x: 0.35, y: 0.3), startRadius: 0, endRadius: 8))
                .frame(width: 13, height: 13)
                .shadow(color: .black.opacity(0.3), radius: 1.5, x: 0, y: 1.5)
                .offset(y: -5)
        }
        .clipShape(RoundedRectangle(cornerRadius: 4))
        .overlay(RoundedRectangle(cornerRadius: 4).strokeBorder(.black.opacity(0.08), lineWidth: 0.7))
        .contentShape(RoundedRectangle(cornerRadius: 4))
    }
}
