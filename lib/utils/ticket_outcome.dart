/// Resultado de intentar entregar el ticket de una venta.
///
/// Existe en su propio archivo (sin nada de web) para que lo compartan la
/// implementación real y el stub de las plataformas no-web, y para que la
/// UI pueda dar un mensaje que corresponda a lo que de verdad pasó.
enum TicketOutcome {
  /// Se abrió el diálogo de impresión del navegador.
  printed,

  /// El navegador no dejó imprimir ni abrir la ventana, así que el ticket
  /// se entregó como archivo descargado.
  downloaded,

  /// No se pudo entregar el ticket (plataforma sin soporte de impresión).
  unavailable,
}
