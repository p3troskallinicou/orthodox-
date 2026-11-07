import Foundation
import PDFKit

guard CommandLine.arguments.count >= 3,
      let document = PDFDocument(url: URL(fileURLWithPath: CommandLine.arguments[1])) else {
    fputs("Usage: pdfkit-extract.swift INPUT.pdf OUTPUT_DIRECTORY [--left-column]\n", stderr)
    exit(2)
}

let outputDirectory = URL(fileURLWithPath: CommandLine.arguments[2], isDirectory: true)
try FileManager.default.createDirectory(at: outputDirectory, withIntermediateDirectories: true)

for index in 0..<document.pageCount {
    guard let page = document.page(at: index) else { continue }
    let text: String
    if CommandLine.arguments.contains("--left-column") {
        let bounds = page.bounds(for: .mediaBox)
        let left = CGRect(x: bounds.minX, y: bounds.minY,
                          width: bounds.width * 0.505, height: bounds.height)
        text = page.selection(for: left)?.string ?? ""
    } else {
        text = page.string ?? ""
    }
    let output = outputDirectory.appendingPathComponent(String(format: "%03d.txt", index + 1))
    try text.write(to: output, atomically: true, encoding: .utf8)
}

print("pdfkit pages=\(document.pageCount)")
