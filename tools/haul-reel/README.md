# 하울 릴스 자동 편집 (haul-reel)

컷 편집이 끝난 세로 영상에 자막·썸네일을 입힌다. 1080×1920 화면 녹화본도, 아이폰 4K 세로 원본(회전 정보 포함)도 1080×1920에 꽉 차게 맞춘다. 맥 기본 기능(AVFoundation)만 쓰고 ffmpeg는 필요 없다.
첫 사용: 2026-10-25 돈키호테 쇼핑리스트 1탄 (`output/261025/reels_돈키호테 추천템 1탄/`). 패션 릴스: 2026-10-25 자라 맨즈 아우터 (`output/261025/reels_자라 맨즈 아우터/`).
회차마다 `episodes/<회차>.json`을 새로 만든다 (자막, 훅·썸네일·엔딩 문구). `reel.swift`는 회차마다 고치지 않는다.
채널 설정(화면 크기, 길이 상한)과 영상 종류별 양식(하울, 피팅)은 `channels/insta-reels/profile.json`에서 읽는다. 형식은 `channels/profile-schema.md`.

## 파일

| 파일 | 하는 일 |
| --- | --- |
| `reel.swift` | 채널 프로필과 회차 파일을 읽어서 자막을 입힌 MP4, 썸네일, 캡컷용 SRT 4개(제품명/메인/강조/가격)를 만든다 |
| `episodes/<회차>.json` | 영상 한 편의 내용 (양식 이름, 자막과 시간, 훅·썸네일·엔딩 문구). `sample.json`은 자라 맨즈 아우터 회차라서 복사해서 시작한다 |
| `fixtures/profile-alt.json` | 시험용 다른 채널 프로필 (화면 1080×1350) |
| `test_profile_swap.sh` | 프로필을 바꾸면 결과가 바뀌는지, 수정 전 코드와 같은 결과인지 확인한다 |
| `cut.swift` | 원본(여러 파일 가능)에서 남길 구간만 이어 붙인다. 다른 파일 구간은 `<경로>@시작-끝` |
| `frames.swift` | 원본의 컷 전환 지점(0.1초 단위 화면 변화량)과 0.5초 간격 장면 모음 이미지를 뽑는다 |
| `one.swift` | 영상의 한 시점을 이미지로 뽑는다 (결과 확인용) |
| `montage.swift`, `grid.swift` | 확인용 이미지 여러 장을 한 장으로 붙인다 (grid는 라벨 포함) |

## 실행

```bash
# 1) 컷 순서 파악
swift tools/haul-reel/frames.swift <원본.MOV> <작업폴더>   # 변화량이 stdout, sheet*.jpg 생성
# 2) episodes/sample.json을 복사해서 episodes/<회차>.json을 만들고 이번 영상에 맞게 고친다 (양식 preset, 자막 caps, 훅, 썸네일, 엔딩)
# 3) 렌더
EPISODE=tools/haul-reel/episodes/<회차>.json SFX=capcut swift tools/haul-reel/reel.swift <원본.MOV> output/YYMMDD/insta-reels_<주제>/
# 다른 채널 프로필로: PROFILE=channels/<채널>/profile.json (기본은 channels/insta-reels/profile.json)
# 썸네일 배경을 따로 찍은 사진(HEIC/JPG)으로: THUMB_IMAGE=<사진 경로> (9:16에 맞게 가운데를 자른다)
# 썸네일만 다른 글꼴로 뽑기
EPISODE=tools/haul-reel/episodes/<회차>.json THUMB_ONLY=1 THUMB_FONT=<PostScript 이름> THUMB_OUT=<경로.jpg> swift tools/haul-reel/reel.swift <원본.MOV> /tmp
```

## 양식 (바꾸지 않는 것)

- 0~3.4초 오프닝: 화면 정중앙, 살짝 어둡게, 타자기 효과(0.15초부터 한 글자 0.05초). 노랑 태그(`HOOK_TAG`) / 흰 큰 제목 / 노랑 큰 제목
  - `HOOK_TAG`: 하울 릴스는 "[저장 필수]". 패션 피팅 릴스는 오프닝 태그를 쓰지 않는다 (2026-10-25 v7에서 뺌). 고정 타겟 키워드는 `brand/profile.md`
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

## 영상 종류별 양식 (profile.json의 presets)

기준은 `channels/insta-reels/profile.json`이다. 아래 표는 설명용이고 표와 다르면 profile.json이 맞다. 표의 이름은 `reel.swift`의 상수 이름이고, profile.json에서는 같은 뜻의 camelCase 키(`HOOK_LINE1_Y` → `hookLine1Y`)다.
`THUMB_TITLE`, `THUMB_TAG`, `THUMB_LOGO`, `SERIES_LABEL`처럼 영상마다 바뀌는 글자는 양식이 아니라 회차 파일에 둔다 (`SERIES_LABEL`은 회차 파일의 `overrides`).

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
| `THUMB_LOGO` 썸네일 브랜드 글자 (Didot, 머리 위, 사람을 오려 얹음) | "" | "ZARA" (검정) |
| `THUMB_SHOW_TAG` 썸네일에 훅 태그 | — | false |
| `VIDEO_LOGO` 오프닝 동안 머리 뒤 로고 (프레임마다 사람 오려냄) | — | true (높이 0.13, 폭 0.86) |
| `OUTRO_INLINE` 엔딩을 마지막 컷에 이어서 | false (OUTRO_FROM 구간 반복) | true |
| `HOOK_TAG` 훅 태그 | "[저장 필수]" | "" (없음) |
| `THUMB_TITLE` 썸네일만 큰 제목 (`/` = 줄바꿈, 둘째 줄이 더 큼) | "" | "자라 맨즈 아우터/이건 사지 마세요.." |
| `THUMB_FONT_NAME` 썸네일 큰 제목 글꼴 | BookkMyungjo-Bd | BookkMyungjo-Bd |
| `THUMB_TITLE_Y` 썸네일 제목 첫 줄 높이 | 0 (오프닝과 같음) | 0.43 (가슴) |
| `THUMB_TAG_CHIP` / `THUMB_TAG_Y` / `THUMB_TAG_BG` 꼬리표 네모 띠 | false | true / 0.545 / 민트 |
| `TITLE_BOTTOM` 제품명 모양 | false (위쪽 큰 명조) | true (작게, 가격과 한 줄) |
| `TITLE_Y` 제품명·가격 줄 높이 | — | 0.125 (맨 위) |
| `SERIES_LABEL` 맨 위 라벨 | "돈키호테 쇼핑템 N탄" | "" (없음) |
| `DISPLAY_FONT` / `MAIN_FONT` | BookkMyungjo-Bd / Pretendard-SemiBold | Pretendard-SemiBold / Pretendard-Medium |

## 알아둘 점

- 아주 짧은(0.05초) 레이어를 여러 개 쓰면 내보낼 때 빠진다. 타자기 효과는 레이어 하나의 contents를 키프레임으로 바꾸는 방식이다.
- 전체 화면 크기 이미지를 여러 장 올리면 앞부분이 빠질 수 있다. 글자가 있는 띠만 잘라서 올린다.
- 배경음악은 넣지 않는다. 캡컷·인스타에서 상업 사용 가능한 음원으로 얹는다.
- 자막 종류별 글꼴(꼬리표·가격·강조 등)은 아직 `reel.swift` 안에 있다. 프로필의 `fonts`와 양식의 글꼴은 훅 큰 제목, 메인 자막, 엔딩, 덧말에 적용된다.
- 필요한 글꼴(부크크 명조, Pretendard, Yoon 초록우산어린이)이 설치돼 있지 않으면 `font missing`으로 멈춘다.
- 시험: `bash tools/haul-reel/test_profile_swap.sh`. 시험용 영상을 직접 만들어 쓰고, 글꼴이 없는 컴퓨터에서는 시스템 글꼴로 바꿔서 돈다. 글꼴이 설치된 컴퓨터에서는 `REEL_REAL_FONTS=1`을 붙인다.
