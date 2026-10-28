// 프로젝트 데이터 모양과 시간 계산. 미리보기와 MP4 내보내기가 같은 계산을 쓴다.

const ASPECTS = {
  '9:16': [1080, 1920],
  '4:5': [1080, 1350],
  '1:1': [1080, 1080],
  '16:9': [1920, 1080],
};

const DEFAULT_SUBTITLE = () => ({
  font: 'Noto Sans KR',
  weight: 900,
  size: 72,
  spacing: 0,
  lineHeight: 1.3,
  y: 50,
  color: '#ffffff',
  stroke: true,
  strokeColor: '#000000',
  glowColor: '#000000',
  glow: 30,
  box: false,
  boxColor: '#000000',
  boxOpacity: 0.6,
  chunk: 0, // 0이면 끊지 않음, 아니면 한 번에 보여줄 글자 수
});

const DEFAULT_PROJECT = () => ({
  version: 2,
  aspect: '9:16',
  channel: '', // 고른 채널 프로필 이름 (channels/<이름>/profile.json), 없으면 ''
  script: '',
  cps: 6,
  minDur: 1.5,
  subtitle: DEFAULT_SUBTITLE(),
  scenes: [],
});

let project = DEFAULT_PROJECT();

const uid = () => Math.random().toString(36).slice(2, 10);
const clamp = (v, a, b) => Math.min(b, Math.max(a, v));

function newScene(text = '') {
  return {
    id: uid(),
    text,
    autoDur: true,
    duration: 2,
    extra: 0, // 끝에 더 보여주기(초)
    hideSub: false,
    visual: null,
    sfx: [],
    overlays: [],
  };
}

function newVisual(type, props = {}) {
  return { type, fit: 'cover', motion: 'none', dim: 0, volume: 0.8, keep: null, ...props };
}

// 예전 버전으로 저장된 데이터에 빠진 값을 채운다
function normalizeProject(p) {
  const out = Object.assign(DEFAULT_PROJECT(), p);
  out.subtitle = Object.assign(DEFAULT_SUBTITLE(), p.subtitle || {});
  out.scenes = (p.scenes || []).map((s) => {
    const n = Object.assign(newScene(), s);
    if (n.visual) n.visual = newVisual(n.visual.type, n.visual);
    n.sfx = n.sfx || [];
    n.overlays = n.overlays || [];
    return n;
  });
  return out;
}

// ---------- 채널 프로필 ----------
// 프로필 형식은 channels/profile-schema.md. 모르는 값(null)은 검사하지 않는다.

let channelProfile = null; // 지금 고른 채널 프로필, 없으면 null

// 프로필 화면 크기와 같은 비율 이름. 이 편집기가 지원하지 않는 크기면 null
function aspectForCanvas(canvas) {
  const hit = Object.entries(ASPECTS).find(([, [w, h]]) => w === canvas.width && h === canvas.height);
  return hit ? hit[0] : null;
}

// 프로필을 고르면 화면 비율을 프로필에 맞춘다. 지원하지 않는 크기면 아무것도 바꾸지 않고 이유를 돌려준다
function applyChannelProfile(profile) {
  const aspect = aspectForCanvas(profile.canvas);
  if (!aspect) {
    return { ok: false, message: `이 편집기는 ${profile.canvas.width}×${profile.canvas.height} 화면을 지원하지 않아요` };
  }
  channelProfile = profile;
  project.aspect = aspect;
  project.channel = profile.channel;
  return { ok: true };
}

function clearChannelProfile() {
  channelProfile = null;
  project.channel = '';
}

// 영상이 채널 길이 상한을 넘으면 알림 글, 아니면 ''
function limitWarning(total) {
  const max = channelProfile && channelProfile.maxSeconds;
  if (max == null || total <= max) return '';
  return `채널 상한 ${max}초를 ${(total - max).toFixed(1)}초 넘어요`;
}

// 글자가 가려지는 위·아래 영역을 화면 높이 비율 띠로. 모르면(null) 빈 목록
function safeAreaBands() {
  const area = channelProfile && channelProfile.safeArea;
  if (!area) return [];
  const bands = [];
  if (area.top > 0) bands.push({ top: 0, height: area.top });
  if (area.bottom > 0) bands.push({ top: 1 - area.bottom, height: area.bottom });
  return bands;
}

// ---------- 길이 ----------

function autoDuration(text) {
  const len = text.replace(/\s/g, '').length;
  return Math.max(project.minDur, len / project.cps);
}

// 자막이 나오는 길이(끝에 더 보여주기 제외)
function sceneBaseDuration(s) {
  return s.autoDur ? autoDuration(s.text) : Math.max(0.1, s.duration);
}

function sceneDuration(s) {
  return sceneBaseDuration(s) + Math.max(0, s.extra || 0);
}

function timing() {
  let acc = 0;
  return project.scenes.map((s) => {
    const start = acc;
    acc += sceneDuration(s);
    return { scene: s, start, end: acc };
  });
}

function totalDuration() {
  const tm = timing();
  return tm.length ? tm[tm.length - 1].end : 0;
}

function sceneIndexAt(time, tm = timing()) {
  if (!tm.length) return -1;
  const i = tm.findIndex((x) => time < x.end);
  return i === -1 ? tm.length - 1 : i;
}

// ---------- 화면 ----------

// 화면을 안 넣은 장면은 앞 장면의 화면을 이어서 쓴다
function resolveVisual(index) {
  for (let i = index; i >= 0; i--) {
    const v = project.scenes[i] && project.scenes[i].visual;
    if (v) return { visual: v, owner: i };
  }
  return { visual: null, owner: -1 };
}

// owner 장면의 화면이 이어지는 구간(다음에 화면을 새로 넣은 장면 직전까지)
function visualSpan(owner, tm) {
  let last = owner;
  while (last + 1 < tm.length && !tm[last + 1].scene.visual) last++;
  return { start: tm[owner].start, end: tm[last].end };
}

// 영상 자르기로 남긴 구간 목록
function keepSegments(visual, dur) {
  if (!isFinite(dur) || dur <= 0) return [];
  const keep = visual.keep && visual.keep.length ? visual.keep : [{ s: 0, e: dur }];
  return keep
    .map((k) => ({ s: clamp(k.s, 0, dur), e: clamp(k.e, 0, dur) }))
    .filter((k) => k.e - k.s > 0.01);
}

// 장면 안에서 흐른 시간 → 원본 영상의 재생 위치. 남긴 구간만 이어서 반복한다.
function videoTimeAt(visual, dur, local) {
  const segs = keepSegments(visual, dur);
  const eff = segs.reduce((a, k) => a + (k.e - k.s), 0);
  if (eff <= 0) return 0;
  let x = ((local % eff) + eff) % eff;
  for (const k of segs) {
    const len = k.e - k.s;
    if (x < len) return k.s + x;
    x -= len;
  }
  return segs[segs.length - 1].e;
}

// ---------- 자막 ----------

function splitSentences(text) {
  return text
    .split(/(?<=[.!?。？！…])\s+|\n+/)
    .map((s) => s.trim())
    .filter(Boolean);
}

// 긴 문장을 약 n글자씩 끊는다. 가능하면 띄어쓰기에서 끊는다.
function chunkText(text, n) {
  if (!n) return [text];
  const out = [];
  let cur = '';
  for (const word of text.split(/\s+/).filter(Boolean)) {
    const test = cur ? cur + ' ' + word : word;
    if (test.length <= n) { cur = test; continue; }
    if (cur) out.push(cur);
    let w = word;
    while (w.length > n) { out.push(w.slice(0, n)); w = w.slice(n); }
    cur = w;
  }
  if (cur) out.push(cur);
  return out.length ? out : [text];
}

// 장면 안 시각에 보여줄 자막 조각. 글자 수 비율로 시간을 나눈다.
function subtitleAt(scene, local) {
  const chunks = chunkText(scene.text, project.subtitle.chunk);
  if (chunks.length === 1) return chunks[0];
  const base = sceneBaseDuration(scene);
  const total = chunks.reduce((a, c) => a + c.length, 0);
  let acc = 0;
  for (const c of chunks) {
    acc += c.length;
    if (local < (base * acc) / total) return c;
  }
  return chunks[chunks.length - 1];
}

// 프로젝트가 쓰는 파일 id (장면 화면, 얹은 이미지)
function usedFileIds() {
  const ids = new Set();
  for (const s of project.scenes) {
    if (s.visual && s.visual.fileId) ids.add(s.visual.fileId);
    for (const o of s.overlays) if (o.type === 'image' && o.fileId) ids.add(o.fileId);
  }
  return ids;
}
