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
  onEntrypointLoaded: async function (engineInitializer) {
    const appRunner = await engineInitializer.initializeEngine();
    await appRunner.runApp();

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
