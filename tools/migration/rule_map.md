# 이관 대조표

옛 스킬 3개(`naver-blog`, `threads-post`, `fashion-reels`)와 `history/feedback.md`를 새 구조로 옮긴 기록이다. 옛 스킬은 새 구조가 검증될 때까지 지우지 않는다.

기준 커밋: `a42526e` (이관 전). 테스트가 이 커밋의 옛 파일을 읽어서 새 위치와 대조한다.

```
python3 -m unittest tools/migration/test_rule_map.py
```

## 옮긴 위치

| 옛 위치 | 새 위치 |
| --- | --- |
| `skills/naver-blog` (어떤 글, 글 쓰는 법, 사진, 구매 링크, 저장) | `channels/naver-blog/channel.md` |
| `skills/threads-post` (글 종류, 잘 된 글, 모음zip 양식, 글감 제안·창고) | `channels/threads/channel.md` |
| `skills/fashion-reels` (벤치마킹, 기획, 썸네일, 대본·자막, 캡션 DM, 하울, 피팅, 저장) | `channels/insta-reels/channel.md` |
| `history/feedback.md` 네이버·블로그 15건 | `channels/naver-blog/feedback.md` |
| `history/feedback.md` 쓰레드 1건 | `channels/threads/feedback.md` |
| `history/feedback.md` 릴스·피팅 릴스 28건 | `channels/insta-reels/feedback.md` |
| `history/feedback.md` 공통 1건 | `history/feedback.md` (그대로) |
| `brand/caption-rules.md` §4 고정으로 들어가는 것 | `tools/haul-reel/README.md` "양식"이 기준, 이쪽은 포인터만 |

## 중복을 한 곳으로 정리한 것

| 내용 | 기준이 되는 곳 | 나머지 |
| --- | --- | --- |
| 시리즈 라벨·엔딩·효과음 양식 | `tools/haul-reel/README.md` | `brand/caption-rules.md`가 가리킴 |
| 자막 글꼴·크기·위치 | `brand/style-guide.md` | `brand/caption-rules.md`는 기호·문구 규칙만 |
| 채널별 규격·말투 차이 | `channels/<채널>/channel.md` | `brand/style-guide.md`는 공통 기준만 |

## 옛 스킬과 새 채널 문서가 같은 내용을 갖는 기간

옛 스킬을 남겨 두는 동안은 같은 규칙이 두 곳에 있다. 규칙을 고칠 때는 **`channel.md`를 기준**으로 고치고, 옛 스킬은 새 구조 검증이 끝난 뒤 지운다.

## 옮기지 않은 줄

옛 스킬의 줄 중 새 위치에 같은 문장으로 없는 것. 없으면 이유를 적는다.

형식: `- 옛 줄의 앞부분 || 이유`. 테스트는 앞부분으로 시작하는 옛 줄을 예외로 본다.

- 먼저 `brand/profile.md`, `brand/voice.md`를 읽는다. 발행은 || 읽을 문서는 조합기가 항상 같은 순서로 붙인다. "발행은 사용자가 직접 한다"는 `channels/naver-blog/channel.md` "역할"에 있다.
- 구성: 서론(2~4문단) || 같은 내용이 `channel.md` "### 구성" 제목 아래 목록 첫 줄로 옮겨졌다 ("구성:" 말머리만 제목으로 바뀜).
- `output/YYMMDD/naver_<글 주제>/` || 저장 폴더 접두어를 채널 폴더 이름(`naver-blog_`)으로 통일했다. 이전 회차가 `naver_`인 것은 `channel.md`에 적었다.
- 이 규칙은 `history/글쓰기_규칙_원본.txt` || 출처 설명을 `channel.md` "참고"와 "예시"로 나눠 적었다. 바탕화면 폴더 보관(`bengjjang/`)은 `CLAUDE.md`의 "지금 제외 중"에 있다.
- 먼저 `brand/profile.md`, `brand/voice.md`를 읽는다. || 위와 같다. 조합기가 brand 문서를 먼저 붙인다.
- 반응 좋은 글은 `naver-blog` 스킬로 || "스킬"이 아니라 "채널"로 바뀌어 `channels/threads/channel.md` "참고"에 있다 ("`naver-blog`로 블로그 장편 글로").
- 모음zip은 `fashion-reels` 스킬로 || 같은 이유로 `channels/threads/channel.md` "참고"에 있다 ("`insta-reels`로 릴스로도").
- 먼저 `brand/profile.md`, `brand/style-guide.md`, `brand/voice.md`를 읽는다. 목표는 || 읽을 문서는 조합기가 붙인다. 목표 문장은 `channels/insta-reels/channel.md` "역할"에 있다.
- `output/YYMMDD/reels_<주제>/` || 저장 폴더 접두어를 `insta-reels_`로 통일했다. 이전 회차는 `reels_`라고 `channel.md`에 적었다.
