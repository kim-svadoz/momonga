// 프로젝트 저장·불러오기: 작업 내용 + 넣어 둔 원본 파일을 zip 하나로 묶는다.

const ProjectIO = (() => {
  async function save() {
    const zip = new JSZip();
    const meta = { format: 'shorts-editor', version: 2, project, files: {}, sfxLibrary: [], fontLibrary: [] };

    for (const id of usedFileIds()) {
      const blob = await DB.get('files', id);
      if (!blob) continue;
      meta.files[id] = { type: blob.type, name: blob.name || id };
      zip.file(`files/${id}`, blob);
    }

    // 보관함 파일 중 이 프로젝트가 쓰는 것만 같이 넣는다
    const usedSfx = new Set(project.scenes.flatMap((s) => s.sfx.map((e) => e.src)));
    for (const item of Sfx.library) {
      if (!usedSfx.has('lib:' + item.id)) continue;
      const blob = await DB.get('library', item.id);
      if (!blob) continue;
      meta.sfxLibrary.push({ ...item, type: blob.type });
      zip.file(`library/${item.id}`, blob);
    }
    const usedFonts = new Set([project.subtitle.font, ...project.scenes.flatMap((s) => s.overlays.filter((o) => o.type === 'text').map((o) => o.font))]);
    for (const item of Fonts.library) {
      if (!usedFonts.has(item.family)) continue;
      const blob = await DB.get('library', item.id);
      if (!blob) continue;
      meta.fontLibrary.push({ ...item, type: blob.type });
      zip.file(`library/${item.id}`, blob);
    }

    zip.file('project.json', JSON.stringify(meta, null, 2));
    const out = await zip.generateAsync({ type: 'blob' });
    const d = new Date();
    const stamp = `${d.getFullYear()}${String(d.getMonth() + 1).padStart(2, '0')}${String(d.getDate()).padStart(2, '0')}-${String(d.getHours()).padStart(2, '0')}${String(d.getMinutes()).padStart(2, '0')}`;
    download(out, `shorts-project-${stamp}.zip`);
  }

  // zip을 읽어서 지금 프로젝트를 바꾼다. 보관함에는 없는 것만 더한다.
  async function load(file) {
    const zip = await JSZip.loadAsync(file);
    const metaFile = zip.file('project.json');
    if (!metaFile) throw new Error('숏츠 편집기 프로젝트 zip이 아니에요.');
    const meta = JSON.parse(await metaFile.async('string'));
    if (meta.format !== 'shorts-editor') throw new Error('숏츠 편집기 프로젝트 zip이 아니에요.');

    const read = async (path, type) => {
      const f = zip.file(path);
      if (!f) return null;
      return new Blob([await f.async('arraybuffer')], { type: type || '' });
    };

    await DB.clear('files');
    for (const [id, info] of Object.entries(meta.files || {})) {
      const blob = await read(`files/${id}`, info.type);
      if (blob) await DB.put('files', id, blob);
    }
    for (const item of meta.sfxLibrary || []) {
      const blob = await read(`library/${item.id}`, item.type);
      if (blob) await Sfx.importItem({ id: item.id, name: item.name }, blob);
    }
    for (const item of meta.fontLibrary || []) {
      const blob = await read(`library/${item.id}`, item.type);
      if (blob) await Fonts.importItem({ id: item.id, family: item.family, name: item.name }, blob);
    }
    return normalizeProject(meta.project);
  }

  return { save, load };
})();

function download(blob, name) {
  const a = document.createElement('a');
  a.href = URL.createObjectURL(blob);
  a.download = name;
  document.body.appendChild(a);
  a.click();
  a.remove();
  setTimeout(() => URL.revokeObjectURL(a.href), 10000);
}
