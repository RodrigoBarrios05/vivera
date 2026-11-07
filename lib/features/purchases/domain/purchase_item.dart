class PurchaseItem {
  const PurchaseItem({
    required this.id,
    required this.purchaseId,
    required this.productId,
    required this.productName,
    required this.unit,
    required this.quantity,
    required this.unitCostCents,
    required this.subtotalCents,
  });

  final String id;
  final String purchaseId;
  final String productId;
  final String productName;
  final String unit;
  final double quantity;
  final int unitCostCents;
  final int subtotalCents;

  factory PurchaseItem.fromMap(Map<String, dynamic> map) {
    return PurchaseItem(
      id: map['id'] as String,
      purchaseId: map['purchase_id'] as String,
      productId: map['product_id'] as String,
      productName: map['product_name'] as String? ?? 'Producto',
      unit: map['unit'] as String? ?? 'pieza',
      quantity: (map['quantity'] as num?)?.toDouble() ?? 0,
      unitCostCents: (map['unit_cost_cents'] as num?)?.toInt() ?? 0,
      subtotalCents: (map['subtotal_cents'] as num?)?.toInt() ?? 0,
    );
  }
}
