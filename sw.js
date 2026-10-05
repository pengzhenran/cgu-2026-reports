/* 离线缓存：GitHub Pages 只给 Cache-Control: max-age=600，
   页面 10 分钟后就又要重新下载。这里用 Service Worker 把页面和数据长期留在本地：
   第二次及以后打开基本瞬开，断网也能查。

   更新数据时：先跑 node build_data.mjs（它会自动改写下面的 BUILD），再提交。
   只改本文件而不改 BUILD 时，缓存不会刷新。 */
const BUILD = 'eb356b99f6.2';
const CACHE = 'cgu-2026-' + BUILD;
const ASSETS = [
  './', './index.html', './cgu_data.js', './qrcode.jpg',
  './favicon.ico', './icon-32.png', './icon-192.png', './icon-512.png',
  './apple-touch-icon.png', './manifest.webmanifest',
];

self.addEventListener('install', (event) => {
  event.waitUntil((async () => {
    const cache = await caches.open(CACHE);
    await Promise.allSettled(ASSETS.map((url) => cache.add(new Request(url, { cache: 'reload' }))));
    await self.skipWaiting();
  })());
});

self.addEventListener('activate', (event) => {
  event.waitUntil((async () => {
    const keys = await caches.keys();
    await Promise.all(keys.filter((k) => k !== CACHE).map((k) => caches.delete(k)));
    await self.clients.claim();
  })());
});

/* stale-while-revalidate：先用本地缓存秒开，同时在后台拉新版本供下次使用 */
self.addEventListener('fetch', (event) => {
  const req = event.request;
  if (req.method !== 'GET') return;
  const url = new URL(req.url);
  if (url.origin !== location.origin) return;

  event.respondWith((async () => {
    const cache = await caches.open(CACHE);
    const hit = await cache.match(req, { ignoreSearch: true });
    const net = fetch(req).then((res) => {
      if (res && res.ok && res.type === 'basic') cache.put(req, res.clone());
      return res;
    }).catch(() => hit);
    return hit || net;
  })());
});
