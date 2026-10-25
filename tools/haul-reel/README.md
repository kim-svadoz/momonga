# 하울 릴스 자동 편집 (haul-reel)

컷 편집이 끝난 세로 영상에 자막·썸네일을 입힌다. 1080×1920 화면 녹화본도, 아이폰 4K 세로 원본(회전 정보 포함)도 1080×1920에 꽉 차게 맞춘다. 맥 기본 기능(AVFoundation)만 쓰고 ffmpeg는 필요 없다.
첫 사용: 2026-10-25 돈키호테 쇼핑리스트 1탄 (`output/261025/reels_돈키호테 추천템 1탄/`). 패션 릴스: 2026-10-25 자라 맨즈 아우터 (`output/261025/reels_자라 맨즈 아우터/`).
회차마다 `reel.swift`의 회차 데이터를 바꾸고, 이전 회차 파일은 그 회차 폴더에 `reel_<회차>.swift`로 남긴다.

## 파일

| 파일 | 하는 일 |
| --- | --- |
| `reel.swift` | 자막을 입힌 MP4, 썸네일, 캡컷용 SRT 4개(제품명/메인/강조/가격)를 만든다 |
| `cut.swift` | 원본(여러 파일 가능)에서 남길 구간만 이어 붙인다. 다른 파일 구간은 `<경로>@시작-끝` |
| `frames.swift` | 원본의 컷 전환 지점(0.1초 단위 화면 변화량)과 0.5초 간격 장면 모음 이미지를 뽑는다 |
| `one.swift` | 영상의 한 시점을 이미지로 뽑는다 (결과 확인용) |
| `montage.swift`, `grid.swift` | 확인용 이미지 여러 장을 한 장으로 붙인다 (grid는 라벨 포함) |

## 실행

```bash
# 1) 컷 순서 파악
swift tools/haul-reel/frames.swift <원본.MOV> <작업폴더>   # 변화량이 stdout, sheet*.jpg 생성
# 2) reel.swift의 caps 배열, hookLines, 썸네일 꼬리표, 썸네일 시점(thumbBg)을 이번 영상에 맞게 고친다
# 3) 렌더
SFX=capcut swift tools/haul-reel/reel.swift <원본.MOV> output/YYMMDD/reels_<주제>/
# 썸네일만 다른 글꼴로 뽑기
THUMB_ONLY=1 THUMB_FONT=<PostScript 이름> THUMB_OUT=<경로.jpg> swift tools/haul-reel/reel.swift <원본.MOV> /tmp
```

## 양식 (바꾸지 않는 것)

- 0~3.4초 오프닝: 화면 정중앙, 살짝 어둡게, 타자기 효과(0.15초부터 한 글자 0.05초). 노랑 태그(`HOOK_TAG`) / 흰 큰 제목 / 노랑 큰 제목
  - `HOOK_TAG`: 하울 릴스는 "[저장 필수]", 패션 릴스는 고정 타겟 키워드 "[162 출근룩]"
- 썸네일: 오프닝과 같은 3단 제목 + 귀여운 손글씨 꼬리표("- 치이카와굿즈/뷰티템 -") + 가장자리 별 스티커
- 맨 위 시리즈 라벨 "돈키호테 쇼핑템 N탄" (배경 없음)
- 제품마다 번호 제품명 "1. 제품명" (부크크 명조 Bold, 크림색)
- 메인 자막: Pretendard SemiBold 흰 글자 + 검정 테두리, 화면 64%
- 강조 한 줄: Yoon 초록우산어린이 대한, 노랑 글자 + 검정 테두리, 메인 자막 바로 밑
- 가격: 아래쪽 작게, 박스·음영 없음. 다른 곳에서 산 물건은 괄호로 작게 "(나고야 관광지에서 구매)"
- 배경 박스는 쓰지 않는다 (검정 박스는 촌스럽다는 피드백)
- 엔딩: 원본 쇼핑 떼샷 구간(`OUTRO_FROM`, 2초)을 다시 붙이고 "곧 N탄도 가져올게요!" (부크크 명조) + 별 스티커
- 소리: **2탄부터 `SFX=capcut`으로 렌더한다** (원본 소리 빼고 캡컷 효과음 배치). 효과음 파일은 `assets/sfx/` (사용자가 1탄을 캡컷에서 편집한 영상에서 잘라낸 것, git 제외)
  - typing: 오프닝 내내 (0.05초~) / click: 제품 번호가 바뀔 때 / transition: 제품 사이 빈 화면(0.3초 이상 틈)이 있으면 앞 제품 끝 0.3초 전 / ding: 첫 노랑 강조 자막 / outro: 엔딩 문구 0.2초 뒤
  - 효과음을 바꾸려면 같은 이름의 m4a 파일만 바꿔 넣는다. 합성 효과음(`SFX=1`)은 촌스럽다는 피드백으로 쓰지 않는다.

## 회차별 설정 (reel.swift 회차 데이터)

| 설정 | 하울 릴스 | 패션 피팅 릴스 |
| --- | --- | --- |
| `STICKERS` 별 스티커 | true | false |
| `HOOK_TAG_CHIP` 훅 태그를 작은 알약으로 (그라데이션 등장, 타자기 제외) | false | true |
| `SERIES_CHIP` 맨 위 라벨 알약 배경 | false | true |
| `PILL_BG` / `PILL_INK` 알약 색 | — | 흰 0.92 / 먹색 |
| `HOOK_PER_CHAR` 타자기 한 글자 간격 | 0.05 | 0.04 |
| `PILL_RADIUS` 태그·라벨 모서리 | — | 0 (네모) |
| `HOOK_FONT` 오프닝 큰 제목 | BookkMyungjo-Bd | BookkMyungjo-Bd |
| `HOOK_LINE1_Y` 오프닝 첫 줄 높이 | 0.495 | 0.41 (태그가 가슴 높이) |
| `OUTRO_SIZE` / `OUTRO_LEAD_SIZE` 엔딩 글자 | 84 / 54 | 70 / 40 |
| `THUMB_LOGO` 썸네일 브랜드 글자 (Didot) | "" | "" (넣어봤다가 별로라 뺌) |
| `THUMB_TITLE` 썸네일만 큰 제목 한 줄 | "" | "자라 맨즈 아우터 추천 4" |
| `THUMB_FONT_NAME` 썸네일 큰 제목 글꼴 | BookkMyungjo-Bd | ChosunGu |
| `TITLE_BOTTOM` 제품명 위치 | false (위쪽 큰 명조) | true (아래쪽 작게, 가격과 한 줄) |
| `DISPLAY_FONT` / `MAIN_FONT` | BookkMyungjo-Bd / Pretendard-SemiBold | Pretendard-SemiBold / Pretendard-Medium |

## 알아둘 점

- 아주 짧은(0.05초) 레이어를 여러 개 쓰면 내보낼 때 빠진다. 타자기 효과는 레이어 하나의 contents를 키프레임으로 바꾸는 방식이다.
- 전체 화면 크기 이미지를 여러 장 올리면 앞부분이 빠질 수 있다. 글자가 있는 띠만 잘라서 올린다.
- 배경음악은 넣지 않는다. 캡컷·인스타에서 상업 사용 가능한 음원으로 얹는다.
