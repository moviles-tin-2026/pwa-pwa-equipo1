// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use
import 'dart:html' as html;
import '../models/models.dart';
import 'ticket_builder.dart';

/// Abre una ventana con el ticket de venta y lanza print().
void printTicket(Sale sale) {
  final content = buildTicketHtml(sale);

  // Abrir about:blank explícitamente y escribir el contenido
  final win = html.window.open('about:blank', '_blank');
  final w = win as dynamic;
  try {
    // Asegurar que el documento esté abierto para escritura
    w.document.open();
    w.document.write(content);
    w.document.close();
    // Dar foco a la ventana y esperar un momento para que renderice
    try {
      w.focus();
    } catch (_) {}
    Future.delayed(const Duration(milliseconds: 250), () {
      try {
        w.print();
      } catch (_) {}
    });
  } catch (_) {}
}
