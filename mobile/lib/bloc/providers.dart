import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/format.dart';
import '../models/managed_user.dart';
import '../models/models.dart';
import '../repositories/repo.dart';
import '../services/auth_service.dart';
import '../services/avatar_service.dart';
import '../services/user_admin_service.dart';

final supabaseProvider = Provider<SupabaseClient>((ref) => Supabase.instance.client);

final repoProvider = Provider<Repo>((ref) => Repo(ref.watch(supabaseProvider)));

final authServiceProvider = Provider<AuthService>((ref) => AuthService(ref.watch(supabaseProvider)));

/// true mientras la cuenta tenga una contraseña temporal pendiente de cambiar.
/// Se deduce de la sesión de Supabase (app_metadata), no de un valor local.
final mustChangePasswordProvider = StreamProvider.autoDispose<bool>((ref) {
  ref.watch(userIdProvider);
  return ref.watch(authServiceProvider).watchMustChangePassword();
});

final userAdminServiceProvider =
    Provider<UserAdminService>((ref) => UserAdminService(ref.watch(supabaseProvider)));

final avatarServiceProvider =
    Provider<AvatarService>((ref) => AvatarService(ref.watch(supabaseProvider)));

/// Consulta de la lista de usuarios: página + búsqueda + filtros.
/// Tiene == para que Riverpod reutilice el resultado cuando no cambia nada.
class UsersQuery {
  final int page;
  final int pageSize;
  final String search;
  final String? role; // null = todos | 'Admin' | 'Employee'
  final bool includeInactive;
  const UsersQuery({
    required this.page,
    this.pageSize = 10,
    this.search = '',
    this.role,
    this.includeInactive = false,
  });

  @override
  bool operator ==(Object other) =>
      other is UsersQuery &&
      other.page == page &&
      other.pageSize == pageSize &&
      other.search == search &&
      other.role == role &&
      other.includeInactive == includeInactive;

  @override
  int get hashCode => Object.hash(page, pageSize, search, role, includeInactive);
}

/// Una página de usuarios con correo, rol y estado (solo Admin; la verificación
/// ocurre en la función SQL `z_conf.admin_list_users`).
final managedUsersProvider =
    FutureProvider.autoDispose.family<ManagedUsersPage, UsersQuery>((ref, q) async {
  ref.watch(userIdProvider);
  final users = ref.watch(userAdminServiceProvider);
  final avatars = ref.watch(avatarServiceProvider);
  final page = await users.listUsers(
    search: q.search,
    role: q.role,
    includeInactive: q.includeInactive,
    page: q.page,
    pageSize: q.pageSize,
  );
  // Fotos: una sola llamada para firmar las URLs de toda la página. Si falla,
  // la lista se muestra igual, con iniciales en lugar de foto.
  final paths = [for (final u in page.users) if (u.avatarPath != null) u.avatarPath!];
  var urls = const <String, String>{};
  try {
    urls = await avatars.signedUrls(paths);
  } catch (_) {}
  return ManagedUsersPage(
    users: [for (final u in page.users) u.avatarPath == null ? u : u.withAvatarUrl(urls[u.avatarPath])],
    total: page.total,
  );
});

/// URL firmada de la foto del usuario con sesión (tarjeta de «Más»).
/// Si la foto cambia sin cambiar la ruta, hay que invalidar este provider.
final myAvatarUrlProvider = FutureProvider.autoDispose<String?>((ref) async {
  final path = ref.watch(profileProvider.select((p) => p.valueOrNull?.avatarPath));
  if (path == null) return null;
  final urls = await ref.watch(avatarServiceProvider).signedUrls([path]);
  return urls[path];
});

/// Emite el id del usuario con sesión (o null). Solo cambia al entrar/salir.
final authStateProvider = StreamProvider<String?>((ref) async* {
  final auth = ref.watch(supabaseProvider).auth;
  yield auth.currentSession?.user.id;
  await for (final state in auth.onAuthStateChange) {
    yield state.session?.user.id;
  }
});

final userIdProvider = Provider<String?>((ref) => ref.watch(authStateProvider).valueOrNull);

final profileProvider = FutureProvider.autoDispose<AppProfile>((ref) {
  ref.watch(userIdProvider);
  return ref.watch(repoProvider).currentProfile();
});

final isAdminProvider =
    Provider.autoDispose<bool>((ref) => ref.watch(profileProvider).valueOrNull?.isAdmin ?? false);

final clientsProvider = FutureProvider.autoDispose<List<Client>>((ref) {
  ref.watch(userIdProvider);
  return ref.watch(repoProvider).clients();
});

final ordersProvider = FutureProvider.autoDispose<List<GarmentOrder>>((ref) {
  ref.watch(userIdProvider);
  return ref.watch(repoProvider).orders();
});

final organizationsProvider = FutureProvider.autoDispose<List<Organization>>((ref) {
  ref.watch(userIdProvider);
  return ref.watch(repoProvider).organizations();
});

final departmentsProvider = FutureProvider.autoDispose<List<Department>>((ref) {
  ref.watch(userIdProvider);
  return ref.watch(repoProvider).departments();
});

final measurementsProvider =
    FutureProvider.autoDispose.family<List<Measurement>, int>((ref, clientId) {
  return ref.watch(repoProvider).measurements(clientId);
});

final paymentsProvider = FutureProvider.autoDispose.family<List<Payment>, int>((ref, orderId) {
  return ref.watch(repoProvider).payments(orderId);
});

final userNamesProvider = FutureProvider.autoDispose<List<UserName>>((ref) {
  return ref.watch(repoProvider).userNames();
});

/// Consulta de auditoría: página + filtros. Tiene == para que Riverpod
/// reutilice el resultado cuando no cambia nada.
class AuditQuery {
  final int page;
  final String? operation;
  final String userQuery;
  const AuditQuery({required this.page, this.operation, this.userQuery = ''});

  @override
  bool operator ==(Object other) =>
      other is AuditQuery &&
      other.page == page &&
      other.operation == operation &&
      other.userQuery == userQuery;

  @override
  int get hashCode => Object.hash(page, operation, userQuery);
}

final auditPageProvider =
    FutureProvider.autoDispose.family<AuditPageResult, AuditQuery>((ref, q) async {
  final repo = ref.watch(repoProvider);
  List<String>? ids;
  var includeSystem = false;
  final text = q.userQuery.trim();
  // Se obtiene antes de cualquier await (buena práctica con ref.watch).
  final usersFuture = text.isEmpty ? null : ref.watch(userNamesProvider.future);
  if (usersFuture != null) {
    // La auditoría solo guarda el id del usuario: se busca por nombre en
    // profile.full_name y se filtra por esos ids. "Sistema / SQL" = sin usuario.
    final users = await usersFuture;
    ids = users.where((u) => matchesSearch(u.fullName, text)).map((u) => u.id).toList();
    includeSystem = matchesSearch('Sistema SQL', text);
  }
  return repo.auditPage(
    page: q.page,
    operation: q.operation,
    userIds: ids,
    includeSystem: includeSystem,
  );
});

/// Mapa id -> cliente para mostrar nombres en las listas de pedidos.
final clientMapProvider = Provider.autoDispose<Map<int, Client>>((ref) {
  final list = ref.watch(clientsProvider).valueOrNull ?? const <Client>[];
  return {for (final c in list) c.id: c};
});

// ---- Estado de navegación ----
enum OrderFilter {
  todos('Todos'),
  pendiente('Pendiente'),
  enProceso('En proceso'),
  entregado('Entregado'),
  cancelado('Cancelado'),
  saldo('Saldo pendiente');

  final String label;
  const OrderFilter(this.label);
}

final tabProvider = StateProvider<int>((ref) => 0);
final orderFilterProvider = StateProvider<OrderFilter>((ref) => OrderFilter.todos);