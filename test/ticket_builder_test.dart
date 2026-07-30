// Prueba del HTML del ticket de venta (issue #26: subtotal + diseño detallado).

import 'package:flutter_test/flutter_test.dart';

import 'package:login_app/models/models.dart';
import 'package:login_app/utils/ticket_builder.dart';

void main() {
  final sale = Sale(
    id: '1',
    folio: 'F-0001',
    items: const [
      SaleItem(
        productId: 'p1',
        productName: 'Café de grano 500g',
        unitPrice: 120.0,
        quantity: 2,
      ),
    ],
    paymentMethod: PaymentMethod.cash,
    userName: 'Ana Operadora',
    date: DateTime(2026, 7, 28, 10, 30),
  );

  test('el ticket incluye negocio, folio, fecha, hora, cajero, productos, '
      'totales y pago', () {
    final html = buildTicketHtml(sale);

    expect(html, contains(kTicketBusinessName));
    expect(html, contains('TICKET DE VENTA'));
    expect(html, contains('Folio:'));
    expect(html, contains('F-0001'));
    expect(html, contains('28/07/2026'));
    expect(html, contains('10:30:00'));
    expect(html, contains('Atendió:'));
    expect(html, contains('Ana Operadora'));
    expect(html, contains('Café de grano 500g'));
    expect(html, contains('2 x \$120.00'));
    expect(html, contains('Artículos'));
    expect(html, contains('Subtotal'));
    expect(html, contains('IVA 16% incluido'));
    expect(html, contains('TOTAL'));
    expect(html, contains('\$240.00'));
    expect(html, contains('Efectivo'));
    expect(html, contains('¡Gracias por su compra!'));
    expect(html, isNot(contains('REIMPRESIÓN')));
  });

  test('el SKU del catálogo aparece en la línea del producto', () {
    final html = buildTicketHtml(sale, skuByProductId: const {'p1': 'SKU-001'});

    expect(html, contains('SKU-001 · 2 x \$120.00'));
  });

  test('marca reimpresión y ventas canceladas', () {
    final html = buildTicketHtml(sale.copyWith(cancelled: true), reprint: true);

    expect(html, contains('REIMPRESIÓN'));
    expect(html, contains('VENTA CANCELADA'));
  });

  test('escapa el marcado que venga de los datos', () {
    final malicious = Sale(
      id: '2',
      folio: 'F-0002',
      items: const [
        SaleItem(
          productId: 'p2',
          productName: '<script>alert(1)</script> & más',
          unitPrice: 10,
          quantity: 1,
        ),
      ],
      paymentMethod: PaymentMethod.card,
      userName: 'Ana',
      date: DateTime(2026, 7, 28, 10, 30),
    );

    final html = buildTicketHtml(malicious);

    expect(html, isNot(contains('<script>')));
    expect(html, contains('&lt;script&gt;alert(1)&lt;/script&gt; &amp; más'));
  });
}
