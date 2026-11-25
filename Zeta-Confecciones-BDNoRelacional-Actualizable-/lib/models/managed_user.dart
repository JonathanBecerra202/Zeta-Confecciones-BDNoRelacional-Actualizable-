/// Usuario administrable, tal como lo devuelve la función SQL
/// `z_conf.admin_list_users` (la lista) o la Edge Function `admin-users`.
class ManagedUser {
  final String id;
  final String email;
  final String fullName;
  final String role; // 'Admin' | 'Employee'
  final bool active;
  final bool mustChangePassword;
  final DateTime? createdAt;

  /// Ruta de la foto en el bucket privado `avatars` (null = sin foto).
  final String? avatarPath;

  /// URL firmada temporal para mostrar la foto (la calcula el provider).
  final String? avatarUrl;
  const ManagedUser({
    required this.id,
    required this.email,
    required this.fullName,
    required this.role,
    required this.active,
    required this.mustChangePassword,
    this.createdAt,
    this.avatarPath,
    this.avatarUrl,
  });

  bool get isAdmin => role == 'Admin';
  String get roleLabel => isAdmin ? 'Administrador' : 'Empleado';

  ManagedUser withAvatarUrl(String? url) => ManagedUser(
        id: id,
        email: email,
        fullName: fullName,
        role: role,
        active: active,
        mustChangePassword: mustChangePassword,
        createdAt: createdAt,
        avatarPath: avatarPath,
        avatarUrl: url,
      );

  factory ManagedUser.fromJson(Map<String, dynamic> j) => ManagedUser(
        id: j['user_id'] as String,
        email: (j['email'] as String?) ?? '',
        fullName: (j['full_name'] as String?) ?? '',
        role: (j['role'] as String?) ?? 'Employee',
        active: (j['active'] as bool?) ?? true,
        mustChangePassword: (j['must_change_password'] as bool?) ?? false,
        createdAt: j['created_at'] == null ? null : DateTime.tryParse(j['created_at'] as String),
        avatarPath: j['avatar_path'] as String?,
      );
}

/// Una página de usuarios y el total de coincidencias (para paginar).
class ManagedUsersPage {
  final List<ManagedUser> users;
  final int total;
  const ManagedUsersPage({required this.users, required this.total});
}