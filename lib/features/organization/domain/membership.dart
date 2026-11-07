class Membership {
  const Membership({
    required this.organizationId,
    required this.userId,
    required this.role,
  });

  final String organizationId;
  final String userId;
  final String role;

  bool get isOwner => role == 'owner';

  factory Membership.fromMap(Map<String, dynamic> map) {
    return Membership(
      organizationId: map['organization_id'] as String,
      userId: map['user_id'] as String,
      role: map['role'] as String? ?? 'member',
    );
  }
}
