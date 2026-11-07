#!/usr/bin/env swift

import AppKit
import Foundation

guard CommandLine.arguments.count == 2 else { exit(2) }
let url = URL(fileURLWithPath: CommandLine.arguments[1])
let data = try Data(contentsOf: url)
let root = try JSONSerialization.jsonObject(with: data) as! [String: Any]
let items = root["items"] as! [[String: Any]]
let checker = NSSpellChecker.shared
var findings: [String: Set<Int>] = [:]

for item in items {
    guard let title = item["title"] as? String,
          let number = item["episodeNumber"] as? Int else { continue }
    title.enumerateSubstrings(in: title.startIndex..<title.endIndex, options: .byWords) { word, _, _, _ in
        guard let word, word.count > 2 else { return }
        let range = checker.checkSpelling(
            of: word,
            startingAt: 0,
            language: "el_GR",
            wrap: false,
            inSpellDocumentWithTag: 0,
            wordCount: nil
        )
        if range.location != NSNotFound {
            findings[word, default: []].insert(number)
        }
    }
}

for (word, numbers) in findings.sorted(by: { $0.key.localizedCaseInsensitiveCompare($1.key) == .orderedAscending }) {
    let guesses = checker.guesses(
        forWordRange: NSRange(location: 0, length: (word as NSString).length),
        in: word,
        language: "el_GR",
        inSpellDocumentWithTag: 0
    ) ?? []
    print("\(word)\t\(numbers.sorted().map(String.init).joined(separator: ","))\t\(guesses.prefix(4).joined(separator: "|"))")
}
