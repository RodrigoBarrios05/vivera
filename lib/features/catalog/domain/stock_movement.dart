class StockMovement {
  const StockMovement({
    required this.id,
    required this.productId,
    required this.movementType,
    required this.quantityDelta,
    required this.stockAfter,
    required this.createdAt,
    this.reason,
    this.createdByName,
  });

  final String id;
  final String productId;
  final String movementType;
  final double quantityDelta;
  final double stockAfter;
  final String? reason;
  final String? createdByName;
  final DateTime createdAt;

  factory StockMovement.fromMap(Map<String, dynamic> map) {
    final profile = map['profiles'];
    return StockMovement(
      id: map['id'] as String,
      productId: map['product_id'] as String,
      movementType: map['movement_type'] as String? ?? 'adjustment',
      quantityDelta: (map['quantity_delta'] as num?)?.toDouble() ?? 0,
      stockAfter: (map['stock_after'] as num?)?.toDouble() ?? 0,
      reason: map['reason'] as String?,
      createdByName: profile is Map<String, dynamic>
          ? profile['full_name'] as String?
          : null,
      createdAt:
          DateTime.tryParse(map['created_at']?.toString() ?? '') ??
          DateTime.now(),
    );
  }
}
