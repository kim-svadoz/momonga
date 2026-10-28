# momonga — 벵짱 패션 콘텐츠 작업실

패션 콘텐츠로 팔로워를 키우고, 착장 정보·추천템·쇼핑하울로 구매 전환을 만들어 수익화하는 작업실이다.
사용자는 IT 비전공자다. 설명은 쉬운 말로 짧게 하고, 전문 용어는 풀어서 쓴다.

## 작업 전에 먼저 읽기

1. `brand/profile.md` — 나는 누구고, 누구에게, 무엇을 파는가
2. `brand/style-guide.md` — 폰트·색·썸네일·자막 규칙 (통일감의 기준)
3. `brand/voice.md` — 내 말투
   - 릴스·하울 영상 자막을 다룰 때는 `brand/caption-rules.md` (자막 적는 기호 `!` `( )` `^( )` `[ ]` `*` `₩` `/`)도 읽는다.
4. 채널과 목적에 맞는 문서 묶음 — `studio` 스킬이 `tools/compose/compose.py <채널> <목적>`으로 조립한다 (아래 "채널 × 목적")

## 채널 × 목적

요청마다 배경을 다시 설명하지 않는다. **올릴 채널**과 **할 일(목적)**을 정하면 필요한 규칙·예시·피드백·편집 설정이 한 묶음으로 조립된다.

| 구분 | 종류 | 위치 |
| --- | --- | --- |
| 채널 | `naver-blog`, `threads`, `insta-reels` (사용 가능) / `insta-post`, `insta-story`, `tiktok`, `youtube-shorts`, `youtube-long` (틀만) | `channels/<채널>/` — 규격, 말투 차이, 링크 정책, 예시(`channel.md`), 피드백(`feedback.md`), 편집 설정(`profile.json`) |
| 목적 | `write`(글쓰기), `edit`(영상편집), `convert`(변환) | `workflows/<목적>.md` |
| 입력 | 사진·영상 + 짧은 배경설명 | `inbox/<YYMMDD>_<주제>/` — `templates/brief.md`를 복사해 `brief.md`로 쓴다 |

- 조립: `python3 tools/compose/compose.py <채널> <목적> [--brief inbox/.../brief.md]`. 같은 입력이면 항상 같은 순서·같은 문서가 나온다.
- 채널이 `틱톡`처럼 `틀만`이면 `⬜` 칸은 추측해서 채우지 않고 사용자에게 알린다.
- 채널과 목적이 분명하지 않으면 추측하지 말고 묻는다.
- 규칙을 고칠 때는 해당 채널의 `channel.md`가 기준이다.
- **결정 시트**: `docs/결정할-것.md`에 벵짱이 정해야 할 것이 모여 있다. 표에서 상태가 `⬜ 미정`이고 이번 채널(또는 `공통`)에 해당하는 항목이 있으면, 작업을 시작할 때 사용자에게 먼저 알리고 그 자리에서 질문 도구로 묻는다. 답을 받으면 시트에 답을 적고 상태를 `✅ 정함`으로 바꾸고, 해당 `channel.md`의 `⬜` 칸을 채우고, `history/decisions.md`에 남긴다. 사용자가 지금은 싫다고 하면 강요하지 않고 비워 둔다.
- `output/`이 있는 컴퓨터에서 처음 pull하면 `docs/원본-컴퓨터에서-이어서.md`를 읽고, 그 순서대로 진행할지 사용자에게 **먼저 제안**한다.

## 채널별 스킬 (옛 방식, 새 구조가 검증될 때까지 남겨 둠)

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

- 사용자가 피드백을 주면 그 채널의 `channels/<채널>/feedback.md`에 `[YYYY-MM-DD] (구분) 내용` 형식으로 추가하고, 규칙이 바뀌면 같은 채널의 `channel.md`와 관련 brand 파일도 같이 고친다. 채널과 무관한 피드백만 `history/feedback.md`에 쓴다.
- 중요한 결정은 `history/decisions.md`에 남긴다.
- 벤치마킹한 계정·영상 분석은 `benchmarks/`에 쌓는다.

## 결과물 저장 위치

- `output/YYMMDD/<채널>_<주제>/` — 채널 이름은 `channels/` 폴더 이름을 쓴다 (예: `output/261027/naver-blog_출근룩 가디건/`). 이전 회차 폴더는 옛 접두어(`naver_`, `reels_`)가 그대로 있다.
- `output/`은 git에 올리지 않는다 (사진·영상 원본이 크고 개인 자료라서).

## 작업 환경과 기록 (기본 설정, 2026-10-24)

- 사용자는 Claude 데스크탑 앱의 **Code** 화면에서 이 폴더(`content-studio`)를 열고 대화로 작업한다. 터미널 Claude Code와 같은 파일·설정을 쓴다.
- **커밋은 자동**: 작업이 하나 끝날 때마다 바뀐 파일을 git 커밋한다. 사용자에게 따로 묻지 않는다.
  - 커밋 메시지는 한국어로, 제목 아래에 왜 바꿨는지 1~3줄을 쓴다.
- **올리기(push)는 매번 묻는다**: GitHub 저장소(`kim-svadoz/momonga`)가 공개라서, push 전에 무엇이 올라가는지 쉬운 말로 알려 주고 허락을 받는다.
- **개인 자료는 git에 넣지 않는다**: 사진·영상, 내가 쓴 글 원본, 예전 작업 폴더 등. 새 개인 자료 폴더가 생기면 `.gitignore`에 먼저 추가하고 커밋한다.
  - 지금 제외 중: `output/`, `inbox/`(입력함), `bengjjang/`(바탕화면 벵짱 폴더 보관본), `brand/samples/`, `history/글쓰기_규칙_원본.txt`, `assets/sfx/`, `sugo/config.json`·`sugo/install-manifest.json`(컴퓨터마다 경로가 달라서)

## 도구

- 숏폼 편집기: `apps/shorts-editor/` — 실행법은 그 폴더의 README. 저장소 폴더에서 서버를 켜야 채널 프로필을 읽는다.
- 릴스 자막·썸네일 도구: `tools/haul-reel/` — 영상 한 편의 내용은 `episodes/<회차>.json`, 채널 설정은 `channels/<채널>/profile.json`에서 읽는다 (README 참고).
- 채널 프로필 형식: `channels/profile-schema.md`

<!-- sugo:harness-rules:start -->
<!-- 이 블록은 sugo가 자동 관리합니다. 손으로 고치면 다음 sugo_add/sugo_update 때 덮어써집니다. -->
## Sugo 하네스

이 프로젝트에 적용된 코딩 표준이 `.claude/rules/`에 자동 로드되도록 설치돼 있습니다.
전문은 `sugo/harness/<id>/harness.md`, 검증 설정은 `sugo/harness/<id>/validation.yaml`에 있습니다.

- `default`
<!-- sugo:harness-rules:end -->
