class Organization {
  const Organization({
    required this.id,
    required this.name,
    required this.currencyCode,
    required this.locale,
    required this.timezone,
    required this.inviteCode,
    required this.createdAt,
  });

  final String id;
  final String name;
  final String currencyCode;
  final String locale;
  final String timezone;
  final String inviteCode;
  final DateTime createdAt;

  factory Organization.fromMap(Map<String, dynamic> map) {
    return Organization(
      id: map['id'] as String,
      name: map['name'] as String? ?? 'Mi vivero',
      currencyCode: map['currency_code'] as String? ?? 'MXN',
      locale: map['locale'] as String? ?? 'es_MX',
      timezone: map['timezone'] as String? ?? 'America/Mexico_City',
      inviteCode: map['invite_code'] as String? ?? '',
      createdAt:
          DateTime.tryParse(map['created_at']?.toString() ?? '') ??
          DateTime.now(),
    );
  }

  Organization copyWith({
    String? name,
    String? currencyCode,
    String? locale,
    String? timezone,
    String? inviteCode,
  }) {
    return Organization(
      id: id,
      name: name ?? this.name,
      currencyCode: currencyCode ?? this.currencyCode,
      locale: locale ?? this.locale,
      timezone: timezone ?? this.timezone,
      inviteCode: inviteCode ?? this.inviteCode,
      createdAt: createdAt,
    );
  }
}
