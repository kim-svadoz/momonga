import AVFoundation
import AppKit
import CoreText
import QuartzCore
import ImageIO
import UniformTypeIdentifiers

// usage: swift reel.swift <input.mov> <outdir>
// v2: lazy.eunn 스타일 (번호 제품명 명조 + 흰 글자 검정 테두리 자막 + 검정 박스 강조)
let input = URL(fileURLWithPath: CommandLine.arguments[1])
let outDir = CommandLine.arguments[2]
let W: CGFloat = 1080, H: CGFloat = 1920
let fontDir = NSHomeDirectory() + "/Library/Fonts/"

for f in ["Pretendard-Black.otf", "Pretendard-ExtraBold.otf", "Pretendard-Bold.otf", "Pretendard-SemiBold.otf",
          "Pretendard-Medium.otf", "BookkMyungjo_Bold.ttf", "YoonChildfundkoreaDaeHan.otf"] {
    CTFontManagerRegisterFontsForURL(URL(fileURLWithPath: fontDir + f) as CFURL, .process, nil)
}
// register every installed user font so THUMB_FONT can name any of them
for f in (try? FileManager.default.contentsOfDirectory(atPath: fontDir)) ?? [] {
    CTFontManagerRegisterFontsForURL(URL(fileURLWithPath: fontDir + f) as CFURL, .process, nil)
}
let env = ProcessInfo.processInfo.environment
// thumbnail title font (big lines); THUMB_ONLY=1 writes only the thumbnail to THUMB_OUT
let titleFont = env["THUMB_FONT"] ?? "BookkMyungjo-Bd"
func font(_ name: String, _ size: CGFloat) -> NSFont {
    guard let f = NSFont(name: name, size: size) else { fatalError("font missing: \(name)") }
    return f
}

let yellow = NSColor(red: 1.0, green: 0.85, blue: 0.30, alpha: 1)
let cream = NSColor(red: 1.0, green: 0.96, blue: 0.86, alpha: 1)

// MARK: - caption timeline

enum Style { case title, main, box, gloss, price, note, series }
struct Cap { let start: Double; let end: Double; let text: String; let style: Style }

let END = 42.83
let caps: [Cap] = [
    Cap(start: 3.4, end: END, text: "돈키호테 쇼핑템 1탄", style: .series),

    // 1. 치이카와
    Cap(start: 3.6, end: 15.0, text: "1. 치이카와 인형 키링", style: .title),
    Cap(start: 3.6, end: 6.5, text: "일본 갔는데 치이카와 못참지..", style: .main),
    Cap(start: 6.5, end: 9.4, text: "복슬복슬 꼬리까지 귀여운 모몽가", style: .main),
    Cap(start: 6.5, end: 9.4, text: "모몽가 1,200엔", style: .price),
    Cap(start: 9.4, end: 11.9, text: "머리에 수건 얹은 온천 치이카와", style: .main),
    Cap(start: 9.4, end: 11.9, text: "온천 치이카와 1,400엔", style: .price),
    Cap(start: 11.9, end: 14.0, text: "사루보보ver. 하치와레까지!", style: .main),
    Cap(start: 11.9, end: 14.0, text: "(*사루보보 = 일본 행운의 인형)", style: .gloss),
    Cap(start: 11.9, end: 14.0, text: "사루보보 하치와레 1,540엔", style: .price),
    Cap(start: 11.9, end: 14.0, text: "(나고야 관광지에서 구매)", style: .note),
    Cap(start: 14.0, end: 15.0, text: "가방에 달면 포인트 완성!", style: .main),

    // 2. 아누아 세럼
    Cap(start: 15.4, end: 20.8, text: "2. 아누아 아젤라익 세럼", style: .title),
    Cap(start: 15.4, end: 20.8, text: "어성초, 티트리 성분 좋아하는\n민감성 피부라면", style: .main),
    Cap(start: 17.2, end: 20.8, text: "이거 진짜 추천해요..", style: .box),
    Cap(start: 15.4, end: 20.8, text: "아누아 아젤라익애씨드 15 세럼 30ml | 2,346엔", style: .price),

    // 3. 아누아 마스크
    Cap(start: 20.8, end: 25.6, text: "3. 아누아 시카 마스크팩", style: .title),
    Cap(start: 20.8, end: 23.2, text: "같은 라인 마스크팩도 세트로 샀는데", style: .main),
    Cap(start: 23.2, end: 25.6, text: "밤에 팩 하고 자면", style: .main),
    Cap(start: 23.6, end: 25.6, text: "다음날 피부결이 진짜 매끈해져요..", style: .box),
    Cap(start: 20.8, end: 25.6, text: "아누아 시카 세럼 인 마스크 7매 | 700엔", style: .price),

    // 4. 루루룬
    Cap(start: 26.2, end: 34.8, text: "4. 루루룬 하이드라 EX", style: .title),
    Cap(start: 26.2, end: 28.6, text: "매번 재구매해오는 루루룬 팩", style: .main),
    Cap(start: 28.6, end: 31.0, text: "보습 탄력 관리에 좋고", style: .main),
    Cap(start: 31.0, end: 32.9, text: "속건조 싹 잡아줘서", style: .main),
    Cap(start: 32.9, end: 34.8, text: "일본 여행 갈 때마다\n쟁여오는 재구매템", style: .main),
    Cap(start: 32.9, end: 34.8, text: "(선물하기도 좋아요!)", style: .box),
    Cap(start: 26.2, end: 34.8, text: "루루룬 하이드라 EX 마스크 7매 | 900엔", style: .price),

    // 5. 클럽 파우더
    Cap(start: 34.8, end: END, text: "5. 클럽 스핀 파우더", style: .title),
    Cap(start: 34.8, end: 37.4, text: "오후만 되면 T존에 기름기 올라온다?", style: .main),
    Cap(start: 35.8, end: 37.4, text: "이거 진짜 추천", style: .box),
    Cap(start: 37.4, end: 39.8, text: "원래 오후만 되면 기름 올라오는데", style: .main),
    Cap(start: 39.8, end: END, text: "하루종일 피부 컨디션이\n훨씬 보송해지는 느낌 (향도 좋아요!)", style: .main),
    Cap(start: 34.8, end: END, text: "클럽 스핀 파우더 | 1,780엔", style: .price),
]

// MARK: - drawing helpers

func bitmap(_ w: Int, _ h: Int, _ draw: (CGContext) -> Void) -> CGImage {
    let ctx = CGContext(data: nil, width: w, height: h, bitsPerComponent: 8, bytesPerRow: 0,
                        space: CGColorSpaceCreateDeviceRGB(),
                        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
    NSGraphicsContext.current = NSGraphicsContext(cgContext: ctx, flipped: false)
    draw(ctx)
    return ctx.makeImage()!
}

func para(lineSpacing: CGFloat = 4) -> NSParagraphStyle {
    let p = NSMutableParagraphStyle()
    p.alignment = .center
    p.lineSpacing = lineSpacing
    return p
}

// outlined text: stroke pass (with soft shadow) then fill pass
func outlined(_ text: String, font f: NSFont, fill: NSColor, stroke: NSColor, strokePct: CGFloat,
              glow: CGFloat, kern: CGFloat = -0.5) -> CGImage {
    let base: [NSAttributedString.Key: Any] = [.font: f, .paragraphStyle: para(), .kern: kern]
    let fillAttr = NSAttributedString(string: text, attributes: base.merging([.foregroundColor: fill]) { $1 })
    let size = fillAttr.boundingRect(with: CGSize(width: W - 80, height: 2000),
                                     options: [.usesLineFragmentOrigin, .usesFontLeading]).size
    let m: CGFloat = 24
    let bw = ceil(size.width), bh = ceil(size.height)
    return bitmap(Int(bw + m * 2), Int(bh + m * 2)) { _ in
        let r = CGRect(x: m, y: m, width: bw, height: bh)
        let shadow = NSShadow()
        shadow.shadowColor = NSColor.black.withAlphaComponent(0.55)
        shadow.shadowBlurRadius = glow
        shadow.shadowOffset = .zero
        let strokeAttr = NSAttributedString(string: text, attributes: base.merging([
            .foregroundColor: stroke, .strokeColor: stroke, .strokeWidth: strokePct, .shadow: shadow]) { $1 })
        strokeAttr.draw(with: r, options: [.usesLineFragmentOrigin, .usesFontLeading])
        fillAttr.draw(with: r, options: [.usesLineFragmentOrigin, .usesFontLeading])
    }
}

func boxed(_ text: String, font f: NSFont, color: NSColor, box: NSColor, padX: CGFloat, padY: CGFloat) -> CGImage {
    let attr = NSAttributedString(string: text, attributes: [
        .font: f, .foregroundColor: color, .paragraphStyle: para(), .kern: -0.5])
    let size = attr.boundingRect(with: CGSize(width: W - 120, height: 2000),
                                 options: [.usesLineFragmentOrigin, .usesFontLeading]).size
    let bw = ceil(size.width + padX * 2), bh = ceil(size.height + padY * 2)
    return bitmap(Int(bw), Int(bh)) { ctx in
        ctx.setFillColor(box.cgColor)
        ctx.fill(CGRect(x: 0, y: 0, width: bw, height: bh))
        attr.draw(with: CGRect(x: padX, y: padY, width: size.width, height: size.height),
                  options: [.usesLineFragmentOrigin, .usesFontLeading])
    }
}

func capImage(_ c: Cap) -> CGImage {
    switch c.style {
    case .title:
        return outlined(c.text, font: font("BookkMyungjo-Bd", 72), fill: cream,
                        stroke: NSColor(white: 0.08, alpha: 1), strokePct: 9, glow: 16, kern: -1)
    case .main:
        return outlined(c.text, font: font("Pretendard-SemiBold", 52), fill: .white,
                        stroke: .black, strokePct: 11, glow: 10)
    case .box:
        return outlined(c.text, font: font("YoonChildfundkoreaDaeHan", 62), fill: yellow,
                        stroke: .black, strokePct: 12, glow: 10, kern: 0)
    case .gloss:
        return outlined(c.text, font: font("Pretendard-Medium", 32), fill: .white,
                        stroke: .black, strokePct: 9, glow: 4)
    case .price:
        return outlined(c.text, font: font("Pretendard-Medium", 34), fill: .white,
                        stroke: .black, strokePct: 9, glow: 4)
    case .note:
        return outlined(c.text, font: font("Pretendard-Medium", 28), fill: .white,
                        stroke: .black, strokePct: 9, glow: 4)
    case .series:
        return outlined(c.text, font: font("Pretendard-SemiBold", 34), fill: .white,
                        stroke: .black, strokePct: 10, glow: 8)
    }
}

// center y measured from top, as a fraction of height
func centerY(_ c: Cap) -> CGFloat {
    switch c.style {
    case .series: return 0.125
    case .title: return 0.235
    case .main: return c.text.contains("\n") ? 0.625 : 0.64
    case .box, .gloss: return 0.705
    case .price: return 0.775
    case .note: return 0.800
    }
}

let hookLines: [(String, String, CGFloat, NSColor, CGFloat)] = [
    ("[저장 필수]", "Pretendard-ExtraBold", 60, yellow, -1),
    ("n번째 재구매중인", titleFont, 86, .white, -3),
    ("돈키호테 쇼핑리스트 1탄", titleFont, 88, yellow, -3),
]
// 5-point star sticker; (x, y) are fractions from the top-left
func star(_ ctx: CGContext, _ x: CGFloat, _ y: CGFloat, _ r: CGFloat, _ fill: NSColor, _ angle: CGFloat) {
    let c = CGPoint(x: x * W, y: H - y * H)
    let path = CGMutablePath()
    for i in 0..<10 {
        let rad = i % 2 == 0 ? r : r * 0.45
        let a = angle + CGFloat(i) * .pi / 5 + .pi / 2
        let p = CGPoint(x: c.x + rad * cos(a), y: c.y + rad * sin(a))
        i == 0 ? path.move(to: p) : path.addLine(to: p)
    }
    path.closeSubpath()
    ctx.saveGState()
    ctx.setShadow(offset: CGSize(width: 0, height: -3), blur: 8, color: NSColor.black.withAlphaComponent(0.25).cgColor)
    ctx.addPath(path); ctx.setFillColor(fill.cgColor); ctx.fillPath()
    ctx.restoreGState()
    ctx.addPath(path)
    ctx.setStrokeColor(NSColor(red: 0.13, green: 0.16, blue: 0.24, alpha: 1).cgColor)
    ctx.setLineWidth(r * 0.09); ctx.setLineJoin(.round); ctx.strokePath()
}
func dot(_ ctx: CGContext, _ x: CGFloat, _ y: CGFloat, _ r: CGFloat) {
    let rect = CGRect(x: x * W - r, y: H - y * H - r, width: r * 2, height: r * 2)
    ctx.setFillColor(NSColor(red: 0.98, green: 0.55, blue: 0.68, alpha: 1).cgColor); ctx.fillEllipse(in: rect)
    ctx.setStrokeColor(NSColor(red: 0.13, green: 0.16, blue: 0.24, alpha: 1).cgColor)
    ctx.setLineWidth(3); ctx.strokeEllipse(in: rect)
}
func drawStickers(_ ctx: CGContext) {
    let mint = NSColor(red: 0.50, green: 0.86, blue: 0.80, alpha: 1)
    star(ctx, 0.11, 0.09, 46, mint, 0.2)
    star(ctx, 0.07, 0.17, 54, .white, -0.15)
    dot(ctx, 0.22, 0.06, 11)
    star(ctx, 0.91, 0.13, 48, mint, -0.25)
    dot(ctx, 0.84, 0.07, 10)
    star(ctx, 0.08, 0.76, 48, mint, 0.3)
    dot(ctx, 0.14, 0.83, 10)
    star(ctx, 0.90, 0.75, 58, .white, 0.1)
    star(ctx, 0.83, 0.84, 40, mint, -0.3)
    dot(ctx, 0.93, 0.66, 9)
}

let hookCharCount = hookLines.reduce(0) { $0 + $1.0.count }

// 3-tier hook text. thumbnail: above the plush toys; video intro: screen center.
// visible: how many characters are typed so far (typewriter); lines stay left-anchored so text does not shift.
func hookImage(background: CGImage?, centered: Bool, visible: Int = Int.max, dim: Bool = true, tag: Bool = false) -> CGImage {
    return bitmap(Int(W), Int(H)) { ctx in
        if let bg = background { ctx.draw(bg, in: CGRect(x: 0, y: 0, width: W, height: H)) }
        if dim && !centered {
            let grad = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                                  colors: [NSColor.black.withAlphaComponent(0.62).cgColor,
                                           NSColor.black.withAlphaComponent(0.45).cgColor,
                                           NSColor.black.withAlphaComponent(0).cgColor] as CFArray,
                                  locations: [0, 0.55, 1])!
            ctx.drawLinearGradient(grad, start: CGPoint(x: 0, y: H), end: CGPoint(x: 0, y: H * 0.55), options: [])
        } else if dim {
            ctx.setFillColor(NSColor.black.withAlphaComponent(0.38).cgColor)
            ctx.fill(CGRect(x: 0, y: 0, width: W, height: H))
        }

        let shadow = NSShadow()
        shadow.shadowColor = NSColor.black.withAlphaComponent(0.7)
        shadow.shadowBlurRadius = 22
        shadow.shadowOffset = CGSize(width: 0, height: -4)

        let ys: [CGFloat] = centered ? [0.435, 0.495, 0.555] : [0.165, 0.225, 0.285]
        var left = visible
        for (i, l) in hookLines.enumerated() {
            let attrs: [NSAttributedString.Key: Any] = [
                .font: font(l.1, l.2), .foregroundColor: l.3, .shadow: shadow,
                .paragraphStyle: para(lineSpacing: 0), .kern: l.4]
            let full = NSAttributedString(string: l.0, attributes: attrs).size()
            let shown = String(l.0.prefix(max(0, left)))
            left -= l.0.count
            if shown.isEmpty { continue }
            NSAttributedString(string: shown, attributes: attrs)
                .draw(at: CGPoint(x: (W - full.width) / 2, y: H - ys[i] * H - full.height / 2))
        }
        // thumbnail only: star stickers around the edges (kockc.o style) + small cute tag
        if tag { drawStickers(ctx) }
        if tag {
            let tag = NSAttributedString(string: "- 치이카와굿즈/뷰티템 -", attributes: [
                .font: font("YoonChildfundkoreaDaeHan", 54), .foregroundColor: NSColor.white, .shadow: shadow])
            let sz = tag.size()
            tag.draw(at: CGPoint(x: (W - sz.width) / 2, y: H - (centered ? 0.615 : 0.345) * H - sz.height / 2))
        }
    }
}

func writeJPEG(_ img: CGImage, _ path: String) {
    let dest = CGImageDestinationCreateWithURL(URL(fileURLWithPath: path) as CFURL, UTType.jpeg.identifier as CFString, 1, nil)!
    CGImageDestinationAddImage(dest, img, [kCGImageDestinationLossyCompressionQuality: 0.92] as CFDictionary)
    CGImageDestinationFinalize(dest)
}

// MARK: - build composition

let asset = AVURLAsset(url: input)
let comp = AVMutableComposition()
let vSrc = asset.tracks(withMediaType: .video)[0]
let range = CMTimeRange(start: .zero, duration: vSrc.timeRange.duration)
let vTrack = comp.addMutableTrack(withMediaType: .video, preferredTrackID: kCMPersistentTrackID_Invalid)!
try! vTrack.insertTimeRange(range, of: vSrc, at: .zero)
if let aSrc = asset.tracks(withMediaType: .audio).first {
    let aTrack = comp.addMutableTrack(withMediaType: .audio, preferredTrackID: kCMPersistentTrackID_Invalid)!
    try! aTrack.insertTimeRange(CMTimeRange(start: .zero, duration: aSrc.timeRange.duration), of: aSrc, at: .zero)
}

let gen = AVAssetImageGenerator(asset: asset)
gen.appliesPreferredTrackTransform = true
gen.requestedTimeToleranceBefore = .zero
gen.requestedTimeToleranceAfter = .zero
// 2.4s: 치이카와·모몽가·하치와레 얼굴이 모두 보이는 전체샷
let thumbBg = try? gen.copyCGImage(at: CMTime(seconds: 2.4, preferredTimescale: 600), actualTime: nil)
writeJPEG(hookImage(background: thumbBg, centered: true, tag: true), env["THUMB_OUT"] ?? "\(outDir)/썸네일_\(titleFont).jpg")
if env["THUMB_ONLY"] != nil { exit(0) }

let parent = CALayer(), videoLayer = CALayer(), overlay = CALayer()
for l in [parent, videoLayer, overlay] { l.frame = CGRect(x: 0, y: 0, width: W, height: H) }
parent.addSublayer(videoLayer)
parent.addSublayer(overlay)

func addTimed(_ img: CGImage, frame: CGRect, start: Double, end: Double, fadeIn: Double = 0.1, fadeOut: Double = 0.1) {
    let l = CALayer()
    l.contents = img
    l.frame = frame
    l.opacity = 0
    let a = CAKeyframeAnimation(keyPath: "opacity")
    a.values = [0, 1, 1, 0]
    let dur = end - start
    a.keyTimes = [0, NSNumber(value: fadeIn / dur), NSNumber(value: 1 - fadeOut / dur), 1]
    a.beginTime = start == 0 ? AVCoreAnimationBeginTimeAtZero : start
    a.duration = dur
    a.isRemovedOnCompletion = false
    l.add(a, forKey: "show")
    overlay.addSublayer(l)
}

// hook: same text as the thumbnail, over the video, 0 ~ 3.4s
// hook: dim layer + typewriter text (one character every 0.05s), 0 ~ 3.4s
let full = CGRect(x: 0, y: 0, width: W, height: H)
// dim as a plain color layer (no full-screen bitmap)
let dimLayer = CALayer()
dimLayer.frame = full
dimLayer.backgroundColor = NSColor.black.withAlphaComponent(0.38).cgColor
dimLayer.opacity = 0
let dimAnim = CAKeyframeAnimation(keyPath: "opacity")
dimAnim.values = [1, 1, 0]
dimAnim.keyTimes = [0, NSNumber(value: 3.3 / 3.4), 1]
dimAnim.beginTime = AVCoreAnimationBeginTimeAtZero
dimAnim.duration = 3.4
dimAnim.isRemovedOnCompletion = false
dimLayer.add(dimAnim, forKey: "show")
overlay.addSublayer(dimLayer)
// only the text band (top-origin 39%~61%) is kept per typing frame
let bandTop = 0.39 * H, bandH = 0.22 * H
func band(_ img: CGImage) -> CGImage {
    let cut = img.cropping(to: CGRect(x: 0, y: bandTop, width: W, height: bandH))!
    return bitmap(Int(W), Int(bandH)) { ctx in ctx.draw(cut, in: CGRect(x: 0, y: 0, width: W, height: bandH)) }
}
let bandFrame = CGRect(x: 0, y: H - bandTop - bandH, width: W, height: bandH)
let typeStart = 0.15, perChar = 0.05, hookEnd = 3.4
// one layer, contents switched per typed character (discrete keyframes), then fade out at the end
var frames: [CGImage] = [bitmap(Int(W), Int(bandH)) { _ in }]
var keyTimes: [NSNumber] = [0]
for n in 1...hookCharCount {
    frames.append(band(hookImage(background: nil, centered: true, visible: n, dim: false)))
    keyTimes.append(NSNumber(value: (typeStart + Double(n - 1) * perChar) / hookEnd))
}
keyTimes.append(1)
let typeLayer = CALayer()
typeLayer.frame = bandFrame
typeLayer.opacity = 0
let contentsAnim = CAKeyframeAnimation(keyPath: "contents")
contentsAnim.values = frames
contentsAnim.keyTimes = keyTimes
contentsAnim.calculationMode = .discrete
let typeFade = CAKeyframeAnimation(keyPath: "opacity")
typeFade.values = [1, 1, 0]
typeFade.keyTimes = [0, NSNumber(value: 3.3 / hookEnd), 1]
let typeGroup = CAAnimationGroup()
contentsAnim.duration = hookEnd
typeFade.duration = hookEnd
typeGroup.animations = [contentsAnim, typeFade]
typeGroup.beginTime = AVCoreAnimationBeginTimeAtZero
typeGroup.duration = hookEnd
typeGroup.isRemovedOnCompletion = false
typeLayer.add(typeGroup, forKey: "type")
overlay.addSublayer(typeLayer)
// star stickers during the intro, same as the thumbnail
addTimed(bitmap(Int(W), Int(H)) { ctx in drawStickers(ctx) }, frame: full, start: 0, end: hookEnd)

// CALayer origin is bottom-left here
func layerFrame(_ c: Cap, _ img: CGImage) -> CGRect {
    let w = CGFloat(img.width), h = CGFloat(img.height)
    let cy = H - centerY(c) * H
    return CGRect(x: (W - w) / 2, y: cy - h / 2, width: w, height: h)
}
let mains = caps.filter { $0.style == .main }.map { ($0, layerFrame($0, capImage($0))) }
for c in caps {
    let img = capImage(c)
    var f = layerFrame(c, img)
    // emphasis sits right under the main caption shown at that moment (images carry 24px margins)
    if c.style == .box || c.style == .gloss, let m = mains.first(where: { $0.0.start <= c.start && c.start < $0.0.end }) {
        f.origin.y = m.1.minY + 24 + 24 - 6 - f.height
    }
    addTimed(img, frame: f, start: c.start, end: c.end)
}

let vc = AVMutableVideoComposition()
vc.renderSize = CGSize(width: W, height: H)
vc.frameDuration = CMTime(value: 1, timescale: 30)
let inst = AVMutableVideoCompositionInstruction()
inst.timeRange = range
inst.layerInstructions = [AVMutableVideoCompositionLayerInstruction(assetTrack: vTrack)]
vc.instructions = [inst]
vc.animationTool = AVVideoCompositionCoreAnimationTool(postProcessingAsVideoLayer: videoLayer, in: parent)

let outURL = URL(fileURLWithPath: "\(outDir)/자막입힌_초안.mp4")
try? FileManager.default.removeItem(at: outURL)
let ex = AVAssetExportSession(asset: comp, presetName: AVAssetExportPreset1920x1080)!
ex.videoComposition = vc
ex.outputURL = outURL
ex.outputFileType = .mp4
let sem = DispatchSemaphore(value: 0)
ex.exportAsynchronously { sem.signal() }
sem.wait()
print("export:", ex.status == .completed ? "ok" : "failed \(String(describing: ex.error))")

// MARK: - SRT for CapCut (one file per caption layer)

func ts(_ t: Double) -> String {
    let ms = Int((t * 1000).rounded())
    return String(format: "%02d:%02d:%02d,%03d", ms / 3_600_000, ms / 60_000 % 60, ms / 1000 % 60, ms % 1000)
}
func srt(_ list: [Cap]) -> String {
    list.sorted { $0.start < $1.start }.enumerated().map { i, c in
        "\(i + 1)\n\(ts(c.start)) --> \(ts(c.end))\n\(c.text)\n"
    }.joined(separator: "\n")
}
func save(_ name: String, _ list: [Cap]) {
    try! srt(list).write(toFile: "\(outDir)/\(name)", atomically: true, encoding: .utf8)
}
let hook = Cap(start: 0, end: 3.4, text: "[저장 필수]\nn번째 재구매중인\n돈키호테 쇼핑리스트 1탄", style: .title)
save("자막_제품명.srt", [hook] + caps.filter { $0.style == .title || $0.style == .series })
save("자막_메인.srt", caps.filter { $0.style == .main })
save("자막_강조.srt", caps.filter { $0.style == .box || $0.style == .gloss })
save("자막_가격.srt", caps.filter { $0.style == .price || $0.style == .note })
