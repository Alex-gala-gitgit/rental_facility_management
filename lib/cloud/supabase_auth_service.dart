import 'package:supabase_flutter/supabase_flutter.dart';

import 'supabase_config.dart';

class CloudProfile {
  const CloudProfile({
    required this.id,
    required this.email,
    required this.fullName,
    required this.role,
    this.guidedTours = const {},
  });

  final String id;
  final String email;
  final String fullName;
  final String role;
  final Map<String, dynamic> guidedTours;

  bool hasSeenGuidedTour(String tourKey) => guidedTours.containsKey(tourKey);

  CloudProfile withGuidedTour({
    required String tourKey,
    required String status,
  }) {
    return CloudProfile(
      id: id,
      email: email,
      fullName: fullName,
      role: role,
      guidedTours: {
        ...guidedTours,
        tourKey: {
          'status': status,
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        },
      },
    );
  }
}

class SupabaseAuthService {
  SupabaseAuthService(this.client);

  final SupabaseClient client;

  Session? get currentSession => client.auth.currentSession;
  Stream<AuthState> get authStateChanges => client.auth.onAuthStateChange;

  Future<CloudProfile?> currentProfile() async {
    final user = client.auth.currentUser;
    if (user == null) return null;
    final row = await client
        .from('profiles')
        .select('id, email, full_name, role, guided_tours')
        .eq('id', user.id)
        .maybeSingle();
    if (row == null) return null;
    return CloudProfile(
      id: row['id'] as String,
      email: row['email'] as String? ?? user.email ?? '',
      fullName: row['full_name'] as String? ?? 'User',
      role: row['role'] as String? ?? 'tenant',
      guidedTours: row['guided_tours'] is Map
          ? Map<String, dynamic>.from(row['guided_tours'] as Map)
          : const {},
    );
  }

  Future<void> saveGuidedTourProgress({
    required String tourKey,
    required String status,
  }) async {
    final user = client.auth.currentUser;
    if (user == null) throw const AuthException('Please sign in again.');
    if (status != 'completed' && status != 'skipped') {
      throw ArgumentError.value(status, 'status', 'Unsupported tour status.');
    }
    final row = await client
        .from('profiles')
        .select('guided_tours')
        .eq('id', user.id)
        .single();
    final existing = row['guided_tours'] is Map
        ? Map<String, dynamic>.from(row['guided_tours'] as Map)
        : <String, dynamic>{};
    existing[tourKey] = {
      'status': status,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    };
    await client
        .from('profiles')
        .update({'guided_tours': existing}).eq('id', user.id);
  }

  Future<CloudProfile> signIn({
    required String email,
    required String password,
  }) async {
    await client.auth.signInWithPassword(
      email: email.trim(),
      password: password,
    );
    final profile = await currentProfile();
    if (profile == null) {
      await client.auth.signOut();
      throw const AuthException(
        'Your account profile is not ready. Run the database setup first.',
      );
    }
    return profile;
  }

  Future<bool> registerAccount({
    required String fullName,
    required String email,
    required String password,
    required String role,
  }) async {
    final response = await client.auth.signUp(
      email: email.trim(),
      password: password,
      emailRedirectTo: SupabaseConfig.authRedirectUrl,
      data: {
        'full_name': fullName.trim(),
        'role': role,
      },
    );
    return response.session != null;
  }

  Future<void> sendPasswordReset(String email) async {
    await client.auth.resetPasswordForEmail(email.trim());
  }

  Future<void> requestEmailChange(String email) async {
    await client.auth.updateUser(
      UserAttributes(email: email.trim().toLowerCase()),
    );
  }

  Future<void> inviteTenant({
    required String email,
    required String fullName,
  }) async {
    final response = await client.functions.invoke(
      'invite-tenant',
      body: {
        'email': email.trim().toLowerCase(),
        'fullName': fullName.trim(),
      },
    );
    if (response.status < 200 || response.status >= 300) {
      final data = response.data;
      final message = data is Map ? data['error']?.toString() : null;
      throw AuthException(message ?? 'Unable to send tenant invitation.');
    }
  }

  Future<void> signOut() => client.auth.signOut();
}
