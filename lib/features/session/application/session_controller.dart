import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/utils/errors.dart';
import '../../auth/application/auth_providers.dart';
import '../../organization/application/organization_providers.dart';
import '../domain/app_session.dart';

final sessionControllerProvider =
    NotifierProvider<SessionController, AppSession>(SessionController.new);

class SessionController extends Notifier<AppSession> {
  StreamSubscription<AuthState>? _authSubscription;
  int _loadId = 0;

  @override
  AppSession build() {
    final auth = ref.watch(authRepositoryProvider);

    _authSubscription = auth.authStateChanges.listen((authState) {
      if (authState.event == AuthChangeEvent.signedOut) {
        _loadId++;
        state = const AppSession.signedOut();
        return;
      }

      if (authState.session != null) {
        _loadCurrentSession();
      }
    });

    ref.onDispose(() {
      _authSubscription?.cancel();
    });

    Future<void>.microtask(_initialize);
    return const AppSession.loading();
  }

  Future<void> _initialize() async {
    final auth = ref.read(authRepositoryProvider);
    final session = auth.currentSession;
    if (session == null) {
      state = const AppSession.signedOut();
      return;
    }
    await _loadSession(session);
  }

  Future<void> _loadCurrentSession() async {
    final auth = ref.read(authRepositoryProvider);
    final session = auth.currentSession;
    if (session == null) {
      state = const AppSession.signedOut();
      return;
    }
    await _loadSession(session);
  }

  Future<void> _loadSession(Session session) async {
    final loadId = ++_loadId;
    state = AppSession(status: SessionStatus.loading, session: session);

    try {
      final authRepository = ref.read(authRepositoryProvider);
      final organizationRepository = ref.read(organizationRepositoryProvider);

      final profile = await authRepository.getProfile(session.user.id);
      final membership = await organizationRepository.getMembership(
        session.user.id,
      );

      var organization = membership == null
          ? null
          : await organizationRepository.getOrganization(
              membership.organizationId,
            );

      if (loadId != _loadId) return;

      state = AppSession(
        status: SessionStatus.signedIn,
        session: session,
        profile: profile,
        membership: membership,
        organization: organization,
      );
    } catch (error) {
      if (loadId != _loadId) return;
      state = AppSession(
        status: SessionStatus.error,
        session: session,
        errorMessage: readableError(error),
      );
    }
  }

  Future<void> refresh() async {
    await _loadCurrentSession();
  }

  Future<void> retry() async {
    await _loadCurrentSession();
  }

  Future<void> signOut() async {
    _loadId++;
    await ref.read(authRepositoryProvider).signOut();
    state = const AppSession.signedOut();
  }
}
