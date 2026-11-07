import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/membership.dart';
import '../domain/organization.dart';

class OrganizationRepository {
  OrganizationRepository(this._client);

  final SupabaseClient _client;

  Future<Membership?> getMembership(String userId) async {
    final data = await _client
        .from('organization_members')
        .select('organization_id, user_id, role')
        .eq('user_id', userId)
        .maybeSingle();
    return data == null ? null : Membership.fromMap(data);
  }

  Future<Organization?> getOrganization(String organizationId) async {
    final data = await _client
        .from('organizations')
        .select(
          'id, name, currency_code, locale, timezone, invite_code, created_at',
        )
        .eq('id', organizationId)
        .maybeSingle();
    return data == null ? null : Organization.fromMap(data);
  }

  Future<String> createOrganization(String name) async {
    final result = await _client.rpc(
      'create_organization',
      params: {
        'p_name': name.trim(),
        'p_currency_code': 'MXN',
        'p_locale': 'es_MX',
        'p_timezone': 'America/Mexico_City',
      },
    );
    return result as String;
  }

  Future<String> joinOrganization(String code) async {
    final result = await _client.rpc(
      'join_organization',
      params: {'p_code': code.trim().toUpperCase()},
    );
    return result as String;
  }

  Future<void> updateOrganization({
    required String organizationId,
    required String name,
    required String currencyCode,
    String locale = 'es_MX',
    String timezone = 'America/Mexico_City',
  }) async {
    await _client
        .from('organizations')
        .update({
          'name': name.trim(),
          'currency_code': currencyCode.trim().toUpperCase(),
          'locale': locale,
          'timezone': timezone,
        })
        .eq('id', organizationId);
  }

  Future<String> rotateInviteCode(String organizationId) async {
    final result = await _client.rpc(
      'rotate_invite_code',
      params: {'p_organization_id': organizationId},
    );
    return result as String;
  }
}
