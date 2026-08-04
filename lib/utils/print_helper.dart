export 'ticket_outcome.dart';
// La condición es `dart.library.js_interop`, NO `dart.library.html`: el
// deploy compila con `flutter build web --wasm` y en dart2wasm `dart:html`
// no existe, así que con la condición vieja la app publicada se quedaba
// siempre con el stub y el ticket nunca se generaba (issue #44).
export 'print_helper_stub.dart'
    if (dart.library.js_interop) 'print_helper_web.dart';
