// 영상 자르기 모달: 원본은 그대로 두고 남길 구간(visual.keep)만 기억한다.

const Trim = (() => {
  let visual, onChange, video, dur = 0, markA = null, markB = null, previewing = false;

  const fmt = (s) => `${Math.floor(s / 60)}:${(s % 60).toFixed(1).padStart(4, '0')}`;

  function segs() {
    return keepSegments(visual, dur);
  }

  // 남긴 구간에서 a~b를 뺀다
  function cut(a, b) {
    if (b - a < 0.05) return;
    const next = [];
    for (const k of segs()) {
      if (k.e <= a || k.s >= b) { next.push(k); continue; }
      if (k.s < a) next.push({ s: k.s, e: a });
      if (k.e > b) next.push({ s: b, e: k.e });
    }
    if (!next.length) { alert('영상을 전부 잘라낼 수는 없어요.'); return; }
    visual.keep = next;
    markA = markB = null;
    onChange();
    render();
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
        <video class="trim-video" controls playsinline></video>
        <div class="trim-bar"><div class="trim-pos"></div></div>
        <div class="trim-info mono"></div>
        <div class="trim-actions">
          <button data-act="front">여기 앞부분 자르기</button>
          <button data-act="back">여기 뒷부분 자르기</button>
          <span class="sep"></span>
          <button data-act="a">구간 시작 표시</button>
          <button data-act="b">구간 끝 표시</button>
          <button data-act="cut" class="primary">표시한 구간 잘라내기</button>
        </div>
        <div class="trim-actions">
          <button data-act="preview">▶ 남긴 구간만 재생</button>
          <span class="sep"></span>
          <button data-act="reset" class="ghost">처음 상태로</button>
          <button data-act="close" class="primary">완료</button>
        </div>
        <p class="hint">원본 파일은 그대로 두고, 남길 구간만 기억해요. 미리보기와 MP4 내보내기에 반영돼요.</p>
      </div>`;
    return el;
  }

  let root;

  function render() {
    if (!root || !dur) return;
    const bar = root.querySelector('.trim-bar');
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
    const kept = segs().reduce((a, k) => a + k.e - k.s, 0);
    root.querySelector('.trim-info').textContent =
      `현재 ${fmt(video.currentTime)} · 원본 ${fmt(dur)} → 남긴 길이 ${fmt(kept)}` +
      (markA != null ? ` · A ${fmt(markA)}` : '') + (markB != null ? ` · B ${fmt(markB)}` : '');
    root.querySelector('.trim-pos').style.left = `${(video.currentTime / dur) * 100}%`;
  }

  // 남긴 구간만 이어서 재생: 잘린 곳에 들어가면 다음 남긴 구간으로 건너뛴다
  function previewTick() {
    if (!previewing || !root) return;
    const t = video.currentTime;
    const list = segs();
    const inside = list.find((k) => t >= k.s && t < k.e - 0.02);
    if (!inside) {
      const next = list.find((k) => k.s > t);
      if (next) video.currentTime = next.s;
      else { video.pause(); previewing = false; }
    }
    requestAnimationFrame(previewTick);
  }

  function close() {
    previewing = false;
    if (video) video.pause();
    if (root) root.remove();
    root = null;
  }

  function open(v, changed) {
    visual = v;
    onChange = changed;
    markA = markB = null;
    root = build();
    document.body.appendChild(root);
    video = root.querySelector('video');
    video.src = media[v.fileId].url;
    video.addEventListener('loadedmetadata', () => { dur = video.duration; render(); });
    video.addEventListener('timeupdate', render);
    video.addEventListener('seeked', render);
    video.addEventListener('pause', () => { previewing = false; });

    root.querySelector('.trim-bar').addEventListener('click', (e) => {
      const r = e.currentTarget.getBoundingClientRect();
      video.currentTime = ((e.clientX - r.left) / r.width) * dur;
    });
    root.addEventListener('click', (e) => {
      if (e.target === root) return close();
      const act = e.target.dataset && e.target.dataset.act;
      if (!act) return;
      const t = video.currentTime;
      switch (act) {
        case 'close': close(); break;
        case 'front': cut(0, t); break;
        case 'back': cut(t, dur); break;
        case 'a': markA = t; render(); break;
        case 'b': markB = t; render(); break;
        case 'cut':
          if (markA == null || markB == null) { alert('구간 시작과 끝을 먼저 표시해 주세요.'); break; }
          cut(Math.min(markA, markB), Math.max(markA, markB));
          break;
        case 'reset': visual.keep = null; markA = markB = null; onChange(); render(); break;
        case 'preview': {
          const first = segs()[0];
          if (first) video.currentTime = first.s;
          previewing = true;
          video.play();
          requestAnimationFrame(previewTick);
          break;
        }
      }
    });
  }

  return { open };
})();
