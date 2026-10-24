// 효과음: 파일 없이 합성하는 기본음 9종 + 내가 넣은 파일(효과음 보관함)

const SYNTH_SFX = {
  click: '클릭',
  pop: '뿅',
  ding: '딩~ (맑은 종)',
  coin: '띠링 (코인)',
  whoosh: '휙 (전환)',
  keyboard: '키보드 타건',
  tap: '탭핑',
  drop: '물방울',
  fire: '모닥불',
};

const SR = 48000;

const Sfx = (() => {
  let library = []; // [{ id, name }]
  const cache = new Map(); // src → AudioBuffer
  let ac;

  function audioCtx() {
    if (!ac) ac = new AudioContext({ sampleRate: SR });
    return ac;
  }

  // ---------- 합성 ----------

  function noiseBuffer(c, seconds) {
    const b = c.createBuffer(1, Math.ceil(SR * seconds), SR);
    const d = b.getChannelData(0);
    for (let i = 0; i < d.length; i++) d[i] = Math.random() * 2 - 1;
    return b;
  }

  function env(c, g, t0, attack, peak, decay) {
    g.gain.setValueAtTime(0.0001, t0);
    g.gain.exponentialRampToValueAtTime(peak, t0 + attack);
    g.gain.exponentialRampToValueAtTime(0.0001, t0 + attack + decay);
  }

  function tone(c, out, { type = 'sine', f0, f1, t0 = 0, dur, attack = 0.003, peak = 0.5 }) {
    const o = c.createOscillator();
    const g = c.createGain();
    o.type = type;
    o.frequency.setValueAtTime(f0, t0);
    if (f1) o.frequency.exponentialRampToValueAtTime(f1, t0 + dur * 0.6);
    env(c, g, t0, attack, peak, dur);
    o.connect(g).connect(out);
    o.start(t0);
    o.stop(t0 + attack + dur + 0.05);
  }

  function noise(c, out, { t0 = 0, dur, filter = 'bandpass', freq = 2000, q = 1, attack = 0.002, peak = 0.5 }) {
    const s = c.createBufferSource();
    s.buffer = noiseBuffer(c, dur + attack + 0.05);
    const f = c.createBiquadFilter();
    f.type = filter;
    f.frequency.value = freq;
    f.Q.value = q;
    const g = c.createGain();
    env(c, g, t0, attack, peak, dur);
    s.connect(f).connect(g).connect(out);
    s.start(t0);
    return f;
  }

  const recipes = {
    click: { len: 0.12, build(c, out) {
      noise(c, out, { dur: 0.018, filter: 'highpass', freq: 3500, peak: 0.7 });
      tone(c, out, { f0: 2400, dur: 0.025, peak: 0.25 });
    } },
    pop: { len: 0.3, build(c, out) {
      tone(c, out, { f0: 260, f1: 1300, dur: 0.16, attack: 0.005, peak: 0.6 });
    } },
    ding: { len: 2.2, build(c, out) {
      [[1568, 0.45], [3136, 0.15], [4704, 0.06], [2352, 0.08]].forEach(([f, p]) =>
        tone(c, out, { f0: f, dur: 2.0, attack: 0.002, peak: p }));
    } },
    coin: { len: 0.7, build(c, out) {
      tone(c, out, { type: 'square', f0: 988, dur: 0.07, peak: 0.3 });
      tone(c, out, { type: 'square', f0: 1319, t0: 0.075, dur: 0.5, peak: 0.3 });
    } },
    whoosh: { len: 0.7, build(c, out) {
      const f = noise(c, out, { dur: 0.55, freq: 400, q: 1.5, attack: 0.25, peak: 0.6 });
      f.frequency.setValueAtTime(400, 0);
      f.frequency.exponentialRampToValueAtTime(3500, 0.3);
      f.frequency.exponentialRampToValueAtTime(600, 0.6);
    } },
    keyboard: { len: 1.4, build(c, out) {
      [0, 0.13, 0.31, 0.42, 0.6, 0.71, 0.92, 1.08].forEach((t0, k) => {
        const p = 0.4 + (k % 3) * 0.1;
        noise(c, out, { t0, dur: 0.025, freq: 2800 + (k % 4) * 400, q: 2, peak: p });
        tone(c, out, { f0: 140, t0, dur: 0.035, peak: p * 0.5 });
      });
    } },
    tap: { len: 0.2, build(c, out) {
      noise(c, out, { dur: 0.05, filter: 'lowpass', freq: 900, peak: 0.8 });
      tone(c, out, { f0: 200, f1: 120, dur: 0.06, peak: 0.4 });
    } },
    drop: { len: 0.4, build(c, out) {
      tone(c, out, { f0: 500, f1: 1700, dur: 0.09, attack: 0.002, peak: 0.6 });
      tone(c, out, { f0: 900, f1: 1500, t0: 0.11, dur: 0.07, peak: 0.15 });
    } },
    fire: { len: 4, build(c, out) {
      const rumble = c.createGain();
      rumble.gain.setValueAtTime(0.0001, 0);
      rumble.gain.linearRampToValueAtTime(0.35, 0.6);
      rumble.gain.setValueAtTime(0.35, 3.2);
      rumble.gain.linearRampToValueAtTime(0.0001, 4);
      const s = c.createBufferSource();
      s.buffer = noiseBuffer(c, 4);
      const lp = c.createBiquadFilter();
      lp.type = 'lowpass';
      lp.frequency.value = 350;
      s.connect(lp).connect(rumble).connect(out);
      s.start(0);
      for (let k = 0; k < 45; k++) {
        const t0 = 0.2 + Math.random() * 3.5;
        noise(c, out, { t0, dur: 0.008 + Math.random() * 0.02, filter: 'highpass', freq: 1500 + Math.random() * 3000, peak: 0.15 + Math.random() * 0.4 });
      }
    } },
  };

  async function synth(kind) {
    const r = recipes[kind];
    const c = new OfflineAudioContext(1, Math.ceil(SR * r.len), SR);
    const out = c.createGain();
    out.connect(c.destination);
    r.build(c, out);
    return c.startRendering();
  }

  // ---------- 보관함 ----------

  async function init() {
    library = (await DB.get('kv', 'sfxLibrary')) || [];
  }

  async function addFile(file) {
    const item = { id: 'sfx_' + uid(), name: file.name.replace(/\.[^.]+$/, '') };
    await DB.put('library', item.id, file);
    library.push(item);
    await DB.put('kv', 'sfxLibrary', library);
    return item;
  }

  async function remove(id) {
    library = library.filter((x) => x.id !== id);
    cache.delete('lib:' + id);
    await DB.del('library', id);
    await DB.put('kv', 'sfxLibrary', library);
  }

  async function importItem(item, blob) {
    if (library.some((x) => x.id === item.id)) return;
    await DB.put('library', item.id, blob);
    library.push(item);
    await DB.put('kv', 'sfxLibrary', library);
  }

  // src: 'synth:click' 또는 'lib:<id>'
  async function buffer(src) {
    if (cache.has(src)) return cache.get(src);
    let buf = null;
    const [kind, key] = src.split(':');
    if (kind === 'synth' && recipes[key]) {
      buf = await synth(key);
    } else if (kind === 'lib') {
      const blob = await DB.get('library', key);
      if (blob) buf = await audioCtx().decodeAudioData(await blob.arrayBuffer()).catch(() => null);
    }
    cache.set(src, buf);
    return buf;
  }

  function label(src) {
    const [kind, key] = src.split(':');
    if (kind === 'synth') return SYNTH_SFX[key] || key;
    const item = library.find((x) => x.id === key);
    return item ? item.name : '(지워진 효과음)';
  }

  function optionsHtml(selected) {
    const opt = (v, l) => `<option value="${v}" ${v === selected ? 'selected' : ''}>${l}</option>`;
    let html = `<optgroup label="기본 효과음">${Object.entries(SYNTH_SFX).map(([k, l]) => opt('synth:' + k, l)).join('')}</optgroup>`;
    if (library.length) html += `<optgroup label="효과음 보관함">${library.map((x) => opt('lib:' + x.id, x.name)).join('')}</optgroup>`;
    if (selected && selected.startsWith('lib:') && !library.some((x) => 'lib:' + x.id === selected)) {
      html += opt(selected, '(지워진 효과음)');
    }
    return html;
  }

  // 프로젝트 전체 효과음 일정: [{ src, at, volume }]
  function events() {
    const out = [];
    timing().forEach((x) => {
      for (const e of x.scene.sfx) out.push({ src: e.src, at: x.start + (e.offset || 0), volume: e.volume });
    });
    return out;
  }

  // 쓰는 효과음을 미리 만들어 둔다. 재생 시각을 맞추려면 schedule 전에 부른다.
  function preload() {
    return Promise.all(events().map((ev) => buffer(ev.src)));
  }

  // 효과음을 오디오 그래프에 올린다. from~to 구간만, 시작 시각 when(컨텍스트 기준)에 맞춘다.
  // preload 뒤에 부르면 기다림 없이 바로 올라간다.
  function schedule(c, dest, from, to, when) {
    const nodes = [];
    for (const ev of events()) {
      const buf = cache.get(ev.src);
      if (!buf) continue;
      if (ev.at + buf.duration <= from || ev.at >= to) continue;
      const s = c.createBufferSource();
      s.buffer = buf;
      const g = c.createGain();
      g.gain.value = ev.volume;
      s.connect(g).connect(dest);
      const offset = Math.max(0, from - ev.at);
      s.start(when + Math.max(0, ev.at - from), offset, Math.min(buf.duration - offset, to - Math.max(from, ev.at)));
      nodes.push(s);
    }
    return nodes;
  }

  async function preview(src, volume = 1) {
    const c = audioCtx();
    await c.resume();
    const buf = await buffer(src);
    if (!buf) return;
    const s = c.createBufferSource();
    s.buffer = buf;
    const g = c.createGain();
    g.gain.value = volume;
    s.connect(g).connect(c.destination);
    s.start();
  }

  return {
    init, addFile, remove, importItem, buffer, label, optionsHtml, preload, schedule, preview, audioCtx,
    get library() { return library; },
  };
})();
