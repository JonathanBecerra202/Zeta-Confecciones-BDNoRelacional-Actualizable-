import 'dart:async';

import '../core/api_client.dart';

/// La contraseña actual escrita no coincide con la de la cuenta.
class WrongCurrentPasswordException implements Exception {
  const WrongCurrentPasswordException();
  @override
  String toString() => 'La contraseña actual no es correcta.';
}

/// Autenticación contra la API FastAPI (JWT + bcrypt).
class AuthService {
  final ApiClient _api;
  AuthService(this._api);

  String? _userId;
  String? _email;
  bool _mustChangePassword = false;
  final _mustChangeController = StreamController<bool>.broadcast();

  String? get currentUserId => _userId;
  String? get currentEmail => _email;
  bool get mustChangePassword => _mustChangePassword;

  Stream<bool> watchMustChangePassword() async* {
    yield _mustChangePassword;
    yield* _mustChangeController.stream;
  }

  /// Restaura sesión si hay un JWT guardado; devuelve `user_id` o `null`.
  Future<String?> restoreSession() async {
    if (_api.token == null || _api.token!.isEmpty) {
      _clearLocal();
      return null;
    }
    try {
      final data = await _api.get('/auth/me') as Map<String, dynamic>;
      _applyUser(data);
      return _userId;
    } on ApiException catch (e) {
      if (e.statusCode == 401 || e.statusCode == 403) {
        await _api.setToken(null);
        _clearLocal();
        return null;
      }
      rethrow;
    }
  }

  Future<void> signIn({required String email, required String password}) async {
    final data = await _api.post(
      '/auth/login',
      body: {'email': email.trim(), 'password': password},
    ) as Map<String, dynamic>;

    final user = data['user'] as Map<String, dynamic>;
    _applyUser(user);
    await _api.setToken(data['access_token'] as String);
  }

  Future<void> signOut() async {
    _clearLocal();
    await _api.setToken(null);
  }

  /// Cambio voluntario (Más → Cambiar contraseña).
  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    try {
      await _api.post(
        '/auth/change-password',
        body: {'current_password': currentPassword, 'new_password': newPassword},
      );
      _mustChangePassword = false;
      _mustChangeController.add(false);
    } on ApiException catch (e) {
      if (e.statusCode == 400) {
        throw const WrongCurrentPasswordException();
      }
      rethrow;
    }
  }

  /// Cambio obligatorio tras recibir una contraseña temporal.
  Future<void> completeTemporaryPasswordChange(String newPassword) async {
    await _api.post(
      '/auth/change-password',
      body: {'new_password': newPassword},
    );
    _mustChangePassword = false;
    _mustChangeController.add(false);
  }

  void _applyUser(Map<String, dynamic> user) {
    _userId = user['user_id'] as String;
    _email = user['email'] as String?;
    _mustChangePassword = (user['must_change_password'] as bool?) ?? false;
    _mustChangeController.add(_mustChangePassword);
  }

  void _clearLocal() {
    _userId = null;
    _email = null;
    _mustChangePassword = false;
    _mustChangeController.add(false);
  }
}
