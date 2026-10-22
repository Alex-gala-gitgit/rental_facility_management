import 'package:supabase_flutter/supabase_flutter.dart';

import '../subscription/subscription_models.dart';

class OwnerAccessConfig {
  const OwnerAccessConfig({
    this.propertyLimit = 1,
    this.tenantLimit = 2,
    this.exploreListingLimit = 0,
    this.electricityTariffEnabled = false,
    this.explorePromotionEnabled = false,
    this.advancedExportEnabled = true,
    this.meterHardwareEnabled = false,
    this.membershipTier = MembershipTier.free,
    this.subscriptionStatus = SubscriptionStatus.active,
    this.subscriptionExpiresAt,
    this.unlimitedAccess = false,
    this.announcementsEnabled = false,
    this.marketplaceEnabled = false,
    this.prioritySupportEnabled = false,
  });

  factory OwnerAccessConfig.fromMap(Map<String, dynamic> row) =>
      OwnerAccessConfig(
        propertyLimit: row['property_limit'] as int? ?? 1,
        tenantLimit: row['tenant_limit'] as int? ?? 2,
        exploreListingLimit: row['explore_listing_limit'] as int? ?? 0,
        electricityTariffEnabled:
            row['electricity_tariff_enabled'] as bool? ?? false,
        explorePromotionEnabled:
            row['explore_promotion_enabled'] as bool? ?? false,
        advancedExportEnabled: row['advanced_export_enabled'] as bool? ?? true,
        meterHardwareEnabled: row['meter_hardware_enabled'] as bool? ?? false,
        membershipTier: membershipTierFromValue(row['membership_tier']),
        subscriptionStatus:
            subscriptionStatusFromValue(row['subscription_status']),
        subscriptionExpiresAt:
            DateTime.tryParse('${row['subscription_expires_at'] ?? ''}'),
        unlimitedAccess: row['unlimited_access'] as bool? ?? false,
        announcementsEnabled: row['announcements_enabled'] as bool? ?? false,
        marketplaceEnabled: row['marketplace_enabled'] as bool? ?? false,
        prioritySupportEnabled:
            row['priority_support_enabled'] as bool? ?? false,
      );

  final int propertyLimit;
  final int tenantLimit;
  final int exploreListingLimit;
  final bool electricityTariffEnabled;
  final bool explorePromotionEnabled;
  final bool advancedExportEnabled;
  final bool meterHardwareEnabled;
  final MembershipTier membershipTier;
  final SubscriptionStatus subscriptionStatus;
  final DateTime? subscriptionExpiresAt;
  final bool unlimitedAccess;
  final bool announcementsEnabled;
  final bool marketplaceEnabled;
  final bool prioritySupportEnabled;
}

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

class OwnerCloudNotification {
  const OwnerCloudNotification({
    required this.id,
    required this.ownerId,
    required this.category,
    required this.title,
    required this.message,
    required this.createdAt,
    this.sourceTable,
    this.sourceId,
    this.readAt,
  });

  factory OwnerCloudNotification.fromMap(Map<String, dynamic> row) =>
      OwnerCloudNotification(
        id: row['id'] as String,
        ownerId: row['owner_id'] as String,
        category: row['category'] as String? ?? 'account',
        title: row['title'] as String? ?? 'Tenant update',
        message: row['message'] as String? ?? 'A tenant updated information.',
        sourceTable: row['source_table'] as String?,
        sourceId: row['source_id'] as String?,
        createdAt: DateTime.parse(row['created_at'] as String),
        readAt: row['read_at'] == null
            ? null
            : DateTime.tryParse(row['read_at'] as String),
      );

  final String id;
  final String ownerId;
  final String category;
  final String title;
  final String message;
  final String? sourceTable;
  final String? sourceId;
  final DateTime createdAt;
  final DateTime? readAt;
}

class SupabaseWorkspaceService {
  SupabaseWorkspaceService(this.client);

  final SupabaseClient client;

  Future<OwnerAccessConfig?> readOwnerAccessConfig(String ownerId) async {
    final row = await client
        .from('owner_access_configs')
        .select()
        .eq('owner_id', ownerId)
        .maybeSingle();
    return row == null
        ? null
        : OwnerAccessConfig.fromMap(Map<String, dynamic>.from(row));
  }

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
    final email = tenantEmail.toLowerCase();
    for (var attempt = 0; attempt < 3; attempt++) {
      final row = await client
          .from('tenant_workspace_snapshots')
          .select('payload, updated_at')
          .eq('owner_id', ownerId)
          .eq('tenant_email', email)
          .maybeSingle();
      if (row == null) {
        // Only owners may create rows. Tenants must update an assigned row.
        if (client.auth.currentUser?.id != ownerId) {
          throw StateError(
              'Your assigned cloud workspace is unavailable. Please contact your owner.');
        }
        try {
          await client.from('tenant_workspace_snapshots').insert({
            'owner_id': ownerId,
            'tenant_email': email,
            'payload': payload,
            'updated_at': DateTime.now().toUtc().toIso8601String(),
          });
          return;
        } on PostgrestException catch (error) {
          if (error.code != '23505') rethrow;
          continue;
        }
      }
      final merged =
          preserveTenantRequests(_payload(row['payload']) ?? {}, payload);
      final updated = await client
          .from('tenant_workspace_snapshots')
          .update({
            'payload': merged,
            'updated_at': DateTime.now().toUtc().toIso8601String(),
          })
          .eq('owner_id', ownerId)
          .eq('tenant_email', email)
          .eq('updated_at', row['updated_at'])
          .select('tenant_email');
      if (updated.isNotEmpty) return;
      // Another device saved first; re-read and merge rather than overwrite it.
    }
    throw StateError(
        'Your request could not be saved because the workspace changed. Please try again.');
  }

  Future<void> deleteOwnerTenantSnapshots(String ownerId) async {
    await client
        .from('tenant_workspace_snapshots')
        .delete()
        .eq('owner_id', ownerId);
  }

  Future<List<OwnerCloudNotification>> readOwnerNotifications(
    String ownerId, {
    int limit = 100,
  }) async {
    final rows = await client
        .from('owner_notifications')
        .select(
          'id,owner_id,category,title,message,source_table,source_id,read_at,created_at',
        )
        .eq('owner_id', ownerId)
        .order('created_at', ascending: false)
        .limit(limit);
    return rows
        .map((row) => OwnerCloudNotification.fromMap(
              Map<String, dynamic>.from(row),
            ))
        .toList();
  }

  RealtimeChannel subscribeOwnerRequests({
    required String ownerId,
    required void Function(Map<String, dynamic> payload) onChange,
    required void Function() onConnected,
  }) =>
      client
          .channel('owner-requests-$ownerId')
          .onPostgresChanges(
              event: PostgresChangeEvent.all,
              schema: 'public',
              table: 'tenant_workspace_snapshots',
              filter: PostgresChangeFilter(
                  type: PostgresChangeFilterType.eq,
                  column: 'owner_id',
                  value: ownerId),
              callback: (event) {
                final payload = _payload(event.newRecord['payload']);
                if (payload != null) onChange(payload);
              })
          .subscribe((status, error) {
        if (status == RealtimeSubscribeStatus.subscribed) onConnected();
      });

  RealtimeChannel subscribeOwnerNotifications({
    required String ownerId,
    required void Function(OwnerCloudNotification notification) onInsert,
  }) =>
      client
          .channel('owner-notifications-$ownerId')
          .onPostgresChanges(
            event: PostgresChangeEvent.insert,
            schema: 'public',
            table: 'owner_notifications',
            filter: PostgresChangeFilter(
              type: PostgresChangeFilterType.eq,
              column: 'owner_id',
              value: ownerId,
            ),
            callback: (payload) {
              if (payload.newRecord.isEmpty) return;
              onInsert(OwnerCloudNotification.fromMap(
                Map<String, dynamic>.from(payload.newRecord),
              ));
            },
          )
          .subscribe();

  Future<void> markOwnerNotificationRead(String notificationId) async {
    await client.from('owner_notifications').update({
      'read_at': DateTime.now().toIso8601String(),
    }).eq('id', notificationId);
  }

  Future<void> markAllOwnerNotificationsRead(String ownerId) async {
    await client
        .from('owner_notifications')
        .update({'read_at': DateTime.now().toIso8601String()})
        .eq('owner_id', ownerId)
        .isFilter('read_at', null);
  }

  Future<void> removeChannel(RealtimeChannel channel) =>
      client.removeChannel(channel);

  static Map<String, dynamic>? _payload(Object? value) {
    if (value == null) return null;
    return Map<String, dynamic>.from(value as Map);
  }
}

Map<String, dynamic> preserveTenantRequests(
    Map<String, dynamic> saved, Map<String, dynamic> incoming) {
  final requests = <String, Map<String, dynamic>>{};
  for (final value in (saved['tenantRequests'] as List? ?? [])) {
    final row = Map<String, dynamic>.from(value as Map);
    requests[row['id'] as String] = row;
  }
  for (final value in (incoming['tenantRequests'] as List? ?? [])) {
    final row = Map<String, dynamic>.from(value as Map);
    final id = row['id'] as String;
    final previous = requests[id];
    if (previous == null) {
      requests[id] = row;
      continue;
    }
    final oldReview =
        DateTime.tryParse(previous['reviewedAt'] as String? ?? '');
    final newReview = DateTime.tryParse(row['reviewedAt'] as String? ?? '');
    final oldEdit =
        DateTime.tryParse(previous['tenantEditedAt'] as String? ?? '');
    final newEdit = DateTime.tryParse(row['tenantEditedAt'] as String? ?? '');
    var merged = {...previous};
    if (newEdit != null && (oldEdit == null || newEdit.isAfter(oldEdit))) {
      merged.addAll({
        'requestedMoveOutDate': row['requestedMoveOutDate'],
        'message': row['message'],
        'tenantEditedAt': row['tenantEditedAt'],
        'bankName': row['bankName'],
        'bankAccountNumber': row['bankAccountNumber'],
      });
    }
    if (newReview != null &&
        (oldReview == null || newReview.isAfter(oldReview))) {
      merged.addAll({
        'status': row['status'],
        'reviewedAt': row['reviewedAt'],
        'rejectionReason': row['rejectionReason']
      });
    }
    if (previous['status'] == 'Withdrawn' ||
        (row['status'] == 'Withdrawn' && newEdit != null)) {
      merged['status'] = 'Withdrawn';
    }
    requests[id] = merged;
  }
  return {...incoming, 'tenantRequests': requests.values.toList()};
}
