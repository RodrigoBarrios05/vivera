class Product {
  const Product({
    required this.id,
    required this.organizationId,
    required this.name,
    required this.unit,
    required this.salePriceCents,
    required this.costCents,
    required this.stock,
    required this.minStock,
    required this.active,
    required this.createdAt,
    required this.updatedAt,
    this.categoryId,
    this.categoryName,
    this.sku,
    this.notes,
  });

  final String id;
  final String organizationId;
  final String? categoryId;
  final String? categoryName;
  final String name;
  final String? sku;
  final String unit;
  final int salePriceCents;
  final int costCents;
  final double stock;
  final double minStock;
  final String? notes;
  final bool active;
  final DateTime createdAt;
  final DateTime updatedAt;

  bool get isLowStock => stock <= minStock;

  double get inventoryValueCents => stock * costCents;

  int get marginPercent {
    if (salePriceCents <= 0) return 0;
    return ((salePriceCents - costCents) / salePriceCents * 100).round();
  }

  factory Product.fromMap(Map<String, dynamic> map) {
    final category = map['categories'];
    return Product(
      id: map['id'] as String,
      organizationId: map['organization_id'] as String,
      categoryId: map['category_id'] as String?,
      categoryName: category is Map<String, dynamic>
          ? category['name'] as String?
          : null,
      name: map['name'] as String? ?? 'Producto',
      sku: map['sku'] as String?,
      unit: map['unit'] as String? ?? 'pieza',
      salePriceCents: (map['sale_price_cents'] as num?)?.toInt() ?? 0,
      costCents: (map['cost_cents'] as num?)?.toInt() ?? 0,
      stock: (map['stock'] as num?)?.toDouble() ?? 0,
      minStock: (map['min_stock'] as num?)?.toDouble() ?? 0,
      notes: map['notes'] as String?,
      active: map['active'] as bool? ?? true,
      createdAt:
          DateTime.tryParse(map['created_at']?.toString() ?? '') ??
          DateTime.now(),
      updatedAt:
          DateTime.tryParse(map['updated_at']?.toString() ?? '') ??
          DateTime.now(),
    );
  }

  Product copyWith({
    String? categoryId,
    String? categoryName,
    String? name,
    String? sku,
    String? unit,
    int? salePriceCents,
    int? costCents,
    double? stock,
    double? minStock,
    String? notes,
    bool? active,
  }) {
    return Product(
      id: id,
      organizationId: organizationId,
      categoryId: categoryId ?? this.categoryId,
      categoryName: categoryName ?? this.categoryName,
      name: name ?? this.name,
      sku: sku ?? this.sku,
      unit: unit ?? this.unit,
      salePriceCents: salePriceCents ?? this.salePriceCents,
      costCents: costCents ?? this.costCents,
      stock: stock ?? this.stock,
      minStock: minStock ?? this.minStock,
      notes: notes ?? this.notes,
      active: active ?? this.active,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }
}
