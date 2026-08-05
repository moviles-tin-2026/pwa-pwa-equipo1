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
