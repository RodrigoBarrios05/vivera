import 'package:flutter_test/flutter_test.dart';

import 'package:vivera/core/utils/formatters.dart';

void main() {
  group('Money.parseCents', () {
    test('acepta formato mexicano con comas y punto decimal', () {
      expect(Money.parseCents('1,234.50'), 123450);
      expect(Money.parseCents(r'$1,234.50'), 123450);
      expect(Money.parseCents('12,345.00'), 1234500);
    });

    test('acepta coma como separador decimal', () {
      expect(Money.parseCents('1234,50'), 123450);
      expect(Money.parseCents('1234,5'), 123450);
    });

    test('acepta punto como separador decimal', () {
      expect(Money.parseCents('1234.50'), 123450);
      expect(Money.parseCents('1234.5'), 123450);
    });

    test('acepta valores enteros', () {
      expect(Money.parseCents('12'), 1200);
      expect(Money.parseCents('0'), 0);
    });

    test('rechaza valores vacíos, negativos o inválidos', () {
      expect(Money.parseCents(''), isNull);
      expect(Money.parseCents('   '), isNull);
      expect(Money.parseCents('-12'), isNull);
      expect(Money.parseCents('abc'), isNull);
    });
  });

  group('Quantity.parse', () {
    test('acepta punto y coma decimal', () {
      expect(Quantity.parse('1.5'), 1.5);
      expect(Quantity.parse('1,5'), 1.5);
      expect(Quantity.parse('0.25'), 0.25);
      expect(Quantity.parse('10'), 10);
    });

    test('rechaza valores inválidos o negativos', () {
      expect(Quantity.parse(''), isNull);
      expect(Quantity.parse('-2'), isNull);
      expect(Quantity.parse('abc'), isNull);
    });
  });

  group('etiquetas', () {
    test('traduce métodos de pago y movimientos', () {
      expect(paymentMethodLabel('efectivo'), 'Efectivo');
      expect(paymentMethodLabel('transferencia'), 'Transferencia');
      expect(movementTypeLabel('sale'), 'Venta');
      expect(movementTypeLabel('sale_cancel'), 'Anulación');
    });
  });
}
