class Profile {
  const Profile({required this.id, this.fullName});

  final String id;
  final String? fullName;

  String get displayName {
    final name = fullName?.trim();
    if (name != null && name.isNotEmpty) return name;
    return 'Usuario';
  }

  factory Profile.fromMap(Map<String, dynamic> map) {
    return Profile(
      id: map['id'] as String,
      fullName: map['full_name'] as String?,
    );
  }
}
