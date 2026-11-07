import AppKit

struct BadgeVariant {
    let name: String
    let color: NSColor
}

let sourceURL = URL(fileURLWithPath: "/Users/petroskallinicou/Downloads/ChatGPT Image Jul 15, 2026, 07_20_09 PM-Photoroom.png")
let assetsURL = URL(fileURLWithPath: "/Users/petroskallinicou/Downloads/Klimax/Klimax/Assets.xcassets")
let sourceImage = NSImage(contentsOf: sourceURL)!
let outputSize = NSSize(width: 512, height: 512)
let outputRect = NSRect(origin: .zero, size: outputSize)

let variants = [
    BadgeVariant(name: "rank_badge_bronze", color: NSColor(calibratedRed: 0.88, green: 0.54, blue: 0.30, alpha: 1)),
    BadgeVariant(name: "rank_badge_iron", color: NSColor(calibratedRed: 0.64, green: 0.68, blue: 0.70, alpha: 1)),
    BadgeVariant(name: "rank_badge_silver", color: NSColor(calibratedRed: 0.86, green: 0.90, blue: 0.93, alpha: 1)),
    BadgeVariant(name: "rank_badge_gold", color: NSColor(calibratedRed: 0.97, green: 0.78, blue: 0.25, alpha: 1)),
    BadgeVariant(name: "rank_badge_emerald", color: NSColor(calibratedRed: 0.17, green: 0.82, blue: 0.49, alpha: 1)),
    BadgeVariant(name: "rank_badge_sapphire", color: NSColor(calibratedRed: 0.22, green: 0.54, blue: 0.98, alpha: 1)),
    BadgeVariant(name: "rank_badge_amethyst", color: NSColor(calibratedRed: 0.66, green: 0.38, blue: 0.98, alpha: 1)),
    BadgeVariant(name: "rank_badge_ruby", color: NSColor(calibratedRed: 0.90, green: 0.12, blue: 0.24, alpha: 1)),
    BadgeVariant(name: "rank_badge_platinum", color: NSColor(calibratedRed: 0.80, green: 0.88, blue: 0.96, alpha: 1)),
    BadgeVariant(name: "rank_badge_diamond", color: NSColor(calibratedRed: 0.72, green: 0.96, blue: 1.00, alpha: 1)),
    BadgeVariant(name: "rank_badge_celestial", color: NSColor(calibratedRed: 0.95, green: 0.62, blue: 1.00, alpha: 1)),
    BadgeVariant(name: "rank_badge_ascendant", color: NSColor(calibratedRed: 1.00, green: 0.92, blue: 0.56, alpha: 1))
]

let contentsJSON = """
{
  "images" : [
    {
      "filename" : "badge.png",
      "idiom" : "universal",
      "scale" : "1x"
    }
  ],
  "info" : {
    "author" : "xcode",
    "version" : 1
  }
}
"""

for variant in variants {
    let image = NSImage(size: outputSize)
    image.lockFocus()
    NSColor.clear.setFill()
    outputRect.fill()
    sourceImage.draw(in: outputRect, from: .zero, operation: .sourceOver, fraction: 1)
    variant.color.setFill()
    outputRect.fill(using: .sourceAtop)
    sourceImage.draw(in: outputRect, from: .zero, operation: .luminosity, fraction: 0.90)
    sourceImage.draw(in: outputRect, from: .zero, operation: .softLight, fraction: 0.25)
    image.unlockFocus()

    let tiff = image.tiffRepresentation!
    let bitmap = NSBitmapImageRep(data: tiff)!
    let data = bitmap.representation(using: .png, properties: [:])!

    let setURL = assetsURL.appendingPathComponent("\(variant.name).imageset", isDirectory: true)
    try FileManager.default.createDirectory(at: setURL, withIntermediateDirectories: true)
    try data.write(to: setURL.appendingPathComponent("badge.png"))
    try contentsJSON.write(to: setURL.appendingPathComponent("Contents.json"), atomically: true, encoding: .utf8)
}
