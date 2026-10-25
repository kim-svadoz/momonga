import AppKit
// usage: grid.swift out.jpg "label|path" ...
let items = CommandLine.arguments.dropFirst(2).map { $0.split(separator: "|").map(String.init) }
let cols = 3, w = 540, h = 960, lh = 70
let rows = (items.count + cols - 1) / cols
let W = cols * w, H = rows * (h + lh)
let out = NSImage(size: NSSize(width: W, height: H))
out.lockFocus()
NSColor.white.setFill(); NSRect(x: 0, y: 0, width: W, height: H).fill()
for (i, it) in items.enumerated() {
    let c = i % cols, r = i / cols
    let y = H - (r + 1) * (h + lh)
    NSImage(contentsOfFile: it[1])!.draw(in: NSRect(x: c * w, y: y, width: w, height: h))
    (it[0] as NSString).draw(in: NSRect(x: c * w + 14, y: y + h + 10, width: w - 28, height: lh - 14),
        withAttributes: [.font: NSFont.boldSystemFont(ofSize: 30), .foregroundColor: NSColor.black])
}
out.unlockFocus()
try! NSBitmapImageRep(data: out.tiffRepresentation!)!.representation(using: .jpeg, properties: [.compressionFactor: 0.85])!.write(to: URL(fileURLWithPath: CommandLine.arguments[1]))
