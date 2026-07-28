// Prueba del HTML del ticket de venta (issue #26: subtotal + diseño detallado).

import 'package:flutter_test/flutter_test.dart';

import 'package:login_app/models/models.dart';
import 'package:login_app/utils/ticket_builder.dart';

void main() {
  test('el ticket incluye folio, cajero, productos, subtotal, total y pago',
      () {
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

    final html = buildTicketHtml(sale);

    expect(html, contains('Folio: F-0001'));
    expect(html, contains('Atendió: Ana Operadora'));
    expect(html, contains('Café de grano 500g'));
    expect(html, contains('2 x \$120.00'));
    expect(html, contains('Subtotal'));
    expect(html, contains('Total'));
    expect(html, contains('\$240.00'));
    expect(html, contains('Efectivo'));
    expect(html, contains('Gracias por su compra'));
  });
}
