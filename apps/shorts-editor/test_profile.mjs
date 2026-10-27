// 채널 프로필 시험. PRD REQ-7: 편집 도구가 채널 프로필을 읽어서 동작하고, 프로필이 다르면 결과가 다르다.
//
// 실행: node --test apps/shorts-editor/test_profile.mjs   (저장소 루트에서)
//
// 1) model.js의 프로필 계산을 node에서 직접 시험한다.
// 2) Chrome이 있으면 서버를 켜고 실제 편집기 화면(headless)에서 프로필이 적용되는지 본다.
import { test } from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import vm from 'node:vm';
import path from 'node:path';
import { spawn, spawnSync } from 'node:child_process';
import { fileURLToPath } from 'node:url';

const here = path.dirname(fileURLToPath(import.meta.url));
const repo = path.resolve(here, '../..');
const readJson = (p) => JSON.parse(fs.readFileSync(path.join(repo, p), 'utf8'));
const reels = readJson('channels/insta-reels/profile.json');
const alt = readJson('tools/haul-reel/fixtures/profile-alt.json');
const tiktok = readJson('channels/tiktok/profile.json'); // 길이 상한을 모르는 채널 (maxSeconds: null)

function freshModel() {
  const ctx = vm.createContext({});
  vm.runInContext(fs.readFileSync(path.join(here, 'model.js'), 'utf8'), ctx);
  // vm 안에서 만든 객체는 프로토타입이 달라 deepEqual이 실패하므로, 값만 JSON으로 꺼낸다
  const run = (code, vars = {}) => {
    Object.assign(ctx, vars);
    const out = vm.runInContext(code, ctx);
    return out !== null && typeof out === 'object' ? JSON.parse(JSON.stringify(out)) : out;
  };
  return run;
}

test('프로필의 화면 크기에 맞는 비율 이름을 찾는다', () => {
  const run = freshModel();
  assert.equal(run('aspectForCanvas(p)', { p: { width: 1080, height: 1920 } }), '9:16');
  assert.equal(run('aspectForCanvas(p)', { p: { width: 1080, height: 1350 } }), '4:5');
  assert.equal(run('aspectForCanvas(p)', { p: { width: 1000, height: 1000 } }), null);
});

test('프로필을 고르면 화면 비율이 프로필을 따른다', () => {
  const run = freshModel();
  assert.deepEqual(run('applyChannelProfile(p)', { p: reels }), { ok: true });
  assert.equal(run('project.aspect'), '9:16');
  assert.equal(run('project.channel'), 'insta-reels');
});

test('다른 프로필을 고르면 다른 결과가 나온다', () => {
  const run = freshModel();
  run('applyChannelProfile(p)', { p: reels });
  const first = run('project.aspect');
  run('applyChannelProfile(p)', { p: alt });
  assert.notEqual(run('project.aspect'), first);
  assert.equal(run('project.aspect'), '4:5');
  assert.equal(run('project.channel'), 'alt-test');
});

test('지원하지 않는 화면 크기면 아무것도 바꾸지 않고 이유를 알린다', () => {
  const run = freshModel();
  run('applyChannelProfile(p)', { p: reels });
  const r = run('applyChannelProfile(p)', { p: { channel: 'weird', canvas: { width: 1000, height: 1000 }, maxSeconds: null, safeArea: null } });
  assert.equal(r.ok, false);
  assert.match(r.message, /1000×1000/);
  assert.equal(run('project.aspect'), '9:16');
  assert.equal(run('project.channel'), 'insta-reels');
});

test('길이 상한이 null이면 검사하지 않고, 있으면 넘을 때만 알린다', () => {
  const run = freshModel();
  run('applyChannelProfile(p)', { p: tiktok });
  assert.equal(run('limitWarning(9999)'), '');
  run('applyChannelProfile(p)', { p: reels });
  assert.equal(run('limitWarning(180)'), '');
  assert.match(run('limitWarning(181)'), /180초를 1\.0초/);
  run('applyChannelProfile(p)', { p: alt });
  assert.equal(run('limitWarning(30)'), '');
  assert.match(run('limitWarning(31.5)'), /30초.*1\.5초/);
});

test('channels 폴더의 모든 편집 설정은 편집기가 지원하는 화면 크기다', () => {
  const run = freshModel();
  const files = fs.readdirSync(path.join(repo, 'channels'), { withFileTypes: true })
    .filter((d) => d.isDirectory() && fs.existsSync(path.join(repo, 'channels', d.name, 'profile.json')))
    .map((d) => d.name);
  assert.ok(files.length >= 5, '영상 채널 편집 설정이 5개 이상 있다');
  for (const name of files) {
    const profile = readJson(`channels/${name}/profile.json`);
    assert.equal(profile.channel, name, `${name}: channel 값이 폴더 이름과 같다`);
    assert.ok(run('aspectForCanvas(p)', { p: profile.canvas }), `${name}: ${profile.canvas.width}x${profile.canvas.height}를 편집기가 지원한다`);
  }
});

test('채널을 풀면 프로필 검사가 사라진다', () => {
  const run = freshModel();
  run('applyChannelProfile(p)', { p: alt });
  run('clearChannelProfile()');
  assert.equal(run('limitWarning(9999)'), '');
  assert.equal(run('project.channel'), '');
});

test('안전 영역이 null이면 띠가 없고, 값이 있으면 위아래 띠를 돌려준다', () => {
  const run = freshModel();
  run('applyChannelProfile(p)', { p: reels });
  assert.deepEqual(run('safeAreaBands()'), []);
  run('applyChannelProfile(p)', { p: { ...alt, safeArea: { top: 0.1, bottom: 0.2 } } });
  assert.deepEqual(run('safeAreaBands()'), [{ top: 0, height: 0.1 }, { top: 0.8, height: 0.2 }]);
});

test('저장된 프로젝트에 channel이 없어도 불러온다', () => {
  const run = freshModel();
  assert.equal(run('normalizeProject({ aspect: "1:1", scenes: [] }).channel'), '');
  assert.equal(run('normalizeProject({ channel: "tiktok", scenes: [] }).channel'), 'tiktok');
});

// ---------- 실제 화면 ----------
// Chrome을 띄워 편집기를 열고, 초기화가 끝난 뒤(body[data-ready]) 화면 상태를 읽는다.

const CHROME = '/Applications/Google Chrome.app/Contents/MacOS/Google Chrome';
const hasChrome = fs.existsSync(CHROME);
const sleep = (ms) => new Promise((r) => setTimeout(r, ms));

async function until(fn, what, tries = 100) {
  for (let i = 0; i < tries; i++) {
    const v = await fn();
    if (v) return v;
    await sleep(100);
  }
  throw new Error(`시간 안에 끝나지 않았다: ${what}`);
}

async function withServer(fn) {
  const port = 5100 + Math.floor(Math.random() * 800);
  const server = spawn('python3', ['-m', 'http.server', String(port), '--bind', '127.0.0.1', '--directory', repo], { stdio: 'ignore' });
  try {
    await until(() => fetch(`http://127.0.0.1:${port}/`).then((r) => r.ok, () => false), '서버 시작', 50);
    return await fn(port);
  } finally {
    server.kill();
  }
}

// 페이지를 열고 준비될 때까지 기다린 뒤 evaluate(expression)의 값을 돌려준다
async function inPage(url, expression) {
  const debugPort = 9300 + Math.floor(Math.random() * 500);
  const dir = fs.mkdtempSync(path.join(process.env.TMPDIR || '/tmp', 'chrome-'));
  const chrome = spawn(CHROME, ['--headless=new', '--disable-gpu', `--user-data-dir=${dir}`, `--remote-debugging-port=${debugPort}`, 'about:blank'], { stdio: 'ignore' });
  try {
    const targets = await until(() => fetch(`http://127.0.0.1:${debugPort}/json`).then((r) => r.json(), () => null), 'Chrome 시작', 100);
    const ws = new WebSocket(targets.find((t) => t.type === 'page').webSocketDebuggerUrl);
    await new Promise((resolve) => { ws.onopen = resolve; });
    let id = 0;
    const waiting = new Map();
    ws.onmessage = (m) => {
      const d = JSON.parse(m.data);
      if (d.id && waiting.has(d.id)) waiting.get(d.id)(d.result);
    };
    const send = (method, params = {}) => new Promise((resolve) => { waiting.set(++id, resolve); ws.send(JSON.stringify({ id, method, params })); });
    const evaluate = async (expr) => (await send('Runtime.evaluate', { expression: expr, returnByValue: true, awaitPromise: true })).result.value;
    await send('Page.navigate', { url });
    await until(async () => (await evaluate('document.body && document.body.dataset.ready')) === 'true', '편집기 초기화', 200);
    return await evaluate(expression);
  } finally {
    // Chrome이 완전히 끝난 뒤에 임시 폴더를 지운다 (끝나기 전에 지우면 파일을 쓰는 중이라 ENOTEMPTY가 난다)
    const exited = new Promise((resolve) => chrome.once('exit', resolve));
    chrome.kill();
    await exited;
    fs.rmSync(dir, { recursive: true, force: true, maxRetries: 5, retryDelay: 100 });
  }
}

const STATE = `(() => {
  const warn = () => { updateTransport(); return document.getElementById('limitWarning').textContent; };
  project.minDur = 40; project.scenes = [newScene('길이 시험')]; changed({ structure: true });
  return JSON.stringify({
    note: document.getElementById('channelNote').textContent,
    options: [...document.querySelectorAll('#channel option')].map((o) => o.value),
    aspect: document.getElementById('aspect').value,
    aspectLocked: document.getElementById('aspect').disabled,
    warning: warn(),
  });
})()`;
const page = (port, query = '') => inPage(`http://127.0.0.1:${port}/apps/shorts-editor/${query}`, STATE).then(JSON.parse);

test('편집기 화면: 채널 없이 열면 비율을 직접 고를 수 있고 경고가 없다', { skip: !hasChrome }, async () => {
  await withServer(async (port) => {
    const s = await page(port);
    assert.equal(s.aspectLocked, false);
    assert.equal(s.note, '');
    assert.equal(s.warning, '');
  });
});

test('편집기 화면: 채널 목록에는 프로필이 있는 채널만 나온다', { skip: !hasChrome }, async () => {
  await withServer(async (port) => {
    const s = await page(port);
    for (const id of ['insta-reels', 'insta-story', 'tiktok', 'youtube-shorts', 'youtube-long']) {
      assert.ok(s.options.includes(id), `${id}가 목록에 있다`);
    }
    for (const id of ['naver-blog', 'threads', 'insta-post']) {
      assert.ok(!s.options.includes(id), `${id}는 프로필이 없어서 목록에 없다`); // 글·사진 채널
    }
  });
});

test('편집기 화면: 프로필이 다르면 화면 비율과 경고가 다르다', { skip: !hasChrome }, async () => {
  await withServer(async (port) => {
    const r = await page(port, '?profile=channels/insta-reels/profile.json');
    const a = await page(port, '?profile=tools/haul-reel/fixtures/profile-alt.json');
    assert.equal(r.aspectLocked, true);
    assert.equal(r.aspect, '9:16');
    assert.match(r.note, /9:16/);
    assert.equal(r.warning, ''); // 40초는 릴스 상한(180초) 안이다
    assert.equal(a.aspectLocked, true);
    assert.equal(a.aspect, '4:5');
    assert.match(a.note, /30초/);
    assert.match(a.warning, /30초를 10\.0초 넘어요/); // 40초 장면 하나 → 상한 30초 초과
  });
});

test('편집기 화면: 길이 상한이 없는 채널(null)은 아무리 길어도 경고하지 않는다', { skip: !hasChrome }, async () => {
  await withServer(async (port) => {
    const t = await page(port, '?profile=channels/tiktok/profile.json');
    assert.equal(t.aspectLocked, true);
    assert.equal(t.warning, '');
  });
});

test('편집기 화면: 목록에서 고른 채널이 프로젝트에 저장된다', { skip: !hasChrome }, async () => {
  await withServer(async (port) => {
    const saved = await inPage(
      `http://127.0.0.1:${port}/apps/shorts-editor/`,
      `(async () => {
        const sel = document.getElementById('channel');
        sel.value = 'insta-reels';
        sel.dispatchEvent(new Event('change'));
        return JSON.stringify({ channel: project.channel, locked: document.getElementById('aspect').disabled });
      })()`,
    );
    assert.deepEqual(JSON.parse(saved), { channel: 'insta-reels', locked: true });
  });
});

test('편집기 화면: 안전 영역 띠는 미리보기에만 그려지고 내보내기 캔버스에는 없다', { skip: !hasChrome }, async () => {
  await withServer(async (port) => {
    const out = await inPage(
      `http://127.0.0.1:${port}/apps/shorts-editor/?profile=channels/insta-reels/profile.json`,
      `(() => {
        channelProfile = { ...channelProfile, safeArea: { top: 0.1, bottom: 0.2 } };
        redraw();
        const px = (c, x, y) => Array.from(c.getContext('2d').getImageData(x, y, 1, 1).data);
        const exportCanvas = document.createElement('canvas');
        exportCanvas.width = canvas.width; exportCanvas.height = canvas.height;
        renderFrame(exportCanvas.getContext('2d'), 0);
        return JSON.stringify({
          previewTop: px(canvas, 10, 10), previewMiddle: px(canvas, 10, canvas.height / 2),
          exportTop: px(exportCanvas, 10, 10),
        });
      })()`,
    );
    const s = JSON.parse(out);
    assert.ok(s.previewTop[0] > s.previewMiddle[0], '미리보기 위쪽 띠가 빨갛게 보인다');
    assert.equal(s.exportTop[0], s.previewMiddle[0], '내보내기 캔버스에는 띠가 없다');
  });
});
