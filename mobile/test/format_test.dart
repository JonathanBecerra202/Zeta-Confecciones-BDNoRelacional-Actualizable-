import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zeta_confecciones_mobile/core/api_client.dart';
import 'package:zeta_confecciones_mobile/core/format.dart';
import 'package:zeta_confecciones_mobile/models/models.dart';

GarmentOrder _order({String? delivery, OrderStatus status = OrderStatus.pending}) => GarmentOrder(
      id: 1,
      description: 'x',
      totalPrice: 100,
      amountPaid: 0,
      status: status,
      paid: false,
      createdAt: DateTime(2026, 1, 1),
      deliveryDate: delivery,
      quantity: 1,
      unitPrice: 100,
      embroidery: false,
      clientId: 1,
    );

void main() {
  group('dinero', () {
    test('money', () {
      expect(money(1234567), '\$1.234.567');
      expect(money(-5000), '-\$5.000');
      expect(money(0), '\$0');
    });

    test('parseMoney y moneyField', () {
      expect(parseMoney('1.234.567'), 1234567);
      expect(parseMoney('abc'), isNull);
      expect(moneyField(45000), '45.000');
    });

    test('MoneyInputFormatter agrupa miles', () {
      final f = MoneyInputFormatter();
      final r = f.formatEditUpdate(TextEditingValue.empty, const TextEditingValue(text: '1234567'));
      expect(r.text, '1.234.567');
      expect(f.formatEditUpdate(TextEditingValue.empty, const TextEditingValue(text: 'a')).text, '');
    });
  });

  group('texto', () {
    test('normalizeText quita acentos', () {
      expect(normalizeText('María Ñandú'), 'maria nandu');
    });

    test('matchesSearch', () {
      expect(matchesSearch('María Fernanda Ortiz', 'maria ort'), isTrue);
      expect(matchesSearch('Carlos Rueda', 'zzz'), isFalse);
      expect(matchesSearch('Carlos', '   '), isTrue);
    });

    test('initials', () {
      expect(initials('ana maria perez'), 'AM');
      expect(initials('  '), '?');
    });
  });

  group('fechas', () {
    test('parseDate / isoDate', () {
      final d = parseDate('2026-12-01');
      expect(d, DateTime(2026, 12, 1));
      expect(isoDate(d), '2026-12-01');
    });

    test('dueLabel', () {
      final t = today();
      expect(dueLabel(_order(delivery: isoDate(t))), 'Hoy');
      expect(dueLabel(_order(delivery: isoDate(t.add(const Duration(days: 1))))), 'Mañana');
      expect(dueLabel(_order(delivery: isoDate(t.subtract(const Duration(days: 1))))), 'Venció hace 1 día');
      expect(dueLabel(_order(delivery: isoDate(t.subtract(const Duration(days: 3))))), 'Venció hace 3 días');
      expect(dueLabel(_order()), 'Sin fecha de entrega');
      expect(dueLabel(_order(status: OrderStatus.delivered)), 'Entregado');
      expect(dueLabel(_order(status: OrderStatus.cancelled)), 'Cancelado');
    });

    test('isOverdue', () {
      final t = today();
      expect(isOverdue(_order(delivery: isoDate(t.subtract(const Duration(days: 2))))), isTrue);
      expect(isOverdue(_order(delivery: isoDate(t.add(const Duration(days: 2))))), isFalse);
      expect(isOverdue(_order(delivery: '2020-01-01', status: OrderStatus.delivered)), isFalse);
    });
  });

  group('friendlyError', () {
    test('ApiException conserva el mensaje', () {
      expect(friendlyError(const ApiException(400, 'Dato inválido')), 'Dato inválido');
    });

    test('errores de red', () {
      expect(friendlyError(Exception('SocketException: Failed host lookup')),
          contains('Sin conexión'));
    });

    test('fecha pasada y duplicados', () {
      expect(friendlyError(Exception('chk_delivery_date_not_past')), contains('anterior a hoy'));
      expect(friendlyError(Exception('duplicate key')), contains('Ya existe'));
    });

    test('quita el prefijo Exception', () {
      expect(friendlyError(Exception('algo')), 'algo');
    });
  });
}
