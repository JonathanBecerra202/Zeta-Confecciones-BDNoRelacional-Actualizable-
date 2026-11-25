import '../core/api_client.dart';
import '../models/managed_user.dart';

/// Gestión de usuarios (solo administradores) contra `/admin/users`.
class UserAdminService {
  final ApiClient _api;
  UserAdminService(this._api);

  Future<ManagedUsersPage> listUsers({
    String search = '',
    String? role,
    bool includeInactive = false,
    int page = 0,
    int pageSize = 10,
  }) async {
    final data = await _api.get(
      '/admin/users',
      query: {
        'search': search.trim(),
        if (role != null) 'role': role,
        'include_inactive': includeInactive,
        'page': page,
        'page_size': pageSize,
      },
    ) as Map<String, dynamic>;

    final rows = (data['users'] as List).cast<Map<String, dynamic>>();
    final total = (data['total'] as num).toInt();
    return ManagedUsersPage(
      users: rows.map(ManagedUser.fromJson).toList(),
      total: total,
    );
  }

  /// Crea la cuenta y devuelve el id del usuario nuevo (se usa para su foto).
  Future<String> createUser({
    required String email,
    required String password,
    required String fullName,
    required String role,
  }) async {
    final data = await _api.post(
      '/admin/users',
      body: {
        'email': email,
        'password': password,
        'full_name': fullName,
        'role': role,
      },
    ) as Map<String, dynamic>;
    return data['user_id'] as String;
  }

  Future<void> updateUser(
    String userId, {
    String? fullName,
    String? role,
    bool? active,
  }) async {
    await _api.patch(
      '/admin/users/$userId',
      body: {
        if (fullName != null) 'full_name': fullName,
        if (role != null) 'role': role,
        if (active != null) 'active': active,
      },
    );
  }

  Future<void> setPassword(String userId, String password) async {
    await _api.post(
      '/admin/users/$userId/password',
      body: {'password': password},
    );
  }
}
