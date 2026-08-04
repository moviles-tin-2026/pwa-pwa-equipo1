import 'dart:async';
import 'dart:js_interop';

import 'package:web/web.dart' as web;

import '../models/models.dart';
import 'ticket_builder.dart';
import 'ticket_outcome.dart';

const String _frameId = 'pymesync-ticket-frame';

/// Entrega el ticket de la venta al usuario y describe cómo lo hizo.
///
/// Se usa `package:web` + `dart:js_interop` en vez de `dart:html` porque el
/// sitio se compila con `--wasm`: `dart:html` no existe en dart2wasm y la
/// importación condicional dejaba a la app publicada con el stub, que
/// siempre devolvía "no se pudo abrir el ticket" (issue #44).
///
/// El orden de intentos va del mejor al más tolerante:
/// 1. `<iframe>` oculto en la misma página — abre el diálogo de impresión
///    sin depender del bloqueador de ventanas emergentes;
/// 2. ventana nueva con el ticket ya renderizado (por si el iframe falla);
/// 3. descarga del ticket como archivo HTML con el formato de 80 mm, que
///    ningún navegador bloquea.
Future<TicketOutcome> printTicket(
  Sale sale, {
  Map<String, String> skuByProductId = const {},
  bool reprint = false,
}) async {
  final content = buildTicketHtml(
    sale,
    skuByProductId: skuByProductId,
    reprint: reprint,
  );
  if (await _printWithIframe(content)) return TicketOutcome.printed;
  if (_printWithPopup(content)) return TicketOutcome.printed;
  if (_downloadTicket(content, sale.folio)) return TicketOutcome.downloaded;
  return TicketOutcome.unavailable;
}

/// Imprime desde un iframe oculto de la propia página. Es la ruta normal:
/// no abre ventanas, así que el bloqueador de emergentes no interviene.
Future<bool> _printWithIframe(String content) async {
  final body = web.document.body;
  if (body == null) return false;
  web.HTMLIFrameElement? frame;
  try {
    // Limpiar un ticket anterior que siguiera en el DOM.
    web.document.getElementById(_frameId)?.remove();

    frame = web.HTMLIFrameElement()
      ..id = _frameId
      ..srcdoc = content.toJS
      // Fuera de pantalla en vez de 0x0: el documento necesita un viewport
      // real para maquetarse antes de que el navegador lo mande a imprimir.
      ..style.position = 'fixed'
      ..style.left = '-10000px'
      ..style.top = '0'
      ..style.width = '80mm'
      ..style.height = '200mm'
      ..style.border = '0'
      ..style.opacity = '0'
      ..setAttribute('aria-hidden', 'true');

    final loaded = Completer<void>();
    frame.addEventListener(
      'load',
      ((web.Event _) {
        if (!loaded.isCompleted) loaded.complete();
      }).toJS,
    );
    body.appendChild(frame);

    // Si el iframe no carga en unos segundos se pasa a los respaldos en vez
    // de dejar al usuario sin ticket ni aviso.
    var timedOut = false;
    await loaded.future.timeout(
      const Duration(seconds: 5),
      onTimeout: () => timedOut = true,
    );
    if (timedOut) {
      frame.remove();
      return false;
    }

    final win = frame.contentWindow;
    if (win == null) {
      frame.remove();
      return false;
    }
    win.focus();
    win.print();

    // El iframe debe seguir en el DOM mientras el diálogo de impresión está
    // abierto; se retira después para no acumular nodos.
    // El cierre es obligatorio: dart2wasm no permite tear-offs de los
    // miembros externos de `package:web` (`printed.remove` no compila).
    final printed = frame;
    Timer(const Duration(minutes: 1), () => printed.remove());
    return true;
  } catch (_) {
    try {
      frame?.remove();
    } catch (_) {}
    return false;
  }
}

/// Respaldo: ventana nueva con el ticket. Solo funciona si el usuario
/// permite ventanas emergentes para el sitio.
bool _printWithPopup(String content) {
  try {
    // Se abre una URL de blob en vez de escribir con `document.write`: el
    // documento queda completo desde el inicio, así que si la impresión
    // automática no sale el usuario igual ve el ticket y puede imprimirlo.
    final url = _blobUrl(content);
    final win = web.window.open(url, '_blank');
    if (win == null) {
      web.URL.revokeObjectURL(url);
      return false;
    }
    try {
      win.focus();
    } catch (_) {}
    Timer(const Duration(milliseconds: 400), () {
      try {
        win.print();
      } catch (_) {}
    });
    Timer(const Duration(minutes: 1), () => web.URL.revokeObjectURL(url));
    return true;
  } catch (_) {
    return false;
  }
}

/// Último respaldo: descargar el ticket como archivo. Conserva el formato
/// de 80 mm (`@page`), así que al abrirlo se imprime igual que en pantalla.
bool _downloadTicket(String content, String folio) {
  try {
    final body = web.document.body;
    if (body == null) return false;
    final url = _blobUrl(content);
    final anchor = web.HTMLAnchorElement()
      ..href = url
      ..download = 'Ticket-${_safeFileName(folio)}.html'
      ..style.display = 'none';
    body.appendChild(anchor);
    anchor.click();
    anchor.remove();
    Timer(const Duration(minutes: 1), () => web.URL.revokeObjectURL(url));
    return true;
  } catch (_) {
    return false;
  }
}

String _blobUrl(String content) => web.URL.createObjectURL(
      web.Blob(
        <web.BlobPart>[content.toJS].toJS,
        web.BlobPropertyBag(type: 'text/html;charset=utf-8'),
      ),
    );

/// El folio ya viene con formato `V-0001`, pero el nombre del archivo se
/// sanea igual para no depender de eso.
String _safeFileName(String folio) {
  final clean = folio.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '-');
  return clean.isEmpty ? 'venta' : clean;
}
