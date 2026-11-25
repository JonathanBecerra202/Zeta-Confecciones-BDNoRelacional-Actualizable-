import 'dart:math';

const minPasswordLength = 8;

/// Contraseña temporal legible (sin caracteres ambiguos como 0/O o 1/l/I).
/// Siempre incluye letras y números.
String generateTempPassword({int length = 10}) {
  const letters = 'abcdefghijkmnpqrstuvwxyzABCDEFGHJKLMNPQRSTUVWXYZ';
  const digits = '23456789';
  final rnd = Random.secure();
  final chars = <String>[
    for (var i = 0; i < length - 2; i++) letters[rnd.nextInt(letters.length)],
    digits[rnd.nextInt(digits.length)],
    digits[rnd.nextInt(digits.length)],
  ]..shuffle(rnd);
  return chars.join();
}

/// Devuelve un mensaje de error o null si la contraseña es aceptable.
/// La Edge Function aplica la misma regla en el servidor.
String? validateNewPassword(String p) {
  if (p.length < minPasswordLength) return 'Debe tener al menos $minPasswordLength caracteres.';
  if (!RegExp(r'[A-Za-z]').hasMatch(p) || !RegExp(r'[0-9]').hasMatch(p)) {
    return 'Debe incluir letras y números.';
  }
  return null;
}