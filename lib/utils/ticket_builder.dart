import '../core/app_theme.dart';
import '../models/models.dart';

/// Construye el HTML del ticket de venta en formato angosto (80mm, como
/// una impresora térmica de tickets). Separado de print_helper_web.dart
/// para poder probarlo sin depender de dart:html.
String buildTicketHtml(Sale sale) {
  final buffer = StringBuffer();
  buffer.writeln('<html><head><meta charset="utf-8"><title>Ticket ${sale.folio}</title>');
  buffer.writeln('''<style>
    @page { size: 80mm auto; margin: 3mm; }
    body { font-family: monospace; font-size: 12px; width: 280px; margin: 0 auto; }
    .center { text-align: center; }
    .row { display: flex; justify-content: space-between; gap: 8px; }
    .muted { color: #444; font-size: 11px; }
    hr { border: none; border-top: 1px dashed #000; margin: 6px 0; }
    table.items { width: 100%; border-collapse: collapse; }
    table.items td { padding: 1px 0; vertical-align: top; }
    .total { font-weight: 800; font-size: 14px; }
  </style>''');
  buffer.writeln('</head><body>');
  buffer.writeln('<div class="center">');
  buffer.writeln('<h3 style="margin:2px 0;">Mi Sucursal</h3>');
  buffer.writeln('<div>Folio: ${sale.folio}</div>');
  buffer.writeln('<div>${formatDateTime(sale.date.toLocal())}</div>');
  buffer.writeln('<div>Atendió: ${sale.userName}</div>');
  buffer.writeln('</div>');
  buffer.writeln('<hr>');
  buffer.writeln('<table class="items">');
  for (final it in sale.items) {
    buffer.writeln('<tr><td colspan="2">${it.productName}</td></tr>');
    buffer.writeln('<tr>');
    buffer.writeln(
      '<td class="muted">${it.quantity} x ${formatCurrency(it.unitPrice)}</td>',
    );
    buffer.writeln(
      '<td style="text-align:right;">${formatCurrency(it.subtotal)}</td>',
    );
    buffer.writeln('</tr>');
  }
  buffer.writeln('</table>');
  buffer.writeln('<hr>');
  buffer.writeln(
    '<div class="row"><div>Subtotal</div><div>${formatCurrency(sale.total)}</div></div>',
  );
  buffer.writeln(
    '<div class="row total"><div>Total</div><div>${formatCurrency(sale.total)}</div></div>',
  );
  buffer.writeln(
    '<div class="row"><div>Pago</div><div>${sale.paymentMethod.label}</div></div>',
  );
  buffer.writeln('<hr>');
  buffer.writeln('<div class="center">Gracias por su compra</div>');
  buffer.writeln('</body></html>');
  return buffer.toString();
}
