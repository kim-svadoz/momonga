import AVFoundation

// 컷편집: 원본에서 남길 구간만 이어 붙인다 (원본 소리 포함, 화질 그대로).
// usage: swift cut.swift <원본.MOV> <결과.mov> 시작-끝 시작-끝 ...   (초 단위, 예: 0.6-2.0 5.4-14.0)
// 다른 영상의 구간은 "<경로>@시작-끝" (예: 1탄 오프닝을 그대로 쓰기)
let src = AVURLAsset(url: URL(fileURLWithPath: CommandLine.arguments[1]))
let outURL = URL(fileURLWithPath: CommandLine.arguments[2])
let ranges = CommandLine.arguments.dropFirst(3).map { arg -> (AVURLAsset, CMTimeRange) in
    let parts = arg.split(separator: "@").map(String.init)
    let asset = parts.count == 2 ? AVURLAsset(url: URL(fileURLWithPath: parts[0])) : src
    let p = parts.last!.split(separator: "-").map { Double($0)! }
    return (asset, CMTimeRange(start: CMTime(seconds: p[0], preferredTimescale: 600),
                               end: CMTime(seconds: p[1], preferredTimescale: 600)))
}

let comp = AVMutableComposition()
let vTrack = comp.addMutableTrack(withMediaType: .video, preferredTrackID: kCMPersistentTrackID_Invalid)!
vTrack.preferredTransform = src.tracks(withMediaType: .video)[0].preferredTransform
let aTrack = comp.addMutableTrack(withMediaType: .audio, preferredTrackID: kCMPersistentTrackID_Invalid)!

var at = CMTime.zero
for (asset, r) in ranges {
    try! vTrack.insertTimeRange(r, of: asset.tracks(withMediaType: .video)[0], at: at)
    if let a = asset.tracks(withMediaType: .audio).first { try! aTrack.insertTimeRange(r, of: a, at: at) }
    at = at + r.duration
}

try? FileManager.default.removeItem(at: outURL)
let ex = AVAssetExportSession(asset: comp, presetName: AVAssetExportPresetPassthrough)!
ex.outputURL = outURL
ex.outputFileType = .mov
let sem = DispatchSemaphore(value: 0)
ex.exportAsynchronously { sem.signal() }
sem.wait()
print("cut:", ex.status == .completed ? "ok" : "failed", String(format: "%.2fs", CMTimeGetSeconds(at)))
for (i, (_, r)) in ranges.enumerated() {
    print(String(format: "  %d) %.2f-%.2f (%.2fs)", i + 1, CMTimeGetSeconds(r.start), CMTimeGetSeconds(r.end), CMTimeGetSeconds(r.duration)))
}
