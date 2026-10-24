# momonga — 벵짱 패션 콘텐츠 작업실

패션 콘텐츠로 팔로워를 키우고, 착장 정보·추천템·쇼핑하울로 구매 전환을 만들어 수익화하는 작업실이다.
사용자는 IT 비전공자다. 설명은 쉬운 말로 짧게 하고, 전문 용어는 풀어서 쓴다.

## 작업 전에 먼저 읽기

1. `brand/profile.md` — 나는 누구고, 누구에게, 무엇을 파는가
2. `brand/style-guide.md` — 폰트·색·썸네일·자막 규칙 (통일감의 기준)
3. `brand/voice.md` — 내 말투
4. 해당 채널 스킬 (`.claude/skills/<채널>/SKILL.md`)

## 채널별 스킬

| 하고 싶은 일 | 스킬 |
| --- | --- |
| 네이버 블로그 글 | `naver-blog` |
| 블로그 글 (네이버 외, 일반) | `blog-post` |
| 인스타 피드 글 (사진·캐러셀·캡션) | `insta-post` |
| 쓰레드 글 (본문 + 답글 링크) | `threads-post` |
| 패션 릴스 기획·대본·썸네일 | `fashion-reels` |
| 숏폼 영상 만들기 (편집기 사용) | `shortform` |
| 블로그 글을 릴스로 바꾸기 | `blog-to-reels` |

## 공통 규칙

- 확인하지 못한 숫자(가격·스펙·조회수)는 쓰지 않는다. 가격은 확인 날짜를 붙인다 ("10.20 기준").
- 내가 겪지 않은 착용감·경험은 지어내지 않는다.
- 수익화 콘텐츠라서 폰트·사진·음원은 **상업적 사용 가능**한 것만 쓴다. (`brand/style-guide.md`의 라이선스 표 참고)
- 국내 기사 사진, AI로 만든 사진은 쓰지 않는다.
- 발행은 사용자가 직접 한다. Claude는 원고·사진·영상 파일까지만 준비한다.

## 피드백과 기록

- 사용자가 피드백을 주면 `history/feedback.md`에 `[YYYY-MM-DD] 내용` 형식으로 추가하고, 관련 brand/스킬 파일도 같이 고친다.
- 중요한 결정은 `history/decisions.md`에 남긴다.
- 벤치마킹한 계정·영상 분석은 `benchmarks/`에 쌓는다.

## 결과물 저장 위치

- `output/YYMMDD/<채널>_<주제>/` (예: `output/261024/naver_출근룩 가디건/`)
- `output/`은 git에 올리지 않는다 (사진·영상 원본이 크고 개인 자료라서).

## 도구

- 숏폼 편집기: `apps/shorts-editor/` — 실행법은 그 폴더의 README.

<!-- sugo:harness-rules:start -->
<!-- 이 블록은 sugo가 자동 관리합니다. 손으로 고치면 다음 sugo_add/sugo_update 때 덮어써집니다. -->
## Sugo 하네스

이 프로젝트에 적용된 코딩 표준이 `.claude/rules/`에 자동 로드되도록 설치돼 있습니다.
전문은 `sugo/harness/<id>/harness.md`, 검증 설정은 `sugo/harness/<id>/validation.yaml`에 있습니다.

- `default`
<!-- sugo:harness-rules:end -->
