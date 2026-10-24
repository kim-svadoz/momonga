// 한 프레임 그리기. 미리보기와 MP4 내보내기가 이 함수 하나를 같이 쓴다.

const media = {}; // fileId → { type, url, el, thumb }

const FONT_FALLBACK = '"Apple SD Gothic Neo", "Malgun Gothic", sans-serif';
const fontStr = (weight, size, family) => `${weight} ${size}px "${family}", ${FONT_FALLBACK}`;

const MOTIONS = {
  none: '없음',
  zoomIn: '천천히 확대',
  zoomOut: '천천히 축소',
  panLeft: '왼쪽으로 이동',
  panRight: '오른쪽으로 이동',
  panUp: '위로 이동',
  panDown: '아래로 이동',
};

function hexToRgba(hex, a) {
  const n = parseInt(hex.slice(1), 16);
  return `rgba(${(n >> 16) & 255},${(n >> 8) & 255},${n & 255},${a})`;
}

function roundRect(ctx, x, y, w, h, r) {
  ctx.beginPath();
  ctx.roundRect(x, y, w, h, Math.max(0, Math.min(r, w / 2, h / 2)));
}

// ---------- 화면 ----------

function mediaSize(m) {
  if (!m) return null;
  if (m.type === 'image') return m.el.complete && m.el.naturalWidth ? [m.el.naturalWidth, m.el.naturalHeight] : null;
  return m.el.readyState >= 2 ? [m.el.videoWidth, m.el.videoHeight] : null;
}

function drawVisual(ctx, visual, progress, cw, ch) {
  if (visual.type === 'color') {
    ctx.fillStyle = visual.color;
    ctx.fillRect(0, 0, cw, ch);
    return;
  }
  const m = media[visual.fileId];
  const size = mediaSize(m);
  if (!size) return;
  const [iw, ih] = size;
  const scale = visual.fit === 'contain' ? Math.min(cw / iw, ch / ih) : Math.max(cw / iw, ch / ih);
  const w = iw * scale, h = ih * scale;

  // 움직임: 확대/축소/이동. 이동할 때는 가장자리가 비지 않게 살짝 키운다.
  const p = progress;
  const Z = 0.15;
  let z = 1, dx = 0, dy = 0;
  switch (visual.motion) {
    case 'zoomIn': z = 1 + Z * p; break;
    case 'zoomOut': z = 1 + Z * (1 - p); break;
    case 'panLeft': z = 1 + Z; dx = (0.5 - p) * Z * w; break;
    case 'panRight': z = 1 + Z; dx = (p - 0.5) * Z * w; break;
    case 'panUp': z = 1 + Z; dy = (0.5 - p) * Z * h; break;
    case 'panDown': z = 1 + Z; dy = (p - 0.5) * Z * h; break;
  }
  ctx.save();
  ctx.translate(cw / 2 + dx, ch / 2 + dy);
  ctx.scale(z, z);
  ctx.drawImage(m.el, -w / 2, -h / 2, w, h);
  ctx.restore();
}

// ---------- 자막 ----------

function wrapText(ctx, text, maxW) {
  const lines = [];
  for (const para of text.split('\n')) {
    let line = '';
    for (const word of para.split(/\s+/).filter(Boolean)) {
      const test = line ? line + ' ' + word : word;
      if (ctx.measureText(test).width <= maxW) { line = test; continue; }
      if (line) lines.push(line);
      // 한 단어가 너무 길면 글자 단위로 끊는다
      let chunk = '';
      for (const c of word) {
        if (chunk && ctx.measureText(chunk + c).width > maxW) { lines.push(chunk); chunk = ''; }
        chunk += c;
      }
      line = chunk;
    }
    lines.push(line);
  }
  return lines.filter((l, i) => l || i < lines.length - 1);
}

function drawSubtitle(ctx, text, cw, ch) {
  const sub = project.subtitle;
  const k = cw / 1080;
  const size = sub.size * k;
  Fonts.use(sub.font, sub.weight);
  ctx.save();
  ctx.font = fontStr(sub.weight, size, sub.font);
  ctx.letterSpacing = `${sub.spacing * k}px`;
  ctx.textAlign = 'center';
  ctx.textBaseline = 'middle';
  const lines = wrapText(ctx, text, cw * 0.86);
  const lh = size * sub.lineHeight;
  const y0 = ch * (sub.y / 100) - ((lines.length - 1) * lh) / 2;

  if (sub.box) {
    const pad = size * 0.35;
    const w = Math.max(...lines.map((l) => ctx.measureText(l).width));
    const h = lines.length * lh;
    ctx.fillStyle = hexToRgba(sub.boxColor, sub.boxOpacity);
    roundRect(ctx, cw / 2 - w / 2 - pad, y0 - lh / 2 - pad * 0.6, w + pad * 2, h + pad * 1.2, size * 0.25);
    ctx.fill();
  }
  // 글자 뒤로 퍼지는 그림자
  if (sub.glow > 0) {
    ctx.shadowColor = sub.glowColor;
    ctx.shadowBlur = sub.glow * k;
    ctx.fillStyle = sub.glowColor;
    for (let n = 0; n < 2; n++) lines.forEach((l, i) => ctx.fillText(l, cw / 2, y0 + i * lh));
    ctx.shadowBlur = 0;
  }
  if (sub.stroke) {
    ctx.lineJoin = 'round';
    ctx.lineWidth = size * 0.12;
    ctx.strokeStyle = sub.strokeColor;
    lines.forEach((l, i) => ctx.strokeText(l, cw / 2, y0 + i * lh));
  }
  ctx.fillStyle = sub.color;
  lines.forEach((l, i) => ctx.fillText(l, cw / 2, y0 + i * lh));
  ctx.restore();
}

// ---------- 얹은 글자·이미지 ----------

const DEFAULT_TEXT_OVERLAY = () => ({
  type: 'text',
  text: '타이틀',
  x: 0.5, y: 0.2,
  font: 'Black Han Sans', weight: 400, size: 110,
  align: 'center', color: '#ffffff',
  strokeWidth: 0, strokeColor: '#000000',
  spacing: 0, lineHeight: 1.2, rotation: 0,
  box: { on: false, color: '#ff4d6d', opacity: 1, padding: 24, radius: 16 },
  shadow: { on: true, color: '#000000', blur: 20 },
  ranges: [],
});

// 스타일로 저장할 값 (글자 내용·위치·부분 색칠은 빼고)
const STYLE_KEYS = ['font', 'weight', 'size', 'align', 'color', 'strokeWidth', 'strokeColor', 'spacing', 'lineHeight', 'rotation', 'box', 'shadow'];

function textLayout(ctx, o, k) {
  Fonts.use(o.font, o.weight);
  ctx.font = fontStr(o.weight, o.size * k, o.font);
  ctx.letterSpacing = `${o.spacing * k}px`;
  const lines = o.text.split('\n');
  const widths = lines.map((l) => ctx.measureText(l).width);
  const w = Math.max(1, ...widths);
  const lh = o.size * k * o.lineHeight;
  const pad = o.box.on ? o.box.padding * k : 0;
  return { lines, widths, w, h: lines.length * lh, lh, pad };
}

// 얹은 것의 중심·크기·회전 (캔버스 좌표). 끌기와 크기 조절에 쓴다.
function overlayBox(ctx, o, cw, ch) {
  const k = cw / 1080;
  if (o.type === 'text') {
    ctx.save();
    const L = textLayout(ctx, o, k);
    ctx.restore();
    return { cx: o.x * cw, cy: o.y * ch, w: L.w + L.pad * 2, h: L.h + L.pad * 2, rot: o.rotation };
  }
  const size = mediaSize(media[o.fileId]) || [1, 1];
  const w = o.w * cw;
  return { cx: o.x * cw, cy: o.y * ch, w, h: (w * size[1]) / size[0], rot: o.rotation };
}

function colorAt(ranges, idx, base) {
  for (let i = ranges.length - 1; i >= 0; i--) {
    if (idx >= ranges[i].s && idx < ranges[i].e) return ranges[i].color;
  }
  return base;
}

function drawTextOverlay(ctx, o, cw, ch) {
  const k = cw / 1080;
  ctx.save();
  const L = textLayout(ctx, o, k);
  ctx.translate(o.x * cw, o.y * ch);
  ctx.rotate((o.rotation * Math.PI) / 180);

  if (o.box.on) {
    ctx.save();
    if (o.shadow.on) { ctx.shadowColor = o.shadow.color; ctx.shadowBlur = o.shadow.blur * k; }
    ctx.fillStyle = hexToRgba(o.box.color, o.box.opacity);
    roundRect(ctx, -L.w / 2 - L.pad, -L.h / 2 - L.pad, L.w + L.pad * 2, L.h + L.pad * 2, o.box.radius * k);
    ctx.fill();
    ctx.restore();
  }

  ctx.textAlign = 'left';
  ctx.textBaseline = 'middle';
  ctx.lineJoin = 'round';

  // 줄마다 같은 색끼리 묶어서 그린다 (부분 색칠)
  const runs = [];
  let idx = 0;
  L.lines.forEach((line, li) => {
    const lw = L.widths[li];
    let x = o.align === 'left' ? -L.w / 2 : o.align === 'right' ? L.w / 2 - lw : -lw / 2;
    const y = -L.h / 2 + L.lh * (li + 0.5);
    let seg = '', segColor = null;
    const flush = () => {
      if (!seg) return;
      runs.push({ text: seg, x, y, color: segColor });
      x += ctx.measureText(seg).width;
      seg = '';
    };
    for (const c of line) {
      const col = colorAt(o.ranges, idx, o.color);
      if (col !== segColor) { flush(); segColor = col; }
      seg += c;
      idx++;
    }
    flush();
    idx++; // 줄바꿈 글자
  });

  if (o.shadow.on && !o.box.on) {
    ctx.shadowColor = o.shadow.color;
    ctx.shadowBlur = o.shadow.blur * k;
  }
  if (o.strokeWidth > 0) {
    ctx.lineWidth = o.strokeWidth * k;
    ctx.strokeStyle = o.strokeColor;
    runs.forEach((r) => ctx.strokeText(r.text, r.x, r.y));
    ctx.shadowBlur = 0;
  }
  runs.forEach((r) => { ctx.fillStyle = r.color; ctx.fillText(r.text, r.x, r.y); });
  ctx.restore();
}

function drawImageOverlay(ctx, o, cw, ch) {
  const m = media[o.fileId];
  if (!mediaSize(m)) return;
  const b = overlayBox(ctx, o, cw, ch);
  ctx.save();
  ctx.globalAlpha = o.opacity == null ? 1 : o.opacity;
  ctx.translate(b.cx, b.cy);
  ctx.rotate((b.rot * Math.PI) / 180);
  ctx.drawImage(m.el, -b.w / 2, -b.h / 2, b.w, b.h);
  ctx.restore();
}

// ---------- 한 프레임 ----------

// opts.hint: 장면이 없을 때 안내 글자를 그릴지
function renderFrame(ctx, time, opts = {}) {
  const [cw, ch] = ASPECTS[project.aspect];
  ctx.setTransform(1, 0, 0, 1, 0, 0);
  ctx.fillStyle = '#000';
  ctx.fillRect(0, 0, cw, ch);

  const tm = timing();
  if (!tm.length) {
    if (opts.hint) {
      ctx.fillStyle = '#666';
      ctx.font = `600 ${Math.round(cw * 0.04)}px sans-serif`;
      ctx.textAlign = 'center';
      ctx.textBaseline = 'middle';
      ctx.fillText("대본을 넣고 '문장으로 나누기'를 누르세요", cw / 2, ch / 2);
    }
    return;
  }

  const i = sceneIndexAt(time, tm);
  const scene = tm[i].scene;
  const { visual, owner } = resolveVisual(i);
  if (visual) {
    const span = visualSpan(owner, tm);
    const p = clamp((time - span.start) / Math.max(0.001, span.end - span.start), 0, 1);
    drawVisual(ctx, visual, p, cw, ch);
    if (visual.dim > 0) {
      ctx.fillStyle = `rgba(0,0,0,${visual.dim})`;
      ctx.fillRect(0, 0, cw, ch);
    }
  }

  if (!scene.hideSub && scene.text) {
    drawSubtitle(ctx, subtitleAt(scene, time - tm[i].start), cw, ch);
  }

  for (const o of scene.overlays) {
    if (o.type === 'text') drawTextOverlay(ctx, o, cw, ch);
    else drawImageOverlay(ctx, o, cw, ch);
  }
}

// 지금 보이는 영상이 무엇이고, 원본의 몇 초를 보여야 하는지
function activeVideoAt(time) {
  const tm = timing();
  if (!tm.length) return null;
  const { visual, owner } = resolveVisual(sceneIndexAt(time, tm));
  if (!visual || visual.type !== 'video') return null;
  const m = media[visual.fileId];
  if (!m) return null;
  const span = visualSpan(owner, tm);
  return { visual, m, target: videoTimeAt(visual, m.el.duration, time - span.start) };
}
