import 'sale_item.dart';

class Sale {
  const Sale({
    required this.id,
    required this.organizationId,
    required this.saleNumber,
    required this.totalCents,
    required this.paymentMethod,
    required this.status,
    required this.createdAt,
    this.notes,
    this.createdBy,
    this.createdByName,
    this.cancelledAt,
    this.cancelReason,
    this.items = const [],
  });

  final String id;
  final String organizationId;
  final int saleNumber;
  final int totalCents;
  final String paymentMethod;
  final String? notes;
  final String status;
  final String? createdBy;
  final String? createdByName;
  final DateTime createdAt;
  final DateTime? cancelledAt;
  final String? cancelReason;
  final List<SaleItem> items;

  bool get isCancelled => status == 'cancelled';

  factory Sale.fromMap(Map<String, dynamic> map) {
    final profile = map['profiles'];
    final rawItems = map['sale_items'];
    return Sale(
      id: map['id'] as String,
      organizationId: map['organization_id'] as String,
      saleNumber: (map['sale_number'] as num?)?.toInt() ?? 0,
      totalCents: (map['total_cents'] as num?)?.toInt() ?? 0,
      paymentMethod: map['payment_method'] as String? ?? 'efectivo',
      notes: map['notes'] as String?,
      status: map['status'] as String? ?? 'completed',
      createdBy: map['created_by'] as String?,
      createdByName: profile is Map<String, dynamic>
          ? profile['full_name'] as String?
          : null,
      createdAt:
          DateTime.tryParse(map['created_at']?.toString() ?? '') ??
          DateTime.now(),
      cancelledAt: DateTime.tryParse(map['cancelled_at']?.toString() ?? ''),
      cancelReason: map['cancel_reason'] as String?,
      items: rawItems is List
          ? rawItems
                .whereType<Map<String, dynamic>>()
                .map(SaleItem.fromMap)
                .toList()
          : const [],
    );
  }
}
