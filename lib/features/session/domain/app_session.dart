import 'package:supabase_flutter/supabase_flutter.dart';

import '../../auth/domain/profile.dart';
import '../../organization/domain/membership.dart';
import '../../organization/domain/organization.dart';

enum SessionStatus { loading, signedOut, signedIn, error }

class AppSession {
  const AppSession({
    required this.status,
    this.session,
    this.profile,
    this.membership,
    this.organization,
    this.errorMessage,
  });

  const AppSession.loading()
    : status = SessionStatus.loading,
      session = null,
      profile = null,
      membership = null,
      organization = null,
      errorMessage = null;

  const AppSession.signedOut()
    : status = SessionStatus.signedOut,
      session = null,
      profile = null,
      membership = null,
      organization = null,
      errorMessage = null;

  final SessionStatus status;
  final Session? session;
  final Profile? profile;
  final Membership? membership;
  final Organization? organization;
  final String? errorMessage;

  User? get user => session?.user;

  bool get isSignedIn => status == SessionStatus.signedIn && session != null;

  bool get hasOrganization => organization != null;

  bool get isOwner => membership?.isOwner ?? false;

  String get displayName => profile?.displayName ?? user?.email ?? 'Usuario';
}
