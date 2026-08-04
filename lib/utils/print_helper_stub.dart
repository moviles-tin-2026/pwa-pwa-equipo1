import '../models/models.dart';
import 'ticket_outcome.dart';

/// En plataformas no-web no hay diálogo de impresión del navegador ni
/// descarga: se avisa a la UI para que lo explique.
Future<TicketOutcome> printTicket(
  Sale sale, {
  Map<String, String> skuByProductId = const {},
  bool reprint = false,
}) async =>
    TicketOutcome.unavailable;
