class Supplier {
  const Supplier({
    required this.id,
    required this.organizationId,
    required this.name,
    required this.active,
  });

  final String id;
  final String organizationId;
  final String name;
  final bool active;

  factory Supplier.fromMap(Map<String, dynamic> map) {
    return Supplier(
      id: map['id'] as String,
      organizationId: map['organization_id'] as String,
      name: map['name'] as String? ?? 'Proveedor',
      active: map['active'] as bool? ?? true,
    );
  }
}
