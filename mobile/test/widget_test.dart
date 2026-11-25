import 'package:flutter_test/flutter_test.dart';
import 'package:zeta_confecciones_mobile/core/format.dart';

void main() {
  test('money formats with thousands separators', () {
    expect(money(1234567), '\$1.234.567');
    expect(money(0), '\$0');
  });

  test('search ignores accents and case', () {
    expect(matchesSearch('María Fernanda Ortiz', 'maria ort'), isTrue);
    expect(matchesSearch('Carlos Rueda', 'zzz'), isFalse);
  });
}
