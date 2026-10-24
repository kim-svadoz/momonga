// 타이틀·이미지 얹기: 미리보기에서 끌어서 옮기고 모서리로 크기 조절, 왼쪽 패널에서 꾸미기

const Overlays = (() => {
  let selId = null;
  let styles = []; // [{ name, style }] 새 프로젝트에도 남는다
  let drag = null;

  const clone = (v) => JSON.parse(JSON.stringify(v));

  function currentScene() {
    const i = sceneIndexAt(t);
    return i >= 0 ? project.scenes[i] : null;
  }

  function selected() {
    const s = currentScene();
    return (s && s.overlays.find((o) => o.id === selId)) || null;
  }

  function select(id) {
    selId = id;
    renderPanel();
    redraw();
  }

  // ---------- 추가·삭제 ----------

  function addText() {
    const s = currentScene();
    if (!s) { alert('장면을 먼저 만들어 주세요.'); return; }
    const o = { id: uid(), ...clone(DEFAULT_TEXT_OVERLAY()) };
    s.overlays.push(o);
    selId = o.id;
    changed();
    renderPanel();
  }

  async function addImage(file) {
    const s = currentScene();
    if (!s) { alert('장면을 먼저 만들어 주세요.'); return; }
    if (!file.type.startsWith('image/')) { alert('이미지 파일만 얹을 수 있어요.'); return; }
    const fileId = 'f_' + uid();
    await DB.put('files', fileId, file);
    loadMedia(fileId, file, 'image');
    const o = { id: uid(), type: 'image', fileId, x: 0.5, y: 0.35, w: 0.5, rotation: 0, opacity: 1 };
    s.overlays.push(o);
    selId = o.id;
    changed();
    renderPanel();
  }

  function remove(id) {
    const s = currentScene();
    if (!s) return;
    s.overlays = s.overlays.filter((o) => o.id !== id);
    if (selId === id) selId = null;
    changed();
    renderPanel();
    cleanupFiles();
  }

  // ---------- 부분 색칠 ----------

  // 글자를 고치면 색칠 범위를 같이 옮긴다
  function adjustRanges(oldT, newT, ranges) {
    let p = 0;
    while (p < oldT.length && p < newT.length && oldT[p] === newT[p]) p++;
    let s = 0;
    while (s < oldT.length - p && s < newT.length - p && oldT[oldT.length - 1 - s] === newT[newT.length - 1 - s]) s++;
    const oldEnd = oldT.length - s, newEnd = newT.length - s, delta = newT.length - oldT.length;
    const map = (x, isEnd) => (x <= p ? x : x >= oldEnd ? x + delta : isEnd ? newEnd : p);
    return ranges
      .map((r) => ({ ...r, s: map(r.s, false), e: map(r.e, true) }))
      .filter((r) => r.e > r.s);
  }

  // ---------- 스타일 ----------

  async function saveStyle(o, name) {
    const style = {};
    for (const k of STYLE_KEYS) style[k] = clone(o[k]);
    const i = styles.findIndex((x) => x.name === name);
    if (i >= 0) styles[i].style = style;
    else styles.push({ name, style });
    await DB.put('kv', 'overlayStyles', styles);
  }

  async function deleteStyle(name) {
    styles = styles.filter((x) => x.name !== name);
    await DB.put('kv', 'overlayStyles', styles);
  }

  // ---------- 패널 ----------

  function field(label, html) {
    return `<label class="row">${label} ${html}</label>`;
  }
  const range = (path, min, max, step = 1) => `<input type="range" data-path="${path}" min="${min}" max="${max}" step="${step}">`;
  const color = (path) => `<input type="color" data-path="${path}">`;
  const check = (path) => `<input type="checkbox" data-path="${path}">`;

  function textForm() {
    return `
      <label>글자 <span class="muted">(Enter로 줄바꿈)</span></label>
      <textarea rows="3" class="ov-text"></textarea>
      <div class="row paint">
        <input type="color" class="paint-color" value="#ffd400" title="칠할 색">
        <button class="small paint-btn">드래그한 글자 색칠</button>
        <button class="small ghost paint-clear">색칠 지우기</button>
      </div>
      ${field('글꼴', `<select data-path="font">${Fonts.optionsHtml(selected().font)}</select>`)}
      ${field('굵기', `<select data-path="weight" data-num><option value="400">보통</option><option value="700">굵게</option><option value="900">아주 굵게</option></select>`)}
      ${field('크기', range('size', 16, 400))}
      ${field('정렬', `<select data-path="align"><option value="left">왼쪽</option><option value="center">가운데</option><option value="right">오른쪽</option></select>`)}
      ${field('글자색', color('color'))}
      ${field('외곽선 두께', range('strokeWidth', 0, 40))}
      ${field('외곽선 색', color('strokeColor'))}
      ${field('자간', range('spacing', -10, 60))}
      ${field('줄 간격', range('lineHeight', 0.8, 2.5, 0.05))}
      ${field('회전', range('rotation', -180, 180))}
      <h3>배경 상자</h3>
      ${field('켜기', check('box.on'))}
      ${field('색', color('box.color'))}
      ${field('투명도', range('box.opacity', 0, 1, 0.05))}
      ${field('여백', range('box.padding', 0, 120))}
      ${field('모서리 둥글기', range('box.radius', 0, 120))}
      <h3>그림자</h3>
      ${field('켜기', check('shadow.on'))}
      ${field('색', color('shadow.color'))}
      ${field('퍼짐', range('shadow.blur', 0, 100))}
      <h3>스타일</h3>
      <div class="row">
        <select class="style-pick"><option value="">저장한 스타일…</option>${styles.map((x) => `<option>${escapeHtml(x.name)}</option>`).join('')}</select>
        <button class="small style-apply">불러오기</button>
        <button class="small ghost style-del">지우기</button>
      </div>
      <div class="row">
        <input type="text" class="style-name" placeholder="스타일 이름">
        <button class="small style-save">지금 스타일 저장</button>
      </div>`;
  }

  function imageForm() {
    return `
      ${field('크기', range('w', 0.05, 1.5, 0.01))}
      ${field('회전', range('rotation', -180, 180))}
      ${field('투명도', range('opacity', 0, 1, 0.05))}`;
  }

  function getPath(o, path) {
    return path.split('.').reduce((a, k) => a[k], o);
  }
  function setPath(o, path, v) {
    const keys = path.split('.');
    const last = keys.pop();
    keys.reduce((a, k) => a[k], o)[last] = v;
  }

  function renderPanel() {
    const el = $('overlayPanel');
    const s = currentScene();
    if (!s) { el.innerHTML = '<p class="hint">장면을 먼저 만들어 주세요.</p>'; return; }
    const o = selected();
    if (!o) selId = null;
    const idx = project.scenes.indexOf(s) + 1;

    el.innerHTML = `
      <p class="hint">${idx}번 장면에 얹어요. 미리보기에서 끌어서 옮기고, 오른쪽 아래 모서리를 끌어서 크기를 바꿔요.</p>
      <div class="row">
        <button class="ov-add-text">+ 글자</button>
        <button class="ov-add-image">+ 이미지</button>
        <input type="file" class="ov-image-file" accept="image/*" hidden>
      </div>
      <div class="ov-list">
        ${s.overlays.map((x, k) => `<button class="small chip ${x.id === selId ? 'on' : ''}" data-id="${x.id}">
          ${x.type === 'text' ? '가 ' + escapeHtml(x.text.split('\n')[0].slice(0, 10) || '(빈 글자)') : '🖼 이미지 ' + (k + 1)}</button>`).join('')}
      </div>
      ${o ? `<div class="ov-form">
        ${o.type === 'text' ? textForm() : imageForm()}
        <button class="small del ov-del">이 ${o.type === 'text' ? '글자' : '이미지'} 지우기</button>
      </div>` : ''}`;

    const q = (sel) => el.querySelector(sel);
    q('.ov-add-text').onclick = addText;
    q('.ov-add-image').onclick = () => q('.ov-image-file').click();
    q('.ov-image-file').onchange = (e) => { if (e.target.files[0]) addImage(e.target.files[0]); };
    el.querySelectorAll('.chip').forEach((b) => { b.onclick = () => select(b.dataset.id); });
    if (!o) return;

    q('.ov-del').onclick = () => remove(o.id);
    el.querySelectorAll('[data-path]').forEach((inp) => {
      const path = inp.dataset.path;
      const v = getPath(o, path);
      if (inp.type === 'checkbox') inp.checked = !!v;
      else inp.value = v;
      inp.addEventListener('input', () => {
        let nv = inp.type === 'checkbox' ? inp.checked : inp.value;
        if (inp.type === 'range' || inp.dataset.num != null) nv = parseFloat(nv);
        setPath(o, path, nv);
        changed();
      });
    });

    if (o.type !== 'text') return;
    const ta = q('.ov-text');
    ta.value = o.text;
    ta.addEventListener('input', () => {
      o.ranges = adjustRanges(o.text, ta.value, o.ranges);
      o.text = ta.value;
      changed();
      const chip = el.querySelector(`.chip[data-id="${o.id}"]`);
      if (chip) chip.textContent = '가 ' + (o.text.split('\n')[0].slice(0, 10) || '(빈 글자)');
    });
    q('.paint-btn').onclick = () => {
      const a = ta.selectionStart, b = ta.selectionEnd;
      if (a === b) { alert('글자 칸에서 칠할 부분을 먼저 드래그해 주세요.'); return; }
      o.ranges.push({ s: a, e: b, color: q('.paint-color').value });
      changed();
    };
    q('.paint-clear').onclick = () => { o.ranges = []; changed(); };
    q('.style-save').onclick = async () => {
      const name = q('.style-name').value.trim();
      if (!name) { alert('스타일 이름을 넣어 주세요.'); return; }
      await saveStyle(o, name);
      renderPanel();
    };
    q('.style-apply').onclick = () => {
      const st = styles.find((x) => x.name === q('.style-pick').value);
      if (!st) return;
      Object.assign(o, clone(st.style));
      changed();
      renderPanel();
    };
    q('.style-del').onclick = async () => {
      const name = q('.style-pick').value;
      if (!name || !confirm(`'${name}' 스타일을 지울까요?`)) return;
      await deleteStyle(name);
      renderPanel();
    };
  }

  // ---------- 미리보기에서 끌기 ----------

  function toCanvas(e) {
    const r = canvas.getBoundingClientRect();
    return [((e.clientX - r.left) / r.width) * canvas.width, ((e.clientY - r.top) / r.height) * canvas.height];
  }

  function toLocal(b, x, y) {
    const a = (-b.rot * Math.PI) / 180;
    const dx = x - b.cx, dy = y - b.cy;
    return [dx * Math.cos(a) - dy * Math.sin(a), dx * Math.sin(a) + dy * Math.cos(a)];
  }

  const handleSize = () => 12 * (canvas.width / canvas.getBoundingClientRect().width);

  function hit(x, y) {
    const s = currentScene();
    if (!s) return null;
    const sel = selected();
    if (sel) {
      const b = overlayBox(ctx, sel, canvas.width, canvas.height);
      const [lx, ly] = toLocal(b, x, y);
      const H = handleSize() * 1.6;
      if (Math.abs(lx - b.w / 2) < H && Math.abs(ly - b.h / 2) < H) return { o: sel, mode: 'resize', b };
    }
    for (let i = s.overlays.length - 1; i >= 0; i--) {
      const o = s.overlays[i];
      const b = overlayBox(ctx, o, canvas.width, canvas.height);
      const [lx, ly] = toLocal(b, x, y);
      if (Math.abs(lx) <= b.w / 2 && Math.abs(ly) <= b.h / 2) return { o, mode: 'move', b };
    }
    return null;
  }

  function bindCanvas() {
    canvas.addEventListener('pointerdown', (e) => {
      const [x, y] = toCanvas(e);
      const h = hit(x, y);
      if (!h) { if (selId) select(null); return; }
      if (h.o.id !== selId) select(h.o.id);
      const [lx, ly] = toLocal(h.b, x, y);
      drag = { ...h, x, y, ox: h.o.x, oy: h.o.y, dist: Math.hypot(lx, ly) || 1, size: h.o.size, w: h.o.w };
      canvas.setPointerCapture(e.pointerId);
      e.preventDefault();
    });
    canvas.addEventListener('pointermove', (e) => {
      const [x, y] = toCanvas(e);
      if (!drag) {
        const h = hit(x, y);
        canvas.style.cursor = !h ? '' : h.mode === 'resize' ? 'nwse-resize' : 'move';
        return;
      }
      const o = drag.o;
      if (drag.mode === 'move') {
        o.x = drag.ox + (x - drag.x) / canvas.width;
        o.y = drag.oy + (y - drag.y) / canvas.height;
      } else {
        const [lx, ly] = toLocal(drag.b, x, y);
        const f = Math.max(0.05, Math.hypot(lx, ly) / drag.dist);
        if (o.type === 'text') o.size = clamp(Math.round(drag.size * f), 8, 800);
        else o.w = clamp(drag.w * f, 0.02, 3);
      }
      redraw();
    });
    const end = () => {
      if (!drag) return;
      drag = null;
      changed();
      renderPanel();
    };
    canvas.addEventListener('pointerup', end);
    canvas.addEventListener('pointercancel', end);
  }

  // 미리보기에만 그리는 선택 테두리 (MP4에는 안 들어감)
  function drawSelection(c) {
    const o = selected();
    if (!o) return;
    const b = overlayBox(c, o, canvas.width, canvas.height);
    const px = canvas.width / canvas.getBoundingClientRect().width;
    c.save();
    c.translate(b.cx, b.cy);
    c.rotate((b.rot * Math.PI) / 180);
    c.strokeStyle = '#4da3ff';
    c.lineWidth = 2 * px;
    c.setLineDash([8 * px, 6 * px]);
    c.strokeRect(-b.w / 2, -b.h / 2, b.w, b.h);
    c.setLineDash([]);
    const H = handleSize();
    c.fillStyle = '#4da3ff';
    c.fillRect(b.w / 2 - H / 2, b.h / 2 - H / 2, H, H);
    c.restore();
  }

  async function init() {
    styles = (await DB.get('kv', 'overlayStyles')) || [];
    bindCanvas();
  }

  return { init, renderPanel, drawSelection, select, get selId() { return selId; } };
})();

function escapeHtml(s) {
  return String(s).replace(/[&<>"']/g, (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]));
}
