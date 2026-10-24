// MP4 내보내기: 서버 없이 브라우저 안에서 인코딩한다 (WebCodecs + mp4-muxer).
// 그림은 미리보기와 같은 renderFrame으로 그리고, 소리는 효과음 + 영상 소리를 미리 섞어서 넣는다.

const Exporter = (() => {
  const FPS = 30;
  let cancelled = false;

  const VIDEO_CODECS = ['avc1.640033', 'avc1.4d0033', 'avc1.42e033', 'avc1.640028', 'avc1.42e028'];

  async function pickVideoConfig(width, height) {
    for (const codec of VIDEO_CODECS) {
      const config = { codec, width, height, bitrate: 10_000_000, framerate: FPS, avc: { format: 'avc' } };
      const r = await VideoEncoder.isConfigSupported(config).catch(() => null);
      if (r && r.supported) return config;
    }
    throw new Error('이 브라우저에서 H.264 인코딩을 쓸 수 없어요. Chrome 최신 버전에서 해 주세요.');
  }

  async function pickAudioConfig() {
    const candidates = [
      { muxCodec: 'aac', config: { codec: 'mp4a.40.2', sampleRate: SR, numberOfChannels: 2, bitrate: 192000 } },
      { muxCodec: 'opus', config: { codec: 'opus', sampleRate: SR, numberOfChannels: 2, bitrate: 192000 } },
    ];
    for (const c of candidates) {
      const r = await AudioEncoder.isConfigSupported(c.config).catch(() => null);
      if (r && r.supported) return c;
    }
    return null;
  }

  // ---------- 소리 섞기 ----------

  const videoAudioCache = new Map();
  async function videoAudio(fileId) {
    if (videoAudioCache.has(fileId)) return videoAudioCache.get(fileId);
    let buf = null;
    try {
      const blob = await DB.get('files', fileId);
      buf = await Sfx.audioCtx().decodeAudioData(await blob.arrayBuffer());
    } catch (e) {
      buf = null; // 소리가 없는 영상
    }
    videoAudioCache.set(fileId, buf);
    return buf;
  }

  async function mixAudio(total) {
    const c = new OfflineAudioContext(2, Math.max(1, Math.ceil(total * SR)), SR);
    await Sfx.preload();
    Sfx.schedule(c, c.destination, 0, total, 0);

    // 영상 소리: 화면이 이어지는 구간 동안 남긴 구간을 반복해서 깐다
    const tm = timing();
    for (let i = 0; i < tm.length; i++) {
      const v = tm[i].scene.visual;
      if (!v || v.type !== 'video' || !(v.volume > 0)) continue;
      const buf = await videoAudio(v.fileId);
      const m = media[v.fileId];
      if (!buf || !m) continue;
      const span = visualSpan(i, tm);
      const segs = keepSegments(v, m.el.duration || buf.duration);
      if (!segs.length) continue;
      const g = c.createGain();
      g.gain.value = v.volume;
      g.connect(c.destination);
      let cursor = span.start;
      while (cursor < span.end - 0.001) {
        for (const k of segs) {
          if (cursor >= span.end - 0.001) break;
          const len = Math.min(k.e - k.s, span.end - cursor);
          const s = c.createBufferSource();
          s.buffer = buf;
          s.connect(g);
          s.start(cursor, k.s, len);
          cursor += len;
        }
      }
    }
    return c.startRendering();
  }

  // ---------- 영상 위치 맞추기 ----------

  function seekVideo(el, time) {
    if (Math.abs(el.currentTime - time) < 0.001 && el.readyState >= 2) return Promise.resolve();
    return new Promise((resolve) => {
      const done = () => { clearTimeout(timer); resolve(); };
      const timer = setTimeout(done, 3000);
      el.addEventListener('seeked', done, { once: true });
      el.currentTime = time;
    });
  }

  // ---------- 내보내기 ----------

  async function run({ onProgress }) {
    cancelled = false;
    if (!('VideoEncoder' in window)) throw new Error('이 브라우저는 MP4 내보내기를 지원하지 않아요. Chrome 최신 버전에서 해 주세요.');
    const total = totalDuration();
    if (!total) throw new Error('장면이 없어요.');
    const [width, height] = ASPECTS[project.aspect];

    onProgress(0, '글꼴과 소리를 준비하는 중…');
    await Fonts.ensureProject();
    await document.fonts.ready;
    for (const m of Object.values(media)) if (m.type === 'video') m.el.pause();

    const videoConfig = await pickVideoConfig(width, height);
    const audio = await pickAudioConfig();
    const mixed = audio ? await mixAudio(total) : null;
    if (cancelled) return null;

    const target = new Mp4Muxer.ArrayBufferTarget();
    const muxer = new Mp4Muxer.Muxer({
      target,
      video: { codec: 'avc', width, height, frameRate: FPS },
      audio: audio ? { codec: audio.muxCodec, numberOfChannels: 2, sampleRate: SR } : undefined,
      fastStart: 'in-memory',
      firstTimestampBehavior: 'offset',
    });

    let encodeError = null;
    const venc = new VideoEncoder({
      output: (chunk, meta) => muxer.addVideoChunk(chunk, meta),
      error: (e) => { encodeError = e; },
    });
    venc.configure(videoConfig);

    // 소리 먼저 인코딩
    if (audio && mixed) {
      const aenc = new AudioEncoder({
        output: (chunk, meta) => muxer.addAudioChunk(chunk, meta),
        error: (e) => { encodeError = e; },
      });
      aenc.configure(audio.config);
      const L = mixed.getChannelData(0), R = mixed.getChannelData(1);
      const BLOCK = 4800;
      for (let i = 0; i < L.length; i += BLOCK) {
        const n = Math.min(BLOCK, L.length - i);
        const data = new Float32Array(n * 2);
        data.set(L.subarray(i, i + n), 0);
        data.set(R.subarray(i, i + n), n);
        const ad = new AudioData({ format: 'f32-planar', sampleRate: SR, numberOfFrames: n, numberOfChannels: 2, timestamp: Math.round((i / SR) * 1e6), data });
        aenc.encode(ad);
        ad.close();
      }
      await aenc.flush();
      aenc.close();
    }

    const canvas = document.createElement('canvas');
    canvas.width = width;
    canvas.height = height;
    const ctx = canvas.getContext('2d');
    const frames = Math.ceil(total * FPS);

    for (let f = 0; f < frames; f++) {
      if (cancelled) { venc.close(); return null; }
      if (encodeError) throw encodeError;
      const time = f / FPS;
      const av = activeVideoAt(time);
      if (av) await seekVideo(av.m.el, av.target);
      renderFrame(ctx, time);
      const frame = new VideoFrame(canvas, { timestamp: Math.round(time * 1e6), duration: Math.round(1e6 / FPS) });
      venc.encode(frame, { keyFrame: f % (FPS * 2) === 0 });
      frame.close();
      while (venc.encodeQueueSize > 8) await new Promise((r) => setTimeout(r, 5));
      if (f % 5 === 0) onProgress(f / frames, `영상 만드는 중… ${f + 1} / ${frames} 프레임`);
    }
    await venc.flush();
    venc.close();
    if (encodeError) throw encodeError;
    muxer.finalize();
    onProgress(1, '완료');
    return new Blob([target.buffer], { type: 'video/mp4' });
  }

  return {
    run,
    cancel() { cancelled = true; },
  };
})();
