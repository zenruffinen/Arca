//
//  LegalCopy.swift
//  ArcaTickets
//
//  Zentrale rechtliche Hinweise (Schweiz) — sachlich, verständlich, nicht juristisch.
//  Entwickler: Hans zen Ruffinen
//

import SwiftUI

// MARK: - Copy

enum LegalCopy {

  // MARK: Notfall & Telefon

  static let emergencyDisclaimer =
    "Arca Tickets isch kein Notrufdienst und ersetzt kei medizinisch oder rechtlich Beratig. "
    + "D'Nummerä gälte für d'Schwiiz (Polizei 117, Feuerwehr 118, Rettung 144, EU-Notruf 112). "
    + "Prüef eigni Kontakt und Nummerä im Usland. Ein Tap öffnet d'Telefon-App — du startisch de Aaruf sälber."

  static let contactsCallFooter =
    "Nummerä trägsch du sälber ii oder nutzsch Schwiizer Standardwärt. Arca Tickets haftet nöd für falschi oder veralteti Agabe."

  // MARK: Visitenkarte

  static let personalIDEditorFooter =
    "Name, Pass- und AHV-Nummer werded in dinere iCloud gspeicheret und durch d'App-Sperre gschützt. "
    + "D'Visitenkarte isch kein amtliche Usweis — im Ernstfall immer Originaldokument mitfüehre."

  static let personalIDBloodTypeNote =
    "Blutgruppe und Gsundheitsagabe sind freiwillig und ohni Gwähr — nur als Merkhilf, nöd als medizinisch Empfehlig."

  // MARK: Datenschutz & iCloud

  static let privacySummary =
    "Arca Tickets isch werbefrei und ohni Tracking. Ticket, Kontakt und Visitenkartedate bliibed uf dim Gerät "
    + "und in dim iCloud-Konto (iCloud Drive). De Entwickler het kei Zuegriff uf dini Inhalt."

  static let iCloudAvailableFooter =
    "Synchronisation über iCloud Drive in dim Apple-Konto. Apple verarbeitet d'Date gemäss sine Datenschutzbestimmige. "
    + "Bi „Warte uf Download“ werded Inhalt no us dr Cloud glade."

  static let iCloudUnavailableFooter =
    "iCloud isch nöd verfügbar. Date werded nur lokal uf dem Gerät gspeicheret — ohni Cloud-Backup riskiersch du Dateverlust bi eme Gerätewechsel."

  // MARK: Backup

  static let backupFooter =
    "S'Backup wird mit dim Passwort verschlüsselt (.arcaticketsbackup). Ohni Passwort kei Wiederherstellung — "
    + "bewahr es sicher uf. Date in iCloud Drive, Mail oder lokal chönd vo Dritte gläse werde, wenn sie s'Passwort kenned."

  static let backupPasswordHint =
    "Wähl es starkes Passwort. De Entwickler cha verlorene Backup nöd entschlüssle."

  // MARK: Familie teilen

  static let familyShareWarning =
    "Geteilti Ordner sind nöd verschlüsslet und chönd Ticket, Foto und persönlich Reisedate enthalte. "
    + "Teil nur mit vertrauenswürdige Persone, wo die Date dörfed übercho."

  static let familyShareConsent =
    "Ich bestätige, dass ich berechtigt bin, die Reisedate z'teile, und weiss, dass d'Datei unverschlüsslet isch."

  static let familyImportFooter =
    "Importierti Ordner erschined als „… (geteilt)“. Es git kei Live-Sync — neui Ticket müend neu exportiert werde."

  // MARK: Versicherung

  static let insuranceDisclaimer =
    "Versicherigsnummer diened nur als Merkhilf. Arca Tickets isch kein Versicherer und erteilt kei Deckungs- oder Rechtsauskünft — "
    + "wend dich im Schadefall direkt a dini Versicherig."

  // MARK: Sicherheit

  static let appLockFooter =
    "PIN und Face ID schütze de App-Zuegriff. Sie ersetzed kei Gerätesperre — schütz dis iPhone zusätzlich."

  // MARK: Volltext (Istellige)

  static let privacyDetailSections: [(title: String, body: String)] = [
    (
      "Was d'App speicheret",
      "Ticket (Foto, PDF), Ordner, Erinnerige, wichtigi Nummerä, Visitenkartedate, Istellige und optional Reisenotize — "
        + "alles in dinere Kontrolle."
    ),
    (
      "Wo d'Date liged",
      "Lokal uf em Gerät, optional synchronisiert über iCloud Drive im Container iCloud.com.hansruffin.ArcaTickets. "
        + "D'App-Sperre-PIN ligt im iOS-Schlüsselbund."
    ),
    (
      "Was mir nöd mache",
      "Kei Werbig, kei Verkauf vo Date, kei Tracking durch de Entwickler. Kei eigene Server mit dine Ticketinhalt."
    ),
    (
      "Notfall & Haftung",
      emergencyDisclaimer
    ),
    (
      "Teile & Backup",
      familyShareWarning + " " + backupFooter
    ),
    (
      "Kontakt",
      "Frage zum Datenschutz: Hans zen Ruffinen, Entwickler vo Arca Tickets (Schwiiz)."
    ),
  ]
}

// MARK: - Views

struct LegalFootnote: View {
  let text: String
  var icon: String = "info.circle"

  var body: some View {
  Label {
    Text(text)
      .font(.caption2)
      .foregroundStyle(.secondary)
      .fixedSize(horizontal: false, vertical: true)
  } icon: {
    Image(systemName: icon)
      .font(.caption2)
      .foregroundStyle(.tertiary)
  }
  .frame(maxWidth: .infinity, alignment: .leading)
  }
}

struct LegalPrivacyDetailView: View {
  @Environment(\.dismiss) private var dismiss

  var body: some View {
    NavigationStack {
      List {
        Section {
          Text(LegalCopy.privacySummary)
            .font(.subheadline)
            .foregroundStyle(.secondary)
        }

        ForEach(Array(LegalCopy.privacyDetailSections.enumerated()), id: \.offset) { _, section in
          Section(section.title) {
            Text(section.body)
              .font(.subheadline)
              .foregroundStyle(.secondary)
          }
        }
      }
      .navigationTitle("Dateschutz & Hinweis")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .confirmationAction) {
          Button(ArcaTicketsStrings.done) { dismiss() }
        }
      }
    }
  }
}
