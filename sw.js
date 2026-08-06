/**
 * Service Worker de AURA VITAE · PymeSync (PWA).
 *
 * Estrategia:
 * - Precache del app shell (index, JS compilado, manifest, íconos) al
 *   instalar, para que la app cargue sin conexión.
 * - Navegaciones: red primero con fallback al index cacheado (offline).
 * - Estáticos del mismo origen: caché primero, poblada bajo demanda.
 * - Peticiones a otros orígenes (Firestore, Google Fonts, imágenes de
 *   Drive) NO se interceptan: los datos los cachea Firestore con su
 *   persistencia local, que la app enciende al arrancar (ver
 *   `_enableOfflinePersistence` en `lib/main.dart`). Interceptarlas aquí
 *   duplicaría ese trabajo y rompería la sincronización en vivo.
 *
 * CACHE_VERSION identifica el caché de este build. Como los estáticos se
 * sirven caché-primero, si no cambia entre builds los navegadores que ya
 * visitaron el sitio siguen ejecutando el `main.dart.js` viejo para
 * siempre. Por eso el workflow de Pages reescribe esta línea con el SHA
 * del commit antes de publicar (ver `.github/workflows/deploy-pages.yml`);
 * el valor de abajo es solo el de desarrollo local.
 */
const CACHE_VERSION = 'aura-vitae-f90d3d9';

// Solo el shell ligero (~400 KB). Los binarios pesados quedan FUERA a
// propósito: `main.dart.wasm` (2.7 MB), `main.dart.js` (3.2 MB, el
// fallback para navegadores sin WasmGC), `canvaskit/skwasm.wasm` (3.5 MB)
// y `canvaskit/canvaskit.wasm` (6.9 MB) suman 17 MB, de los cuales cada
// navegador ejecuta menos de la mitad: usa `main.dart.wasm` + skwasm, o
// `main.dart.js` + canvaskit, nunca los cuatro.
//
// Dos razones para no precargarlos:
//  1. `addAll` es atómico. Un timeout en cualquiera de esos 17 MB tumba la
//     instalación completa del service worker, sin error visible, y te
//     quedas sin offline.
//  2. La página los pide por su cuenta al arrancar y esas peticiones ya
//     pasan por el fetch handler de abajo, que las cachea. Precargarlas
//     aquí además hace que el visitante las baje dos veces, compitiendo
//     por ancho de banda con la carga que está midiendo el usuario.
//
// El costo: la primera visita no queda offline-capable hasta terminar de
// cargar la página. En la práctica es el mismo instante.
const APP_SHELL = [
  './',
  'index.html',
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
  'canvaskit/canvaskit.js',
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
