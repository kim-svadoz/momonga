# 채널 프로필 형식

편집 도구가 읽는 채널별 설정 파일 `channels/<채널>/profile.json`의 형식이다. 영상 채널에만 둔다.

## 무엇을 어디에 두나

| 종류 | 예 | 두는 곳 |
| --- | --- | --- |
| 채널 설정 | 화면 크기, 길이 상한, 자막이 가려지는 영역, 기본 글꼴 | `profile.json` 위쪽 |
| 영상 종류별 양식 | 하울 릴스, 피팅 릴스처럼 같은 채널 안에서 모양이 다른 것 | `profile.json`의 `presets` |
| 영상 한 편의 내용 | 자막과 시간, 훅 문구, 썸네일 문구, 엔딩 문구 | 회차 파일 (`tools/haul-reel/episodes/<회차>.json`) |

회차 파일은 어떤 양식(preset)을 쓰는지 이름으로 고르고, 그 양식의 값을 일부만 덮어쓸 수 있다.

## 값의 규칙

- 확인하지 못한 값은 `null`로 둔다. 도구는 `null`인 항목의 검사를 하지 않는다. 추측한 숫자를 넣지 않는다.
- 화면 안 위치는 **화면 위에서부터의 비율**(0~1)이다. 0.5는 가운데.
- 색은 `[빨강, 초록, 파랑, 투명도]` 네 숫자(각 0~1)다.
- 시간은 초 단위다.

## 위쪽 항목

| 키 | 뜻 | 값 |
| --- | --- | --- |
| `schemaVersion` | 형식 버전 | `1` |
| `channel` | 채널 폴더 이름 | 문자열 |
| `canvas` | 화면 크기 `{ "width", "height" }` | 픽셀 |
| `maxSeconds` | 영상 길이 상한 | 초, 모르면 `null` |
| `safeArea` | 글자가 가려지는 위·아래 영역 `{ "top", "bottom" }` | 비율, 모르면 `null` |
| `fonts` | 기본 글꼴 이름 `display`(훅 큰 제목·엔딩), `main`(메인 자막), `hook`(오프닝 큰 제목), `handwriting`(덧말) | PostScript 이름 |
| `sfx` | 효과음 `{ "defaultMode", "dir" }`. `defaultMode`는 `capcut` 또는 `none` | 문자열 |
| `presets` | 영상 종류별 양식 | 아래 표 |

## presets 항목

양식마다 아래 키를 가진다. 없는 키는 도구의 기본값을 쓴다.

| 키 | 뜻 |
| --- | --- |
| `stickers` | 별·점 스티커를 쓸지 |
| `hookTag` | 훅 맨 윗줄 태그 글자 (`""` = 없음) |
| `hookTagChip` | 태그를 작은 배경 띠에 넣을지 (false면 큰 노랑 글자) |
| `seriesChip` | 맨 위 라벨을 배경 띠로 할지 |
| `seriesLabel` | 맨 위 라벨 글자 (`""` = 없음) |
| `pillBg`, `pillInk`, `pillRadius` | 띠의 배경색, 글자색, 모서리 (0 = 네모) |
| `hookPerChar` | 타자기 한 글자 간격(초) |
| `hookFont` | 오프닝 큰 제목 글꼴 |
| `hookLine1Y` | 오프닝 첫 줄 높이 |
| `outroSize`, `outroLeadSize` | 엔딩 큰 글자, 위 작은 글자 크기 |
| `outroInline` | 엔딩을 마지막 컷에 이어 붙일지 (false면 지정 구간을 반복) |
| `videoLogo` | 오프닝 동안 머리 뒤에 로고를 둘지 `{ "y", "width" }` 또는 `null` |
| `thumbShowTag` | 썸네일에 훅 태그를 넣을지 |
| `thumbFont` | 썸네일 큰 제목 글꼴 |
| `thumbTitleY` | 썸네일 제목 첫 줄 높이 (0 = 오프닝과 같음) |
| `thumbTagChip`, `thumbTagY`, `thumbTagBg` | 썸네일 꼬리표 띠 여부, 높이, 색 |
| `titleBottom` | 제품명을 아래쪽 작은 글씨로 할지 |
| `titleY` | 제품명·가격 줄 높이 |
| `displayFont`, `mainFont` | 이 양식의 글꼴 (위쪽 `fonts`보다 우선) |
| `outroFrom`, `outroLen` | 엔딩을 따로 붙일 때의 구간 (`outroInline`이 false일 때만 씀) |

## 회차 파일이 가지는 것

회차 파일은 프로필에 두지 않은 내용만 가진다.

- `preset`: 쓸 양식 이름
- `overrides`: 양식 값 중 이번 영상만 다르게 할 것
- `end`, `hookEnd`: 영상 끝 시간, 오프닝 끝 시간
- `hook`: 오프닝 큰 제목 `line1`, `line2`, `line3`과 크기. 덧말 색 `line3Color`(기본 흰색), 큰 제목이 다 쳐진 뒤 덧말까지 쉬는 시간 `line3Pause`(초, 기본 0)
- `thumb`: 썸네일 제목, 꼬리표, 로고 글자, 로고 색
- `outro`: 엔딩 큰 글씨, 위 작은 줄, 아래 작은 줄
- `caps`: 자막 목록 `{ "start", "end", "text", "style" }`
- `floats` (없어도 됨): 원하는 위치에 띄우는 작은 색 배경 자막 `{ "start", "end", "text", "x", "y", "bg" }`. `x`·`y`는 글자 가운데의 위치(왼쪽 위에서부터 비율), `bg`를 빼면 썸네일 꼬리표 색(`thumbTagBg`)

## 새 채널 프로필을 추가할 때

1. 이 형식으로 `channels/<채널>/profile.json`을 만든다.
2. 공식 문서로 확인하지 못한 값은 `null`로 둔다.
3. `channels/<채널>/channel.md`의 `## 규격`과 값이 어긋나지 않게 한다.
