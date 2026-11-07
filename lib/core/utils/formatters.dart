import 'package:intl/intl.dart';

class Money {
  const Money._();

  static const Map<String, String> _symbols = {
    'MXN': r'$',
    'USD': r'$',
    'ARS': r'$',
    'UYU': r'$',
    'CLP': r'$',
    'COP': r'$',
    'PEN': r'S/',
    'PYG': r'₲',
    'BOB': 'Bs',
    'EUR': '€',
  };

  static String symbolFor(String currencyCode) {
    return _symbols[currencyCode.toUpperCase()] ?? currencyCode;
  }

  static String format(
    int cents, {
    String currencyCode = 'MXN',
    String locale = 'es_MX',
  }) {
    final formatter = NumberFormat.currency(
      locale: locale,
      symbol: symbolFor(currencyCode),
      decimalDigits: 2,
    );
    return formatter.format(cents / 100);
  }

  /// Convierte texto escrito por el usuario a centavos.
  /// Acepta "$1,234.50", "1234,50" y "1234.5".
  static int? parseCents(String input) {
    final cleaned = input.replaceAll(RegExp(r'[^\d,.\-]'), '').trim();
    if (cleaned.isEmpty || cleaned == '-' || cleaned == '.' || cleaned == ',') {
      return null;
    }

    var normalized = cleaned;
    final lastComma = cleaned.lastIndexOf(',');
    final lastDot = cleaned.lastIndexOf('.');

    if (lastComma >= 0 && lastDot >= 0) {
      final decimalSeparator = lastComma > lastDot ? ',' : '.';
      final thousandsSeparator = decimalSeparator == ',' ? '.' : ',';
      normalized = cleaned
          .replaceAll(thousandsSeparator, '')
          .replaceAll(decimalSeparator, '.');
    } else if (lastComma >= 0) {
      final decimals = cleaned.length - lastComma - 1;
      normalized = decimals == 1 || decimals == 2
          ? cleaned.replaceAll(',', '.')
          : cleaned.replaceAll(',', '');
    } else if (lastDot >= 0) {
      final decimals = cleaned.length - lastDot - 1;
      if (decimals > 2) {
        final parts = cleaned.split('.');
        normalized = '${parts.take(parts.length - 1).join()}.${parts.last}';
      }
    }

    final value = double.tryParse(normalized);
    if (value == null || value < 0) return null;
    return (value * 100).round();
  }
}

class Quantity {
  const Quantity._();

  static String format(num value, {String locale = 'es_MX'}) {
    final formatter = NumberFormat('#,##0.###', locale);
    return formatter.format(value);
  }

  static String withUnit(num value, String unit, {String locale = 'es_MX'}) {
    final amount = format(value, locale: locale);
    final label = unit.trim().isEmpty ? '' : unit.trim();
    if (label.isEmpty) return amount;

    final isOne = value == 1;
    final plural = switch (label.toLowerCase()) {
      'pieza' => 'piezas',
      'docena' => 'docenas',
      'bolsa' => 'bolsas',
      'maceta' => 'macetas',
      'planta' => 'plantas',
      'árbol' || 'arbol' => 'árboles',
      _ => null,
    };

    if (isOne || plural == null) {
      return '$amount $label';
    }
    return '$amount $plural';
  }

  static double? parse(String input) {
    final cleaned = input.replaceAll(RegExp(r'[^\d,.\-]'), '').trim();
    if (cleaned.isEmpty) return null;
    final normalized = cleaned.replaceAll(',', '.');
    final value = double.tryParse(normalized);
    if (value == null || value < 0) return null;
    return value;
  }
}

class Dates {
  const Dates._();

  static String short(DateTime value) {
    return DateFormat('dd/MM/yyyy', 'es_MX').format(value.toLocal());
  }

  static String dateTime(DateTime value) {
    return DateFormat('dd/MM/yyyy HH:mm', 'es_MX').format(value.toLocal());
  }

  static String monthDay(DateTime value) {
    return DateFormat('dd MMM', 'es_MX').format(value.toLocal());
  }

  static String time(DateTime value) {
    return DateFormat('HH:mm', 'es_MX').format(value.toLocal());
  }

  static bool isSameDay(DateTime a, DateTime b) {
    final localA = a.toLocal();
    final localB = b.toLocal();
    return localA.year == localB.year &&
        localA.month == localB.month &&
        localA.day == localB.day;
  }
}

String paymentMethodLabel(String method) {
  return switch (method) {
    'efectivo' => 'Efectivo',
    'transferencia' => 'Transferencia',
    'tarjeta' => 'Tarjeta',
    'otro' => 'Otro',
    _ => method,
  };
}

String movementTypeLabel(String type) {
  return switch (type) {
    'initial' => 'Stock inicial',
    'purchase' => 'Compra',
    'sale' => 'Venta',
    'adjustment' => 'Ajuste',
    'sale_cancel' => 'Anulación',
    _ => type,
  };
}
