import '../core/api_client.dart';
import '../models/models.dart';

typedef Json = Map<String, dynamic>;

/// Acceso a datos a través de la API REST de FastAPI.
class Repo {
  final ApiClient api;
  Repo(this.api);

  List<Json> _rows(dynamic data) => (data as List).cast<Json>();

  // ---- Perfil ----
  Future<AppProfile> currentProfile() async {
    final data = await api.get('/auth/me') as Json;
    return AppProfile(
      userId: data['user_id'] as String,
      fullName: data['full_name'] as String,
      role: data['role'] as String,
      active: (data['active'] as bool?) ?? true,
      avatarPath: data['avatar_path'] as String?,
    );
  }

  // ---- Organizaciones ----
  Future<List<Organization>> organizations() async {
    final data = await api.get('/organizations');
    return _rows(data).map(Organization.fromJson).toList();
  }

  Future<Organization> createOrganization(String name) async {
    final data = await api.post('/organizations', body: {'name': name}) as Json;
    return Organization.fromJson(data);
  }

  Future<void> renameOrganization(int id, String name) async {
    await api.patch('/organizations/$id', body: {'name': name});
  }

  Future<void> deleteOrganization(int id) async {
    await api.delete('/organizations/$id');
  }

  // ---- Dependencias ----
  Future<List<Department>> departments() async {
    final data = await api.get('/departments');
    return _rows(data).map(Department.fromJson).toList();
  }

  Future<Department> createDepartment(String name, int organizationId) async {
    final data = await api.post(
      '/departments',
      body: {'name': name, 'organization_id': organizationId},
    ) as Json;
    return Department.fromJson(data);
  }

  Future<void> renameDepartment(int id, String name) async {
    await api.patch('/departments/$id', body: {'name': name});
  }

  Future<void> deleteDepartment(int id) async {
    await api.delete('/departments/$id');
  }

  // ---- Clientes ----
  Future<List<Client>> clients() async {
    final data = await api.get('/clients');
    return _rows(data).map(Client.fromJson).toList();
  }

  Future<Client> createClient(Json values) async {
    final data = await api.post('/clients', body: values) as Json;
    return Client.fromJson(data);
  }

  Future<Client> updateClient(int id, Json values) async {
    final data = await api.patch('/clients/$id', body: values) as Json;
    return Client.fromJson(data);
  }

  // ---- Medidas ----
  Future<List<Measurement>> measurements(int clientId) async {
    final data = await api.get('/clients/$clientId/measurements');
    return _rows(data).map(Measurement.fromJson).toList();
  }

  Future<void> createMeasurement(Json values) async {
    final clientId = values['client_id'] as int;
    final body = Map<String, dynamic>.from(values)..remove('client_id');
    await api.post('/clients/$clientId/measurements', body: body);
  }

  // ---- Pedidos ----
  Future<List<GarmentOrder>> orders() async {
    final data = await api.get('/orders');
    return _rows(data).map(GarmentOrder.fromJson).toList();
  }

  Future<void> createOrder(Json values) async {
    await api.post('/orders', body: values);
  }

  Future<void> updateOrder(int id, Json values) async {
    await api.patch('/orders/$id', body: values);
  }

  Future<void> deleteOrder(int id) async {
    await api.delete('/orders/$id');
  }

  // ---- Abonos ----
  Future<List<Payment>> payments(int orderId) async {
    final data = await api.get('/orders/$orderId/payments');
    return _rows(data).map(Payment.fromJson).toList();
  }

  Future<void> createPayment({required int orderId, required num amount, String? note}) async {
    await api.post(
      '/orders/$orderId/payments',
      body: {'amount': amount, 'note': note},
    );
  }

  Future<void> deletePayment(int id) async {
    await api.delete('/payments/$id');
  }

  // ---- Usuarios ----
  Future<List<UserName>> userNames() async {
    final data = await api.get('/users/names');
    return _rows(data)
        .map((j) => UserName(j['user_id'] as String, j['full_name'] as String))
        .toList();
  }

  // ---- Auditoría ----
  Future<AuditPageResult> auditPage({
    required int page,
    int pageSize = 10,
    String? operation,
    List<String>? userIds,
    bool includeSystem = false,
  }) async {
    if (userIds != null && userIds.isEmpty && !includeSystem) {
      return const AuditPageResult([], 0);
    }
    final data = await api.get(
      '/audit',
      query: {
        'page': page,
        'page_size': pageSize,
        if (operation != null) 'operation': operation,
        if (userIds != null) 'user_ids': userIds,
        'include_system': includeSystem,
      },
    ) as Json;

    final rows = _rows(data['rows']).map(AuditLog.fromJson).toList();
    final total = (data['total'] as num).toInt();
    return AuditPageResult(rows, total);
  }
}
