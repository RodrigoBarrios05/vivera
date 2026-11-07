import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/dashboard_summary.dart';

class DashboardRepository {
  DashboardRepository(this._client);

  final SupabaseClient _client;

  Future<DashboardSummary> getSummary({
    required String organizationId,
    required DateTime start,
    required DateTime end,
  }) async {
    final result = await _client.rpc(
      'dashboard_summary',
      params: {
        'p_organization_id': organizationId,
        'p_start': start.toUtc().toIso8601String(),
        'p_end': end.toUtc().toIso8601String(),
      },
    );

    final map = Map<String, dynamic>.from(result as Map);
    return DashboardSummary.fromMap(map);
  }
}
