import 'package:flutter_test/flutter_test.dart';
import 'package:zeta_confecciones_mobile/models/managed_user.dart';
import 'package:zeta_confecciones_mobile/models/models.dart';

void main() {
  group('GarmentOrder.fromJson', () {
    final base = {
      'garment_order_id': 7,
      'description': '2 batas',
      'total_price': 90000,
      'amount_paid': 40000,
      'balance_due': 50000,
      'status': 'In_progress',
      'paid': false,
      'created_at': '2026-11-25T14:35:55Z',
      'delivery_date': '2026-12-01',
      'notes': null,
      'quantity': 2,
      'unit_price': 45000,
      'embroidery': true,
      'client_id': 1,
      'measurement_id': 1,
    };

    test('lee paid, delivery_date y estado', () {
      final o = GarmentOrder.fromJson(base);
      expect(o.id, 7);
      expect(o.paid, isFalse);
      expect(o.deliveryDate, '2026-12-01');
      expect(o.status, OrderStatus.inProgress);
      expect(o.totalPrice, 90000.0);
      expect(o.balance, 50000.0);
      expect(o.hasBalance, isTrue);
    });

    test('paid true y sin saldo', () {
      final o = GarmentOrder.fromJson({...base, 'paid': true, 'amount_paid': 90000, 'balance_due': 0});
      expect(o.paid, isTrue);
      expect(o.balance, 0);
      expect(o.hasBalance, isFalse);
    });

    test('balance_due nulo se calcula', () {
      final o = GarmentOrder.fromJson({...base, 'balance_due': null, 'amount_paid': 10000});
      expect(o.balance, 80000.0);
    });

    test('pedido cancelado no tiene saldo por cobrar', () {
      final o = GarmentOrder.fromJson({...base, 'status': 'Cancelled'});
      expect(o.hasBalance, isFalse);
    });

    test('estado desconocido cae en pending', () {
      expect(OrderStatus.fromDb('xyz'), OrderStatus.pending);
    });
  });

  group('AuditLog.fromJson', () {
    test('mapea before/after', () {
      final a = AuditLog.fromJson({
        'audit_log_id': 3,
        'table_name': 'client',
        'operation': 'UPDATE',
        'record_id': '5',
        'before': {'first_name': 'Ana'},
        'after': {'first_name': 'Anita'},
        'logged_at': '2026-11-25T14:35:55+00:00',
        'user_id': 'abc',
      });
      expect(a.before, {'first_name': 'Ana'});
      expect(a.after, {'first_name': 'Anita'});
      expect(a.recordId, '5');
    });

    test('INSERT sin before', () {
      final a = AuditLog.fromJson({
        'audit_log_id': 1,
        'table_name': 'payment',
        'operation': 'INSERT',
        'before': null,
        'after': {'amount': 100},
        'logged_at': '2026-11-25T14:35:55+00:00',
      });
      expect(a.before, isNull);
      expect(a.after, {'amount': 100});
      expect(a.userId, isNull);
    });
  });

  group('Client / Organization / Department', () {
    test('Client.fullName ignora campos vacíos', () {
      final c = Client.fromJson({
        'client_id': 1,
        'first_name': 'María',
        'middle_name': null,
        'last_name': 'Ortiz',
        'second_last_name': '  ',
        'phone': '3001112233',
        'active': null,
        'department_id': 4,
      });
      expect(c.fullName, 'María Ortiz');
      expect(c.active, isTrue);
      expect(c.departmentId, 4);
    });

    test('Organization y Department', () {
      expect(Organization.fromJson({'organization_id': 2, 'name': 'UIS'}).name, 'UIS');
      final d = Department.fromJson({'department_id': 3, 'name': 'Urgencias', 'organization_id': 5});
      expect(d.organizationId, 5);
    });
  });

  group('Measurement / Payment', () {
    test('Measurement lee las 9 medidas', () {
      final m = Measurement.fromJson({
        'measurement_id': 1,
        'client_id': 2,
        'back_width_ae': 37,
        'bust_circumference_cb': 94.5,
        'notes': 'ok',
        'taken_at': '2026-11-25T14:35:55Z',
      });
      expect(m.values.length, measureFields.length);
      expect(m.values['back_width_ae'], 37.0);
      expect(m.values['bust_circumference_cb'], 94.5);
      expect(m.values['waist_circumference_cc'], isNull);
    });

    test('Payment.fromJson', () {
      final p = Payment.fromJson({
        'payment_id': 9,
        'amount': 40000,
        'note': 'Adelanto',
        'paid_at': '2026-11-25T14:35:55Z',
        'garment_order_id': 1,
      });
      expect(p.amount, 40000.0);
      expect(p.orderId, 1);
    });
  });

  group('ManagedUser', () {
    test('fromJson con valores por defecto', () {
      final u = ManagedUser.fromJson({'user_id': 'u1', 'full_name': 'Ana', 'role': 'Admin'});
      expect(u.email, '');
      expect(u.active, isTrue);
      expect(u.mustChangePassword, isFalse);
      expect(u.isAdmin, isTrue);
      expect(u.roleLabel, 'Administrador');
    });

    test('withAvatarUrl conserva los datos', () {
      final u = ManagedUser.fromJson({
        'user_id': 'u1',
        'email': 'a@b.com',
        'full_name': 'Ana',
        'role': 'Employee',
        'avatar_path': '/static/avatars/u1/avatar.jpg',
      }).withAvatarUrl('http://x/static/avatars/u1/avatar.jpg');
      expect(u.avatarUrl, 'http://x/static/avatars/u1/avatar.jpg');
      expect(u.avatarPath, '/static/avatars/u1/avatar.jpg');
      expect(u.isAdmin, isFalse);
    });
  });
}
