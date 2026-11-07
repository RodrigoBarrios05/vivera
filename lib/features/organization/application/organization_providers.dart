import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/supabase_provider.dart';
import '../../session/application/session_controller.dart';
import '../../session/domain/app_session.dart';
import '../data/organization_repository.dart';
import '../domain/membership.dart';
import '../domain/organization.dart';

final organizationRepositoryProvider = Provider<OrganizationRepository>((ref) {
  return OrganizationRepository(ref.watch(supabaseProvider));
});

final currentOrganizationProvider = Provider<Organization>((ref) {
  final organization = ref.watch(sessionControllerProvider).organization;
  if (organization == null) {
    throw StateError('No hay un vivero activo.');
  }
  return organization;
});

final currentMembershipProvider = Provider<Membership>((ref) {
  final membership = ref.watch(sessionControllerProvider).membership;
  if (membership == null) {
    throw StateError('No hay una membresía activa.');
  }
  return membership;
});

final sessionDisplayNameProvider = Provider<String>((ref) {
  final session = ref.watch(sessionControllerProvider);
  return session.displayName;
});

final sessionStatusProvider = Provider<SessionStatus>((ref) {
  return ref.watch(sessionControllerProvider).status;
});
