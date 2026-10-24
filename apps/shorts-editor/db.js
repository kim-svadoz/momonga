// IndexedDB 래퍼. 프로젝트 JSON(kv), 장면에 넣은 파일(files), 보관함 파일(library)을 저장한다.
const DB = (() => {
  const NAME = 'shorts-editor';
  const VERSION = 2;
  let dbPromise;

  function open() {
    if (!dbPromise) {
      dbPromise = new Promise((resolve, reject) => {
        const req = indexedDB.open(NAME, VERSION);
        req.onupgradeneeded = () => {
          const db = req.result;
          if (!db.objectStoreNames.contains('kv')) db.createObjectStore('kv');
          if (!db.objectStoreNames.contains('files')) db.createObjectStore('files');
          // 보관함(글꼴·효과음): 새 프로젝트를 시작해도 남는다
          if (!db.objectStoreNames.contains('library')) db.createObjectStore('library');
        };
        req.onsuccess = () => resolve(req.result);
        req.onerror = () => reject(req.error);
      });
    }
    return dbPromise;
  }

  async function tx(store, mode, fn) {
    const db = await open();
    return new Promise((resolve, reject) => {
      const t = db.transaction(store, mode);
      const req = fn(t.objectStore(store));
      t.oncomplete = () => resolve(req && req.result);
      t.onerror = () => reject(t.error);
    });
  }

  return {
    get: (store, key) => tx(store, 'readonly', s => s.get(key)),
    put: (store, key, value) => tx(store, 'readwrite', s => s.put(value, key)),
    del: (store, key) => tx(store, 'readwrite', s => s.delete(key)),
    keys: (store) => tx(store, 'readonly', s => s.getAllKeys()),
    clear: (store) => tx(store, 'readwrite', s => s.clear()),
  };
})();
