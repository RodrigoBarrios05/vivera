import 'purchase_item.dart';

class Purchase {
  const Purchase({
    required this.id,
    required this.organizationId,
    required this.purchaseNumber,
    required this.totalCents,
    required this.createdAt,
    this.supplierName,
    this.notes,
    this.createdBy,
    this.createdByName,
    this.items = const [],
  });

  final String id;
  final String organizationId;
  final int purchaseNumber;
  final String? supplierName;
  final int totalCents;
  final String? notes;
  final String? createdBy;
  final String? createdByName;
  final DateTime createdAt;
  final List<PurchaseItem> items;

  factory Purchase.fromMap(Map<String, dynamic> map) {
    final profile = map['profiles'];
    final rawItems = map['purchase_items'];
    return Purchase(
      id: map['id'] as String,
      organizationId: map['organization_id'] as String,
      purchaseNumber: (map['purchase_number'] as num?)?.toInt() ?? 0,
      supplierName: map['supplier_name'] as String?,
      totalCents: (map['total_cents'] as num?)?.toInt() ?? 0,
      notes: map['notes'] as String?,
      createdBy: map['created_by'] as String?,
      createdByName: profile is Map<String, dynamic>
          ? profile['full_name'] as String?
          : null,
      createdAt:
          DateTime.tryParse(map['created_at']?.toString() ?? '') ??
          DateTime.now(),
      items: rawItems is List
          ? rawItems
                .whereType<Map<String, dynamic>>()
                .map(PurchaseItem.fromMap)
                .toList()
          : const [],
    );
  }
}
