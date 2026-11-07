import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/supabase_provider.dart';
import '../../organization/application/organization_providers.dart';
import '../data/dashboard_repository.dart';
import '../domain/dashboard_summary.dart';

final dashboardRepositoryProvider = Provider<DashboardRepository>((ref) {
  return DashboardRepository(ref.watch(supabaseProvider));
});

final dashboardSummaryProvider = FutureProvider<DashboardSummary>((ref) async {
  final organization = ref.watch(currentOrganizationProvider);
  final now = DateTime.now();
  final start = DateTime(now.year, now.month, now.day);
  final end = start.add(const Duration(days: 1));

  return ref
      .watch(dashboardRepositoryProvider)
      .getSummary(organizationId: organization.id, start: start, end: end);
});
