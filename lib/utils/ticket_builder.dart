import '../core/app_theme.dart';
import '../models/models.dart';

/// Datos del negocio que encabezan el ticket. Se mantienen aquí como
/// constantes porque el modelo de Firestore no guarda todavía una
/// colección de configuración; cambiar estos valores cambia el ticket.
const String kTicketBusinessName = 'AURA VITAE';
const String kTicketBusinessTagline = 'PymeSync · Skincare CRM';

/// Tasa de IVA usada solo para desglosar (los precios de venta que
/// guardamos en Firestore ya lo incluyen; el desglose es informativo).
const double kTicketVatRate = 0.16;

/// Construye el HTML del ticket de venta en formato angosto (80mm, como
/// una impresora térmica de tickets). Separado de print_helper_web.dart
/// para poder probarlo sin depender de dart:html.
///
/// [skuByProductId] permite imprimir el SKU de cada línea: la venta solo
/// guarda id, nombre, precio y cantidad, así que el SKU se resuelve desde
/// el catálogo del repositorio cuando está disponible.
/// [reprint] marca el ticket como reimpresión (historial de ventas).
String buildTicketHtml(
  Sale sale, {
  Map<String, String> skuByProductId = const {},
  bool reprint = false,
  DateTime? printedAt,
}) {
  final date = sale.date.toLocal();
  final now = (printedAt ?? DateTime.now()).toLocal();
  final vatBase = sale.total / (1 + kTicketVatRate);
  final vat = sale.total - vatBase;

  final buffer = StringBuffer();
  buffer.writeln('<!DOCTYPE html>');
  buffer.writeln('<html lang="es"><head><meta charset="utf-8">');
  buffer.writeln('<title>Ticket ${_esc(sale.folio)}</title>');
  buffer.writeln('''<style>
    @page { size: 80mm auto; margin: 4mm; }
    * { box-sizing: border-box; }
    body {
      font-family: "Courier New", Consolas, monospace;
      font-size: 12px;
      line-height: 1.35;
      color: #000;
      width: 72mm;
      margin: 0 auto;
      padding: 4px 0 10px;
      background: #fff;
    }
    .center { text-align: center; }
    .right { text-align: right; }
    .bold { font-weight: 700; }
    .brand { font-size: 19px; font-weight: 700; letter-spacing: 2px; margin: 0; }
    .tagline { font-size: 10px; letter-spacing: 1px; margin: 2px 0 0; }
    .doc-type { font-size: 11px; letter-spacing: 2px; margin: 6px 0 0; }
    hr { border: none; border-top: 1px dashed #000; margin: 6px 0; }
    .meta { width: 100%; border-collapse: collapse; }
    .meta td { padding: 1px 0; vertical-align: top; font-size: 11px; }
    .meta td:first-child { width: 34%; }
    .meta td:last-child { text-align: right; font-weight: 700; }
    table.items { width: 100%; border-collapse: collapse; }
    table.items td { padding: 0; vertical-align: top; }
    .item-name { font-weight: 700; padding-top: 3px !important; }
    .item-detail { font-size: 10px; }
    .item-amount { text-align: right; white-space: nowrap; }
    .row { display: flex; justify-content: space-between; gap: 8px; font-size: 11px; }
    .row.total { font-size: 16px; font-weight: 700; margin: 4px 0; }
    .pay {
      display: flex; justify-content: space-between; gap: 8px;
      font-size: 12px; font-weight: 700; margin-top: 4px;
    }
    .badge {
      border: 1px solid #000; padding: 3px 0; margin: 6px 0;
      font-weight: 700; letter-spacing: 2px; font-size: 12px;
    }
    .folio-mark { font-size: 15px; font-weight: 700; letter-spacing: 3px; }
    .footer { font-size: 10px; margin-top: 6px; }
    @media print { body { width: auto; } }
  </style>''');
  buffer.writeln('</head><body>');

  // ── Encabezado del negocio ──────────────────────────────────────
  buffer.writeln('<div class="center">');
  buffer.writeln('<p class="brand">${_esc(kTicketBusinessName)}</p>');
  buffer.writeln('<p class="tagline">${_esc(kTicketBusinessTagline)}</p>');
  buffer.writeln('<p class="doc-type">TICKET DE VENTA</p>');
  buffer.writeln('</div>');

  if (sale.cancelled) {
    buffer.writeln('<div class="center badge">VENTA CANCELADA</div>');
  }
  if (reprint) {
    buffer.writeln('<div class="center badge">REIMPRESIÓN</div>');
  }

  // ── Datos de la venta ───────────────────────────────────────────
  buffer.writeln('<hr>');
  buffer.writeln('<table class="meta">');
  buffer.writeln(_metaRow('Folio:', sale.folio));
  buffer.writeln(_metaRow('Fecha:', formatDate(date)));
  buffer.writeln(_metaRow('Hora:', _formatTime(date)));
  buffer.writeln(_metaRow('Atendió:', sale.userName));
  buffer.writeln('</table>');

  // ── Productos ───────────────────────────────────────────────────
  buffer.writeln('<hr>');
  buffer.writeln('<table class="items">');
  buffer.writeln(
    '<tr><td class="bold item-detail">CANT. DESCRIPCIÓN</td>'
    '<td class="bold item-detail item-amount">IMPORTE</td></tr>',
  );
  for (final item in sale.items) {
    final sku = skuByProductId[item.productId];
    buffer.writeln(
      '<tr><td class="item-name" colspan="2">'
      '${item.quantity} x ${_esc(item.productName)}</td></tr>',
    );
    buffer.writeln('<tr>');
    buffer.writeln(
      '<td class="item-detail">'
      '${sku != null && sku.isNotEmpty ? '${_esc(sku)} · ' : ''}'
      '${item.quantity} x ${formatCurrency(item.unitPrice)}</td>',
    );
    buffer.writeln(
      '<td class="item-amount">${formatCurrency(item.subtotal)}</td>',
    );
    buffer.writeln('</tr>');
  }
  buffer.writeln('</table>');

  // ── Totales ─────────────────────────────────────────────────────
  buffer.writeln('<hr>');
  buffer.writeln(_totalRow('Artículos', '${sale.itemCount}'));
  buffer.writeln(_totalRow('Subtotal', formatCurrency(sale.total)));
  buffer.writeln(
    _totalRow(
      'IVA ${(kTicketVatRate * 100).round()}% incluido',
      formatCurrency(vat),
    ),
  );
  buffer.writeln(
    '<div class="row total"><div>TOTAL</div>'
    '<div>${formatCurrency(sale.total)}</div></div>',
  );
  buffer.writeln(
    '<div class="pay"><div>Pago</div>'
    '<div>${_esc(sale.paymentMethod.label)}</div></div>',
  );

  // ── Pie ─────────────────────────────────────────────────────────
  buffer.writeln('<hr>');
  buffer.writeln('<div class="center">');
  buffer.writeln('<div class="bold">¡Gracias por su compra!</div>');
  buffer.writeln('<div class="folio-mark">*${_esc(sale.folio)}*</div>');
  buffer.writeln(
    '<div class="footer">Comprobante interno de venta · no es un '
    'comprobante fiscal.<br>Conserve este ticket para cambios y '
    'devoluciones.<br>Impreso: ${formatDateTime(now)}</div>',
  );
  buffer.writeln('</div>');
  buffer.writeln('</body></html>');
  return buffer.toString();
}

String _metaRow(String label, String value) =>
    '<tr><td>${_esc(label)}</td><td>${_esc(value)}</td></tr>';

String _totalRow(String label, String value) =>
    '<div class="row"><div>${_esc(label)}</div><div>${_esc(value)}</div></div>';

String _formatTime(DateTime d) {
  String two(int n) => n.toString().padLeft(2, '0');
  return '${two(d.hour)}:${two(d.minute)}:${two(d.second)}';
}

/// Escapa el texto que viene de Firestore (nombres de producto, cajero)
/// para que no rompa ni inyecte marcado en el ticket.
String _esc(String value) => value
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;')
    .replaceAll('"', '&quot;');
