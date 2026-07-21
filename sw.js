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
 * Al cambiar la versión del build, subir CACHE_VERSION invalida el
 * caché anterior (se limpia en `activate`).
 */
const CACHE_VERSION = 'aura-vitae-v1';

const APP_SHELL = [
  './',
  'index.html',
  'main.dart.js',
  'flutter.js',
  'flutter_bootstrap.js',
  'manifest.json',
  'favicon.png',
  'icons/Icon-192.png',
  'icons/Icon-512.png',
  'icons/Icon-maskable-192.png',
  'icons/Icon-maskable-512.png',
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
