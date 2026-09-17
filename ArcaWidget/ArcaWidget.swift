//
//  ArcaWidget.swift
//  Arca
//
//  Zwei Widgets:
//  – „Arca": was in der Sammlung liegt, mit Sprungmarken in die Bereiche.
//  – „Notfallkoffer": ein Tipp oeffnet den roten Koffer. Auch fuer den
//    Sperrbildschirm des iPhones.
//
//  Widgets zeigen nur Anzahlen, nie Namen oder Inhalte: ein Widget sieht
//  jeder, der auf den Bildschirm schaut.
//
//  Entwickler: Hans zen Ruffinen
//

import WidgetKit
import SwiftUI

// MARK: - Farben (wie in der App: warmes Papier, Arca-Blau, Notfall-Rot)

private enum WidgetFarbe {
    static let papier = Color(UIColor { t in
        t.userInterfaceStyle == .dark
            ? UIColor(red: 0.11, green: 0.10, blue: 0.095, alpha: 1)
            : UIColor(red: 0.98, green: 0.965, blue: 0.94, alpha: 1)
    })
    static let rot = Color(red: 0.92, green: 0.28, blue: 0.24)
}

// MARK: - Daten

struct ArcaWidgetData {
    let noteCount: Int
    let listCount: Int
    let docCount: Int
    let vaultCount: Int
    let notfallWichtig: Int
    let notfallMedikamente: Int
    let notfallKontakte: Int

    static func load() -> ArcaWidgetData {
        let d = UserDefaults(suiteName: "group.com.hansruffin.arca")
        return ArcaWidgetData(
            noteCount:          d?.integer(forKey: "widget_noteCount")          ?? 0,
            listCount:          d?.integer(forKey: "widget_listCount")          ?? 0,
            docCount:           d?.integer(forKey: "widget_docCount")           ?? 0,
            vaultCount:         d?.integer(forKey: "widget_vaultCount")         ?? 0,
            notfallWichtig:     d?.integer(forKey: "widget_notfallWichtig")     ?? 0,
            notfallMedikamente: d?.integer(forKey: "widget_notfallMedikamente") ?? 0,
            notfallKontakte:    d?.integer(forKey: "widget_notfallKontakte")    ?? 0
        )
    }

    static let beispiel = ArcaWidgetData(noteCount: 12, listCount: 3, docCount: 48, vaultCount: 9,
                                         notfallWichtig: 1, notfallMedikamente: 4, notfallKontakte: 2)
}

// MARK: - Timeline

struct ArcaEntry: TimelineEntry {
    let date: Date
    let data: ArcaWidgetData
}

struct ArcaProvider: TimelineProvider {
    func placeholder(in context: Context) -> ArcaEntry {
        ArcaEntry(date: .now, data: .beispiel)
    }

    func getSnapshot(in context: Context, completion: @escaping (ArcaEntry) -> Void) {
        completion(ArcaEntry(date: .now, data: context.isPreview ? .beispiel : .load()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<ArcaEntry>) -> Void) {
        // Die App meldet jede Aenderung selbst (reloadAllTimelines) —
        // der Takt hier ist nur das Sicherheitsnetz.
        let entry = ArcaEntry(date: .now, data: .load())
        let next = Calendar.current.date(byAdding: .hour, value: 1, to: .now)!
        completion(Timeline(entries: [entry], policy: .after(next)))
    }
}

// MARK: - Arca-Widget

private struct Bereich: Identifiable {
    let id: String
    let name: String
    let symbol: String
    let farbe: Color
    let anzahl: Int
    var url: URL { URL(string: "arca://\(id)")! }
}

private func bereiche(_ d: ArcaWidgetData) -> [Bereich] {
    [Bereich(id: "documents", name: "Dokumente", symbol: "doc.fill",   farbe: .blue,   anzahl: d.docCount),
     Bereich(id: "notes",     name: "Notizen",   symbol: "note.text",  farbe: .orange, anzahl: d.noteCount),
     Bereich(id: "tasks",     name: "Aufgaben",  symbol: "checklist",  farbe: .green,  anzahl: d.listCount),
     Bereich(id: "vault",     name: "Tresor",    symbol: "lock.fill",  farbe: .indigo, anzahl: d.vaultCount)]
}

private struct ArcaKopf: View {
    var body: some View {
        HStack(spacing: 5) {
            Image(systemName: "archivebox.fill")
                .foregroundStyle(.blue)
            Text("Arca")
                .font(.system(size: 15, weight: .bold, design: .rounded))
        }
    }
}

struct ArcaSmallView: View {
    let data: ArcaWidgetData

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ArcaKopf()
            Spacer(minLength: 6)
            VStack(alignment: .leading, spacing: 5) {
                ForEach(bereiche(data)) { b in
                    HStack(spacing: 6) {
                        Image(systemName: b.symbol)
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(b.farbe)
                            .frame(width: 16)
                        Text(b.name)
                            .foregroundStyle(.secondary)
                        Spacer(minLength: 4)
                        Text("\(b.anzahl)")
                            .fontWeight(.semibold)
                            .monospacedDigit()
                    }
                    .font(.system(size: 12))
                }
            }
        }
        .containerBackground(WidgetFarbe.papier, for: .widget)
    }
}

struct ArcaMediumView: View {
    let data: ArcaWidgetData

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                ArcaKopf()
                Spacer()
                // Blitzidee: diktieren, ohne erst einen Bereich zu waehlen
                Link(destination: URL(string: "arca://blitzidee")!) {
                    Label("Blitzidee", systemImage: "bolt.fill")
                        .font(.system(size: 11, weight: .semibold))
                        .padding(.horizontal, 9)
                        .padding(.vertical, 4)
                        .background(Color.orange.opacity(0.15), in: Capsule())
                        .foregroundStyle(.orange)
                }
            }
            Spacer(minLength: 0)
            HStack(spacing: 6) {
                ForEach(bereiche(data)) { b in
                    Link(destination: b.url) {
                        VStack(alignment: .leading, spacing: 3) {
                            Image(systemName: b.symbol)
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(b.farbe)
                            Spacer(minLength: 0)
                            Text("\(b.anzahl)")
                                .font(.system(size: 18, weight: .bold, design: .rounded))
                                .monospacedDigit()
                                .foregroundStyle(.primary)
                            Text(b.name)
                                .font(.system(size: 10, weight: .medium))
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                                .minimumScaleFactor(0.8)
                        }
                        .padding(8)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
                        .background(b.farbe.opacity(0.10), in: RoundedRectangle(cornerRadius: 12))
                    }
                }
            }
        }
        .containerBackground(WidgetFarbe.papier, for: .widget)
    }
}

struct ArcaWidgetEntryView: View {
    @Environment(\.widgetFamily) var family
    let entry: ArcaEntry

    var body: some View {
        switch family {
        case .systemMedium: ArcaMediumView(data: entry.data)
        default:            ArcaSmallView(data: entry.data)
        }
    }
}

struct ArcaWidget: Widget {
    let kind = "ArcaWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: ArcaProvider()) { entry in
            ArcaWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("Arca")
        .description("Dokumente, Notizen, Aufgaben und Tresor auf einen Blick.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

// MARK: - Notfallkoffer-Widget

/// „1 wichtiger Hinweis · 4 Medikamente · 2 Kontakte" — ohne Namen.
private func kofferInhalt(_ d: ArcaWidgetData) -> [String] {
    var zeilen: [String] = []
    if d.notfallWichtig > 0 {
        zeilen.append(d.notfallWichtig == 1 ? "1 wichtiger Hinweis" : "\(d.notfallWichtig) wichtige Hinweise")
    }
    if d.notfallMedikamente > 0 {
        zeilen.append(d.notfallMedikamente == 1 ? "1 Medikament" : "\(d.notfallMedikamente) Medikamente")
    }
    if d.notfallKontakte > 0 {
        zeilen.append(d.notfallKontakte == 1 ? "1 Notfallkontakt" : "\(d.notfallKontakte) Notfallkontakte")
    }
    return zeilen
}

struct NotfallKofferView: View {
    @Environment(\.widgetFamily) var family
    let data: ArcaWidgetData

    var body: some View {
        switch family {
        case .accessoryCircular:
            ZStack {
                AccessoryWidgetBackground()
                Image(systemName: "cross.case.fill")
                    .font(.system(size: 22, weight: .semibold))
            }
            .widgetAccentable()
            .containerBackground(.clear, for: .widget)

        case .accessoryRectangular:
            HStack(spacing: 8) {
                Image(systemName: "cross.case.fill")
                    .font(.system(size: 22, weight: .semibold))
                    .widgetAccentable()
                VStack(alignment: .leading, spacing: 0) {
                    Text("Notfallkoffer")
                        .font(.system(size: 14, weight: .bold))
                    Text("Notruf · Medikamente")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .containerBackground(.clear, for: .widget)

        default:
            VStack(alignment: .leading, spacing: 0) {
                Image(systemName: "cross.case.fill")
                    .font(.system(size: 26, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 48, height: 48)
                    .background(WidgetFarbe.rot, in: RoundedRectangle(cornerRadius: 13))
                Spacer(minLength: 6)
                Text("Notfallkoffer")
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundStyle(.primary)
                let inhalt = kofferInhalt(data)
                if inhalt.isEmpty {
                    Text("Notrufnummern · Medikamente eintragen")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                } else {
                    ForEach(inhalt, id: \.self) { zeile in
                        Text(zeile)
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.85)
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
            .containerBackground(WidgetFarbe.papier, for: .widget)
        }
    }
}

struct NotfallKofferWidget: Widget {
    let kind = "ArcaNotfallWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: ArcaProvider()) { entry in
            NotfallKofferView(data: entry.data)
                .widgetURL(URL(string: "arca://notfall")!)
        }
        .configurationDisplayName("Notfallkoffer")
        .description("Ein Tipp öffnet deinen Notfallkoffer: Notruf, Medikamente, Kontakte.")
        .supportedFamilies([.systemSmall, .accessoryCircular, .accessoryRectangular])
    }
}

@main
struct ArcaWidgetBundle: WidgetBundle {
    var body: some Widget {
        ArcaWidget()
        NotfallKofferWidget()
    }
}
