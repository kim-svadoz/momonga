# 숏츠 편집기

대본을 붙여 넣으면 문장마다 장면을 만들고 화면·자막·효과음·타이틀을 얹어 MP4로 내보내는 브라우저 편집기. 설치 없이 HTML/CSS/JS로 동작한다. TTS는 쓰지 않고, 장면 길이는 글자 수 ÷ 읽는 속도로 정한다.

## 실행

```bash
cd <저장소 폴더>   # momonga
python3 -m http.server 5173 --bind 127.0.0.1
```

Chrome에서 http://localhost:5173/apps/shorts-editor/ 를 연다. 작업 내용은 브라우저(IndexedDB)에 자동 저장된다.
서버를 저장소 폴더에서 켜야 채널 프로필(`channels/<채널>/profile.json`)을 읽을 수 있다. 편집기 폴더만 열면 채널 목록이 비어 있고 "채널 목록을 불러오지 못했어요"가 뜬다.

## 채널 프로필

위쪽 **채널** 칸에서 올릴 채널을 고르면 그 채널의 프로필(`channels/profile-schema.md`)에 맞춰 동작한다.

| 프로필 값 | 편집기에서 하는 일 |
| --- | --- |
| `canvas` | 화면 비율을 프로필 크기에 맞추고 비율 칸을 잠근다. 편집기가 지원하는 크기(9:16, 4:5, 1:1, 16:9)가 아니면 이유를 알리고 바꾸지 않는다 |
| `maxSeconds` | 영상이 상한을 넘으면 시간 표시 옆에 빨간 경고. 값이 `null`(모름)이면 검사하지 않는다 |
| `safeArea` | 글자가 가려지는 위·아래를 미리보기에 붉은 띠로 보여 준다. 내보내는 MP4에는 들어가지 않는다. `null`이면 띠가 없다 |

고른 채널은 프로젝트에 저장된다. 프로필이 있는 채널만 목록에 나온다. 시험용으로 주소 뒤에 `?profile=<저장소 기준 파일 경로>`를 붙이면 그 프로필을 바로 쓴다.
효과음 규칙과 훅 위치는 이 편집기가 읽지 않는다 (`tools/haul-reel/reel.swift`가 읽는다).

시험: `node --test apps/shorts-editor/test_profile.mjs` (저장소 루트에서. Chrome이 있으면 실제 화면까지 확인한다).

## 파일

| 파일 | 역할 |
| --- | --- |
| `model.js` | 프로젝트 데이터와 시간 계산 |
| `render.js` | 한 프레임 그리기 (미리보기·MP4 공용) |
| `app.js` | 화면, 장면 목록, 재생, 패널 |
| `overlay.js` | 타이틀·이미지 얹기 |
| `sfx.js` | 합성 효과음 9종, 효과음 보관함 |
| `fonts.js` | 무료 한글 글꼴, 글꼴 보관함 |
| `trim.js` | 영상 자르기 |
| `export.js` | MP4 내보내기 (WebCodecs + mp4-muxer) |
| `projectio.js` | 프로젝트 zip 저장·불러오기 (JSZip) |
| `db.js` | IndexedDB 저장 |
