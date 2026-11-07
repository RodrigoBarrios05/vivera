class Category {
  const Category({
    required this.id,
    required this.organizationId,
    required this.name,
    required this.sortOrder,
    required this.active,
  });

  final String id;
  final String organizationId;
  final String name;
  final int sortOrder;
  final bool active;

  factory Category.fromMap(Map<String, dynamic> map) {
    return Category(
      id: map['id'] as String,
      organizationId: map['organization_id'] as String,
      name: map['name'] as String? ?? 'Sin categoría',
      sortOrder: (map['sort_order'] as num?)?.toInt() ?? 0,
      active: map['active'] as bool? ?? true,
    );
  }
}
