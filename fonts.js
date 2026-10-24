// 글꼴: 무료 한글 글꼴(Google Fonts)과 내가 넣은 글꼴 파일(글꼴 보관함)

const BUILTIN_FONTS = [
  'Noto Sans KR',
  'Black Han Sans',
  'Do Hyeon',
  'Jua',
  'Gothic A1',
  'Nanum Gothic',
  'Nanum Myeongjo',
  'Nanum Pen Script',
  'Gowun Dodum',
  'Sunflower',
  'Gaegu',
  'Song Myung',
  'Dongle',
];

const Fonts = (() => {
  let library = []; // [{ id, family, name }]
  const requested = new Map(); // "weight family" → Promise
  let onLoad = () => {};

  function spec(family, weight) {
    return `${weight || 400} 40px "${family}"`;
  }

  // 캔버스에 그리기 전에 글꼴을 불러온다. 다 불러오면 onLoad(다시 그리기)를 부른다.
  function use(family, weight) {
    const key = `${weight} ${family}`;
    if (!requested.has(key)) {
      const p = document.fonts.load(spec(family, weight), '가A').catch(() => {}).then(() => onLoad());
      requested.set(key, p);
    }
    return requested.get(key);
  }

  async function register(item, blob) {
    const face = new FontFace(item.family, await blob.arrayBuffer());
    await face.load();
    document.fonts.add(face);
  }

  async function init(redraw) {
    onLoad = redraw;
    library = (await DB.get('kv', 'fontLibrary')) || [];
    for (const item of library) {
      const blob = await DB.get('library', item.id);
      if (blob) await register(item, blob).catch(() => {});
    }
  }

  async function addFile(file) {
    const family = file.name.replace(/\.(ttf|otf|woff2?)$/i, '');
    if (library.some((f) => f.family === family)) throw new Error(`'${family}' 글꼴이 이미 있어요.`);
    const item = { id: 'font_' + uid(), family, name: file.name };
    await register(item, file);
    await DB.put('library', item.id, file);
    library.push(item);
    await DB.put('kv', 'fontLibrary', library);
    return item;
  }

  async function remove(id) {
    library = library.filter((f) => f.id !== id);
    await DB.del('library', id);
    await DB.put('kv', 'fontLibrary', library);
  }

  // 받은 zip에 든 글꼴을 보관함에 넣는다
  async function importItem(item, blob) {
    if (library.some((f) => f.family === item.family)) return;
    await register(item, blob);
    await DB.put('library', item.id, blob);
    library.push(item);
    await DB.put('kv', 'fontLibrary', library);
  }

  // 프로젝트가 쓰는 글꼴을 모두 불러올 때까지 기다린다 (MP4 내보내기 전)
  function ensureProject() {
    const specs = new Set([`${project.subtitle.weight}|${project.subtitle.font}`]);
    for (const s of project.scenes) {
      for (const o of s.overlays) if (o.type === 'text') specs.add(`${o.weight}|${o.font}`);
    }
    return Promise.all([...specs].map((k) => {
      const [w, f] = k.split('|');
      return use(f, w);
    }));
  }

  function optionsHtml(selected) {
    const opt = (f) => `<option value="${f}" ${f === selected ? 'selected' : ''}>${f}</option>`;
    let html = `<optgroup label="무료 한글 글꼴">${BUILTIN_FONTS.map(opt).join('')}</optgroup>`;
    if (library.length) html += `<optgroup label="글꼴 보관함">${library.map((f) => opt(f.family)).join('')}</optgroup>`;
    return html;
  }

  return {
    use, init, addFile, remove, importItem, ensureProject, optionsHtml,
    get library() { return library; },
  };
})();
