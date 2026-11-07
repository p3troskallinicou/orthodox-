// Build-size optimization only: preserves the supplied photographs, aspect
// ratios and orientation. Originals on Desktop are never modified.
import Foundation
import ImageIO
import UniformTypeIdentifiers

let groups = [
    ("PrayerMorning", "/Users/petroskallinicou/Desktop/Πρωινη Προσευχη pics"),
    ("PrayerEvening", "/Users/petroskallinicou/Desktop/Μικρον Αποδειπνον pics ")
]
let output = URL(fileURLWithPath: "Klimax/Assets.xcassets")
for (prefix, folder) in groups {
    let files = try FileManager.default.contentsOfDirectory(at: URL(fileURLWithPath: folder), includingPropertiesForKeys: nil)
        .filter { $0.pathExtension.lowercased() == "jpg" }
        .sorted { $0.lastPathComponent < $1.lastPathComponent }
    for (index, file) in files.enumerated() {
        let directory = output.appendingPathComponent("\(prefix)\(index + 1).imageset")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        guard let source = CGImageSourceCreateWithURL(file as CFURL, nil),
              let image = CGImageSourceCreateThumbnailAtIndex(source, 0, [
                kCGImageSourceCreateThumbnailFromImageAlways: true,
                kCGImageSourceCreateThumbnailWithTransform: true,
                kCGImageSourceThumbnailMaxPixelSize: 1440
              ] as CFDictionary),
              let destination = CGImageDestinationCreateWithURL(directory.appendingPathComponent(file.lastPathComponent) as CFURL, UTType.jpeg.identifier as CFString, 1, nil)
        else { fatalError("Cannot prepare \(file.lastPathComponent)") }
        CGImageDestinationAddImage(destination, image, [kCGImageDestinationLossyCompressionQuality: 0.65] as CFDictionary)
        guard CGImageDestinationFinalize(destination) else { fatalError("Cannot save image") }
        let manifest: [String: Any] = ["images": [["filename": file.lastPathComponent, "idiom": "universal"]], "info": ["author": "xcode", "version": 1]]
        try JSONSerialization.data(withJSONObject: manifest, options: [.prettyPrinted, .sortedKeys])
            .write(to: directory.appendingPathComponent("Contents.json"))
        print("\(prefix)\(index + 1): \(image.width)×\(image.height)")
    }
}
