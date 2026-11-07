//
//  OrthodoxCalendarModels.swift
//  Klimax
//
//  UI-friendly models for the Greek Orthodox calendar. Fasting deliberately
//  does not belong to this model; it will be a separate feature later.
//

import Foundation

enum FeastType: String, Codable, Hashable {
    case saintFeast = "saint_feast"
    case lordFeast = "lord_feast"
    case theotokosFeast = "theotokos_feast"
    case apostleFeast = "apostle_feast"
    case martyrFeast = "martyr_feast"
    case movableFeast = "movable_feast"
    case other
}

enum FeastImportance: String, Codable, Hashable {
    case normal
    case major
    case great
}

enum FeastDateKind: String, Codable, Hashable {
    case fixed
    case movable
}

struct OrthodoxFeast: Codable, Identifiable, Hashable {
    let id: String
    let title: String
    let type: FeastType
    let importance: FeastImportance
    let namesCelebrated: [String]
    let description: String?
    let category: String?
    let principal: Bool
    let kind: FeastDateKind
    let month: Int?
    let day: Int?
    let paschaOffset: Int?
    // The catalogue id of the commemorated saint, when this feast is a fixed
    // saint commemoration. nil for Δεσποτικές/Θεομητορικές feasts and movable
    // feasts. Lets the eortologio open the saint's page in the Ἅγιοι catalogue.
    let saintId: String?
}

struct OrthodoxCalendarDay: Codable, Identifiable, Hashable {
    let id: String
    let date: String
    let day: Int
    let month: Int
    let year: Int
    let feasts: [OrthodoxFeast]
    let majorFeast: OrthodoxFeast?
    let liturgicalNotes: [String]
}

struct OrthodoxCalendarSource: Codable, Hashable {
    let name: String
    let calendarSystem: String
    let script: String
    let notes: String?
    let fastNotes: String?
}
