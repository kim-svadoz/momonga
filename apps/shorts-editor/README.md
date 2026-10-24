# 숏츠 편집기

대본을 붙여 넣으면 문장마다 장면을 만들고 화면·자막·효과음·타이틀을 얹어 MP4로 내보내는 브라우저 편집기. 설치 없이 HTML/CSS/JS로 동작한다. TTS는 쓰지 않고, 장면 길이는 글자 수 ÷ 읽는 속도로 정한다.

## 실행

```bash
python3 -m http.server 5173 --bind 127.0.0.1 --directory ~/content-studio/apps/shorts-editor
```

Chrome에서 http://localhost:5173 을 연다. 작업 내용은 브라우저(IndexedDB)에 자동 저장된다.

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
