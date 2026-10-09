// Fridge-to-Table service worker: lets the app open without a connection.
// Pages are fetched network-first (so new deploys show up right away) and fall back to the cached copy.
// Supabase (database, sign-in, AI) is never cached.
const CACHE = 'ftt-shell-v1';
const SHELL = ['/', '/privacy.html', '/manifest.webmanifest', '/icons/icon-192.png', '/icons/icon-512.png', '/icons/apple-touch-icon.png'];
const STATIC_HOSTS = ['unpkg.com', 'cdn.jsdelivr.net', 'fonts.googleapis.com', 'fonts.gstatic.com'];

self.addEventListener('install', (event) => {
  event.waitUntil(caches.open(CACHE).then((cache) => cache.addAll(SHELL)).then(() => self.skipWaiting()));
});

self.addEventListener('activate', (event) => {
  event.waitUntil(
    caches.keys()
      .then((keys) => Promise.all(keys.filter((k) => k !== CACHE).map((k) => caches.delete(k))))
      .then(() => self.clients.claim())
  );
});

self.addEventListener('fetch', (event) => {
  const req = event.request;
  if (req.method !== 'GET') return;
  const url = new URL(req.url);
  if (url.hostname.endsWith('supabase.co') || url.hostname.endsWith('supabase.in')) return;

  // Pages: network first, cached copy when offline.
  if (req.mode === 'navigate') {
    const key = url.pathname === '/' || url.pathname === '/index.html' ? '/' : url.pathname;
    event.respondWith(
      fetch(req)
        .then((res) => {
          if (res.ok) { const copy = res.clone(); caches.open(CACHE).then((c) => c.put(key, copy)); }
          return res;
        })
        .catch(() => caches.match(key).then((hit) => hit || caches.match('/')))
    );
    return;
  }

  // Icons, fonts, the Supabase library: serve from cache, refresh in the background.
  if (url.origin === self.location.origin || STATIC_HOSTS.includes(url.hostname)) {
    event.respondWith(
      caches.open(CACHE).then((cache) =>
        cache.match(req).then((hit) => {
          const fresh = fetch(req)
            .then((res) => { if (res.ok || res.type === 'opaque') cache.put(req, res.clone()); return res; })
            .catch(() => hit);
          return hit || fresh;
        })
      )
    );
  }
});
