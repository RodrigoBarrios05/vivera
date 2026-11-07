import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/profile.dart';

class AuthRepository {
  AuthRepository(this._client);

  final SupabaseClient _client;

  Stream<AuthState> get authStateChanges => _client.auth.onAuthStateChange;

  Session? get currentSession => _client.auth.currentSession;

  Future<AuthResponse> signIn({
    required String email,
    required String password,
  }) {
    return _client.auth.signInWithPassword(
      email: email.trim(),
      password: password,
    );
  }

  Future<AuthResponse> signUp({
    required String email,
    required String password,
    required String fullName,
  }) {
    return _client.auth.signUp(
      email: email.trim(),
      password: password,
      data: {'full_name': fullName.trim()},
    );
  }

  Future<void> signOut() => _client.auth.signOut();

  Future<void> sendPasswordReset(String email) {
    return _client.auth.resetPasswordForEmail(email.trim());
  }

  Future<Profile?> getProfile(String userId) async {
    final data = await _client
        .from('profiles')
        .select('id, full_name')
        .eq('id', userId)
        .maybeSingle();
    return data == null ? null : Profile.fromMap(data);
  }

  Future<void> updateFullName({
    required String userId,
    required String fullName,
  }) async {
    await _client
        .from('profiles')
        .update({'full_name': fullName.trim()})
        .eq('id', userId);
  }
}
