#!/usr/bin/env swift

import AppKit
import PDFKit
import Vision

guard CommandLine.arguments.count >= 3 else {
    fputs("Usage: ocr-typikon.swift INPUT.pdf OUTPUT.txt [first-page] [last-page]\n", stderr)
    exit(2)
}

let input = URL(fileURLWithPath: CommandLine.arguments[1])
let output = URL(fileURLWithPath: CommandLine.arguments[2])
let requestedFirst = CommandLine.arguments.count > 3 ? Int(CommandLine.arguments[3]) ?? 1 : 1

guard let document = PDFDocument(url: input) else {
    fputs("Could not open PDF\n", stderr)
    exit(3)
}

let requestedLast = CommandLine.arguments.count > 4
    ? Int(CommandLine.arguments[4]) ?? document.pageCount
    : document.pageCount
let first = max(1, requestedFirst)
let last = min(document.pageCount, requestedLast)
var pages: [String] = []

for pageNumber in first...last {
    autoreleasepool {
        guard let page = document.page(at: pageNumber - 1) else { return }
        let bounds = page.bounds(for: .mediaBox)
        let scale: CGFloat = 2.5
        let size = NSSize(width: bounds.width * scale, height: bounds.height * scale)
        let image = NSImage(size: size)
        image.lockFocus()
        NSColor.white.setFill()
        NSRect(origin: .zero, size: size).fill()
        guard let context = NSGraphicsContext.current?.cgContext else {
            image.unlockFocus(); return
        }
        context.saveGState()
        context.scaleBy(x: scale, y: scale)
        page.draw(with: .mediaBox, to: context)
        context.restoreGState()
        image.unlockFocus()
        guard let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else { return }

        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.recognitionLanguages = ["el-GR", "en-US"]
        request.usesLanguageCorrection = true
        let handler = VNImageRequestHandler(cgImage: cgImage)
        do {
            try handler.perform([request])
            let observations = (request.results ?? []).sorted {
                if abs($0.boundingBox.midY - $1.boundingBox.midY) > 0.012 {
                    return $0.boundingBox.midY > $1.boundingBox.midY
                }
                return $0.boundingBox.minX < $1.boundingBox.minX
            }
            let text = observations.compactMap { $0.topCandidates(1).first?.string }.joined(separator: "\n")
            pages.append("\n--- PAGE \(pageNumber) ---\n\(text)\n")
            print("[\(pageNumber)/\(last)] \(text.count) characters")
        } catch {
            let failure = error as NSError
            pages.append("\n--- PAGE \(pageNumber) ---\n[OCR ERROR: \(failure.domain) \(failure.code) \(failure.userInfo)]\n")
        }
    }
}

try pages.joined().write(to: output, atomically: true, encoding: .utf8)
