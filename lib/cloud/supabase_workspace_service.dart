import 'package:supabase_flutter/supabase_flutter.dart';

class TenantCloudSnapshot {
  const TenantCloudSnapshot({
    required this.ownerId,
    required this.tenantEmail,
    required this.payload,
  });

  final String ownerId;
  final String tenantEmail;
  final Map<String, dynamic> payload;
}

class SupabaseWorkspaceService {
  SupabaseWorkspaceService(this.client);

  final SupabaseClient client;

  Future<Map<String, dynamic>?> readOwnerSnapshot(String ownerId) async {
    final row = await client
        .from('workspace_snapshots')
        .select('payload')
        .eq('owner_id', ownerId)
        .maybeSingle();
    return _payload(row?['payload']);
  }

  Future<void> writeOwnerSnapshot(
    String ownerId,
    Map<String, dynamic> payload,
  ) async {
    await client.from('workspace_snapshots').upsert({
      'owner_id': ownerId,
      'payload': payload,
      'updated_at': DateTime.now().toIso8601String(),
    });
  }

  Future<List<TenantCloudSnapshot>> readOwnerTenantSnapshots(
    String ownerId,
  ) async {
    final rows = await client
        .from('tenant_workspace_snapshots')
        .select('owner_id, tenant_email, payload')
        .eq('owner_id', ownerId);
    return rows
        .map((row) => Map<String, dynamic>.from(row))
        .map((row) => TenantCloudSnapshot(
              ownerId: row['owner_id'] as String,
              tenantEmail: row['tenant_email'] as String,
              payload: _payload(row['payload']) ?? const {},
            ))
        .toList();
  }

  Future<TenantCloudSnapshot?> readTenantSnapshot(String email) async {
    final row = await client
        .from('tenant_workspace_snapshots')
        .select('owner_id, tenant_email, payload')
        .eq('tenant_email', email.toLowerCase())
        .maybeSingle();
    if (row == null) return null;
    return TenantCloudSnapshot(
      ownerId: row['owner_id'] as String,
      tenantEmail: row['tenant_email'] as String,
      payload: _payload(row['payload']) ?? const {},
    );
  }

  Future<void> writeTenantSnapshot({
    required String ownerId,
    required String tenantEmail,
    required Map<String, dynamic> payload,
  }) async {
    await client.from('tenant_workspace_snapshots').upsert({
      'owner_id': ownerId,
      'tenant_email': tenantEmail.toLowerCase(),
      'payload': payload,
      'updated_at': DateTime.now().toIso8601String(),
    });
  }

  Future<void> deleteOwnerTenantSnapshots(String ownerId) async {
    await client
        .from('tenant_workspace_snapshots')
        .delete()
        .eq('owner_id', ownerId);
  }

  static Map<String, dynamic>? _payload(Object? value) {
    if (value == null) return null;
    return Map<String, dynamic>.from(value as Map);
  }
}
