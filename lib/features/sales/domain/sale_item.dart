class SaleItem {
  const SaleItem({
    required this.id,
    required this.saleId,
    required this.productId,
    required this.productName,
    required this.unit,
    required this.quantity,
    required this.unitPriceCents,
    required this.subtotalCents,
  });

  final String id;
  final String saleId;
  final String productId;
  final String productName;
  final String unit;
  final double quantity;
  final int unitPriceCents;
  final int subtotalCents;

  factory SaleItem.fromMap(Map<String, dynamic> map) {
    return SaleItem(
      id: map['id'] as String,
      saleId: map['sale_id'] as String,
      productId: map['product_id'] as String,
      productName: map['product_name'] as String? ?? 'Producto',
      unit: map['unit'] as String? ?? 'pieza',
      quantity: (map['quantity'] as num?)?.toDouble() ?? 0,
      unitPriceCents: (map['unit_price_cents'] as num?)?.toInt() ?? 0,
      subtotalCents: (map['subtotal_cents'] as num?)?.toInt() ?? 0,
    );
  }
}
