import AVFoundation
import AppKit
let a = AVURLAsset(url: URL(fileURLWithPath: CommandLine.arguments[1]))
let g = AVAssetImageGenerator(asset: a); g.requestedTimeToleranceBefore = .zero; g.requestedTimeToleranceAfter = .zero
g.maximumSize = CGSize(width: 720, height: 1280)
let img = try! g.copyCGImage(at: CMTime(seconds: Double(CommandLine.arguments[2])!, preferredTimescale: 600), actualTime: nil)
try! NSBitmapImageRep(cgImage: img).representation(using: .jpeg, properties: [:])!.write(to: URL(fileURLWithPath: CommandLine.arguments[3]))
