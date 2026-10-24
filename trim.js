// 영상 자르기 모달: 원본은 그대로 두고 남길 구간(visual.keep)만 기억한다.
// 모달 안 재생은 항상 잘라낸 구간을 건너뛰어서, 자른 결과를 바로 보고 들을 수 있다.

// 화면 녹화 webm처럼 길이 정보가 없는 영상은 끝까지 한 번 찾아가서 길이를 알아낸다
function realDuration(el) {
  return new Promise((resolve) => {
    const finish = () => resolve(isFinite(el.duration) ? el.duration : 0);
    const probe = () => {
      if (isFinite(el.duration) && el.duration > 0) return finish();
      el.addEventListener('durationchange', function onChange() {
        if (!isFinite(el.duration)) return;
        el.removeEventListener('durationchange', onChange);
        el.currentTime = 0;
        finish();
      });
      el.currentTime = 1e101;
    };
    if (el.readyState >= 1) probe();
    else el.addEventListener('loadedmetadata', probe, { once: true });
  });
}

const Trim = (() => {
  let visual, onChange, root, video, dur = 0, markA = null, markB = null, raf = 0, scrubbing = false;

  const fmt = (s) => `${Math.floor(s / 60)}:${(s % 60).toFixed(1).padStart(4, '0')}`;
  const segs = () => keepSegments(visual, dur);
  const keptLength = () => segs().reduce((a, k) => a + k.e - k.s, 0);
  const q = (sel) => root.querySelector(sel);

  function status(msg, ok = true) {
    const el = q('.trim-status');
    el.textContent = msg;
    el.className = 'trim-status ' + (ok ? 'ok' : 'warn');
  }

  // 남긴 구간에서 a~b를 뺀다
  function cut(a, b, label) {
    if (b - a < 0.05) {
      status('자를 부분이 없어요. 아래 막대를 클릭하거나 끌어서 자를 위치로 먼저 옮겨 주세요.', false);
      return;
    }
    const next = [];
    for (const k of segs()) {
      if (k.e <= a || k.s >= b) { next.push(k); continue; }
      if (k.s < a) next.push({ s: k.s, e: a });
      if (k.e > b) next.push({ s: b, e: k.e });
    }
    if (!next.length) { status('영상을 전부 잘라낼 수는 없어요.', false); return; }
    visual.keep = next;
    markA = markB = null;
    onChange();
    status(`${label} ${fmt(b - a)}를 잘라냈어요. 남은 길이 ${fmt(keptLength())}`);
    // 잘라낸 곳에 있으면 다음 남긴 구간으로 옮긴다
    video.currentTime = snap(video.currentTime);
    render();
  }

  // 잘라낸 곳이면 다음 남긴 구간 시작으로
  function snap(t) {
    const list = segs();
    if (list.some((k) => t >= k.s && t < k.e)) return t;
    const next = list.find((k) => k.s >= t);
    return next ? next.s : list.length ? list[0].s : 0;
  }

  // 이 영상이 화면에 나오는 장면 구간
  function ownerInfo() {
    const owner = project.scenes.findIndex((s) => s.visual === visual);
    if (owner < 0) return null;
    const tm = timing();
    const span = visualSpan(owner, tm);
    return { owner, span: span.end - span.start, tm };
  }

  // 장면 구간 길이를 남긴 영상 길이에 맞춘다 (화면을 이어 쓰는 뒤 장면 길이는 그대로)
  function fitScene() {
    const info = ownerInfo();
    if (!info) return;
    const s = project.scenes[info.owner];
    const others = info.span - sceneDuration(s);
    s.autoDur = false;
    s.duration = Math.max(0.5, +(keptLength() - others - (s.extra || 0)).toFixed(1));
    onChange({ structure: true });
    status(`영상이 나오는 장면 구간을 ${fmt(keptLength())}에 맞췄어요. (${info.owner + 1}번 장면 길이 → ${s.duration}초)`);
    render();
  }

  function render() {
    if (!root || !dur) return;
    const bar = q('.trim-bar');
    bar.querySelectorAll('.trim-keep, .trim-mark').forEach((n) => n.remove());
    for (const k of segs()) {
      const d = document.createElement('div');
      d.className = 'trim-keep';
      d.style.left = `${(k.s / dur) * 100}%`;
      d.style.width = `${((k.e - k.s) / dur) * 100}%`;
      bar.appendChild(d);
    }
    for (const [m, label] of [[markA, 'A'], [markB, 'B']]) {
      if (m == null) continue;
      const d = document.createElement('div');
      d.className = 'trim-mark';
      d.style.left = `${(m / dur) * 100}%`;
      d.textContent = label;
      bar.appendChild(d);
    }
    q('.trim-pos').style.left = `${(video.currentTime / dur) * 100}%`;
    q('.trim-info').textContent =
      `${fmt(video.currentTime)} / 원본 ${fmt(dur)} · 남긴 길이 ${fmt(keptLength())}` +
      (markA != null ? ` · A ${fmt(markA)}` : '') + (markB != null ? ` · B ${fmt(markB)}` : '');
    q('.trim-play').textContent = video.paused ? '▶ 재생' : '⏸ 정지';

    // 장면 길이와 남긴 영상 길이가 다르면 알려 준다
    const info = ownerInfo();
    const note = q('.trim-length');
    const kept = keptLength();
    if (info && Math.abs(info.span - kept) > 0.15) {
      note.hidden = false;
      q('.trim-length-text').textContent = info.span < kept
        ? `이 영상이 나오는 장면 구간은 ${fmt(info.span)}라서, 남긴 영상 ${fmt(kept)} 중 앞 ${fmt(info.span)}만 보여요.`
        : `이 영상이 나오는 장면 구간은 ${fmt(info.span)}라서, 남긴 영상 ${fmt(kept)}가 반복돼요.`;
    } else {
      note.hidden = true;
    }
  }

  // 재생 중에는 잘라낸 구간을 건너뛴다
  function tick() {
    if (!root) return;
    if (!video.paused && !scrubbing) {
      const t = video.currentTime;
      const list = segs();
      if (!list.some((k) => t >= k.s && t < k.e - 0.03)) {
        const next = list.find((k) => k.s > t);
        if (next) video.currentTime = next.s;
        else { video.pause(); video.currentTime = list.length ? list[0].s : 0; }
      }
    }
    render();
    raf = requestAnimationFrame(tick);
  }

  function build() {
    const el = document.createElement('div');
    el.className = 'modal-back';
    el.innerHTML = `
      <div class="modal trim">
        <div class="modal-head">
          <h3>영상 자르기</h3>
          <button class="ghost" data-act="close">닫기</button>
        </div>
        <video class="trim-video" playsinline></video>
        <div class="trim-bar" title="클릭하거나 끌어서 위치 옮기기"><div class="trim-pos"></div></div>
        <div class="trim-row">
          <button class="trim-play primary" data-act="play">▶ 재생</button>
          <span class="trim-info mono"></span>
        </div>
        <p class="hint">초록은 남는 부분, 빨강은 잘라낸 부분이에요. 재생하면 잘라낸 부분은 건너뛰어요.</p>
        <div class="trim-actions">
          <button data-act="front">⇤ 여기 앞부분 자르기</button>
          <button data-act="back">여기 뒷부분 자르기 ⇥</button>
        </div>
        <div class="trim-actions">
          <span class="muted">중간 자르기:</span>
          <button data-act="a">① 여기를 시작으로</button>
          <button data-act="b">② 여기를 끝으로</button>
          <button data-act="cut">③ 그 사이 잘라내기</button>
        </div>
        <p class="trim-status"></p>
        <div class="trim-length" hidden>
          <span class="trim-length-text"></span>
          <button class="small" data-act="fit">장면 길이를 영상에 맞추기</button>
        </div>
        <div class="trim-actions">
          <button data-act="reset" class="ghost">처음 상태로</button>
          <span class="sep"></span>
          <button data-act="close" class="primary">완료</button>
        </div>
      </div>`;
    return el;
  }

  function close() {
    cancelAnimationFrame(raf);
    if (video) video.pause();
    if (root) root.remove();
    root = null;
  }

  async function open(v, changed) {
    visual = v;
    onChange = changed;
    markA = markB = null;
    dur = 0;
    root = build();
    document.body.appendChild(root);
    video = q('video');
    video.src = media[v.fileId].url;
    status('막대를 클릭하거나 끌어서 위치를 옮긴 뒤 자르기 버튼을 눌러요.');
    dur = await realDuration(video);
    if (!root) return;
    if (!dur) { status('이 영상의 길이를 읽지 못했어요. mp4로 바꿔서 넣어 주세요.', false); return; }
    // 영상 길이를 읽지 못했던 파일이면 미리보기 쪽 영상도 길이를 알게 한다
    if (!isFinite(media[v.fileId].el.duration)) await realDuration(media[v.fileId].el);
    video.currentTime = snap(0);
    raf = requestAnimationFrame(tick);

    const bar = q('.trim-bar');
    const seekBar = (e) => {
      const r = bar.getBoundingClientRect();
      video.currentTime = clamp((e.clientX - r.left) / r.width, 0, 1) * dur;
    };
    bar.addEventListener('pointerdown', (e) => { scrubbing = true; bar.setPointerCapture(e.pointerId); seekBar(e); });
    bar.addEventListener('pointermove', (e) => { if (scrubbing) seekBar(e); });
    bar.addEventListener('pointerup', () => { scrubbing = false; });

    root.addEventListener('click', (e) => {
      if (e.target === root) return close();
      const btn = e.target.closest('[data-act]');
      if (!btn) return;
      const t = video.currentTime;
      switch (btn.dataset.act) {
        case 'close': close(); break;
        case 'play':
          if (video.paused) { video.currentTime = snap(video.currentTime); video.play(); } else video.pause();
          break;
        case 'front': cut(0, t, '앞부분'); break;
        case 'back': cut(t, dur, '뒷부분'); break;
        case 'a': markA = t; status(`시작 ${fmt(t)} 표시. 이제 끝 위치로 옮기고 ②를 눌러요.`); render(); break;
        case 'b': markB = t; status(`끝 ${fmt(t)} 표시. ③을 누르면 그 사이를 잘라내요.`); render(); break;
        case 'cut':
          if (markA == null || markB == null) { status('①과 ②로 자를 구간의 시작과 끝을 먼저 표시해 주세요.', false); break; }
          cut(Math.min(markA, markB), Math.max(markA, markB), '중간');
          break;
        case 'fit': fitScene(); break;
        case 'reset':
          visual.keep = null;
          markA = markB = null;
          onChange();
          status('처음 상태로 되돌렸어요.');
          render();
          break;
      }
    });
  }

  return { open };
})();
