// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use
import 'dart:async';
import 'dart:html' as html;

import '../models/models.dart';
import 'ticket_builder.dart';

const String _frameId = 'pymesync-ticket-frame';

/// Imprime el ticket de la venta y devuelve `true` si se pudo lanzar el
/// diálogo de impresión del navegador.
///
/// Se imprime desde un `<iframe>` oculto dentro de la misma página: la
/// versión anterior abría una ventana nueva con `window.open`, que los
/// navegadores bloquean como popup (en incógnito casi siempre) y entonces
/// no ocurría absolutamente nada. El iframe no depende del bloqueador;
/// la ventana emergente queda solo como último recurso.
bool printTicket(
  Sale sale, {
  Map<String, String> skuByProductId = const {},
  bool reprint = false,
}) {
  final content = buildTicketHtml(
    sale,
    skuByProductId: skuByProductId,
    reprint: reprint,
  );
  return _printWithIframe(content) || _printWithPopup(content);
}

bool _printWithIframe(String content) {
  final body = html.document.body;
  if (body == null) return false;
  try {
    // Limpiar un ticket anterior que siguiera en el DOM.
    html.document.getElementById(_frameId)?.remove();

    final frame = html.IFrameElement()
      ..id = _frameId
      ..srcdoc = content
      ..style.position = 'fixed'
      ..style.right = '0'
      ..style.bottom = '0'
      ..style.width = '0'
      ..style.height = '0'
      ..style.border = '0'
      ..style.opacity = '0'
      ..setAttribute('aria-hidden', 'true');

    frame.onLoad.first.then((_) {
      final win = frame.contentWindow as dynamic;
      if (win == null) {
        frame.remove();
        _printWithPopup(content);
        return;
      }
      try {
        win.focus();
        win.print();
      } catch (_) {
        frame.remove();
        _printWithPopup(content);
        return;
      }
      // El iframe debe seguir en el DOM mientras el diálogo de impresión
      // está abierto; se retira después para no acumular nodos.
      Timer(const Duration(minutes: 1), frame.remove);
    });

    body.append(frame);
    return true;
  } catch (_) {
    return false;
  }
}

/// Respaldo: ventana nueva que se imprime sola al cargar. Solo funciona si
/// el usuario permite ventanas emergentes para el sitio.
bool _printWithPopup(String content) {
  try {
    final win = html.window.open('about:blank', '_blank');
    final w = win as dynamic;
    if (w == null) return false;
    w.document.open();
    w.document.write(content);
    w.document.close();
    try {
      w.focus();
    } catch (_) {}
    Timer(const Duration(milliseconds: 250), () {
      try {
        w.print();
      } catch (_) {}
    });
    return true;
  } catch (_) {
    return false;
  }
}
