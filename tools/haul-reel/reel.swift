import AVFoundation
import AppKit
import CoreText
import QuartzCore
import CoreImage
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

enum Style { case title, main, box, cute, lead, gloss, price, note, series, outro }
struct Cap { let start: Double; let end: Double; let text: String; let style: Style }

// ===== 회차 데이터: 돈키호테 쇼핑리스트 2탄 (1탄 데이터는 output/261025/reels_돈키호테 추천템 1탄/reel_1탄.swift) =====
let END = 35.1
// 오프닝(훅) 길이: 쇼핑 떼샷부터 바로 시작 (2탄은 쇼핑백 컷을 빼서 2초)
let HOOK_END = 2.0
// 엔딩: 원본의 쇼핑 떼샷 구간을 한 번 더 붙이고 마무리 문구를 띄운다
let OUTRO_FROM = 0.0, OUTRO_LEN = 2.0
let OUTRO_TEXT = "11월 일본 출장 가서\n또 말아올게요!"
let HOOK_LINE1 = "n번째 재구매중인", HOOK_LINE2 = "돈키호테 재구매템 2탄"
let SERIES_LABEL = "돈키호테 쇼핑템 2탄"
let THUMB_TAG = "- 진통제/간식/생활용품 -"
let caps: [Cap] = [
    Cap(start: 2.0, end: END, text: SERIES_LABEL, style: .series),

    // 1. 이브 (2.0~10.6)
    Cap(start: 2.0, end: 10.6, text: "1. 이브 쓰리샷 프리미엄", style: .title),
    Cap(start: 2.2, end: 6.2, text: "이브 진통제 대부분 국내 반입 금지인데\n쓰리샷 프리미엄은 국내 반입 가능해요", style: .main),
    Cap(start: 6.2, end: 10.6, text: "타이레놀 잘 안맞는다면 이브 추천해요", style: .main),
    Cap(start: 6.6, end: 10.6, text: "두통, 생리통 필수템", style: .box),
    Cap(start: 2.0, end: 10.6, text: "이브 쓰리샷 프리미엄 60정 | 2,280엔", style: .price),

    // 2. 타케노코노사토 (10.6~20.6)
    Cap(start: 10.6, end: 20.6, text: "2. 타케노코노사토", style: .title),
    Cap(start: 10.6, end: 13.6, text: "일본 갈 때마다\n털어오는 죽순 과자", style: .main),
    Cap(start: 10.6, end: 13.6, text: "*타케노코 = 죽순", style: .gloss),
    Cap(start: 13.6, end: 17.4, text: "오리지널은 워낙 유명해서 다들 아시죠", style: .main),
    Cap(start: 14.0, end: 17.4, text: "초코송이랑 비슷하지만\n훨씬 고급진 맛", style: .box),
    Cap(start: 13.6, end: 17.4, text: "오리지널 | 168엔", style: .price),
    Cap(start: 17.4, end: 20.6, text: "말차맛은 처음 먹어봤는데", style: .main),
    Cap(start: 17.8, end: 20.6, text: "말차향이 진짜 진하고 고급져요..", style: .box),
    Cap(start: 17.4, end: 20.6, text: "말차맛 | 198엔", style: .price),

    // 3. 불닭 카레 (20.6~27.1)
    Cap(start: 20.6, end: 27.1, text: "3. 삼양 불닭 카레", style: .title),
    Cap(start: 20.6, end: 23.0, text: "돈키호테 한정판 불닭 카레?!", style: .main),
    Cap(start: 23.0, end: 25.5, text: "불닭 러버라면 꼭 사오세요", style: .main),
    Cap(start: 23.4, end: 25.5, text: "진짜 맛있어요..", style: .box),
    Cap(start: 25.5, end: 27.1, text: "(11월에 출장 가는데)", style: .lead),
    Cap(start: 25.5, end: 27.1, text: "여러 개 쟁여오려고요..\n완전 밥도둑", style: .main),
    Cap(start: 20.6, end: 27.1, text: "삼양 불닭 카레 | 299엔", style: .price),

    // 4. 샤워타월 (27.1~35.1)
    Cap(start: 27.1, end: END, text: "4. 일본 샤워타월", style: .title),
    Cap(start: 27.1, end: 29.4, text: "엄마 애착템 일본 샤워타월", style: .main),
    Cap(start: 29.4, end: 31.6, text: "부드러운 타입부터 하드 타입까지\n골라올 수 있어요", style: .main),
    Cap(start: 31.6, end: 33.4, text: "남대문 수입상가는 더 비싸서\n일본 갔을 때 사는 거 추천", style: .main),
    Cap(start: 33.4, end: END, text: "목욕에 진심이라면", style: .main),
    Cap(start: 33.7, end: END, text: "한 번 꼭 사보세요", style: .box),
    Cap(start: 27.1, end: END, text: "샤워타월 | 개당 298~598엔", style: .price),
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
    // +2: a line measured at its exact width can wrap when drawn (e.g. "쟁여오려고요.."), pushing the last line out of the image
    let bw = ceil(size.width) + 2, bh = ceil(size.height)
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
    case .cute, .lead:
        return outlined(c.text, font: font("YoonChildfundkoreaDaeHan", 46), fill: yellow,
                        stroke: .black, strokePct: 12, glow: 8, kern: 0)
    case .gloss:
        return outlined(c.text, font: font("Pretendard-Medium", 32), fill: .white,
                        stroke: .black, strokePct: 9, glow: 4)
    case .price:
        return outlined(c.text, font: font("Pretendard-Medium", 34), fill: .white,
                        stroke: .black, strokePct: 9, glow: 4)
    case .note:
        return outlined(c.text, font: font("Pretendard-Medium", 28), fill: .white,
                        stroke: .black, strokePct: 9, glow: 4)
    case .outro:
        return outlined(c.text, font: font("BookkMyungjo-Bd", 84), fill: cream,
                        stroke: NSColor(white: 0.08, alpha: 1), strokePct: 9, glow: 18, kern: -1)
    case .series:
        return outlined(c.text, font: font("Pretendard-SemiBold", 34), fill: .white,
                        stroke: .black, strokePct: 10, glow: 8)
    }
}

// center y measured from top, as a fraction of height
func centerY(_ c: Cap) -> CGFloat {
    switch c.style {
    case .series: return 0.125
    case .outro: return 0.50
    case .title: return 0.235
    case .main: return c.text.contains("\n") ? 0.625 : 0.64
    case .box, .cute, .lead, .gloss: return 0.705
    case .price: return 0.775
    case .note: return 0.800
    }
}

let hookLines: [(String, String, CGFloat, NSColor, CGFloat)] = [
    ("[저장 필수]", "Pretendard-ExtraBold", 60, yellow, -1),
    (HOOK_LINE1, titleFont, 86, .white, -3),
    (HOOK_LINE2, titleFont, 88, yellow, -3),
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

// thumbnail brightness: THUMB_DIM = darkening over the photo (0~1), THUMB_EV = exposure boost of the photo
let thumbDim = CGFloat(Double(env["THUMB_DIM"] ?? "") ?? 0.38)
let thumbEV = Double(env["THUMB_EV"] ?? "") ?? 0
func brightened(_ img: CGImage) -> CGImage {
    guard thumbEV != 0, let f = CIFilter(name: "CIExposureAdjust") else { return img }
    f.setValue(CIImage(cgImage: img), forKey: kCIInputImageKey)
    f.setValue(thumbEV, forKey: kCIInputEVKey)
    return CIContext().createCGImage(f.outputImage!, from: CIImage(cgImage: img).extent)!
}

let hookCharCount = hookLines.reduce(0) { $0 + $1.0.count }
// typewriter timing: first character at 0.15s, one every 0.05s; hook shown until HOOK_END
let typeStart = 0.15, perChar = 0.05, hookEnd = HOOK_END

// 3-tier hook text. thumbnail: above the plush toys; video intro: screen center.
// visible: how many characters are typed so far (typewriter); lines stay left-anchored so text does not shift.
func hookImage(background: CGImage?, centered: Bool, visible: Int = Int.max, dim: Bool = true, tag: Bool = false) -> CGImage {
    return bitmap(Int(W), Int(H)) { ctx in
        if let bg = background { ctx.draw(brightened(bg), in: CGRect(x: 0, y: 0, width: W, height: H)) }
        if dim && !centered {
            let grad = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                                  colors: [NSColor.black.withAlphaComponent(0.62).cgColor,
                                           NSColor.black.withAlphaComponent(0.45).cgColor,
                                           NSColor.black.withAlphaComponent(0).cgColor] as CFArray,
                                  locations: [0, 0.55, 1])!
            ctx.drawLinearGradient(grad, start: CGPoint(x: 0, y: H), end: CGPoint(x: 0, y: H * 0.55), options: [])
        } else if dim {
            ctx.setFillColor(NSColor.black.withAlphaComponent(thumbDim).cgColor)
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
            let tag = NSAttributedString(string: THUMB_TAG, attributes: [
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
// 소리: 기본은 원본 소리(+엔딩 구간 소리). SFX=1이면 원본 소리를 빼고 합성 효과음만 넣는다.
// SFX=capcut: 사용자가 캡컷에서 고른 효과음(assets/sfx/)을 1탄과 같은 규칙으로 배치. SFX=1: 합성 효과음(안 씀)
let sfxMode = env["SFX"] ?? ""
let useSFX = sfxMode == "1"
let useCapcut = sfxMode == "capcut"
if sfxMode.isEmpty, let aSrc = asset.tracks(withMediaType: .audio).first {
    let aTrack = comp.addMutableTrack(withMediaType: .audio, preferredTrackID: kCMPersistentTrackID_Invalid)!
    try! aTrack.insertTimeRange(CMTimeRange(start: .zero, duration: aSrc.timeRange.duration), of: aSrc, at: .zero)
    try! aTrack.insertTimeRange(CMTimeRange(start: CMTime(seconds: OUTRO_FROM, preferredTimescale: 600),
                                            duration: CMTime(seconds: OUTRO_LEN, preferredTimescale: 600)),
                                of: aSrc, at: range.duration)
}
let outroStart = CMTimeGetSeconds(range.duration)
try! vTrack.insertTimeRange(CMTimeRange(start: CMTime(seconds: OUTRO_FROM, preferredTimescale: 600),
                                        duration: CMTime(seconds: OUTRO_LEN, preferredTimescale: 600)),
                            of: vSrc, at: range.duration)
let total = CMTimeRange(start: .zero, duration: comp.duration)

// MARK: - CapCut sound effects (clips cut from the user's CapCut edit of 1탄, 2026-10-25)
if useCapcut {
    let sfxDir = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
        .appendingPathComponent("../../assets/sfx").standardized
    // every clip goes on ONE audio track (separate tracks stay unmixed in the MP4 and players play only the first)
    var events: [(String, Double)] = []
    func place(_ name: String, at t: Double) { events.append((name, max(0, t))) }
    // 1) 타자기: 오프닝 내내
    place("typing", at: 0.05)
    // 2) 클릭: 제품 번호가 바뀔 때
    let titles = caps.filter { $0.style == .title }.sorted { $0.start < $1.start }
    for c in titles { place("click", at: c.start) }
    // 3) 전환음: 제품 사이에 빈 화면(0.3초 이상 틈)이 있을 때, 앞 제품이 끝나기 직전
    for (a, b) in zip(titles, titles.dropFirst()) where b.start - a.end >= 0.3 { place("transition", at: a.end - 0.3) }
    // 4) 딩: 첫 노랑 강조 자막
    if let first = caps.filter({ $0.style == .box }).min(by: { $0.start < $1.start }) { place("ding", at: first.start) }
    // 5) 엔딩 음
    place("outro", at: outroStart + 0.2)

    let sfxTrack = comp.addMutableTrack(withMediaType: .audio, preferredTrackID: kCMPersistentTrackID_Invalid)!
    let sorted = events.sorted { $0.1 < $1.1 }
    for (k, e) in sorted.enumerated() {
        let clip = AVURLAsset(url: sfxDir.appendingPathComponent("\(e.0).m4a"))
        guard let src = clip.tracks(withMediaType: .audio).first else { fatalError("missing sfx: \(e.0)") }
        let at = CMTime(seconds: e.1, preferredTimescale: 600)
        // trim so a clip never runs into the next one or past the video end
        let next = k + 1 < sorted.count ? CMTime(seconds: sorted[k + 1].1, preferredTimescale: 600) : total.duration
        let dur = min(src.timeRange.duration, next - at)
        guard dur > .zero else { continue }
        try! sfxTrack.insertTimeRange(CMTimeRange(start: .zero, duration: dur), of: src, at: at)
    }
}

if useSFX {
    // MARK: - sound effects (synthesized like apps/shorts-editor/sfx.js, no files or licenses needed)

    let SR = 48000.0
    var mix = [Float](repeating: 0, count: Int(CMTimeGetSeconds(total.duration) * SR) + 1)

    func envAt(_ t: Double, attack: Double, peak: Double, decay: Double) -> Double {
        if t < 0 { return 0 }
        if t < attack { return 0.0001 * pow(peak / 0.0001, t / attack) }
        let d = t - attack
        if d > decay { return 0 }
        return peak * pow(0.0001 / peak, d / decay)
    }
    func tone(at t0: Double, square: Bool = false, f0: Double, f1: Double? = nil, dur: Double,
              attack: Double = 0.003, peak: Double = 0.5) {
        let start = Int(t0 * SR), n = Int((attack + dur + 0.05) * SR)
        var phase = 0.0
        for i in 0..<n where start + i < mix.count {
            let t = Double(i) / SR
            var f = f0
            if let f1 = f1 { f = f0 * pow(f1 / f0, min(1, t / (dur * 0.6))) }
            phase += 2 * .pi * f / SR
            let v = square ? (sin(phase) >= 0 ? 1.0 : -1.0) : sin(phase)
            mix[start + i] += Float(v * envAt(t, attack: attack, peak: peak, decay: dur))
        }
    }
    // RBJ biquad on white noise
    func noise(at t0: Double, dur: Double, highpass: Bool = false, freq: Double, q: Double = 1,
               attack: Double = 0.002, peak: Double = 0.5) {
        let w = 2 * .pi * freq / SR, alpha = sin(w) / (2 * q), cw = cos(w)
        var b0, b1, b2: Double
        if highpass { b0 = (1 + cw) / 2; b1 = -(1 + cw); b2 = (1 + cw) / 2 }
        else { b0 = alpha; b1 = 0; b2 = -alpha }
        let a0 = 1 + alpha, a1 = -2 * cw, a2 = 1 - alpha
        var x1 = 0.0, x2 = 0.0, y1 = 0.0, y2 = 0.0
        let start = Int(t0 * SR), n = Int((attack + dur + 0.05) * SR)
        for i in 0..<n where start + i < mix.count {
            let x = Double.random(in: -1...1)
            let y = (b0 * x + b1 * x1 + b2 * x2 - a1 * y1 - a2 * y2) / a0
            x2 = x1; x1 = x; y2 = y1; y1 = y
            mix[start + i] += Float(y * envAt(Double(i) / SR, attack: attack, peak: peak, decay: dur))
        }
    }
    func sfxClick(_ t: Double) {
        noise(at: t, dur: 0.018, highpass: true, freq: 3500, peak: 0.7)
        tone(at: t, f0: 2400, dur: 0.025, peak: 0.25)
    }
    func sfxKey(_ t: Double, _ k: Int) {
        let p = 0.4 + Double(k % 3) * 0.1
        noise(at: t, dur: 0.025, freq: 2800 + Double(k % 4) * 400, q: 2, peak: p)
        tone(at: t, f0: 140, dur: 0.035, peak: p * 0.5)
    }
    func sfxDing(_ t: Double) {
        for (f, p) in [(1568.0, 0.45), (3136.0, 0.15), (4704.0, 0.06), (2352.0, 0.08)] {
            tone(at: t, f0: f, dur: 2.0, attack: 0.002, peak: p * 0.8)
        }
    }
    func sfxCoin(_ t: Double) {
        tone(at: t, square: true, f0: 988, dur: 0.07, peak: 0.3)
        tone(at: t + 0.075, square: true, f0: 1319, dur: 0.5, peak: 0.3)
    }

    // 1) 타자기: 오프닝 글자마다  2) 클릭: 제품 번호 바뀔 때  3) 딩: 노랑 강조  4) 코인: 엔딩 문구
    for n in 1...hookCharCount { sfxKey(typeStart + Double(n - 1) * perChar, n) }
    for c in caps where c.style == .title { sfxClick(c.start) }
    for c in caps where c.style == .box || c.style == .cute { sfxDing(c.start) }
    sfxCoin(outroStart + 0.1)

    // soft limit so overlapping sounds don't clip
    let peakAbs = mix.map { abs($0) }.max() ?? 1
    if peakAbs > 0.95 { let g = 0.95 / peakAbs; for i in mix.indices { mix[i] *= g } }

    let sfxURL = URL(fileURLWithPath: NSTemporaryDirectory() + "haul_sfx.caf")
    try? FileManager.default.removeItem(at: sfxURL)
    let fmt = AVAudioFormat(standardFormatWithSampleRate: SR, channels: 1)!
    let buf = AVAudioPCMBuffer(pcmFormat: fmt, frameCapacity: AVAudioFrameCount(mix.count))!
    buf.frameLength = AVAudioFrameCount(mix.count)
    mix.withUnsafeBufferPointer { buf.floatChannelData![0].update(from: $0.baseAddress!, count: mix.count) }
    do {
        let file = try AVAudioFile(forWriting: sfxURL, settings: fmt.settings)
        try file.write(from: buf)
    }
    let sfxAsset = AVURLAsset(url: sfxURL)
    let sfxSrc = sfxAsset.tracks(withMediaType: .audio)[0]
    let sfxTrack = comp.addMutableTrack(withMediaType: .audio, preferredTrackID: kCMPersistentTrackID_Invalid)!
    try! sfxTrack.insertTimeRange(CMTimeRange(start: .zero, duration: min(sfxSrc.timeRange.duration, total.duration)),
                                  of: sfxSrc, at: .zero)
}

let gen = AVAssetImageGenerator(asset: asset)
gen.appliesPreferredTrackTransform = true
gen.requestedTimeToleranceBefore = .zero
gen.requestedTimeToleranceAfter = .zero
// 2.4s: 치이카와·모몽가·하치와레 얼굴이 모두 보이는 전체샷
let thumbT = Double(env["THUMB_T"] ?? "") ?? 2.4  // 덜 흔들린 프레임은 sharp 순위로 고른다
let thumbBg = try? gen.copyCGImage(at: CMTime(seconds: thumbT, preferredTimescale: 600), actualTime: nil)
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

// hook: same text as the thumbnail, over the video, 0 ~ hookEnd
// hook: dim layer + typewriter text (one character every 0.05s), 0 ~ hookEnd
let full = CGRect(x: 0, y: 0, width: W, height: H)
// dim as a plain color layer (no full-screen bitmap)
let dimLayer = CALayer()
dimLayer.frame = full
dimLayer.backgroundColor = NSColor.black.withAlphaComponent(0.38).cgColor
dimLayer.opacity = 0
let dimAnim = CAKeyframeAnimation(keyPath: "opacity")
dimAnim.values = [1, 1, 0]
dimAnim.keyTimes = [0, NSNumber(value: (hookEnd - 0.1) / hookEnd), 1]
dimAnim.beginTime = AVCoreAnimationBeginTimeAtZero
dimAnim.duration = hookEnd
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
typeFade.keyTimes = [0, NSNumber(value: (hookEnd - 0.1) / hookEnd), 1]
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
// outro: dim + stars + closing line over the group shot
let outroEnd = outroStart + OUTRO_LEN
addTimed(bitmap(Int(W), Int(H)) { ctx in
    ctx.setFillColor(NSColor.black.withAlphaComponent(0.38).cgColor); ctx.fill(full)
    drawStickers(ctx)
}, frame: full, start: outroStart, end: outroEnd, fadeIn: 0.15, fadeOut: 0.01)
let outroCap = Cap(start: outroStart, end: outroEnd, text: OUTRO_TEXT, style: .outro)
addTimed(capImage(outroCap), frame: layerFrame(outroCap, capImage(outroCap)), start: outroStart + 0.1, end: outroEnd,
         fadeIn: 0.2, fadeOut: 0.01)

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
    if [.box, .cute, .gloss].contains(c.style), let m = mains.first(where: { $0.0.start <= c.start && c.start < $0.0.end }) {
        f.origin.y = m.1.minY + 24 + 24 - 6 - f.height
    }
    // lead: small line right above the main caption (e.g. "(11월에 출장 가는데)")
    if c.style == .lead, let m = mains.first(where: { $0.0.start <= c.start && c.start < $0.0.end }) {
        f.origin.y = m.1.maxY - 24 - 24 + 6
    }
    addTimed(img, frame: f, start: c.start, end: c.end)
}

let vc = AVMutableVideoComposition()
vc.renderSize = CGSize(width: W, height: H)
vc.frameDuration = CMTime(value: 1, timescale: 30)
let inst = AVMutableVideoCompositionInstruction()
inst.timeRange = total
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
let hook = Cap(start: 0, end: HOOK_END, text: "[저장 필수]\n\(HOOK_LINE1)\n\(HOOK_LINE2)", style: .title)
save("자막_제품명.srt", [hook] + caps.filter { $0.style == .title || $0.style == .series })
save("자막_메인.srt", caps.filter { $0.style == .main })
save("자막_강조.srt", caps.filter { [.box, .cute, .lead, .gloss].contains($0.style) })
save("자막_가격.srt", caps.filter { $0.style == .price || $0.style == .note })
