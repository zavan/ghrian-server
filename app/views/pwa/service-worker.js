// ghrian service worker. Served at /service-worker, so its scope is "/" (controls
// the whole app — required for installability). Strategy:
//   - navigations: network-first, fall back to the cached app shell when offline
//   - fingerprinted assets (css/js/img/font): cache-first (safe: digested URLs)
const CACHE = "ghrian-v1";
const SHELL = "/";

self.addEventListener("install", (event) => {
  event.waitUntil(
    caches.open(CACHE).then((cache) => cache.add(SHELL)).catch(() => {})
  );
  self.skipWaiting();
});

self.addEventListener("activate", (event) => {
  event.waitUntil(
    caches.keys().then((keys) =>
      Promise.all(keys.filter((key) => key !== CACHE).map((key) => caches.delete(key)))
    )
  );
  self.clients.claim();
});

self.addEventListener("fetch", (event) => {
  const { request } = event;
  if (request.method !== "GET") return;

  if (request.mode === "navigate") {
    event.respondWith(
      fetch(request)
        .then((response) => {
          const copy = response.clone();
          caches.open(CACHE).then((cache) => cache.put(SHELL, copy)).catch(() => {});
          return response;
        })
        .catch(() => caches.match(SHELL, { ignoreSearch: true }))
    );
    return;
  }

  const cacheable = ["style", "script", "image", "font"];
  if (cacheable.includes(request.destination)) {
    event.respondWith(
      caches.match(request).then((cached) =>
        cached ||
        fetch(request).then((response) => {
          const copy = response.clone();
          caches.open(CACHE).then((cache) => cache.put(request, copy)).catch(() => {});
          return response;
        })
      )
    );
  }
});
