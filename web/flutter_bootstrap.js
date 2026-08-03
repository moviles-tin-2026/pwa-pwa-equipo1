// Bootstrap personalizado de Flutter web — AURA VITAE · PymeSync.
//
// Sustituye al que Flutter genera por defecto. Existe por una sola razón:
// avisarle a `index.html` cuándo la app ya pintó su primer frame, para que
// el splash de arranque se retire en ese momento exacto y no antes (se
// vería un parpadeo en blanco) ni después (segundos de splash de más).
//
// Los dos tokens de plantilla los reemplaza `flutter build web` al
// compilar; no los toques ni los reordenes.
//
// Nota: aquí NO se registra el service worker propio de Flutter. Esta app
// usa el suyo (`sw.js`, registrado desde index.html) y el de Flutter ya
// está marcado como deprecado; registrar los dos sobre el mismo scope
// hacía que compitieran entre sí.

{{flutter_js}}
{{flutter_build_config}}

_flutter.loader.load({
  config: {
    canvasKitBaseUrl: "canvaskit/"
  },
  onEntrypointLoaded: async function (engineInitializer) {
    const appRunner = await engineInitializer.initializeEngine();
    await appRunner.runApp();

    // Al arrancar, el motor reemplaza la etiqueta <meta name="viewport"> de
    // index.html por una propia (queda marcada con `flt-viewport`) que trae
    // `user-scalable=no, maximum-scale=1.0`, es decir bloquea el zoom.
    //
    // Eso es un fallo de accesibilidad real: quien tiene baja visión depende
    // de ampliar la pantalla para leer, y este es un sistema de inventario y
    // punto de venta que se usa a diario. Se restaura una que sí permita
    // ampliar. La app no usa gestos de pellizco, así que no hay conflicto
    // con el manejo de gestos de Flutter.
    const viewport = document.querySelector('meta[name="viewport"]');
    if (viewport) {
      viewport.setAttribute('content', 'width=device-width, initial-scale=1.0');
    }

    // `runApp` regresa cuando la app arrancó, no cuando ya se pintó.
    // Dos frames encadenados garantizan que el primer frame real de
    // Flutter esté en pantalla antes de empezar a desvanecer el splash.
    requestAnimationFrame(function () {
      requestAnimationFrame(function () {
        const splash = document.getElementById('splash');
        if (!splash) return;

        document.documentElement.classList.add('is-ready');

        // Retirar el nodo al terminar la transición para que no siga
        // ocupando el árbol ni interceptando eventos. El temporizador es
        // el respaldo por si `transitionend` no dispara (transición
        // desactivada por `prefers-reduced-motion`, pestaña en segundo
        // plano, etc.).
        const remove = function () { splash.remove(); };
        splash.addEventListener('transitionend', remove, { once: true });
        setTimeout(remove, 600);
      });
    });
  }
});
