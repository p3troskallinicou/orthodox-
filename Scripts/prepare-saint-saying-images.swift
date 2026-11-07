// Format/size conversion only. No retouching or crops; Desktop originals stay intact.
import Foundation
import ImageIO
import UniformTypeIdentifiers
let folder = URL(fileURLWithPath: "/Users/petroskallinicou/Desktop/Αγιος Παίσιος")
let files = try FileManager.default.contentsOfDirectory(at: folder, includingPropertiesForKeys: nil)
    .filter { ["jpg", "jpeg", "webp"].contains($0.pathExtension.lowercased()) }
    .sorted { $0.lastPathComponent < $1.lastPathComponent }
precondition(files.count == 8, "Review the photo manifest before adding new photographs")
for (index, file) in files.enumerated() {
    let asset = String(format: "SaintSayingPaisios%02d", index + 1)
    let directory = URL(fileURLWithPath: "Klimax/Assets.xcassets/\(asset).imageset")
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    guard let source = CGImageSourceCreateWithURL(file as CFURL, nil),
          let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
          let width = properties[kCGImagePropertyPixelWidth] as? Int,
          let height = properties[kCGImagePropertyPixelHeight] as? Int,
          let image = CGImageSourceCreateThumbnailAtIndex(source, 0, [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: min(1440, max(width, height))
          ] as CFDictionary),
          let destination = CGImageDestinationCreateWithURL(directory.appendingPathComponent("photo.jpg") as CFURL, UTType.jpeg.identifier as CFString, 1, nil)
    else { fatalError("Cannot import \(file.lastPathComponent)") }
    CGImageDestinationAddImage(destination, image, [kCGImageDestinationLossyCompressionQuality: 0.9] as CFDictionary)
    precondition(CGImageDestinationFinalize(destination))
    let manifest: [String: Any] = ["images": [["filename": "photo.jpg", "idiom": "universal"]], "info": ["author": "xcode", "version": 1]]
    try JSONSerialization.data(withJSONObject: manifest, options: [.prettyPrinted, .sortedKeys]).write(to: directory.appendingPathComponent("Contents.json"))
    print("\(asset): \(file.lastPathComponent) · \(image.width)×\(image.height)")
}
