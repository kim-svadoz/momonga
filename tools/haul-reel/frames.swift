import AVFoundation
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers
import AppKit

// usage: swift frames.swift <video> <outdir>
let args = CommandLine.arguments
let asset = AVURLAsset(url: URL(fileURLWithPath: args[1]))
let outDir = args[2]
let gen = AVAssetImageGenerator(asset: asset)
gen.appliesPreferredTrackTransform = true
gen.requestedTimeToleranceBefore = .zero
gen.requestedTimeToleranceAfter = .zero
let duration = CMTimeGetSeconds(asset.duration)

func frame(_ t: Double, _ w: Int) -> CGImage? {
    gen.maximumSize = CGSize(width: w, height: w * 16 / 9)
    return try? gen.copyCGImage(at: CMTime(seconds: t, preferredTimescale: 600), actualTime: nil)
}

// 1) cut detection: grayscale 18x32 at 0.1s steps
func gray(_ img: CGImage) -> [Double] {
    let w = 18, h = 32
    var buf = [UInt8](repeating: 0, count: w * h)
    let ctx = CGContext(data: &buf, width: w, height: h, bitsPerComponent: 8, bytesPerRow: w,
                        space: CGColorSpaceCreateDeviceGray(), bitmapInfo: 0)!
    ctx.draw(img, in: CGRect(x: 0, y: 0, width: w, height: h))
    return buf.map { Double($0) }
}
var prev: [Double]? = nil
var t = 0.0
var diffs: [(Double, Double)] = []
while t < duration {
    if let img = frame(t, 72) {
        let g = gray(img)
        if let p = prev {
            var sum: Double = 0
            for j in 0..<g.count { sum += abs(g[j] - p[j]) }
            let d: Double = sum / Double(g.count)
            diffs.append((t, d))
        }
        prev = g
    }
    t += 0.1
}
for (tt, d) in diffs { print(String(format: "%.1f %.1f", tt, d)) }

// 2) contact sheets: one frame every 0.5s, 6 cols x 4 rows per sheet, time label
let cols = 6, rows = 4, tw = 240, th = 427
var times: [Double] = []
var s = 0.0
while s < duration { times.append(s); s += 0.5 }
var sheet = 0
var i = 0
while i < times.count {
    let W = cols * tw, H = rows * th
    let ctx = CGContext(data: nil, width: W, height: H, bitsPerComponent: 8, bytesPerRow: 0,
                        space: CGColorSpaceCreateDeviceRGB(),
                        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
    ctx.setFillColor(CGColor(red: 0, green: 0, blue: 0, alpha: 1))
    ctx.fill(CGRect(x: 0, y: 0, width: W, height: H))
    let ns = NSGraphicsContext(cgContext: ctx, flipped: false)
    NSGraphicsContext.current = ns
    for k in 0..<(cols * rows) {
        guard i + k < times.count, let img = frame(times[i + k], tw) else { continue }
        let c = k % cols, r = k / cols
        let rect = CGRect(x: c * tw, y: H - (r + 1) * th, width: tw, height: th)
        ctx.draw(img, in: rect)
        let label = String(format: "%.1fs", times[i + k]) as NSString
        let attrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.boldSystemFont(ofSize: 28),
            .foregroundColor: NSColor.yellow,
            .backgroundColor: NSColor.black.withAlphaComponent(0.7)]
        label.draw(at: CGPoint(x: rect.minX + 6, y: rect.maxY - 36), withAttributes: attrs)
    }
    let out = ctx.makeImage()!
    let url = URL(fileURLWithPath: "\(outDir)/sheet\(sheet).jpg")
    let dest = CGImageDestinationCreateWithURL(url as CFURL, UTType.jpeg.identifier as CFString, 1, nil)!
    CGImageDestinationAddImage(dest, out, [kCGImageDestinationLossyCompressionQuality: 0.7] as CFDictionary)
    CGImageDestinationFinalize(dest)
    sheet += 1
    i += cols * rows
}
