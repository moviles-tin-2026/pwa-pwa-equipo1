import 'dart:math';

import '../../models/models.dart';

enum SortOption { nameAsc, nameDesc, role, email }

/// Una entrada real del historial de actividad de un usuario.
typedef UserActivityEntry = ({DateTime time, String label, bool isNegative});

/// Construye el historial de actividad de [userName] a partir de las
/// ventas y movimientos que ya existen en Firestore — nunca datos
/// inventados.
///
/// Los movimientos que ya representan una línea de venta (`reason` empieza
/// con "Venta: ") se omiten: esa venta ya aparece una sola vez como evento
/// propio, así que no hace falta repetirla una vez por cada producto.
List<UserActivityEntry> userActivityHistory({
  required List<Sale> sales,
  required List<StockMovement> movements,
  required String userName,
  int limit = 15,
}) {
  final entries = <UserActivityEntry>[];

  for (final sale in sales.where((s) => s.userName == userName)) {
    entries.add((
      time: sale.date,
      label: sale.cancelled
          ? 'Venta ${sale.folio} cancelada'
          : 'Venta ${sale.folio} · ${sale.itemCount} artículo(s)',
      isNegative: sale.cancelled,
    ));
  }

  for (final movement in movements.where((m) => m.userName == userName)) {
    if (movement.reason.startsWith('Venta: ')) continue;
    final isRestore = movement.reason.startsWith(
      'Devolución por cancelación:',
    );
    entries.add((
      time: movement.date,
      label: isRestore
          ? '${movement.reason} · ${movement.quantity}× ${movement.productName}'
          : '${movement.type.label} de stock: ${movement.productName} '
              '(${movement.quantity}) — ${movement.reason}',
      isNegative: movement.type == MovementType.exit,
    ));
  }

  entries.sort((a, b) => b.time.compareTo(a.time));
  return entries.take(limit).toList();
}

/// Métricas de desempeño operativo de [userName], calculadas de las ventas
/// y movimientos reales que ya existen en Firestore (nunca datos
/// inventados). Las ventas canceladas no cuentan como desempeño: no
/// generaron ingreso real.
typedef UserPerformance = ({
  int saleCount,
  double revenue,
  double averageTicket,
  int movementCount,
  int cancelledCount,
  double? cancellationRate,
});

UserPerformance userPerformance({
  required List<Sale> sales,
  required List<StockMovement> movements,
  required String userName,
}) {
  final ownSales = sales.where((s) => s.userName == userName).toList();
  final activeSales = ownSales.where((s) => !s.cancelled).toList();
  final cancelledCount = ownSales.length - activeSales.length;

  final saleCount = activeSales.length;
  final revenue = activeSales.fold<double>(0, (sum, s) => sum + s.total);

  // Ajustes manuales de inventario (entradas/salidas fuera de una venta o
  // una cancelación): reflejan trabajo de bodega, no de caja.
  final movementCount = movements
      .where(
        (m) =>
            m.userName == userName &&
            !m.reason.startsWith('Venta: ') &&
            !m.reason.startsWith('Devolución por cancelación:'),
      )
      .length;

  return (
    saleCount: saleCount,
    revenue: revenue,
    averageTicket: saleCount == 0 ? 0 : revenue / saleCount,
    movementCount: movementCount,
    cancelledCount: cancelledCount,
    // `null` cuando nunca hizo una venta: no hay tasa que calcular, y 0%
    // se leería como "nunca cancela" en vez de "no aplica".
    cancellationRate:
        ownSales.isEmpty ? null : cancelledCount / ownSales.length,
  );
}

// ---- Semáforo de actividad reciente ----

/// Qué tan reciente fue la última actividad de un usuario. La UI le pone
/// color: verde/amarillo/naranja/rojo.
enum ActivityStatus { today, thisWeek, thisMonth, stale }

/// Fecha de la venta o el movimiento más reciente de [userName], o `null`
/// si nunca registró ninguno.
DateTime? lastActivityAt({
  required List<Sale> sales,
  required List<StockMovement> movements,
  required String userName,
}) {
  DateTime? latest;
  for (final sale in sales.where((s) => s.userName == userName)) {
    if (latest == null || sale.date.isAfter(latest)) latest = sale.date;
  }
  for (final movement in movements.where((m) => m.userName == userName)) {
    if (latest == null || movement.date.isAfter(latest)) latest = movement.date;
  }
  return latest;
}

/// Clasifica [lastActivity] en un balde de recencia. `null` (nunca tuvo
/// actividad) cae en [ActivityStatus.stale].
ActivityStatus activityStatusFor(DateTime? lastActivity, {DateTime? now}) {
  if (lastActivity == null) return ActivityStatus.stale;
  final today = now ?? DateTime.now();
  final lastDay = DateTime(
    lastActivity.year,
    lastActivity.month,
    lastActivity.day,
  );
  final todayDay = DateTime(today.year, today.month, today.day);
  // <= 0 cubre "hoy" y cualquier reloj ligeramente adelantado del cliente.
  final days = todayDay.difference(lastDay).inDays;
  if (days <= 0) return ActivityStatus.today;
  if (days <= 7) return ActivityStatus.thisWeek;
  if (days <= 30) return ActivityStatus.thisMonth;
  return ActivityStatus.stale;
}

// ---- Medidor de meta de ventas ----

/// Avance de [userName] hacia su meta de ventas del mes en curso.
///
/// `ratio` es `null` cuando `goal <= 0` (sin meta definida): el medidor
/// debe mostrar "Sin meta" en vez de leerse como 0%.
typedef GoalProgress = ({double revenue, double goal, double? ratio});

GoalProgress monthlySalesGoalProgress({
  required List<Sale> sales,
  required String userName,
  required double goal,
  DateTime? now,
}) {
  final today = now ?? DateTime.now();
  final revenue = sales
      .where(
        (s) =>
            s.userName == userName &&
            !s.cancelled &&
            s.date.year == today.year &&
            s.date.month == today.month,
      )
      .fold<double>(0, (sum, s) => sum + s.total);
  return (revenue: revenue, goal: goal, ratio: goal <= 0 ? null : revenue / goal);
}

// ---- Horas de conexión ----

/// Horas conectadas de [userName] desde [since] (o de todo lo sincronizado
/// si se omite), sumando la duración de cada sesión en `sessions/`.
///
/// La duración de una sesión abierta usa `UserSession.effectiveEnd`
/// (`endedAt`, o el último heartbeat si cerraron la pestaña sin cerrar
/// sesión), así que nunca cuenta como "conectado" desde que abrió hasta
/// ahora mismo.
double connectedHours({
  required List<UserSession> sessions,
  required String userName,
  DateTime? since,
}) {
  final ownSessions = sessions.where(
    (s) =>
        s.userName == userName &&
        (since == null || s.startedAt.isAfter(since)),
  );
  final totalMinutes = ownSessions.fold<int>(
    0,
    (sum, s) => sum + s.duration.inMinutes,
  );
  return totalMinutes / 60;
}

// ---- Contraseña de las altas de usuario ----
//
// Los requisitos son los que aplica Firebase Auth en este proyecto y los
// que documenta el README: 8 a 64 caracteres, sin espacios, con mayúscula,
// minúscula, número y carácter especial. Se validan aquí, antes de llamar
// a Firebase, para dar un mensaje claro en vez de un `weak-password`.

const int kPasswordMinLength = 8;
const int kPasswordMaxLength = 64;
const String kPasswordSpecialChars = '!@#\$%^&*()-_=+[]{};:,.?';

/// Valida la contraseña de un usuario nuevo. Devuelve el mensaje de error
/// o `null` si cumple.
String? validateNewPassword(String? value) {
  final password = value ?? '';
  if (password.isEmpty) return 'Ingresa una contraseña';
  if (password.length < kPasswordMinLength) {
    return 'Debe tener al menos $kPasswordMinLength caracteres';
  }
  if (password.length > kPasswordMaxLength) {
    return 'No debe exceder $kPasswordMaxLength caracteres';
  }
  if (RegExp(r'\s').hasMatch(password)) {
    return 'No debe contener espacios en blanco';
  }
  if (!RegExp(r'[A-Z]').hasMatch(password)) return 'Falta una mayúscula';
  if (!RegExp(r'[a-z]').hasMatch(password)) return 'Falta una minúscula';
  if (!RegExp(r'[0-9]').hasMatch(password)) return 'Falta un número';
  if (!password.split('').any(kPasswordSpecialChars.contains)) {
    return 'Falta un carácter especial (por ejemplo $kPasswordSpecialChars)';
  }
  return null;
}

/// Valida la confirmación de una contraseña nueva.
String? validatePasswordConfirmation(String? confirmation, String password) {
  if (confirmation == null || confirmation.isEmpty) {
    return 'Repite la contraseña nueva';
  }
  if (confirmation != password) return 'Las contraseñas no coinciden';
  return null;
}

/// Genera una contraseña temporal que cumple [validateNewPassword].
///
/// El administrador se la entrega al operador, que la cambia desde
/// "¿Olvidaste tu contraseña?" en el login.
String generateTemporaryPassword({Random? random}) {
  const upper = 'ABCDEFGHJKLMNPQRSTUVWXYZ'; // sin I ni O: se confunden
  const lower = 'abcdefghijkmnopqrstuvwxyz'; // sin l
  const digits = '23456789'; // sin 0 ni 1
  final rng = random ?? Random.secure();

  String pick(String from) => from[rng.nextInt(from.length)];

  // Uno de cada clase para garantizar los requisitos y el resto al azar.
  final chars = <String>[
    pick(upper),
    pick(lower),
    pick(digits),
    pick(kPasswordSpecialChars),
  ];
  const pool = upper + lower + digits;
  while (chars.length < 12) {
    chars.add(pick(pool));
  }
  chars.shuffle(rng);
  return chars.join();
}
