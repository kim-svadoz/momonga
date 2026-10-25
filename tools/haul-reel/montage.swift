import AppKit
let paths = Array(CommandLine.arguments.dropFirst().dropLast())
let imgs = paths.map { NSImage(contentsOfFile: $0)! }
let w = 360, h = 640
let out = NSImage(size: NSSize(width: w * imgs.count, height: h))
out.lockFocus()
for (i, im) in imgs.enumerated() { im.draw(in: NSRect(x: i * w, y: 0, width: w, height: h)) }
out.unlockFocus()
let rep = NSBitmapImageRep(data: out.tiffRepresentation!)!
try! rep.representation(using: .jpeg, properties: [:])!.write(to: URL(fileURLWithPath: CommandLine.arguments.last!))
