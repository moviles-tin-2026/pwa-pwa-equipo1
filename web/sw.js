/**
 * Service Worker de AURA VITAE · PymeSync (PWA).
 *
 * Estrategia:
 * - Precache del app shell (index, JS compilado, manifest, íconos) al
 *   instalar, para que la app cargue sin conexión.
 * - Navegaciones: red primero con fallback al index cacheado (offline).
 * - Estáticos del mismo origen: caché primero, poblada bajo demanda.
 * - Peticiones a otros orígenes (Firestore, Google Fonts, imágenes de
 *   Drive) NO se interceptan: Firestore maneja su propia persistencia.
 *
 * CACHE_VERSION identifica el caché de este build. Como los estáticos se
 * sirven caché-primero, si no cambia entre builds los navegadores que ya
 * visitaron el sitio siguen ejecutando el `main.dart.js` viejo para
 * siempre. Por eso el workflow de Pages reescribe esta línea con el SHA
 * del commit antes de publicar (ver `.github/workflows/deploy-pages.yml`);
 * el valor de abajo es solo el de desarrollo local.
 */
const CACHE_VERSION = 'aura-vitae-dev';

const APP_SHELL = [
  './',
  'index.html',
  'main.dart.js',
  'main.dart.wasm',
  'main.dart.mjs',
  'flutter.js',
  'flutter_bootstrap.js',
  'manifest.json',
  'favicon.png',
  'icons/Icon-192.png',
  'icons/Icon-512.png',
  'icons/Icon-maskable-192.png',
  'icons/Icon-maskable-512.png',
  'canvaskit/skwasm.js',
  'canvaskit/skwasm.wasm',
  'canvaskit/canvaskit.js',
  'canvaskit/canvaskit.wasm',
];

self.addEventListener('install', (event) => {
  event.waitUntil(
    caches
      .open(CACHE_VERSION)
      .then((cache) => cache.addAll(APP_SHELL))
      .then(() => self.skipWaiting()),
  );
});

self.addEventListener('activate', (event) => {
  event.waitUntil(
    caches
      .keys()
      .then((keys) =>
        Promise.all(
          keys
            .filter((key) => key !== CACHE_VERSION)
            .map((key) => caches.delete(key)),
        ),
      )
      .then(() => self.clients.claim()),
  );
});

self.addEventListener('fetch', (event) => {
  const request = event.request;
  if (request.method !== 'GET') return;

  const url = new URL(request.url);
  if (url.origin !== self.location.origin) return; // Firestore, fuentes, Drive…

  // Navegaciones: red primero, fallback al shell cacheado (modo offline).
  if (request.mode === 'navigate') {
    event.respondWith(
      fetch(request).catch(() =>
        caches.match('index.html', { ignoreSearch: true }),
      ),
    );
    return;
  }

  // Estáticos: caché primero; si no está, red y se guarda para después.
  event.respondWith(
    caches.match(request, { ignoreSearch: true }).then((cached) => {
      if (cached) return cached;
      return fetch(request).then((response) => {
        if (response.ok && response.type === 'basic') {
          const copy = response.clone();
          caches
            .open(CACHE_VERSION)
            .then((cache) => cache.put(request, copy));
        }
        return response;
      });
    }),
  );
});
