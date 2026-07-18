// Recovery-only service worker for Cloudflare Pages deployments.
// It intentionally provides no offline cache. Its only job is to replace any
// older Flutter worker immediately and remove assets that can strand iOS
// Safari on a previous release.
self.addEventListener('install', (event) => {
  event.waitUntil(self.skipWaiting());
});

self.addEventListener('activate', (event) => {
  event.waitUntil(
    caches
      .keys()
      .then((keys) => Promise.all(keys.map((key) => caches.delete(key))))
      .then(() => self.clients.claim()),
  );
});

// Do not intercept fetches. Every application asset must come from the
// current Cloudflare deployment and respect its Cache-Control headers.
self.addEventListener('fetch', () => {});
