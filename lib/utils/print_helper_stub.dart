import '../models/models.dart';

/// En plataformas no-web no hay diálogo de impresión del navegador:
/// devuelve `false` para que la UI avise al usuario.
bool printTicket(
  Sale sale, {
  Map<String, String> skuByProductId = const {},
  bool reprint = false,
}) =>
    false;
