import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/models.dart';

typedef Json = Map<String, dynamic>;

/// Acceso a datos. El schema `z_conf` ya viene configurado en
/// `Supabase.initialize(postgrestOptions: ...)`, así que aquí solo se usan
/// los nombres de tabla. El RLS de la base decide qué puede hacer cada rol.
class Repo {
  final SupabaseClient db;
  Repo(this.db);

  List<Json> _rows(dynamic data) => (data as List).cast<Json>();

  // ---- Perfil ----
  Future<AppProfile> currentProfile() async {
    final user = db.auth.currentUser;
    if (user == null) throw Exception('No hay sesión activa');
    final data = await db
        .from('profile')
        .select('user_id, full_name, active, avatar_path, role:role_id(name)')
        .eq('user_id', user.id)
        .single();
    return AppProfile(
      userId: data['user_id'] as String,
      fullName: data['full_name'] as String,
      role: (data['role'] as Map)['name'] as String,
      active: (data['active'] as bool?) ?? true,
      avatarPath: data['avatar_path'] as String?,
    );
  }

  // ---- Organizaciones ----
  Future<List<Organization>> organizations() async {
    final data = await db.from('organization').select().order('name');
    return _rows(data).map(Organization.fromJson).toList();
  }

  Future<Organization> createOrganization(String name) async {
    final data = await db.from('organization').insert({'name': name}).select().single();
    return Organization.fromJson(data);
  }

  Future<void> renameOrganization(int id, String name) async {
    await db.from('organization').update({'name': name}).eq('organization_id', id);
  }

  Future<void> deleteOrganization(int id) async {
    await db.from('organization').delete().eq('organization_id', id);
  }

  // ---- Dependencias ----
  Future<List<Department>> departments() async {
    final data = await db.from('department').select().order('name');
    return _rows(data).map(Department.fromJson).toList();
  }

  Future<Department> createDepartment(String name, int organizationId) async {
    final data = await db
        .from('department')
        .insert({'name': name, 'organization_id': organizationId})
        .select()
        .single();
    return Department.fromJson(data);
  }

  Future<void> renameDepartment(int id, String name) async {
    await db.from('department').update({'name': name}).eq('department_id', id);
  }

  Future<void> deleteDepartment(int id) async {
    await db.from('department').delete().eq('department_id', id);
  }

  // ---- Clientes ----
  Future<List<Client>> clients() async {
    final data = await db.from('client').select().order('first_name');
    return _rows(data).map(Client.fromJson).toList();
  }

  Future<Client> createClient(Json values) async {
    final data = await db.from('client').insert(values).select().single();
    return Client.fromJson(data);
  }

  Future<Client> updateClient(int id, Json values) async {
    final data =
        await db.from('client').update(values).eq('client_id', id).select().single();
    return Client.fromJson(data);
  }

  // ---- Medidas ----
  Future<List<Measurement>> measurements(int clientId) async {
    final data = await db
        .from('measurement')
        .select()
        .eq('client_id', clientId)
        .order('taken_at', ascending: false);
    return _rows(data).map(Measurement.fromJson).toList();
  }

  Future<void> createMeasurement(Json values) async {
    await db.from('measurement').insert(values);
  }

  // ---- Pedidos ----
  Future<List<GarmentOrder>> orders() async {
    final data = await db.from('garment_order').select().order('created_at', ascending: false);
    return _rows(data).map(GarmentOrder.fromJson).toList();
  }

  Future<void> createOrder(Json values) async {
    await db.from('garment_order').insert(values);
  }

  Future<void> updateOrder(int id, Json values) async {
    await db.from('garment_order').update(values).eq('garment_order_id', id);
  }

  Future<void> deleteOrder(int id) async {
    await db.from('garment_order').delete().eq('garment_order_id', id);
  }

  // ---- Abonos ----
  Future<List<Payment>> payments(int orderId) async {
    final data = await db
        .from('payment')
        .select()
        .eq('garment_order_id', orderId)
        .order('paid_at', ascending: false);
    return _rows(data).map(Payment.fromJson).toList();
  }

  Future<void> createPayment({required int orderId, required num amount, String? note}) async {
    await db.from('payment').insert({
      'garment_order_id': orderId,
      'amount': amount,
      'note': note,
    });
  }

  Future<void> deletePayment(int id) async {
    await db.from('payment').delete().eq('payment_id', id);
  }

  // ---- Usuarios (nombres de profile; el Admin los ve todos por RLS) ----
  Future<List<UserName>> userNames() async {
    final data = await db.from('profile').select('user_id, full_name');
    return _rows(data)
        .map((j) => UserName(j['user_id'] as String, j['full_name'] as String))
        .toList();
  }

  // ---- Auditoría (solo Admin por RLS) ----
  /// Una página de auditoría, paginada en el servidor (range + conteo exacto).
  /// - [operation]: 'INSERT' | 'UPDATE' | 'DELETE' (null = todas).
  /// - [userIds]: null = sin filtro de usuario; lista = solo esos usuarios.
  /// - [includeSystem]: incluye registros sin usuario (SQL Editor / sistema).
  Future<AuditPageResult> auditPage({
    required int page,
    int pageSize = 10,
    String? operation,
    List<String>? userIds,
    bool includeSystem = false,
  }) async {
    var q = db.from('audit_log').select();
    if (operation != null) q = q.eq('operation', operation);
    if (userIds != null) {
      if (userIds.isEmpty && !includeSystem) return const AuditPageResult([], 0);
      if (userIds.isEmpty) {
        q = q.isFilter('user_id', null);
      } else if (!includeSystem) {
        q = q.inFilter('user_id', userIds);
      } else {
        q = q.or('user_id.in.(${userIds.join(',')}),user_id.is.null');
      }
    }
    final from = page * pageSize;
    final res = await q
        .order('logged_at', ascending: false)
        .order('audit_log_id', ascending: false)
        .range(from, from + pageSize - 1)
        .count(CountOption.exact);
    final rows = (res.data as List).cast<Json>().map(AuditLog.fromJson).toList();
    return AuditPageResult(rows, res.count);
  }
}