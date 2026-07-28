// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use
import 'dart:html' as html;
import '../models/models.dart';

/// Abre una ventana con un HTML sencillo con el ticket y lanza print().
void printTicket(Sale sale) {
  final buffer = StringBuffer();
  buffer.writeln('<html><head><meta charset="utf-8"><title>Ticket</title>');
  buffer.writeln('<style>body{font-family: monospace; font-size:12px;} .center{text-align:center;} .items{width:100%; border-collapse:collapse;} .items td{padding:4px;} .total{font-weight:800;}</style>');
  buffer.writeln('</head><body>');
  buffer.writeln('<div class="center">');
  buffer.writeln('<h3>Mi Sucursal</h3>');
  buffer.writeln('<div>Folio: ${sale.folio}</div>');
  buffer.writeln('<div>${sale.date.toLocal()}</div>');
  buffer.writeln('</div>');
  buffer.writeln('<hr>');
  buffer.writeln('<table class="items">');
  for (final it in sale.items) {
    buffer.writeln('<tr>');
    buffer.writeln('<td>${it.productName} x${it.quantity}</td>');
    buffer.writeln('<td style="text-align:right;">${it.subtotal.toStringAsFixed(2)}</td>');
    buffer.writeln('</tr>');
  }
  buffer.writeln('</table>');
  buffer.writeln('<hr>');
  buffer.writeln('<div style="display:flex; justify-content:space-between;">');
  buffer.writeln('<div>Pago: ${sale.paymentMethod.label}</div>');
  buffer.writeln('<div class="total">Total: ${sale.total.toStringAsFixed(2)}</div>');
  buffer.writeln('</div>');
  buffer.writeln('<div class="center">Gracias por su compra</div>');
  buffer.writeln('</body></html>');

  // Abrir about:blank explícitamente y escribir el contenido
  final win = html.window.open('about:blank', '_blank');
  final w = win as dynamic;
  try {
    // Asegurar que el documento esté abierto para escritura
    w.document.open();
    w.document.write(buffer.toString());
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

