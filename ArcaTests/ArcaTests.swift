//
//  ArcaTests.swift
//  ArcaTests
//
//  Created by Hans zen Ruffinen on 13.04.2026.
//

import Foundation
import Testing
@testable import Arca

/// Die Sicherung ist das Versprechen der App. Diese Tests pruefen die
/// Stellen, an denen ein Fehler still Daten kosten wuerde.
struct SicherungsTests {

    /// Eine Sicherung von VOR dem Notfallkoffer muss lesbar bleiben —
    /// sonst waere jedes alte Backup mit einem Update wertlos.
    @Test func alteSicherungOhneNotfallBleibtLesbar() throws {
        let alt = """
        {"vaultItems":[],"documents":[],"notes":[],"lists":[],
         "documentCategories":["Unsortiert"],"exportDate":0}
        """.data(using: .utf8)!
        let backup = try JSONDecoder().decode(ArcaBackup.self, from: alt)
        #expect(backup.notfallEintraege == nil)
        #expect(backup.documentCategories == ["Unsortiert"])
    }

    /// Medikamente und Kontakte kommen vollstaendig zurueck — jedes Feld.
    @Test func notfallEintraegeUeberlebenDieSicherung() throws {
        let med = NotfallEintrag(art: .medikament, name: "Beloc Zok",
                                 detail: "Metoprolol 50 mg", zusatz: "1 Tablette morgens",
                                 hinweis: "zum Essen", fotoDatei: "notfall_x.jpg", reihenfolge: 0)
        let kontakt = NotfallEintrag(art: .kontakt, name: "Anna", detail: "Tochter",
                                     zusatz: "+41 79 123 45 67", reihenfolge: 1)
        let backup = ArcaBackup(vaultItems: [], documents: [], notes: [], lists: [],
                                documentCategories: [], exportDate: Date(timeIntervalSince1970: 0),
                                notfallEintraege: [med, kontakt])
        let gelesen = try JSONDecoder().decode(ArcaBackup.self, from: JSONEncoder().encode(backup))
        let zurueck = try #require(gelesen.notfallEintraege)
        #expect(zurueck.count == 2)
        let m = try #require(zurueck.first { $0.art == .medikament })
        #expect(m.name == "Beloc Zok")
        #expect(m.detail == "Metoprolol 50 mg")
        #expect(m.zusatz == "1 Tablette morgens")
        #expect(m.hinweis == "zum Essen")
        #expect(m.fotoDatei == "notfall_x.jpg")
        let k = try #require(zurueck.first { $0.art == .kontakt })
        #expect(k.detail == "Tochter")
        #expect(k.zusatz == "+41 79 123 45 67")
    }

    /// Ein Eintrag, dem Felder fehlen (aeltere oder kuenftige Fassung), wird
    /// mit Standardwerten gelesen statt die ganze Sicherung zu verwerfen.
    @Test func eintragMitFehlendenFeldernWirdGelesen() throws {
        let knapp = #"{"art":"kontakt","name":"Hausarzt"}"#.data(using: .utf8)!
        let e = try JSONDecoder().decode(NotfallEintrag.self, from: knapp)
        #expect(e.art == .kontakt)
        #expect(e.name == "Hausarzt")
        #expect(e.zusatz == "")
        #expect(e.fotoDatei == "")
    }

    /// „Wichtig" (Herzschrittmacher …) ueberlebt das Hin und Her; eine
    /// unbekannte kuenftige Art macht den Eintrag nicht unlesbar.
    @Test func wichtigUndUnbekannteArt() throws {
        let w = NotfallEintrag(art: .wichtig, name: "Herzschrittmacher", detail: "wegen Bradykardie")
        let zurueck = try JSONDecoder().decode(NotfallEintrag.self, from: JSONEncoder().encode(w))
        #expect(zurueck.art == .wichtig)
        #expect(zurueck.detail == "wegen Bradykardie")

        let fremd = #"{"art":"blutgruppe","name":"A+"}"#.data(using: .utf8)!
        let e = try JSONDecoder().decode(NotfallEintrag.self, from: fremd)
        #expect(e.name == "A+")
    }
}
