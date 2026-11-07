class DashboardSummary {
  const DashboardSummary({
    required this.todaySalesCents,
    required this.todaySalesCount,
    required this.inventoryValueCents,
    required this.lowStockCount,
    required this.lowStock,
  });

  final int todaySalesCents;
  final int todaySalesCount;
  final int inventoryValueCents;
  final int lowStockCount;
  final List<LowStockProduct> lowStock;

  factory DashboardSummary.fromMap(Map<String, dynamic> map) {
    final rawLowStock = map['low_stock'];
    return DashboardSummary(
      todaySalesCents: (map['today_sales_cents'] as num?)?.toInt() ?? 0,
      todaySalesCount: (map['today_sales_count'] as num?)?.toInt() ?? 0,
      inventoryValueCents: (map['inventory_value_cents'] as num?)?.toInt() ?? 0,
      lowStockCount: (map['low_stock_count'] as num?)?.toInt() ?? 0,
      lowStock: rawLowStock is List
          ? rawLowStock
                .whereType<Map<String, dynamic>>()
                .map(LowStockProduct.fromMap)
                .toList()
          : const [],
    );
  }
}

class LowStockProduct {
  const LowStockProduct({
    required this.id,
    required this.name,
    required this.stock,
    required this.minStock,
    required this.unit,
  });

  final String id;
  final String name;
  final double stock;
  final double minStock;
  final String unit;

  factory LowStockProduct.fromMap(Map<String, dynamic> map) {
    return LowStockProduct(
      id: map['id'] as String,
      name: map['name'] as String? ?? 'Producto',
      stock: (map['stock'] as num?)?.toDouble() ?? 0,
      minStock: (map['min_stock'] as num?)?.toDouble() ?? 0,
      unit: map['unit'] as String? ?? 'pieza',
    );
  }
}
