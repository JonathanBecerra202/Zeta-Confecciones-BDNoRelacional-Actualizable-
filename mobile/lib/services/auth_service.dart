import 'package:supabase_flutter/supabase_flutter.dart';

/// La contraseña actual escrita no coincide con la de la cuenta.
class WrongCurrentPasswordException implements Exception {
  const WrongCurrentPasswordException();
  @override
  String toString() => 'La contraseña actual no es correcta.';
}

/// Autenticación con Supabase Auth: inicio y cierre de sesión y cambio de
/// contraseña. Las pantallas no llaman a `supabase.auth` directamente.
class AuthService {
  final SupabaseClient _db;
  AuthService(this._db);

  User? get currentUser => _db.auth.currentUser;
  String? get currentEmail => currentUser?.email;

  /// true si el administrador dejó una contraseña temporal que el usuario
  /// todavía debe reemplazar.
  ///
  /// La marca vive en `app_metadata` de la cuenta de Supabase Auth: se guarda
  /// en el servidor, viaja en la sesión y el usuario NO puede modificarla desde
  /// la app (solo la Edge Function con la clave de servicio). Por eso persiste
  /// aunque se cierre la app o se vuelva a iniciar sesión.
  bool get mustChangePassword => currentUser?.appMetadata['must_change_password'] == true;

  /// Emite el valor actual y se actualiza con cada cambio de sesión.
  Stream<bool> watchMustChangePassword() async* {
    yield mustChangePassword;
    await for (final _ in _db.auth.onAuthStateChange) {
      yield mustChangePassword;
    }
  }

  Future<void> signIn({required String email, required String password}) async {
    await _db.auth.signInWithPassword(email: email, password: password);
  }

  Future<void> signOut() => _db.auth.signOut();

  /// Cambio voluntario (Más → Cambiar contraseña). Comprueba primero la
  /// contraseña actual.
  Future<void> changePassword({required String currentPassword, required String newPassword}) async {
    final email = currentEmail;
    if (email == null) throw Exception('No hay sesión activa.');
    try {
      await _db.auth.signInWithPassword(email: email, password: currentPassword);
    } on AuthException {
      throw const WrongCurrentPasswordException();
    }
    await _db.auth.updateUser(UserAttributes(password: newPassword));
  }

  /// Cambio obligatorio tras recibir una contraseña temporal.
  /// Lo hace la Edge Function: cambia la contraseña y borra la marca en el
  /// servidor en un solo paso (el usuario no puede borrar la marca por su cuenta).
  Future<void> completeTemporaryPasswordChange(String newPassword) async {
    final email = currentEmail;
    if (email == null) throw Exception('No hay sesión activa.');
    try {
      final res = await _db.functions.invoke(
        'admin-users',
        body: {'action': 'change_own_password', 'password': newPassword},
      );
      final data = res.data;
      if (data is Map && data['error'] != null) throw Exception(data['error'].toString());
    } on FunctionException catch (e) {
      final d = e.details;
      if (d is Map && d['error'] != null) throw Exception(d['error'].toString());
      if (e.status == 404) {
        throw Exception('La función admin-users aún no está desplegada en Supabase.');
      }
      throw Exception('Error del servidor (${e.status}).');
    }

    // Renueva la sesión para que traiga la marca ya borrada. Si el servidor
    // invalidó el token anterior, se vuelve a entrar con la contraseña nueva.
    try {
      await _db.auth.refreshSession();
    } on AuthException {
      await _db.auth.signInWithPassword(email: email, password: newPassword);
    }
    if (mustChangePassword) {
      await _db.auth.signInWithPassword(email: email, password: newPassword);
    }
  }
}