#!/bin/bash
# reel.swift 시험: 채널 프로필·회차 파일을 바꾸면 결과가 바뀌는지, 수정 전 코드와 같은 결과를 내는지 본다.
#
# 실행: bash tools/haul-reel/test_profile_swap.sh   (저장소 어디서든)
#
# 시험용 세로 영상을 직접 만들어서 쓰므로 원본 영상이 없어도 된다.
# 이 컴퓨터에 부크크 명조·Pretendard·Yoon 글꼴이 없으면 렌더링이 멈추므로, 기본으로 그 글꼴 이름을
# 시스템 글꼴로 바꾼 사본을 돌린다. 진짜 글꼴이 설치된 컴퓨터에서는 REEL_REAL_FONTS=1을 붙여서 그대로 돌린다.
#
# 확인하는 것
#  1. insta-reels 프로필 + 회차 → 1080×1920 썸네일, 자막 파일 4개, MP4
#  2. 다른 프로필(fixtures/profile-alt.json) + 같은 회차 → 1080×1350 썸네일 (프로필이 다르면 결과가 다르다)
#  3. 길이 상한이 있는 프로필에서 영상이 상한을 넘으면 멈춘다 (MP4를 만들지 않는다)
#  4. 회차 파일이 없거나 양식 이름이 틀리면 이유를 알리고 멈춘다
#  5. 수정 전 코드(a42526e)와 썸네일·자막 파일이 바이트까지 같다 (MP4는 인코더 때문에 바이트가 매번 달라서 제외)
set -u

HERE="$(cd "$(dirname "$0")" && pwd)"
REPO="$(cd "$HERE/../.." && pwd)"
BASE_REV="a42526e"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
PASS=0; FAIL=0

ok()   { PASS=$((PASS+1)); echo "  통과  $1"; }
bad()  { FAIL=$((FAIL+1)); echo "  실패  $1"; }
check(){ if [ "$1" = "$2" ]; then ok "$3"; else bad "$3 (기대 '$2', 실제 '$1')"; fi; }
width(){ sips -g pixelWidth "$1" | awk '/pixelWidth/{print $2}'; }
height(){ sips -g pixelHeight "$1" | awk '/pixelHeight/{print $2}'; }

FONT_SUB='s/BookkMyungjo-Bd|Pretendard-[A-Za-z]+|YoonChildfundkorea[A-Za-z]+/AppleSDGothicNeo-Bold/g'
if [ "${REEL_REAL_FONTS:-}" = "1" ]; then
  cp "$HERE/reel.swift" "$TMP/reel.swift"
  git -C "$REPO" show "$BASE_REV:tools/haul-reel/reel.swift" > "$TMP/old_reel.swift"
  cp "$REPO/channels/insta-reels/profile.json" "$TMP/profile_a.json"
else
  sed -E "$FONT_SUB" "$HERE/reel.swift" > "$TMP/reel.swift"
  git -C "$REPO" show "$BASE_REV:tools/haul-reel/reel.swift" | sed -E "$FONT_SUB" > "$TMP/old_reel.swift"
  python3 - "$REPO/channels/insta-reels/profile.json" "$TMP/profile_a.json" <<'EOF'
import json, re, sys
def sub(o):
    if isinstance(o, str): return re.sub(r"BookkMyungjo-Bd|Pretendard-[A-Za-z]+|YoonChildfundkorea[A-Za-z]+", "AppleSDGothicNeo-Bold", o)
    if isinstance(o, list): return [sub(x) for x in o]
    if isinstance(o, dict): return {k: sub(v) for k, v in o.items()}
    return o
json.dump(sub(json.load(open(sys.argv[1]))), open(sys.argv[2], "w"), ensure_ascii=False)
EOF
fi

# 길이 상한이 10초인 프로필 (fixtures/profile-alt.json에서 만든다)
python3 - "$HERE/fixtures/profile-alt.json" "$TMP/profile_limit.json" <<'EOF'
import json, sys
p = json.load(open(sys.argv[1])); p["maxSeconds"] = 10
json.dump(p, open(sys.argv[2], "w"), ensure_ascii=False)
EOF

# 시험용 세로 영상 26초 (회차의 end 23.9초 + 엔딩 1.5초가 들어가는 길이)
cat > "$TMP/gen.swift" <<'EOF'
import AVFoundation
import CoreVideo
let out = URL(fileURLWithPath: CommandLine.arguments[1])
let secs = Double(CommandLine.arguments[2])!
try? FileManager.default.removeItem(at: out)
let w = 540, h = 960, fps = 10
let writer = try! AVAssetWriter(outputURL: out, fileType: .mov)
let input = AVAssetWriterInput(mediaType: .video, outputSettings: [AVVideoCodecKey: AVVideoCodecType.h264, AVVideoWidthKey: w, AVVideoHeightKey: h])
let adaptor = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: input, sourcePixelBufferAttributes: [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA, kCVPixelBufferWidthKey as String: w, kCVPixelBufferHeightKey as String: h])
writer.add(input); writer.startWriting(); writer.startSession(atSourceTime: .zero)
for i in 0..<Int(secs * Double(fps)) {
    while !input.isReadyForMoreMediaData { Thread.sleep(forTimeInterval: 0.005) }
    var pb: CVPixelBuffer?
    CVPixelBufferCreate(nil, w, h, kCVPixelFormatType_32BGRA, nil, &pb)
    CVPixelBufferLockBaseAddress(pb!, [])
    let base = CVPixelBufferGetBaseAddress(pb!)!.assumingMemoryBound(to: UInt8.self)
    let bpr = CVPixelBufferGetBytesPerRow(pb!)
    for y in 0..<h { for x in 0..<w {
        let o = y * bpr + x * 4
        base[o] = UInt8((x * 255) / w); base[o+1] = UInt8((y * 255) / h); base[o+2] = UInt8((i * 7) % 255); base[o+3] = 255
    } }
    CVPixelBufferUnlockBaseAddress(pb!, [])
    adaptor.append(pb!, withPresentationTime: CMTime(value: CMTimeValue(i), timescale: CMTimeScale(fps)))
}
input.markAsFinished()
let sem = DispatchSemaphore(value: 0); writer.finishWriting { sem.signal() }; sem.wait()
if writer.status != .completed { FileHandle.standardError.write(Data("video failed\n".utf8)); exit(1) }
EOF
echo "시험용 영상 만드는 중"
swift "$TMP/gen.swift" "$TMP/in.mov" 26 2>/dev/null || { echo "시험용 영상을 만들지 못했다"; exit 1; }

EP="$HERE/episodes/sample.json"
run() { # run <outdir> <profile> <episode> [env...]  → stderr는 $TMP/err.txt
  local out="$1" profile="$2" episode="$3"; shift 3
  mkdir -p "$out"
  env "$@" PROFILE="$profile" EPISODE="$episode" swift "$TMP/reel.swift" "$TMP/in.mov" "$out" > "$TMP/stdout.txt" 2> "$TMP/err.txt"
}

echo "1. insta-reels 프로필 + 회차"
run "$TMP/a" "$TMP/profile_a.json" "$EP" X=1; check "$?" "0" "렌더가 끝난다"
THUMB_A="$(ls "$TMP"/a/*.jpg 2>/dev/null | head -1)"
check "$(width "$THUMB_A")x$(height "$THUMB_A")" "1080x1920" "썸네일이 1080x1920이다"
check "$(ls "$TMP"/a/*.srt | wc -l | tr -d ' ')" "4" "자막 파일 4개"
[ -s "$TMP/a/자막입힌_초안.mp4" ] && ok "MP4가 만들어진다" || bad "MP4가 만들어진다"

echo "2. 다른 프로필 + 같은 회차"
run "$TMP/b" "$HERE/fixtures/profile-alt.json" "$EP" THUMB_ONLY=1; check "$?" "0" "렌더가 끝난다"
THUMB_B="$(ls "$TMP"/b/*.jpg 2>/dev/null | head -1)"
check "$(width "$THUMB_B")x$(height "$THUMB_B")" "1080x1350" "썸네일이 1080x1350이다 (프로필이 달라서 결과가 다르다)"

echo "3. 길이 상한 10초 프로필 + 26초 영상"
run "$TMP/c" "$TMP/profile_limit.json" "$EP" X=1; RC=$?
[ "$RC" != "0" ] && ok "멈춘다 (종료 코드 $RC)" || bad "멈춘다"
grep -q "상한" "$TMP/err.txt" && ok "이유에 '상한'이 들어 있다" || bad "이유에 '상한'이 들어 있다"
[ ! -e "$TMP/c/자막입힌_초안.mp4" ] && ok "MP4를 만들지 않는다" || bad "MP4를 만들지 않는다"

echo "4. 잘못된 입력"
mkdir -p "$TMP/d"
env PROFILE="$TMP/profile_a.json" swift "$TMP/reel.swift" "$TMP/in.mov" "$TMP/d" > /dev/null 2> "$TMP/err.txt"; RC=$?
check "$RC" "2" "회차 파일 없이 실행하면 종료 코드 2"
grep -q "EPISODE" "$TMP/err.txt" && ok "이유에 EPISODE가 들어 있다" || bad "이유에 EPISODE가 들어 있다"
python3 - "$EP" "$TMP/ep_bad.json" <<'EOF'
import json, sys
e = json.load(open(sys.argv[1])); e["preset"] = "없는양식"
json.dump(e, open(sys.argv[2], "w"), ensure_ascii=False)
EOF
run "$TMP/e" "$TMP/profile_a.json" "$TMP/ep_bad.json" X=1; check "$?" "2" "없는 양식 이름이면 종료 코드 2"
grep -q "fitting" "$TMP/err.txt" && ok "있는 양식 이름을 알려 준다" || bad "있는 양식 이름을 알려 준다"

echo "5. 수정 전 코드($BASE_REV)와 비교"
mkdir -p "$TMP/old"
swift "$TMP/old_reel.swift" "$TMP/in.mov" "$TMP/old" > /dev/null 2>&1
for f in "$TMP"/old/*.jpg "$TMP"/old/*.srt; do
  name="$(basename "$f")"
  if cmp -s "$f" "$TMP/a/$name"; then ok "$name 이 같다"; else bad "$name 이 다르다"; fi
done

echo
echo "통과 $PASS, 실패 $FAIL"
[ "$FAIL" = "0" ]
