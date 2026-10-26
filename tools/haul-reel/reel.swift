import AVFoundation
import AppKit
import CoreText
import QuartzCore
import CoreImage
import ImageIO
import UniformTypeIdentifiers
import Vision

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
// chip: ordihome-style flat color strip behind dark text (matcha green for the 2탄 말차 line)
let chipBg = NSColor(red: 0.78, green: 0.91, blue: 0.60, alpha: 1)
let chipInk = NSColor(red: 0.12, green: 0.16, blue: 0.08, alpha: 1)

// MARK: - caption timeline

enum Style { case title, main, box, cute, lead, chip, gloss, price, note, series, outro }
struct Cap { let start: Double; let end: Double; let text: String; let style: Style }

// ===== 회차 데이터: 자라 맨즈 아우터 (162 출근룩) v6 — 제목 "이건 사지 마세요..", 대본 v2 =====
// 이전 회차: output/261025/reels_돈키호테 추천템 1탄/reel_1탄.swift, output/261025/reels_돈키호테 추천템 2탄/reel_2탄.swift
let END = 23.9
// 오프닝(훅) 길이: 1~4번 착장 전신 숏컷(0.8초씩) 위에 훅 문구. 다 쳐진 뒤 2초 가까이 머문다
let HOOK_END = 3.2
// 타자기 속도: 한 글자 간격(초)
let HOOK_PER_CHAR = 0.04
// 엔딩: 버건디 전신 컷(3.2~4.6)을 한 번 더 붙이고 댓글 유도 문구
let OUTRO_FROM = 3.2, OUTRO_LEN = 1.5
// true: 엔딩을 따로 붙이지 않고 컷편집본의 마지막 OUTRO_LEN초(이어지는 장면) 위에 엔딩 문구를 띄운다. OUTRO_FROM은 안 씀
let OUTRO_INLINE = true
let OUTRO_TEXT = "댓글에 '자라' 남겨주시면"
// 엔딩 큰 글씨 위에 작게 붙는 줄 ("" = 없음)
let OUTRO_LEAD = ""
// 엔딩 큰 글씨 밑에 작게 붙는 줄 ("" = 없음, "\n" = 줄바꿈)
let OUTRO_TAIL = "영상 속 제품 정보, 착용 사이즈까지\n정리해서 보내드릴게요 💌"
// 엔딩 글자 크기: 큰 줄 / 위 작은 줄 (하울 릴스: 84 / 54)
let OUTRO_SIZE: CGFloat = 70, OUTRO_LEAD_SIZE: CGFloat = 40
// 훅 맨 윗줄 (작은 태그). 하울 릴스는 "[저장 필수]", 패션 릴스는 고정 타겟 키워드
let HOOK_TAG = ""  // "" = 태그 없음
// true: 태그를 작은 알약 모양 배경에 넣어 큰 제목 바로 위에 붙인다, false: 큰 노랑 글자 (하울 릴스)
let HOOK_TAG_CHIP = true
// 알약 배경 (훅 태그·맨 위 시리즈 라벨): 흰 배경 + 먹색 글자. 오프닝에선 태그가 왼쪽부터 닦이듯 그라데이션으로 들어온다
let PILL_BG = NSColor(white: 1, alpha: 0.92), PILL_INK = NSColor(white: 0.1, alpha: 1)
// 알약 모서리 둥글기 (0 = 네모, 높이의 절반 = 완전 둥근 알약)
let PILL_RADIUS: CGFloat = 0
// 오프닝 큰 제목 글꼴 (썸네일은 THUMB_FONT로 따로 고를 수 있다)
let HOOK_FONT = "BookkMyungjo-Bd"
// 오프닝 큰 제목 첫 줄 높이 (화면 위에서부터 비율). 0.41이면 태그가 전신 컷의 가슴 높이에 온다 (하울 릴스: 0.495)
let HOOK_LINE1_Y: CGFloat = 0.41
// 썸네일 로고 글자 ("" = 없음). 머리 위에 크게, Didot 글꼴. 사람을 따로 오려 로고 위에 얹어 머리가 로고를 살짝 가린다
let THUMB_LOGO = "ZARA"
let THUMB_LOGO_COLOR = NSColor.black
// 오프닝(0~HOOK_END) 동안 로고를 머리 바로 뒤에 고정 (썸네일처럼 프레임마다 사람을 오려 머리가 로고를 가린다)
// 높이는 오프닝 컷들의 머리 꼭대기(0.12~0.18)에 맞춤. 1번 제품이 시작되면 사라진다
let VIDEO_LOGO = true, VIDEO_LOGO_Y: CGFloat = 0.13, VIDEO_LOGO_WIDTH: CGFloat = 0.86
// 썸네일 큰 제목: "" = 오프닝과 같은 두 줄. 값이 있으면 썸네일만 이 문구로 ("/" = 줄바꿈, 둘째 줄이 더 크다)
let THUMB_TITLE = "자라 맨즈 아우터/이건 사지 마세요.."
// 썸네일 제목 첫 줄 높이 (화면 위에서부터 비율, 가운데 기준). 0 = 오프닝 문구와 같은 높이
let THUMB_TITLE_Y: CGFloat = 0.43
// 썸네일에 훅 태그(고정 타겟 키워드)를 넣을지
let THUMB_SHOW_TAG = false
// 썸네일 큰 제목 글꼴 (환경변수 THUMB_FONT가 있으면 그게 우선)
let THUMB_FONT_NAME = "BookkMyungjo-Bd"
// 오프닝 큰 제목 두 줄 (첫 줄 작게, 둘째 줄 크게 — 썸네일과 같은 모양)
let HOOK_LINE1 = "자라 맨즈 아우터", HOOK_LINE2 = "이건 사지 마세요.."
let HOOK_LINE1_SIZE: CGFloat = 56, HOOK_LINE2_SIZE: CGFloat = 100
let HOOK_LINE2_COLOR = NSColor.white
// 오프닝 큰 제목 밑에 작게 붙는 줄 ("" = 없음). 얇고 귀여운 손글씨
let HOOK_LINE3 = "저만 입고싶으니까..", HOOK_LINE3_FONT = "YoonChildfundkoreaManSeh"
// 별·점 스티커 (썸네일·오프닝·엔딩). 하울 릴스에만 쓴다
let STICKERS = false
// 글꼴: 훅 큰 제목·엔딩 문구 / 메인 자막 (하울 릴스: BookkMyungjo-Bd / Pretendard-SemiBold)
let DISPLAY_FONT = "Pretendard-SemiBold", MAIN_FONT = "Pretendard-Medium"
// true: 제품명을 위쪽 큰 명조 대신 아래쪽 작은 글씨로 (패션 피팅 영상). 이때 제품명 줄에 가격을 같이 쓴다
let TITLE_BOTTOM = true
// true: 맨 위 시리즈 라벨을 색 배경 띠로
let SERIES_CHIP = true
// 맨 위 시리즈 라벨 ("" = 없음)
let SERIES_LABEL = ""
// 제품명·가격 줄 높이 (화면 위에서부터 비율). TITLE_BOTTOM일 때 0.775 = 아래쪽, 0.125 = 맨 위 라벨 자리
let TITLE_Y: CGFloat = 0.125
let THUMB_TAG = "두툼한 초겨울 아우터 모음zip."
// true: 썸네일 꼬리표를 네모 배경 띠로 (THUMB_TAG_Y 높이, THUMB_TAG_BG 색), false: 제목 밑 손글씨
let THUMB_TAG_CHIP = true, THUMB_TAG_Y: CGFloat = 0.545
let THUMB_TAG_BG = NSColor(red: 0.62, green: 0.90, blue: 0.84, alpha: 1)
let caps: [Cap] = (SERIES_LABEL.isEmpty ? [] : [Cap(start: HOOK_END, end: END, text: SERIES_LABEL, style: .series)]) + [

    // 1. 버건디 퀼팅 재킷 (3.2~9.3)
    Cap(start: 3.2, end: 9.3, text: "릴렉스핏 퀼팅 재킷 | 149,900원", style: .title),
    Cap(start: 3.2, end: 7.0, text: "톤다운된 버건디 컬러로\n늦가을 분위기 끝", style: .main),
    Cap(start: 7.0, end: 9.3, text: "안에 퀼팅 안감이\n도톰하게 들어있어서", style: .main),
    Cap(start: 7.3, end: 9.3, text: "초가을 말고 지금 입기 딱!", style: .box),

    // 2. 바버맛 퀼팅 재킷 (9.3~14.3)
    Cap(start: 9.3, end: 14.3, text: "콤비 기하학적 퀼팅 재킷 | 109,900원", style: .title),
    Cap(start: 9.3, end: 11.4, text: "10만원대 바버맛 퀼팅 자켓 실존", style: .main),
    Cap(start: 11.4, end: 14.3, text: "카라랑 소매는 코듀로이", style: .main),
    Cap(start: 11.9, end: 14.3, text: "디테일까지 바버 맛..", style: .box),

    // 3. 페이크 레더 재킷 (14.3~19.1)
    Cap(start: 14.3, end: 19.1, text: "릴렉스핏 페이크 레더 | 149,900원", style: .title),
    Cap(start: 14.3, end: 16.3, text: "일잘러 출근룩 필수템\n블랙 레더 재킷", style: .main),
    Cap(start: 16.3, end: 19.1, text: "엉덩이 덮는 기장이라", style: .main),
    Cap(start: 16.6, end: 19.1, text: "와이드 팬츠랑 찰떡", style: .box),

    // 4. 코튼 100% 숏 파카 (19.1~23.9, 엔딩 23.9~25.4는 숄더백 컷이 이어짐)
    Cap(start: 19.1, end: END, text: "코튼 100% 숏 파카 | 139,900원", style: .title),
    Cap(start: 19.1, end: 20.3, text: "화사한 베이지 컬러 야상", style: .main),
    Cap(start: 20.3, end: 21.5, text: "허리 스트링으로 핏 조절 가능하고", style: .main),
    Cap(start: 21.5, end: END, text: "체크 안감 포인트가 너무 예쁨", style: .main),
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

func boxed(_ text: String, font f: NSFont, color: NSColor, box: NSColor, padX: CGFloat, padY: CGFloat, radius: CGFloat = 0) -> CGImage {
    let attr = NSAttributedString(string: text, attributes: [
        .font: f, .foregroundColor: color, .paragraphStyle: para(), .kern: -0.5])
    let size = attr.boundingRect(with: CGSize(width: W - 120, height: 2000),
                                 options: [.usesLineFragmentOrigin, .usesFontLeading]).size
    let bw = ceil(size.width + padX * 2), bh = ceil(size.height + padY * 2)
    return bitmap(Int(bw), Int(bh)) { ctx in
        ctx.setFillColor(box.cgColor)
        let r = CGRect(x: 0, y: 0, width: bw, height: bh)
        let rad = min(radius, bh / 2)
        ctx.addPath(CGPath(roundedRect: r, cornerWidth: rad, cornerHeight: rad, transform: nil)); ctx.fillPath()
        attr.draw(with: CGRect(x: padX, y: padY, width: size.width, height: size.height),
                  options: [.usesLineFragmentOrigin, .usesFontLeading])
    }
}

func capImage(_ c: Cap) -> CGImage {
    switch c.style {
    case .title:
        if TITLE_BOTTOM {
            return outlined(c.text, font: font("Pretendard-Medium", 34), fill: .white,
                            stroke: .black, strokePct: 9, glow: 4)
        }
        return outlined(c.text, font: font("BookkMyungjo-Bd", 72), fill: cream,
                        stroke: NSColor(white: 0.08, alpha: 1), strokePct: 9, glow: 16, kern: -1)
    case .main:
        return outlined(c.text, font: font(MAIN_FONT, 52), fill: .white,
                        stroke: .black, strokePct: 11, glow: 10)
    case .box:
        return outlined(c.text, font: font("YoonChildfundkoreaDaeHan", 62), fill: yellow,
                        stroke: .black, strokePct: 12, glow: 10, kern: 0)
    case .cute, .lead:
        return outlined(c.text, font: font("YoonChildfundkoreaDaeHan", 46), fill: yellow,
                        stroke: .black, strokePct: 12, glow: 8, kern: 0)
    case .chip:
        return boxed(c.text, font: font("Pretendard-SemiBold", 40), color: chipInk, box: chipBg, padX: 22, padY: 10)
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
        return outlined(c.text, font: font(DISPLAY_FONT, OUTRO_SIZE), fill: cream,
                        stroke: NSColor(white: 0.08, alpha: 1), strokePct: 9, glow: 18, kern: -1)
    case .series:
        if SERIES_CHIP {
            return boxed(c.text, font: font("Pretendard-Medium", 30), color: PILL_INK, box: PILL_BG, padX: 22, padY: 8, radius: PILL_RADIUS)
        }
        return outlined(c.text, font: font("Pretendard-SemiBold", 34), fill: .white,
                        stroke: .black, strokePct: 10, glow: 8)
    }
}

// center y measured from top, as a fraction of height
func centerY(_ c: Cap) -> CGFloat {
    switch c.style {
    case .series: return 0.125
    case .outro: return 0.50
    case .title: return TITLE_BOTTOM ? TITLE_Y : 0.235
    case .main: return c.text.contains("\n") ? 0.625 : 0.64
    case .box, .cute, .lead, .chip, .gloss: return 0.705
    case .price: return 0.775
    case .note: return 0.800
    }
}

let hookLines: [(String, String, CGFloat, NSColor, CGFloat)] = [
    HOOK_TAG_CHIP ? (HOOK_TAG, "Pretendard-Medium", 34, PILL_INK, 0) : (HOOK_TAG, "Pretendard-ExtraBold", 60, yellow, -1),
    (HOOK_LINE1, HOOK_FONT, HOOK_LINE1_SIZE, .white, -2),
    (HOOK_LINE2, HOOK_FONT, HOOK_LINE2_SIZE, HOOK_LINE2_COLOR, -3),
] + (HOOK_LINE3.isEmpty ? [] : [(HOOK_LINE3, HOOK_LINE3_FONT, 50, NSColor.white, 0)])
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

// pill tag is not typed (it wipes in), so only the big lines count
let hookCharCount = hookLines.enumerated().reduce(0) { $0 + (HOOK_TAG_CHIP && $1.offset == 0 ? 0 : $1.element.0.count) }
// pill tag wipe-in: starts at TAG_WIPE_START, takes TAG_WIPE_LEN; typing of the big lines starts after it
let TAG_WIPE_START = 0.1, TAG_WIPE_LEN = 0.45
// typewriter timing: first character at 0.15s, one every 0.05s; hook shown until HOOK_END
let typeStart = HOOK_TAG_CHIP && !HOOK_TAG.isEmpty ? TAG_WIPE_START + TAG_WIPE_LEN : 0.15, perChar = HOOK_PER_CHAR, hookEnd = HOOK_END

// 3-tier hook text. thumbnail: above the plush toys; video intro: screen center.
// visible: how many characters are typed so far (typewriter); lines stay left-anchored so text does not shift.
// hook line y positions (center, fraction from top); the small pill tag sits right on top of the first big line
func hookYs(centered: Bool) -> [CGFloat] {
    // lines stack down from the first big line by their own heights; the tag sits on top of the first big line
    let hs = hookLines.map { NSAttributedString(string: $0.0, attributes: [.font: font($0.1, $0.2)]).size().height }
    var ys = [CGFloat](repeating: 0, count: hookLines.count)
    ys[1] = centered ? HOOK_LINE1_Y : 0.225
    for i in 2..<hookLines.count { ys[i] = ys[i - 1] + (hs[i - 1] / 2 + hs[i] / 2 + 6) / H }
    ys[0] = ys[1] - (hs[1] / 2 + hs[0] / 2 + (HOOK_TAG_CHIP ? 26 : 10)) / H
    return ys
}
// pill tag: text + rounded background rect, in bitmap coordinates (bottom-left origin)
func tagPill(centered: Bool) -> (text: NSAttributedString, origin: CGPoint, rect: CGRect) {
    let l = hookLines[0]
    let text = NSAttributedString(string: l.0, attributes: [.font: font(l.1, l.2), .foregroundColor: l.3,
                                                            .paragraphStyle: para(lineSpacing: 0), .kern: l.4])
    let full = text.size()
    let origin = CGPoint(x: (W - full.width) / 2, y: H - hookYs(centered: centered)[0] * H - full.height / 2)
    return (text, origin, CGRect(x: origin.x - 22, y: origin.y - 8, width: full.width + 44, height: full.height + 16))
}
func drawPill(_ ctx: CGContext, _ r: CGRect) {
    let rad = min(PILL_RADIUS, r.height / 2)
    ctx.addPath(CGPath(roundedRect: r, cornerWidth: rad, cornerHeight: rad, transform: nil))
    ctx.setFillColor(PILL_BG.cgColor); ctx.fillPath()
}

// brand wordmark (Didot, letters pulled tight like the ZARA logo), about 86% of the width, near the top
func drawLogo(_ ctx: CGContext, y: CGFloat = THUMB_LOGO_Y, widthFrac: CGFloat = 0.86) {
    var size: CGFloat = 400
    func attr(_ sz: CGFloat) -> NSAttributedString {
        NSAttributedString(string: THUMB_LOGO, attributes: [.font: font("Didot", sz), .foregroundColor: THUMB_LOGO_COLOR, .kern: -sz * 0.06])
    }
    while attr(size).size().width > W * widthFrac { size -= 4 }
    let a = attr(size), sz = a.size()
    a.draw(at: CGPoint(x: (W - sz.width) / 2, y: H - y * H - sz.height / 2))
}
// 로고 높이 (화면 위에서부터 비율, 가운데 기준)
let THUMB_LOGO_Y = CGFloat(Double(env["THUMB_LOGO_Y"] ?? "") ?? 0.19)
// person segmentation (Vision) as a grayscale clip mask, scaled to the frame
func personMask(_ img: CGImage) -> CGImage? {
    let req = VNGeneratePersonSegmentationRequest()
    req.qualityLevel = .accurate
    req.outputPixelFormat = kCVPixelFormatType_OneComponent8
    do { try VNImageRequestHandler(cgImage: img).perform([req]) } catch { print("person mask failed: \(error)"); return nil }
    guard let buf = req.results?.first?.pixelBuffer else { return nil }
    let ci = CIImage(cvPixelBuffer: buf)
    let scaled = ci.transformed(by: CGAffineTransform(scaleX: W / ci.extent.width, y: H / ci.extent.height))
    guard let rgb = CIContext().createCGImage(scaled, from: CGRect(x: 0, y: 0, width: W, height: H)) else { return nil }
    // clip(to:mask:) wants a gray image
    return bitmapGray(Int(W), Int(H)) { $0.draw(rgb, in: CGRect(x: 0, y: 0, width: W, height: H)) }
}
func bitmapGray(_ w: Int, _ h: Int, _ draw: (CGContext) -> Void) -> CGImage {
    let ctx = CGContext(data: nil, width: w, height: h, bitsPerComponent: 8, bytesPerRow: 0,
                        space: CGColorSpaceCreateDeviceGray(), bitmapInfo: CGImageAlphaInfo.none.rawValue)!
    draw(ctx)
    return ctx.makeImage()!
}

// skipTag: leave the pill tag out (the video draws it as its own wipe-in layer)
func hookImage(background: CGImage?, centered: Bool, visible: Int = Int.max, dim: Bool = true, tag: Bool = false, skipTag: Bool = false) -> CGImage {
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
        // thumbnail only: brand wordmark over the head, then the person cut out and laid back on top
        if tag && !THUMB_LOGO.isEmpty, let bg = background {
            drawLogo(ctx)
            if let mask = personMask(bg) {
                ctx.saveGState()
                ctx.clip(to: CGRect(x: 0, y: 0, width: W, height: H), mask: mask)
                ctx.draw(brightened(bg), in: CGRect(x: 0, y: 0, width: W, height: H))
                if dim { ctx.setFillColor(NSColor.black.withAlphaComponent(thumbDim).cgColor); ctx.fill(CGRect(x: 0, y: 0, width: W, height: H)) }
                ctx.restoreGState()
            }
        }

        let shadow = NSShadow()
        shadow.shadowColor = NSColor.black.withAlphaComponent(0.7)
        shadow.shadowBlurRadius = 22
        shadow.shadowOffset = CGSize(width: 0, height: -4)

        let ys = hookYs(centered: centered)
        var left = visible
        for (i, l) in hookLines.enumerated() {
            if i == 0 && HOOK_TAG_CHIP {
                if !skipTag && !HOOK_TAG.isEmpty && !(tag && !THUMB_SHOW_TAG) { let p = tagPill(centered: centered); drawPill(ctx, p.rect); p.text.draw(at: p.origin) }
                continue
            }
            // thumbnail: big lines in the thumbnail font; a THUMB_TITLE replaces both lines with one
            let lineFont = tag ? (env["THUMB_FONT"] ?? THUMB_FONT_NAME) : l.1
            if tag && !THUMB_TITLE.isEmpty {
                if i == 1 {
                    // up to two lines; the second (the punch line) is bigger. Each shrinks to fit the width.
                    let parts = THUMB_TITLE.split(separator: "/").map { $0.trimmingCharacters(in: .whitespaces) }
                    let sizes: [CGFloat] = parts.count > 1 ? [56, 112] : [l.2]
                    let y0 = THUMB_TITLE_Y > 0 ? THUMB_TITLE_Y : ys[1] - 0.035
                    let lineYs: [CGFloat] = parts.count > 1 ? [y0, y0 + 0.058] : [THUMB_TITLE_Y > 0 ? THUMB_TITLE_Y : ys[1]]
                    for (k, text) in parts.enumerated() {
                        var size = sizes[k]
                        while NSAttributedString(string: text, attributes: [.font: font(lineFont, size), .kern: l.4]).size().width > W - 100 { size -= 2 }
                        let one = NSAttributedString(string: text, attributes: [
                            .font: font(lineFont, size), .foregroundColor: NSColor.white, .shadow: shadow,
                            .paragraphStyle: para(lineSpacing: 0), .kern: l.4])
                        let sz = one.size()
                        one.draw(at: CGPoint(x: (W - sz.width) / 2, y: H - lineYs[k] * H - sz.height / 2))
                    }
                }
                continue
            }
            let attrs: [NSAttributedString.Key: Any] = [
                .font: font(lineFont, l.2), .foregroundColor: l.3, .shadow: shadow,
                .paragraphStyle: para(lineSpacing: 0), .kern: l.4]
            let full = NSAttributedString(string: l.0, attributes: attrs).size()
            let shown = String(l.0.prefix(max(0, left)))
            left -= l.0.count
            if shown.isEmpty { continue }
            let origin = CGPoint(x: (W - full.width) / 2, y: H - ys[i] * H - full.height / 2)
            NSAttributedString(string: shown, attributes: attrs).draw(at: origin)
        }
        // thumbnail only: star stickers around the edges (kockc.o style) + small cute tag
        if tag && STICKERS { drawStickers(ctx) }
        if tag && THUMB_TAG_CHIP {
            let t = NSAttributedString(string: THUMB_TAG, attributes: [.font: font("Pretendard-Medium", 30), .foregroundColor: PILL_INK])
            let sz = t.size()
            let origin = CGPoint(x: (W - sz.width) / 2, y: H - THUMB_TAG_Y * H - sz.height / 2)
            ctx.setFillColor(THUMB_TAG_BG.cgColor)
            ctx.fill(CGRect(x: origin.x - 18, y: origin.y - 8, width: sz.width + 36, height: sz.height + 16))
            t.draw(at: origin)
        } else if tag {
            let tag = NSAttributedString(string: THUMB_TAG, attributes: [
                .font: font("YoonChildfundkoreaDaeHan", 54), .foregroundColor: NSColor.white, .shadow: shadow])
            let sz = tag.size()
            let tagY = THUMB_TITLE.isEmpty ? ys[2] + 0.06 : THUMB_TITLE.contains("/") ? ys[1] + 0.1 : ys[1] + 0.06
            tag.draw(at: CGPoint(x: (W - sz.width) / 2, y: H - tagY * H - sz.height / 2))
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
    if !OUTRO_INLINE {
        try! aTrack.insertTimeRange(CMTimeRange(start: CMTime(seconds: OUTRO_FROM, preferredTimescale: 600),
                                                duration: CMTime(seconds: OUTRO_LEN, preferredTimescale: 600)),
                                    of: aSrc, at: range.duration)
    }
}
let outroStart = CMTimeGetSeconds(range.duration) - (OUTRO_INLINE ? OUTRO_LEN : 0)
if !OUTRO_INLINE {
    try! vTrack.insertTimeRange(CMTimeRange(start: CMTime(seconds: OUTRO_FROM, preferredTimescale: 600),
                                            duration: CMTime(seconds: OUTRO_LEN, preferredTimescale: 600)),
                                of: vSrc, at: range.duration)
}
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
// THUMB_IMAGE=<사진 경로>: 영상 장면 대신 따로 찍은 사진(HEIC/JPG)을 배경으로. 세로 9:16에 맞게 가운데를 잘라 쓴다
func photoBackground(_ path: String) -> CGImage? {
    guard let src = CGImageSourceCreateWithURL(URL(fileURLWithPath: path) as CFURL, nil),
          let img = CGImageSourceCreateThumbnailAtIndex(src, 0, [kCGImageSourceCreateThumbnailFromImageAlways: true,
              kCGImageSourceCreateThumbnailWithTransform: true, kCGImageSourceThumbnailMaxPixelSize: 4000] as CFDictionary)
    else { fatalError("photo unreadable: \(path)") }
    let w = CGFloat(img.width), h = CGFloat(img.height)
    let crop = w / h > W / H ? CGRect(x: (w - h * W / H) / 2, y: 0, width: h * W / H, height: h)
                             : CGRect(x: 0, y: (h - w * H / W) / 2, width: w, height: w * H / W)
    return img.cropping(to: crop.integral)
}
let thumbBg = env["THUMB_IMAGE"].map(photoBackground)
    ?? (try? gen.copyCGImage(at: CMTime(seconds: thumbT, preferredTimescale: 600), actualTime: nil))
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
// band from a little above the tag to a little below the last big line
let bandYs = hookYs(centered: true)
let bandTop = (bandYs[0] - 0.045) * H, bandH = (bandYs[bandYs.count - 1] - bandYs[0] + 0.09) * H
func band(_ img: CGImage) -> CGImage {
    let cut = img.cropping(to: CGRect(x: 0, y: bandTop, width: W, height: bandH))!
    return bitmap(Int(W), Int(bandH)) { ctx in ctx.draw(cut, in: CGRect(x: 0, y: 0, width: W, height: bandH)) }
}
let bandFrame = CGRect(x: 0, y: H - bandTop - bandH, width: W, height: bandH)
// one layer, contents switched per typed character (discrete keyframes), then fade out at the end
var frames: [CGImage] = [bitmap(Int(W), Int(bandH)) { _ in }]
var keyTimes: [NSNumber] = [0]
for n in 1...hookCharCount {
    frames.append(band(hookImage(background: nil, centered: true, visible: n, dim: false, skipTag: true)))
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
// pill tag: wipes in from the left with a soft gradient edge, then fades out with the hook
if HOOK_TAG_CHIP && !HOOK_TAG.isEmpty {
    let p = tagPill(centered: true)
    let tagLayer = CALayer()
    tagLayer.frame = p.rect
    tagLayer.contents = bitmap(Int(ceil(p.rect.width)), Int(ceil(p.rect.height))) { ctx in
        drawPill(ctx, CGRect(origin: .zero, size: p.rect.size))
        p.text.draw(at: CGPoint(x: p.origin.x - p.rect.minX, y: p.origin.y - p.rect.minY))
    }
    let mask = CAGradientLayer()
    mask.frame = tagLayer.bounds
    mask.startPoint = CGPoint(x: 0, y: 0.5); mask.endPoint = CGPoint(x: 1, y: 0.5)
    mask.colors = [NSColor.black.cgColor, NSColor.black.withAlphaComponent(0).cgColor]
    mask.locations = [-0.35, 0]
    let wipe = CABasicAnimation(keyPath: "locations")
    wipe.fromValue = [-0.35, 0]; wipe.toValue = [1, 1.35]
    wipe.beginTime = TAG_WIPE_START; wipe.duration = TAG_WIPE_LEN
    wipe.timingFunction = CAMediaTimingFunction(name: .easeOut)
    wipe.fillMode = .both; wipe.isRemovedOnCompletion = false
    mask.add(wipe, forKey: "wipe")
    tagLayer.mask = mask
    let tagFade = CAKeyframeAnimation(keyPath: "opacity")
    tagFade.values = [1, 1, 0]
    tagFade.keyTimes = [0, NSNumber(value: (hookEnd - 0.1) / hookEnd), 1]
    tagFade.beginTime = AVCoreAnimationBeginTimeAtZero; tagFade.duration = hookEnd
    tagFade.isRemovedOnCompletion = false
    tagLayer.opacity = 0
    tagLayer.add(tagFade, forKey: "fade")
    overlay.addSublayer(tagLayer)
}
// star stickers during the intro, same as the thumbnail
if STICKERS { addTimed(bitmap(Int(W), Int(H)) { ctx in drawStickers(ctx) }, frame: full, start: 0, end: hookEnd) }
// outro: dim + stars + closing line over the group shot
let outroEnd = outroStart + OUTRO_LEN
addTimed(bitmap(Int(W), Int(H)) { ctx in
    ctx.setFillColor(NSColor.black.withAlphaComponent(0.38).cgColor); ctx.fill(full)
    if STICKERS { drawStickers(ctx) }
}, frame: full, start: outroStart, end: outroEnd, fadeIn: 0.15, fadeOut: 0.01)
let outroCap = Cap(start: outroStart, end: outroEnd, text: OUTRO_TEXT, style: .outro)
let outroFrame = layerFrame(outroCap, capImage(outroCap))
addTimed(capImage(outroCap), frame: outroFrame, start: outroStart + 0.1, end: outroEnd,
         fadeIn: 0.2, fadeOut: 0.01)
if !OUTRO_LEAD.isEmpty {
    let leadImg = outlined(OUTRO_LEAD, font: font(DISPLAY_FONT, OUTRO_LEAD_SIZE), fill: cream,
                           stroke: NSColor(white: 0.08, alpha: 1), strokePct: 9, glow: 14, kern: -1)
    let lw = CGFloat(leadImg.width), lh = CGFloat(leadImg.height)
    addTimed(leadImg, frame: CGRect(x: (W - lw) / 2, y: outroFrame.maxY - 24 - 24 + 14, width: lw, height: lh),
             start: outroStart + 0.1, end: outroEnd, fadeIn: 0.2, fadeOut: 0.01)
}
if !OUTRO_TAIL.isEmpty {
    let tailImg = outlined(OUTRO_TAIL, font: font(DISPLAY_FONT, OUTRO_LEAD_SIZE), fill: cream,
                           stroke: NSColor(white: 0.08, alpha: 1), strokePct: 9, glow: 14, kern: -1)
    let tw = CGFloat(tailImg.width), th = CGFloat(tailImg.height)
    addTimed(tailImg, frame: CGRect(x: (W - tw) / 2, y: outroFrame.minY + 24 + 24 - 10 - th, width: tw, height: th),
             start: outroStart + 0.1, end: outroEnd, fadeIn: 0.2, fadeOut: 0.01)
}

// CALayer origin is bottom-left here
func layerFrame(_ c: Cap, _ img: CGImage) -> CGRect {
    let w = CGFloat(img.width), h = CGFloat(img.height)
    let cy = H - centerY(c) * H
    return CGRect(x: (W - w) / 2, y: cy - h / 2, width: w, height: h)
}
let mains = caps.filter { $0.style == .main }.map { ($0, layerFrame($0, capImage($0))) }
var placed: [(Cap, CGRect)] = []
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
    // chip: right under the emphasis shown at that moment (the chip image has no margin)
    if c.style == .chip, let b = placed.last(where: { [.box, .cute, .gloss].contains($0.0.style) && $0.0.start <= c.start && c.start < $0.0.end }) {
        f.origin.y = b.1.minY + 24 - 4 - f.height
    }
    placed.append((c, f))
    addTimed(img, frame: f, start: c.start, end: c.end)
}
// opening logo behind the head: one layer whose contents switch every frame (logo with the person cut out)
if VIDEO_LOGO {
    let logoGen = AVAssetImageGenerator(asset: asset)
    logoGen.appliesPreferredTrackTransform = true
    logoGen.requestedTimeToleranceBefore = .zero; logoGen.requestedTimeToleranceAfter = .zero
    logoGen.maximumSize = CGSize(width: W, height: H)
    let logoFull = bitmap(Int(W), Int(H)) { drawLogo($0, y: VIDEO_LOGO_Y, widthFrac: VIDEO_LOGO_WIDTH) }
    // only the band around the logo is kept per frame
    let lTop = (VIDEO_LOGO_Y - 0.09) * H, lH = 0.18 * H
    let fps = 30.0
    var logoFrames: [CGImage] = [], logoTimes: [NSNumber] = []
    var t = 0.0
    while t < HOOK_END {
        let frame = try! logoGen.copyCGImage(at: CMTime(seconds: t, preferredTimescale: 600), actualTime: nil)
        let holed = bitmap(Int(W), Int(H)) { ctx in
            ctx.draw(logoFull, in: CGRect(x: 0, y: 0, width: W, height: H))
            // punch the person out of the logo
            if let m = personMask(frame) {
                ctx.saveGState(); ctx.setBlendMode(.destinationOut)
                ctx.clip(to: CGRect(x: 0, y: 0, width: W, height: H), mask: m)
                ctx.setFillColor(NSColor.black.cgColor); ctx.fill(CGRect(x: 0, y: 0, width: W, height: H))
                ctx.restoreGState()
            }
        }
        logoFrames.append(holed.cropping(to: CGRect(x: 0, y: lTop, width: W, height: lH))!)
        logoTimes.append(NSNumber(value: t / HOOK_END))
        t += 1 / fps
    }
    let logoLayer = CALayer()
    logoLayer.frame = CGRect(x: 0, y: H - lTop - lH, width: W, height: lH)
    logoLayer.opacity = 0
    let swap = CAKeyframeAnimation(keyPath: "contents")
    swap.values = logoFrames; swap.keyTimes = logoTimes; swap.calculationMode = .discrete; swap.duration = HOOK_END
    let fade = CAKeyframeAnimation(keyPath: "opacity")
    fade.values = [1, 1, 0]; fade.keyTimes = [0, NSNumber(value: (HOOK_END - 0.1) / HOOK_END), 1]; fade.duration = HOOK_END
    let grp = CAAnimationGroup()
    grp.animations = [swap, fade]; grp.duration = HOOK_END
    grp.beginTime = AVCoreAnimationBeginTimeAtZero; grp.isRemovedOnCompletion = false
    logoLayer.add(grp, forKey: "logo")
    overlay.addSublayer(logoLayer)
}

let vc = AVMutableVideoComposition()
vc.renderSize = CGSize(width: W, height: H)
vc.frameDuration = CMTime(value: 1, timescale: 30)
let inst = AVMutableVideoCompositionInstruction()
inst.timeRange = total
// 아이폰 원본(4K 세로, 회전 정보 포함)도 1080×1920 화면에 꽉 차게: 회전 적용 후 가로 폭 기준으로 축소
let layerInst = AVMutableVideoCompositionLayerInstruction(assetTrack: vTrack)
let srcSize = vSrc.naturalSize.applying(vSrc.preferredTransform)
let fitScale = W / abs(srcSize.width)
layerInst.setTransform(vSrc.preferredTransform.concatenating(CGAffineTransform(scaleX: fitScale, y: fitScale)), at: .zero)
inst.layerInstructions = [layerInst]
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
let hook = Cap(start: 0, end: HOOK_END, text: "\(HOOK_TAG)\n\(HOOK_LINE1)\n\(HOOK_LINE2)", style: .title)
save("자막_제품명.srt", [hook] + caps.filter { $0.style == .title || $0.style == .series })
save("자막_메인.srt", caps.filter { $0.style == .main })
save("자막_강조.srt", caps.filter { [.box, .cute, .lead, .chip, .gloss].contains($0.style) })
save("자막_가격.srt", caps.filter { $0.style == .price || $0.style == .note })
