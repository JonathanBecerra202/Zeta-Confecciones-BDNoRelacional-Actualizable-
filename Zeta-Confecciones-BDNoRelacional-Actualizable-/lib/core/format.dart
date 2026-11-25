import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/models.dart';

/// $1.234.567
String money(num v) {
  final neg = v < 0;
  final s = v.abs().round().toString();
  final buf = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) buf.write('.');
    buf.write(s[i]);
  }
  return '${neg ? '-' : ''}\$$buf';
}

String _groupDigits(String digits) {
  final buf = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) buf.write('.');
    buf.write(digits[i]);
  }
  return buf.toString();
}

/// Campo de dinero: solo dígitos, con puntos de miles.
class MoneyInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    final digits = newValue.text.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.isEmpty) return const TextEditingValue(text: '');
    final text = _groupDigits(digits);
    return TextEditingValue(text: text, selection: TextSelection.collapsed(offset: text.length));
  }
}

int? parseMoney(String s) => int.tryParse(s.replaceAll('.', '').trim());

String moneyField(num v) => _groupDigits(v.round().toString());

String normalizeText(String input) {
  const from = 'áàäâãéèëêíìïîóòöôõúùüûñç';
  const to = 'aaaaaeeeeiiiiooooouuuunc';
  final s = input.toLowerCase();
  final buf = StringBuffer();
  for (final ch in s.split('')) {
    final i = from.indexOf(ch);
    buf.write(i >= 0 ? to[i] : ch);
  }
  return buf.toString();
}

/// Búsqueda tolerante a mayúsculas y acentos (igual que en la web).
bool matchesSearch(String text, String query) {
  final terms = normalizeText(query).trim().split(RegExp(r'\s+')).where((t) => t.isNotEmpty);
  if (terms.isEmpty) return true;
  final words = normalizeText(text).split(RegExp(r'\s+'));
  return terms.every((t) => words.any((w) => w.contains(t)));
}

String initials(String name) {
  final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
  if (parts.isEmpty) return '?';
  return parts.take(2).map((p) => p[0].toUpperCase()).join();
}

const _monthsShort = ['ene', 'feb', 'mar', 'abr', 'may', 'jun', 'jul', 'ago', 'sep', 'oct', 'nov', 'dic'];
const _monthsLong = [
  'enero', 'febrero', 'marzo', 'abril', 'mayo', 'junio',
  'julio', 'agosto', 'septiembre', 'octubre', 'noviembre', 'diciembre'
];
const _daysShort = ['Lun', 'Mar', 'Mié', 'Jue', 'Vie', 'Sáb', 'Dom'];
const _daysLong = ['Lunes', 'Martes', 'Miércoles', 'Jueves', 'Viernes', 'Sábado', 'Domingo'];

DateTime today() {
  final n = DateTime.now();
  return DateTime(n.year, n.month, n.day);
}

/// Convierte 'yyyy-mm-dd' en fecha local a medianoche.
DateTime parseDate(String iso) {
  final p = iso.substring(0, 10).split('-');
  return DateTime(int.parse(p[0]), int.parse(p[1]), int.parse(p[2]));
}

String isoDate(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

/// 26 sep 2026
String shortDate(DateTime d) => '${d.day} ${_monthsShort[d.month - 1]} ${d.year}';

/// Viernes, 23 de octubre
String longToday() {
  final n = DateTime.now();
  return '${_daysLong[n.weekday - 1]}, ${n.day} de ${_monthsLong[n.month - 1]}';
}

/// 23 oct 2026 · 3:14 p. m.
String dateTimeLabel(String iso) {
  final d = DateTime.parse(iso).toLocal();
  final h12 = d.hour % 12 == 0 ? 12 : d.hour % 12;
  final ampm = d.hour >= 12 ? 'p. m.' : 'a. m.';
  return '${shortDate(d)} · $h12:${d.minute.toString().padLeft(2, '0')} $ampm';
}

String greeting() {
  final h = DateTime.now().hour;
  if (h < 12) return 'Buenos días';
  if (h < 19) return 'Buenas tardes';
  return 'Buenas noches';
}

bool isOpen(GarmentOrder o) =>
    o.status == OrderStatus.pending || o.status == OrderStatus.inProgress;

bool isOverdue(GarmentOrder o) {
  if (o.deliveryDate == null || !isOpen(o)) return false;
  return parseDate(o.deliveryDate!).isBefore(today());
}

/// Texto de entrega: "Mañana", "Vie, 26 sep", "Venció hace 3 días"...
String dueLabel(GarmentOrder o) {
  if (o.status == OrderStatus.delivered) return 'Entregado';
  if (o.status == OrderStatus.cancelled) return 'Cancelado';
  if (o.deliveryDate == null) return 'Sin fecha de entrega';
  final d = parseDate(o.deliveryDate!);
  final diff = d.difference(today()).inDays;
  if (diff < 0) {
    final n = -diff;
    return 'Venció hace $n ${n == 1 ? 'día' : 'días'}';
  }
  if (diff == 0) return 'Hoy';
  if (diff == 1) return 'Mañana';
  return '${_daysShort[d.weekday - 1]}, ${d.day} ${_monthsShort[d.month - 1]}';
}

/// Traduce errores de Supabase/Postgres a mensajes entendibles.
String friendlyError(Object e) {
  if (e is AuthException) {
    final m = e.message.toLowerCase();
    if (m.contains('invalid login')) return 'Correo o contraseña incorrectos.';
    return e.message;
  }
  var msg = e is PostgrestException ? e.message : e.toString();
  final lower = msg.toLowerCase();
  if (e is PostgrestException && (e.code == 'PGRST106' || lower.contains('invalid schema'))) {
    return 'El schema z_conf no está expuesto en Supabase. Actívalo en '
        'Project Settings → Data API → Exposed schemas y guarda.';
  }
  if (e is PostgrestException && e.code == '42501' && lower.contains('schema')) {
    return 'Falta el permiso sobre el schema z_conf. Ejecuta de nuevo los GRANT del script de RLS '
        '(GRANT USAGE ON SCHEMA z_conf TO authenticated ...).';
  }
  if (e is PostgrestException && (e.code == 'PGRST116' || lower.contains('no rows'))) {
    return 'No se encontró tu perfil. Verifica que tu usuario tenga una fila en z_conf.profile.';
  }
  if (lower.contains('email not confirmed')) {
    return 'El correo aún no está confirmado en Supabase (Authentication → Users).';
  }
  if (lower.contains('chk_delivery_date_not_past')) {
    return 'La fecha de entrega no puede ser anterior a hoy.';
  }
  if (lower.contains('client_phone_key') || lower.contains('duplicate key')) {
    return 'Ya existe un registro con ese dato (por ejemplo, el mismo teléfono o nombre).';
  }
  if (lower.contains('row-level security') || lower.contains('permission denied')) {
    return 'No tienes permiso para realizar esta acción.';
  }
  if (lower.contains('foreign key')) {
    return 'No se puede eliminar porque tiene información relacionada.';
  }
  if (lower.contains('socketexception') || lower.contains('failed host lookup')) {
    return 'Sin conexión. Revisa tu internet e inténtalo de nuevo.';
  }
  msg = msg.replaceFirst('Exception: ', '');
  return msg;
}
