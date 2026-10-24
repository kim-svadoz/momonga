// 숏츠 편집기 화면: 장면 목록, 재생, 설정 패널, 파일 넣기, 저장·내보내기
// TTS 없이 동작한다. 장면 길이는 글자 수 ÷ 읽는 속도로 자동 계산하거나 직접 정한다.

const $ = (id) => document.getElementById(id);
const canvas = $('preview');
const ctx = canvas.getContext('2d');

// 재생 상태
let t = 0;
let playing = false;
let playEnd = 0;
let lastPerf = 0;
let exporting = false;
let liveSfx = [];
const openDetails = new Set(); // 장면 카드에서 펼쳐 둔 칸 ("장면id:칸")

// ---------- 미디어 ----------

function loadMedia(fileId, blob, type) {
  if (media[fileId]) return media[fileId];
  const url = URL.createObjectURL(blob);
  const m = { type, url, el: null, thumb: null };
  if (type === 'image') {
    m.el = new Image();
    m.el.onload = () => { redraw(); updateThumbs(fileId); };
    m.el.src = url;
  } else {
    const v = document.createElement('video');
    v.loop = false;
    v.playsInline = true;
    v.preload = 'auto';
    v.addEventListener('loadeddata', () => {
      // 썸네일용 첫 화면
      try {
        const c = document.createElement('canvas');
        c.width = 120;
        c.height = Math.round((120 * v.videoHeight) / v.videoWidth) || 200;
        c.getContext('2d').drawImage(v, 0, 0, c.width, c.height);
        m.thumb = c.toDataURL('image/jpeg', 0.7);
      } catch (e) { /* 썸네일 없이 진행 */ }
      redraw();
      updateThumbs(fileId);
    }, { once: true });
    v.addEventListener('seeked', () => { if (!playing && !exporting) redraw(); });
    v.src = url;
    m.el = v;
  }
  media[fileId] = m;
  return m;
}

function fileType(file) {
  if (file.type.startsWith('video/')) return 'video';
  if (file.type.startsWith('image/')) return 'image';
  return null;
}

async function setSceneFile(scene, file) {
  const type = fileType(file);
  if (!type) { alert('이미지나 영상 파일만 넣을 수 있어요.'); return; }
  const fileId = 'f_' + uid();
  await DB.put('files', fileId, file);
  loadMedia(fileId, file, type);
  const prev = scene.visual && scene.visual.type !== 'color' ? scene.visual : null;
  // 화면만 바꾸고 움직임·어둡게 같은 설정은 이어 쓴다
  scene.visual = newVisual(type, prev ? { fit: prev.fit, motion: prev.motion, dim: prev.dim } : {});
  scene.visual.fileId = fileId;
  scene.visual.name = file.name;
  changed({ structure: true });
  cleanupFiles();
}

// 어느 장면에서도 쓰지 않는 파일은 지운다
async function cleanupFiles() {
  const used = usedFileIds();
  const keys = await DB.keys('files');
  for (const k of keys) {
    if (used.has(k)) continue;
    await DB.del('files', k);
    if (media[k]) { URL.revokeObjectURL(media[k].url); delete media[k]; }
  }
}

function currentScene() {
  const i = sceneIndexAt(t);
  return i >= 0 ? project.scenes[i] : null;
}

// ---------- 미리보기 ----------

function resizeCanvas() {
  const [w, h] = ASPECTS[project.aspect];
  if (canvas.width !== w || canvas.height !== h) {
    canvas.width = w;
    canvas.height = h;
  }
}

function syncVideos() {
  const av = activeVideoAt(t);
  for (const m of Object.values(media)) {
    if (m.type !== 'video') continue;
    const v = m.el;
    if (!av || av.m !== m) { if (!v.paused) v.pause(); continue; }
    const vol = clamp(av.visual.volume, 0, 1);
    v.muted = vol === 0;
    v.volume = vol;
    if (playing) {
      if (v.paused) v.play().catch(() => {});
      if (Math.abs(v.currentTime - av.target) > 0.25) v.currentTime = av.target;
    } else {
      if (!v.paused) v.pause();
      if (Math.abs(v.currentTime - av.target) > 0.04) v.currentTime = av.target;
    }
  }
}

function redraw() {
  if (exporting) return;
  resizeCanvas();
  syncVideos();
  renderFrame(ctx, t, { hint: true });
  Overlays.drawSelection(ctx);
}

// ---------- 재생 ----------

function stopSfx() {
  for (const s of liveSfx) { try { s.stop(); } catch (e) { /* 이미 끝남 */ } }
  liveSfx = [];
}

async function startSfx(from, to) {
  stopSfx();
  const ac = Sfx.audioCtx();
  await ac.resume();
  await Sfx.preload();
  if (!playing) return;
  liveSfx = Sfx.schedule(ac, ac.destination, from, to, ac.currentTime + 0.03);
}

async function play(from, to) {
  const total = totalDuration();
  if (!total) return;
  t = from >= total - 0.01 ? 0 : from;
  playEnd = to != null ? to : total;
  playing = true;
  $('playBtn').textContent = '⏸ 정지';
  // 효과음을 만드는 동안(처음 한 번) 그림이 앞서가지 않게 기다렸다가 같이 출발한다
  await Sfx.preload();
  if (!playing) return;
  lastPerf = performance.now();
  startSfx(t, playEnd);
  requestAnimationFrame(loop);
}

function stop() {
  playing = false;
  stopSfx();
  $('playBtn').textContent = '▶ 재생';
  redraw();
  updateTransport();
}

function loop(now) {
  if (!playing) return;
  t += Math.max(0, now - lastPerf) / 1000;
  lastPerf = now;
  if (t >= playEnd) {
    t = Math.min(playEnd, totalDuration());
    stop();
    return;
  }
  redraw();
  updateTransport();
  requestAnimationFrame(loop);
}

function seek(time) {
  t = clamp(time, 0, totalDuration());
  if (playing) {
    playEnd = totalDuration();
    lastPerf = performance.now();
    startSfx(t, playEnd);
  }
  redraw();
  updateTransport();
}

const fmt = (s) => {
  const m = Math.floor(s / 60);
  return `${m}:${(s - m * 60).toFixed(1).padStart(4, '0')}`;
};

let lastActive = -2;
let panelSceneId = null;
function updateTransport() {
  const total = totalDuration();
  $('timeLabel').textContent = `${fmt(t)} / ${fmt(total)}`;
  $('playhead').style.left = total ? `${(t / total) * 100}%` : '0';
  const i = sceneIndexAt(t);
  if (i !== lastActive) {
    lastActive = i;
    document.querySelectorAll('.tl-block').forEach((b, k) => b.classList.toggle('active', k === i));
    document.querySelectorAll('.scene').forEach((c, k) => c.classList.toggle('active', k === i));
  }
  // 얹기 패널은 지금 장면이 바뀔 때만 다시 그린다 (입력 중인 칸이 날아가지 않게)
  const id = i >= 0 ? project.scenes[i].id : null;
  if (id !== panelSceneId) {
    panelSceneId = id;
    Overlays.renderPanel();
  }
}

// ---------- 장면 목록·타임라인 ----------

function visualStyle(visual) {
  if (!visual) return '';
  if (visual.type === 'color') return `background:${visual.color}`;
  const m = media[visual.fileId];
  if (!m) return 'background:#333';
  if (m.type === 'image') return `background-image:url("${m.url}")`;
  return m.thumb ? `background-image:url("${m.thumb}")` : 'background:#333';
}

function visualLabel(visual) {
  if (!visual) return '없음';
  if (visual.type === 'color') return '';
  return visual.type === 'video' ? '🎬' : '';
}

function updateThumbs(fileId) {
  document.querySelectorAll(`[data-file="${fileId}"]`).forEach((el) => {
    el.style.cssText += ';' + visualStyle({ type: media[fileId].type, fileId });
  });
}

function renderTimeline() {
  const tl = $('timeline');
  tl.querySelectorAll('.tl-block').forEach((b) => b.remove());
  const tm = timing();
  const total = totalDuration();
  tm.forEach((x, i) => {
    const b = document.createElement('div');
    const { visual } = resolveVisual(i);
    b.className = 'tl-block';
    b.style.width = `${((x.end - x.start) / total) * 100}%`;
    b.style.cssText += ';' + visualStyle(visual);
    if (visual && visual.fileId) b.dataset.file = visual.fileId;
    const label = x.scene.text || '(화면만)';
    b.textContent = `${i + 1}. ${label}`;
    b.title = `${i + 1}. ${label} (${(x.end - x.start).toFixed(1)}초)`;
    tl.appendChild(b);
  });
  lastActive = -2;
  updateTransport();
}

function sfxItemHtml(e, k) {
  return `
    <div class="sfx-item" data-k="${k}">
      <div class="row">
        <select class="sfx-src">${Sfx.optionsHtml(e.src)}</select>
        <button class="small sfx-play" title="미리 듣기">▶</button>
        <button class="small ghost sfx-del" title="빼기">✕</button>
      </div>
      <div class="row">
        <span>음량</span><input type="range" class="sfx-vol" min="0" max="1.5" step="0.05" value="${e.volume}">
        <span>시작</span><input type="number" class="sfx-off" min="0" step="0.1" value="${e.offset}"><span>초 뒤</span>
      </div>
    </div>`;
}

function visualSettingsHtml(v) {
  const isMedia = v.type === 'image' || v.type === 'video';
  return `
    ${isMedia ? `<label class="row">맞추기
      <select class="v-fit">
        <option value="cover" ${v.fit === 'cover' ? 'selected' : ''}>화면 가득 채우기</option>
        <option value="contain" ${v.fit === 'contain' ? 'selected' : ''}>전체가 보이게</option>
      </select></label>
    <label class="row">움직임
      <select class="v-motion">${Object.entries(MOTIONS).map(([k, l]) => `<option value="${k}" ${v.motion === k ? 'selected' : ''}>${l}</option>`).join('')}</select>
    </label>` : ''}
    <label class="row">어둡게 <input type="range" class="v-dim" min="0" max="0.85" step="0.05" value="${v.dim}"></label>
    ${v.type === 'video' ? `<label class="row">영상 소리 <input type="range" class="v-vol" min="0" max="1" step="0.05" value="${v.volume}"></label>` : ''}`;
}

function renderScenes() {
  const list = $('sceneList');
  const scroll = list.parentElement.scrollTop;
  list.innerHTML = '';
  $('sceneCount').textContent = project.scenes.length ? `${project.scenes.length}개` : '';

  project.scenes.forEach((s, i) => {
    const li = document.createElement('li');
    li.className = 'scene';
    const { visual, owner } = resolveVisual(i);
    const inherited = !s.visual && owner >= 0;
    const own = s.visual;
    // 자르기는 지금 보이는 영상(이어 쓰는 앞 장면 영상 포함)에 적용한다
    const video = visual && visual.type === 'video' ? visual : null;

    li.innerHTML = `
      <div class="scene-thumb ${inherited ? 'inherit' : ''}" ${visual && visual.fileId ? `data-file="${visual.fileId}"` : ''}
        style='${visualStyle(visual)}' title="${inherited ? '앞 장면 화면을 이어서 써요' : ''}">
        ${i + 1}${inherited ? ' ↑' : ''} ${visualLabel(visual)}
      </div>
      <div class="scene-body">
        <textarea rows="2" class="txt" placeholder="(화면만 보여주는 장면)"></textarea>
        <div class="scene-meta">
          <label><input type="checkbox" class="auto" ${s.autoDur ? 'checked' : ''}> 자동</label>
          <input type="number" class="dur" min="0.1" step="0.1" ${s.autoDur ? 'disabled' : ''} value="${sceneBaseDuration(s).toFixed(1)}"> 초
          <span class="muted">· 끝에 더</span>
          <input type="number" class="extra" min="0" step="0.5" value="${s.extra || 0}"> 초
        </div>
        <div class="scene-meta">
          <label><input type="checkbox" class="hidesub" ${s.hideSub ? 'checked' : ''}> 자막 숨기기</label>
        </div>
        <div class="scene-meta">
          화면:
          <button class="small pick">이미지/영상</button>
          <input type="color" class="color" value="${own && own.type === 'color' ? own.color : '#222222'}" title="단색 화면">
          <button class="small trim" ${video ? `title="${inherited ? '이어 쓰는 앞 장면 영상을 잘라요' : '영상 앞뒤·중간 자르기'}"` : 'disabled title="영상을 넣은 장면에서 쓸 수 있어요"'}>✂ 영상 자르기</button>
          ${own ? '<button class="small ghost clear" title="앞 장면 화면 이어쓰기">비우기</button>' : ''}
          <input type="file" class="file" accept="image/*,video/*" hidden>
        </div>
        ${own ? `<details data-key="vis"><summary>화면 설정</summary>${visualSettingsHtml(own)}</details>` : ''}
        <details data-key="sfx">
          <summary>효과음 ${s.sfx.length ? `(${s.sfx.length})` : ''}</summary>
          ${s.sfx.map(sfxItemHtml).join('')}
          <button class="small sfx-add">+ 효과음</button>
        </details>
        <div class="scene-actions">
          <button class="small playone" title="이 장면만 재생">▶</button>
          <button class="small up" ${i === 0 ? 'disabled' : ''}>↑</button>
          <button class="small down" ${i === project.scenes.length - 1 ? 'disabled' : ''}>↓</button>
          <span class="spacer"></span>
          <button class="small del">삭제</button>
        </div>
      </div>`;

    const q = (sel) => li.querySelector(sel);

    // 펼쳐 둔 칸은 다시 그려도 펼친 채로
    li.querySelectorAll('details').forEach((d) => {
      const key = `${s.id}:${d.dataset.key}`;
      d.open = openDetails.has(key);
      d.addEventListener('toggle', () => { d.open ? openDetails.add(key) : openDetails.delete(key); });
    });

    q('.txt').value = s.text;
    q('.txt').addEventListener('input', (e) => {
      s.text = e.target.value;
      if (s.autoDur) q('.dur').value = sceneBaseDuration(s).toFixed(1);
      changed();
    });
    q('.auto').addEventListener('change', (e) => {
      if (!e.target.checked) s.duration = sceneBaseDuration(s);
      s.autoDur = e.target.checked;
      changed({ structure: true });
    });
    q('.dur').addEventListener('input', (e) => {
      const v = parseFloat(e.target.value);
      if (v > 0) { s.duration = v; changed(); }
    });
    q('.extra').addEventListener('input', (e) => {
      const v = parseFloat(e.target.value);
      s.extra = v > 0 ? v : 0;
      changed();
    });
    q('.hidesub').addEventListener('change', (e) => { s.hideSub = e.target.checked; changed(); });

    // 화면
    q('.pick').addEventListener('click', () => q('.file').click());
    q('.file').addEventListener('change', (e) => { if (e.target.files[0]) setSceneFile(s, e.target.files[0]); });
    q('.color').addEventListener('input', (e) => {
      if (s.visual && s.visual.type === 'color') s.visual.color = e.target.value;
      else s.visual = newVisual('color', { color: e.target.value, dim: s.visual ? s.visual.dim : 0 });
      changed({ structure: true, debounceUi: true });
    });
    q('.color').addEventListener('change', () => cleanupFiles());
    if (q('.clear')) q('.clear').addEventListener('click', () => {
      s.visual = null;
      changed({ structure: true });
      cleanupFiles();
    });
    if (video) q('.trim').addEventListener('click', () => Trim.open(video, () => changed()));
    if (q('.v-fit')) q('.v-fit').addEventListener('change', (e) => { s.visual.fit = e.target.value; changed(); });
    if (q('.v-motion')) q('.v-motion').addEventListener('change', (e) => { s.visual.motion = e.target.value; changed(); });
    if (q('.v-dim')) q('.v-dim').addEventListener('input', (e) => { s.visual.dim = parseFloat(e.target.value); changed(); });
    if (q('.v-vol')) q('.v-vol').addEventListener('input', (e) => { s.visual.volume = parseFloat(e.target.value); changed(); });

    // 효과음
    q('.sfx-add').addEventListener('click', () => {
      s.sfx.push({ id: uid(), src: 'synth:click', volume: 0.8, offset: 0 });
      openDetails.add(`${s.id}:sfx`);
      changed({ structure: true });
    });
    li.querySelectorAll('.sfx-item').forEach((row) => {
      const e = s.sfx[+row.dataset.k];
      row.querySelector('.sfx-src').addEventListener('change', (ev) => { e.src = ev.target.value; changed(); Sfx.preview(e.src, e.volume); });
      row.querySelector('.sfx-play').addEventListener('click', () => Sfx.preview(e.src, e.volume));
      row.querySelector('.sfx-del').addEventListener('click', () => {
        s.sfx = s.sfx.filter((x) => x !== e);
        changed({ structure: true });
      });
      row.querySelector('.sfx-vol').addEventListener('input', (ev) => { e.volume = parseFloat(ev.target.value); changed(); });
      row.querySelector('.sfx-off').addEventListener('input', (ev) => {
        const v = parseFloat(ev.target.value);
        e.offset = v > 0 ? v : 0;
        changed();
      });
    });

    // 순서·재생
    q('.playone').addEventListener('click', () => {
      const x = timing()[i];
      play(x.start, x.end);
    });
    q('.up').addEventListener('click', () => moveScene(i, -1));
    q('.down').addEventListener('click', () => moveScene(i, 1));
    q('.del').addEventListener('click', () => {
      project.scenes.splice(i, 1);
      changed({ structure: true });
      cleanupFiles();
    });
    // 카드 어디를 눌러도 그 장면을 선택한다. ↑↓·삭제·▶는 각자 처리한다.
    li.addEventListener('click', (e) => {
      if (e.target.closest('.up, .down, .del, .playone')) return;
      if (sceneIndexAt(t) !== i) seek(timing()[i].start);
    });

    // 파일을 카드에 끌어다 놓으면 그 장면 화면으로
    li.addEventListener('dragover', (e) => { e.preventDefault(); li.classList.add('drop-target'); });
    li.addEventListener('dragleave', () => li.classList.remove('drop-target'));
    li.addEventListener('drop', (e) => {
      e.preventDefault();
      e.stopPropagation();
      li.classList.remove('drop-target');
      const f = e.dataTransfer.files[0];
      if (f) setSceneFile(s, f);
    });

    list.appendChild(li);
  });
  list.parentElement.scrollTop = scroll;
  lastActive = -2;
  updateTransport();
}

function moveScene(i, dir) {
  const j = i + dir;
  if (j < 0 || j >= project.scenes.length) return;
  const arr = project.scenes;
  [arr[i], arr[j]] = [arr[j], arr[i]];
  changed({ structure: true });
  // 옮긴 카드를 선택 상태로 따라가고, 같은 버튼에 포커스를 둬서 연달아 누를 수 있게 한다
  seek(timing()[j].start);
  const card = $('sceneList').children[j];
  card.scrollIntoView({ block: 'nearest' });
  const btn = card.querySelector(dir < 0 ? '.up' : '.down');
  (btn.disabled ? card.querySelector(dir < 0 ? '.down' : '.up') : btn).focus();
}

// ---------- 변경·저장 ----------

let saveTimer, uiTimer;
function changed({ structure = false, debounceUi = false } = {}) {
  if (structure) {
    if (debounceUi) {
      clearTimeout(uiTimer);
      uiTimer = setTimeout(renderScenes, 150);
    } else {
      renderScenes();
    }
  }
  renderTimeline();
  if (t > totalDuration()) t = totalDuration();
  if (!playing) redraw();
  $('saveStatus').textContent = '저장 중…';
  clearTimeout(saveTimer);
  saveTimer = setTimeout(async () => {
    await DB.put('kv', 'project', project);
    $('saveStatus').textContent = '저장됨';
  }, 300);
}

// ---------- 왼쪽 패널 ----------

function readInput(el) {
  if (el.type === 'checkbox') return el.checked;
  if (el.type === 'range' || el.type === 'number' || el.dataset.num != null) return parseFloat(el.value);
  return el.value;
}

function showOutput(el) {
  const out = el.parentElement.querySelector('output');
  if (out) out.textContent = el.value;
}

function bindSettings() {
  const simple = { aspect: 'aspect', script: 'script', cps: 'cps', minDur: 'minDur' };
  for (const [id, key] of Object.entries(simple)) {
    $(id).addEventListener('input', () => {
      const v = readInput($(id));
      if (typeof v === 'number' && !(v > 0)) return;
      project[key] = v;
      changed({ structure: key === 'cps' || key === 'minDur' });
    });
  }
  document.querySelectorAll('[data-sub]').forEach((el) => {
    el.addEventListener('input', () => {
      project.subtitle[el.dataset.sub] = readInput(el);
      showOutput(el);
      changed();
    });
  });
}

function fillSettings() {
  $('aspect').value = project.aspect;
  $('script').value = project.script;
  $('cps').value = project.cps;
  $('minDur').value = project.minDur;
  $('subFont').innerHTML = Fonts.optionsHtml(project.subtitle.font);
  document.querySelectorAll('[data-sub]').forEach((el) => {
    const v = project.subtitle[el.dataset.sub];
    if (el.type === 'checkbox') el.checked = !!v;
    else el.value = v;
    showOutput(el);
  });
}

function renderFontLibrary() {
  $('fontLibrary').innerHTML = Fonts.library.length
    ? Fonts.library.map((f) => `<li><span style="font-family:'${f.family}'">${escapeHtml(f.family)}</span>
        <button class="small ghost" data-id="${f.id}">지우기</button></li>`).join('')
    : '<li class="muted">아직 없어요</li>';
  $('fontLibrary').querySelectorAll('button').forEach((b) => {
    b.onclick = async () => {
      if (!confirm('이 글꼴을 보관함에서 지울까요?')) return;
      await Fonts.remove(b.dataset.id);
      renderFontLibrary();
    };
  });
  $('subFont').innerHTML = Fonts.optionsHtml(project.subtitle.font);
  Overlays.renderPanel();
}

function renderSfxLibrary() {
  $('sfxLibrary').innerHTML = Sfx.library.length
    ? Sfx.library.map((x) => `<li><span>${escapeHtml(x.name)}</span>
        <span><button class="small" data-play="${x.id}">▶</button>
        <button class="small ghost" data-del="${x.id}">지우기</button></span></li>`).join('')
    : '<li class="muted">아직 없어요</li>';
  $('sfxLibrary').querySelectorAll('[data-play]').forEach((b) => { b.onclick = () => Sfx.preview('lib:' + b.dataset.play); });
  $('sfxLibrary').querySelectorAll('[data-del]').forEach((b) => {
    b.onclick = async () => {
      if (!confirm('이 효과음을 보관함에서 지울까요? 이 효과음을 쓰던 장면에서는 소리가 안 나요.')) return;
      await Sfx.remove(b.dataset.del);
      renderSfxLibrary();
      renderScenes();
    };
  });
}

// ---------- 내보내기·저장 ----------

async function exportMp4() {
  if (!project.scenes.length) { alert('장면이 없어요.'); return; }
  stop();
  exporting = true;
  const modal = $('exportModal');
  modal.hidden = false;
  $('exportBar').style.width = '0';
  try {
    const blob = await Exporter.run({
      onProgress: (p, msg) => {
        $('exportBar').style.width = `${Math.round(p * 100)}%`;
        $('exportMsg').textContent = msg;
      },
    });
    if (blob) {
      const d = new Date();
      const stamp = `${d.getMonth() + 1}${String(d.getDate()).padStart(2, '0')}-${String(d.getHours()).padStart(2, '0')}${String(d.getMinutes()).padStart(2, '0')}`;
      download(blob, `shorts-${stamp}.mp4`);
    }
  } catch (e) {
    console.error(e);
    alert('MP4 내보내기에 실패했어요: ' + e.message);
  } finally {
    exporting = false;
    modal.hidden = true;
    redraw();
  }
}

async function loadProjectZip(file) {
  if (!confirm('지금 프로젝트를 불러온 프로젝트로 바꿀까요? 지금 작업은 사라져요. 필요하면 먼저 "프로젝트 저장"을 해 주세요.')) return;
  stop();
  try {
    const next = await ProjectIO.load(file);
    for (const k of Object.keys(media)) { URL.revokeObjectURL(media[k].url); delete media[k]; }
    project = next;
    await loadProjectMedia();
    t = 0;
    fillSettings();
    renderFontLibrary();
    renderSfxLibrary();
    changed({ structure: true });
  } catch (e) {
    console.error(e);
    alert('불러오기에 실패했어요: ' + e.message);
  }
}

async function loadProjectMedia() {
  const types = new Map();
  for (const s of project.scenes) {
    if (s.visual && s.visual.fileId) types.set(s.visual.fileId, s.visual.type);
    for (const o of s.overlays) if (o.type === 'image') types.set(o.fileId, 'image');
  }
  for (const [id, type] of types) {
    const blob = await DB.get('files', id);
    if (blob) loadMedia(id, blob, type);
  }
  // 파일이 없어진 화면은 비운다
  for (const s of project.scenes) {
    if (s.visual && s.visual.fileId && !media[s.visual.fileId]) s.visual = null;
    s.overlays = s.overlays.filter((o) => o.type !== 'image' || media[o.fileId]);
  }
}

// ---------- 이벤트 ----------

function initEvents() {
  $('splitBtn').addEventListener('click', () => {
    const sentences = splitSentences(project.script);
    if (!sentences.length) { alert('대본을 먼저 넣어 주세요.'); return; }
    const old = project.scenes;
    project.scenes = sentences.map((text, i) => {
      const s = newScene(text);
      // 글만 바꾸고, 같은 자리 장면의 화면·효과음·얹은 것·설정은 이어 쓴다
      if (old[i]) Object.assign(s, { visual: old[i].visual, sfx: old[i].sfx, overlays: old[i].overlays, extra: old[i].extra, hideSub: old[i].hideSub });
      return s;
    });
    t = 0;
    changed({ structure: true });
    cleanupFiles();
  });

  const insertScene = (s) => {
    const i = sceneIndexAt(t);
    project.scenes.splice(i + 1, 0, s);
    changed({ structure: true });
    seek(timing()[i + 1].start);
  };
  $('addScene').addEventListener('click', () => insertScene(newScene('새 문장')));
  $('addVisualScene').addEventListener('click', () => {
    const s = newScene('');
    s.autoDur = false;
    s.duration = 3;
    insertScene(s);
  });

  $('playBtn').addEventListener('click', () => (playing ? stop() : play(t)));

  $('timeline').addEventListener('click', (e) => {
    const r = e.currentTarget.getBoundingClientRect();
    seek(((e.clientX - r.left) / r.width) * totalDuration());
  });

  $('resetProject').addEventListener('click', async () => {
    if (!confirm('지금 프로젝트를 지우고 새로 시작할까요? 넣어 둔 화면 파일도 지워져요. (글꼴·효과음 보관함은 남아요)')) return;
    stop();
    await DB.del('kv', 'project');
    await DB.clear('files');
    for (const k of Object.keys(media)) { URL.revokeObjectURL(media[k].url); delete media[k]; }
    project = DEFAULT_PROJECT();
    t = 0;
    fillSettings();
    changed({ structure: true });
  });

  // 보관함
  $('addFont').addEventListener('click', () => $('addFontFile').click());
  $('addFontFile').addEventListener('change', async (e) => {
    for (const f of e.target.files) {
      try { await Fonts.addFile(f); } catch (err) { alert(`${f.name}: ${err.message || '글꼴을 읽지 못했어요.'}`); }
    }
    e.target.value = '';
    renderFontLibrary();
  });
  $('addSfx').addEventListener('click', () => $('addSfxFile').click());
  $('addSfxFile').addEventListener('change', async (e) => {
    for (const f of e.target.files) await Sfx.addFile(f);
    e.target.value = '';
    renderSfxLibrary();
    renderScenes();
  });

  // 저장·불러오기·내보내기
  $('saveZip').addEventListener('click', async () => {
    $('saveZip').disabled = true;
    try { await ProjectIO.save(); } catch (e) { alert('저장에 실패했어요: ' + e.message); }
    $('saveZip').disabled = false;
  });
  $('loadZip').addEventListener('click', () => $('loadZipFile').click());
  $('loadZipFile').addEventListener('change', (e) => {
    if (e.target.files[0]) loadProjectZip(e.target.files[0]);
    e.target.value = '';
  });
  $('exportMp4').addEventListener('click', exportMp4);
  $('exportCancel').addEventListener('click', () => {
    Exporter.cancel();
    $('exportMsg').textContent = '취소하는 중…';
  });

  // 미리보기에 끌어다 놓기 → 지금 장면 화면
  const wrap = $('previewWrap');
  wrap.addEventListener('dragover', (e) => { e.preventDefault(); canvas.classList.add('drop-target'); });
  wrap.addEventListener('dragleave', () => canvas.classList.remove('drop-target'));
  wrap.addEventListener('drop', (e) => {
    e.preventDefault();
    canvas.classList.remove('drop-target');
    const f = e.dataTransfer.files[0];
    const s = currentScene();
    if (f && s) setSceneFile(s, f);
  });
  // 창 다른 곳에 떨어뜨려도 브라우저가 파일을 열지 않게
  window.addEventListener('dragover', (e) => e.preventDefault());
  window.addEventListener('drop', (e) => e.preventDefault());

  // 복사한 이미지 붙여넣기 → 지금 장면 화면
  document.addEventListener('paste', (e) => {
    const file = [...(e.clipboardData ? e.clipboardData.files : [])].find((f) => fileType(f));
    if (!file) return; // 글자 붙여넣기는 그대로
    const s = currentScene();
    if (!s) return;
    e.preventDefault();
    setSceneFile(s, file);
  });

  document.addEventListener('keydown', (e) => {
    if (e.code !== 'Space' || exporting) return;
    const tag = document.activeElement && document.activeElement.tagName;
    if (['TEXTAREA', 'INPUT', 'SELECT', 'BUTTON'].includes(tag)) return;
    e.preventDefault();
    playing ? stop() : play(t);
  });

  window.addEventListener('resize', () => redraw());
}

async function init() {
  const saved = await DB.get('kv', 'project');
  if (saved) project = normalizeProject(saved);
  await Fonts.init(() => { if (!playing) redraw(); });
  await Sfx.init();
  await Overlays.init();
  await loadProjectMedia();
  fillSettings();
  bindSettings();
  initEvents();
  renderFontLibrary();
  renderSfxLibrary();
  renderScenes();
  renderTimeline();
  redraw();
}

init();
