//
//  ArcaWidget.swift
//  Arca
//
//  Entwickler: Hans zen Ruffinen
//

import WidgetKit
import SwiftUI

// MARK: - Data

struct ArcaWidgetData {
    let noteCount: Int
    let listCount: Int
    let docCount: Int
    let vaultCount: Int

    static func load() -> ArcaWidgetData {
        let d = UserDefaults(suiteName: "group.com.hansruffin.arca")
        return ArcaWidgetData(
            noteCount:  d?.integer(forKey: "widget_noteCount")  ?? 0,
            listCount:  d?.integer(forKey: "widget_listCount")  ?? 0,
            docCount:   d?.integer(forKey: "widget_docCount")   ?? 0,
            vaultCount: d?.integer(forKey: "widget_vaultCount") ?? 0
        )
    }
}

// MARK: - Timeline

struct ArcaEntry: TimelineEntry {
    let date: Date
    let data: ArcaWidgetData
}

struct ArcaProvider: TimelineProvider {
    func placeholder(in context: Context) -> ArcaEntry {
        ArcaEntry(date: .now, data: ArcaWidgetData(noteCount: 5, listCount: 3, docCount: 8, vaultCount: 12))
    }

    func getSnapshot(in context: Context, completion: @escaping (ArcaEntry) -> Void) {
        completion(ArcaEntry(date: .now, data: .load()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<ArcaEntry>) -> Void) {
        let entry = ArcaEntry(date: .now, data: .load())
        let next = Calendar.current.date(byAdding: .minute, value: 30, to: .now)!
        completion(Timeline(entries: [entry], policy: .after(next)))
    }
}

// MARK: - Views

struct ArcaSmallView: View {
    let data: ArcaWidgetData

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 6) {
                Image(systemName: "archivebox.fill")
                    .foregroundStyle(.blue)
                Text("Arca")
                    .font(.headline).bold()
            }
            Spacer(minLength: 8)
            VStack(alignment: .leading, spacing: 6) {
                statRow(icon: "note.text",  label: "Notizen",    count: data.noteCount)
                statRow(icon: "checklist",  label: "Tasks",      count: data.listCount)
                statRow(icon: "doc.fill",   label: "Dokumente",  count: data.docCount)
                statRow(icon: "lock.fill",  label: "Passwörter", count: data.vaultCount)
            }
        }
        .padding()
        .containerBackground(.fill.tertiary, for: .widget)
    }

    private func statRow(icon: String, label: String, count: Int) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .foregroundStyle(.secondary)
                .frame(width: 16)
            Text("\(count)")
                .fontWeight(.semibold)
            Text(label)
                .foregroundStyle(.secondary)
        }
        .font(.caption)
    }
}

struct ArcaMediumView: View {
    let data: ArcaWidgetData

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: 5) {
                    Image(systemName: "archivebox.fill")
                        .foregroundStyle(.blue)
                    Text("Arca")
                        .font(.headline).bold()
                }
                Spacer(minLength: 6)
                VStack(alignment: .leading, spacing: 4) {
                    mediumRow(icon: "note.text", label: "Notizen",    count: data.noteCount)
                    mediumRow(icon: "checklist", label: "Tasks",      count: data.listCount)
                    mediumRow(icon: "doc.fill",  label: "Dokumente",  count: data.docCount)
                    mediumRow(icon: "lock.fill", label: "Passwörter", count: data.vaultCount)
                }
            }
            Divider()
            VStack(spacing: 5) {
                HStack(spacing: 5) {
                    actionLink("Notizen",    icon: "note.text", url: "arca://notes",      color: .purple)
                    actionLink("Tasks",      icon: "checklist", url: "arca://tasks",      color: .green)
                }
                HStack(spacing: 5) {
                    actionLink("Dokumente",  icon: "doc.fill",  url: "arca://documents",  color: .orange)
                    actionLink("Passwörter", icon: "lock.fill", url: "arca://vault",      color: .blue)
                }
                actionLink("⚡ Blitzidee", icon: "bolt.fill",  url: "arca://blitzidee",  color: Color(red: 1.00, green: 0.45, blue: 0.10), fullWidth: true)
            }
        }
        .padding()
        .containerBackground(.fill.tertiary, for: .widget)
    }

    private func mediumRow(icon: String, label: String, count: Int) -> some View {
        HStack(spacing: 5) {
            Image(systemName: icon)
                .foregroundStyle(.secondary)
                .frame(width: 14)
            Text("\(count)")
                .fontWeight(.semibold)
            Text(label)
                .foregroundStyle(.secondary)
        }
        .font(.caption)
    }

    private func actionLink(_ label: String, icon: String, url: String, color: Color, fullWidth: Bool = false) -> some View {
        Link(destination: URL(string: url)!) {
            Label(label, systemImage: icon)
                .font(.caption2.weight(.semibold))
                .frame(maxWidth: fullWidth ? .infinity : nil)
                .padding(.vertical, 6)
                .padding(.horizontal, fullWidth ? 0 : 6)
                .frame(maxWidth: .infinity)
                .background(color.opacity(0.75))
                .foregroundStyle(.white)
                .clipShape(RoundedRectangle(cornerRadius: 8))
        }
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

// MARK: - Widget Definition

struct ArcaWidget: Widget {
    let kind = "ArcaWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: ArcaProvider()) { entry in
            ArcaWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("Arca Übersicht")
        .description("Zeigt Notizen, Tasks, Dokumente und Passwörter auf einen Blick.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

@main
struct ArcaWidgetBundle: WidgetBundle {
    var body: some Widget {
        ArcaWidget()
    }
}
