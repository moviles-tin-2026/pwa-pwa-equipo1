import 'dart:math';

enum SortOption { nameAsc, nameDesc, role, email }

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
