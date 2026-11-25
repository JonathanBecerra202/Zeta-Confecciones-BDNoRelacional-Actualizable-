double? _d(dynamic v) => v == null ? null : (v as num).toDouble();

class Organization {
  final int id;
  final String name;
  const Organization({required this.id, required this.name});
  factory Organization.fromJson(Map<String, dynamic> j) =>
      Organization(id: j['organization_id'] as int, name: j['name'] as String);
}

class Department {
  final int id;
  final String name;
  final int organizationId;
  const Department({required this.id, required this.name, required this.organizationId});
  factory Department.fromJson(Map<String, dynamic> j) => Department(
        id: j['department_id'] as int,
        name: j['name'] as String,
        organizationId: j['organization_id'] as int,
      );
}

class Client {
  final int id;
  final String firstName;
  final String? middleName;
  final String lastName;
  final String? secondLastName;
  final String? phone;
  final bool active;
  final int? departmentId;

  const Client({
    required this.id,
    required this.firstName,
    this.middleName,
    required this.lastName,
    this.secondLastName,
    this.phone,
    required this.active,
    this.departmentId,
  });

  factory Client.fromJson(Map<String, dynamic> j) => Client(
        id: j['client_id'] as int,
        firstName: j['first_name'] as String,
        middleName: j['middle_name'] as String?,
        lastName: j['last_name'] as String,
        secondLastName: j['second_last_name'] as String?,
        phone: j['phone'] as String?,
        active: (j['active'] as bool?) ?? true,
        departmentId: j['department_id'] as int?,
      );

  String get fullName => [firstName, middleName, lastName, secondLastName]
      .where((p) => p != null && p.trim().isNotEmpty)
      .join(' ');
}

class MeasureField {
  final String key;
  final String label;
  final String short;
  const MeasureField(this.key, this.label, this.short);
}

/// Las 9 medidas de la tabla `measurement`.
const measureFields = <MeasureField>[
  MeasureField('back_width_ae', 'Ancho de espalda', 'Espalda'),
  MeasureField('bust_circumference_cb', 'Contorno de busto', 'Busto'),
  MeasureField('waist_circumference_cc', 'Contorno de cintura', 'Cintura'),
  MeasureField('hip_circumference_ck', 'Contorno de cadera', 'Cadera'),
  MeasureField('torso_length_lt', 'Largo de talle', 'Talle'),
  MeasureField('pants_length_lp', 'Largo de pantalón', 'Pantalón'),
  MeasureField('sleeve_length_lm', 'Largo de manga', 'Manga'),
  MeasureField('sleeve_circumference_cm', 'Contorno de manga', 'Cont. manga'),
  MeasureField('leg_circumference_cp', 'Contorno de pierna', 'Pierna'),
];

class Measurement {
  final int id;
  final int clientId;
  final Map<String, double?> values;
  final String? notes;
  final DateTime takenAt;

  const Measurement({
    required this.id,
    required this.clientId,
    required this.values,
    this.notes,
    required this.takenAt,
  });

  factory Measurement.fromJson(Map<String, dynamic> j) => Measurement(
        id: j['measurement_id'] as int,
        clientId: j['client_id'] as int,
        values: {for (final f in measureFields) f.key: _d(j[f.key])},
        notes: j['notes'] as String?,
        takenAt: DateTime.parse(j['taken_at'] as String).toLocal(),
      );
}

enum OrderStatus {
  pending('Pending', 'Pendiente'),
  inProgress('In_progress', 'En proceso'),
  delivered('Delivered', 'Entregado'),
  cancelled('Cancelled', 'Cancelado');

  final String db;
  final String label;
  const OrderStatus(this.db, this.label);

  static OrderStatus fromDb(String? v) =>
      OrderStatus.values.firstWhere((s) => s.db == v, orElse: () => OrderStatus.pending);
}

class GarmentOrder {
  final int id;
  final String description;
  final double totalPrice;
  final double amountPaid;
  final double? balanceDue;
  final OrderStatus status;
  final bool paid;
  final DateTime createdAt;
  final String? deliveryDate; // yyyy-mm-dd
  final String? notes;
  final int quantity;
  final double unitPrice;
  final bool embroidery;
  final int clientId;
  final int? measurementId;

  const GarmentOrder({
    required this.id,
    required this.description,
    required this.totalPrice,
    required this.amountPaid,
    this.balanceDue,
    required this.status,
    required this.paid,
    required this.createdAt,
    this.deliveryDate,
    this.notes,
    required this.quantity,
    required this.unitPrice,
    required this.embroidery,
    required this.clientId,
    this.measurementId,
  });

  factory GarmentOrder.fromJson(Map<String, dynamic> j) => GarmentOrder(
        id: j['garment_order_id'] as int,
        description: j['description'] as String,
        totalPrice: _d(j['total_price']) ?? 0,
        amountPaid: _d(j['amount_paid']) ?? 0,
        balanceDue: _d(j['balance_due']),
        status: OrderStatus.fromDb(j['status'] as String?),
        paid: j['payment_status'] == 'Paid',
        createdAt: DateTime.parse(j['created_at'] as String).toLocal(),
        deliveryDate: j['delivery_date'] as String?,
        notes: j['notes'] as String?,
        quantity: (j['quantity'] as int?) ?? 1,
        unitPrice: _d(j['unit_price']) ?? 0,
        embroidery: (j['embroidery'] as bool?) ?? false,
        clientId: j['client_id'] as int,
        measurementId: j['measurement_id'] as int?,
      );

  /// balance_due es NULL hasta el primer abono, por eso se calcula si falta.
  double get balance => balanceDue ?? (totalPrice - amountPaid);
  bool get hasBalance => balance > 0 && status != OrderStatus.cancelled;
}

class Payment {
  final int id;
  final double amount;
  final String? note;
  final DateTime paidAt;
  final int orderId;
  const Payment({
    required this.id,
    required this.amount,
    this.note,
    required this.paidAt,
    required this.orderId,
  });
  factory Payment.fromJson(Map<String, dynamic> j) => Payment(
        id: j['payment_id'] as int,
        amount: _d(j['amount']) ?? 0,
        note: j['note'] as String?,
        paidAt: DateTime.parse(j['paid_at'] as String).toLocal(),
        orderId: j['garment_order_id'] as int,
      );
}

class AuditLog {
  final int id;
  final String tableName;
  final String operation;
  final String? recordId;
  final Map<String, dynamic>? before;
  final Map<String, dynamic>? after;
  final String loggedAt;
  final String? userId;
  const AuditLog({
    required this.id,
    required this.tableName,
    required this.operation,
    this.recordId,
    this.before,
    this.after,
    required this.loggedAt,
    this.userId,
  });
  factory AuditLog.fromJson(Map<String, dynamic> j) => AuditLog(
        id: j['audit_log_id'] as int,
        tableName: j['table_name'] as String,
        operation: j['operation'] as String,
        recordId: j['record_id'] as String?,
        before: (j['data_before'] as Map?)?.cast<String, dynamic>(),
        after: (j['data_after'] as Map?)?.cast<String, dynamic>(),
        loggedAt: j['logged_at'] as String,
        userId: j['user_id'] as String?,
      );
}

class AppProfile {
  final String userId;
  final String fullName;
  final String role; // 'Admin' | 'Employee'
  final bool active;
  final String? avatarPath; // ruta en el bucket privado `avatars` (null = sin foto)
  const AppProfile({
    required this.userId,
    required this.fullName,
    required this.role,
    required this.active,
    this.avatarPath,
  });
  bool get isAdmin => role == 'Admin';
  String get roleLabel => isAdmin ? 'Admin' : 'Empleado';
}

/// Un usuario del sistema (id de auth + nombre del perfil).
class UserName {
  final String id;
  final String fullName;
  const UserName(this.id, this.fullName);
}

/// Una página de auditoría + el total de registros que cumplen los filtros.
class AuditPageResult {
  final List<AuditLog> rows;
  final int total;
  const AuditPageResult(this.rows, this.total);
}