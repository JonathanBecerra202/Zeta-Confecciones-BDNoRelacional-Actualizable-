import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/managed_user.dart';

/// Gestión de usuarios (solo administradores).
///
/// La lista se consulta con una función SQL (`admin_list_users`). Crear cuentas
/// de Supabase Auth exige la clave `service_role`, que no puede ir en la app:
/// por eso crear, editar y restablecer pasan por la Edge Function
/// `admin-users`, que vuelve a verificar en el servidor que quien llama es un
/// Admin activo.
class UserAdminService {
  final SupabaseClient _db;
  UserAdminService(this._db);

  Future<dynamic> _call(Map<String, dynamic> body) async {
    try {
      final res = await _db.functions.invoke('admin-users', body: body);
      final data = res.data;
      if (data is Map && data['error'] != null) throw Exception(data['error'].toString());
      return data;
    } on FunctionException catch (e) {
      final d = e.details;
      if (d is Map && d['error'] != null) throw Exception(d['error'].toString());
      if (e.status == 404) {
        throw Exception('La función admin-users aún no está desplegada en Supabase.');
      }
      throw Exception('Error del servidor (${e.status}).');
    }
  }

  /// Una página de usuarios con búsqueda y filtros. La búsqueda, el filtro y la
  /// paginación se resuelven en la base de datos (función `admin_list_users`),
  /// que además verifica en el servidor que quien llama es un Admin activo.
  Future<ManagedUsersPage> listUsers({
    String search = '',
    String? role,
    bool includeInactive = false,
    int page = 0,
    int pageSize = 10,
  }) async {
    final data = await _db.rpc('admin_list_users', params: {
      'p_search': search.trim(),
      'p_role': role,
      'p_include_inactive': includeInactive,
      'p_page': page,
      'p_page_size': pageSize,
    });
    final rows = (data as List).cast<Map<String, dynamic>>();
    final total = rows.isEmpty ? 0 : (rows.first['total_count'] as num).toInt();
    return ManagedUsersPage(users: rows.map(ManagedUser.fromJson).toList(), total: total);
  }

  /// Crea la cuenta y devuelve el id del usuario nuevo (se usa para su foto).
  Future<String> createUser({
    required String email,
    required String password,
    required String fullName,
    required String role,
  }) async {
    final data = await _call({
      'action': 'create',
      'email': email,
      'password': password,
      'full_name': fullName,
      'role': role,
    });
    return (data as Map)['user_id'] as String;
  }

  Future<void> updateUser(String userId, {String? fullName, String? role, bool? active}) async {
    await _call({
      'action': 'update',
      'user_id': userId,
      if (fullName != null) 'full_name': fullName,
      if (role != null) 'role': role,
      if (active != null) 'active': active,
    });
  }

  Future<void> setPassword(String userId, String password) async {
    await _call({'action': 'set_password', 'user_id': userId, 'password': password});
  }
}