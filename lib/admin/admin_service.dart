import 'package:supabase_flutter/supabase_flutter.dart';

import '../cloud/supabase_config.dart';

class AdminPortalException implements Exception {
  const AdminPortalException(this.message);
  final String message;
  @override
  String toString() => message;
}

class AdminPortalService {
  AdminPortalService(this.client);

  final SupabaseClient client;

  Session? get currentSession => client.auth.currentSession;

  Future<void> requestEmailOtp(String email) async {
    final redirectUrl = SupabaseConfig.isUatHost()
        ? 'https://facility-billing-management.pages.dev/admin'
        : 'https://admin.homeops360.app/';
    await client.auth.signInWithOtp(
      email: email.trim().toLowerCase(),
      shouldCreateUser: false,
      emailRedirectTo: redirectUrl,
    );
  }

  Future<void> verifyEmailOtp({
    required String email,
    required String code,
  }) async {
    final response = await client.auth.verifyOTP(
      type: OtpType.email,
      email: email.trim().toLowerCase(),
      token: code.trim(),
    );
    if (response.session == null) {
      throw const AdminPortalException(
        'The verification code could not create an administrator session.',
      );
    }
  }

  Future<Map<String, dynamic>> loadConsole({
    String action = 'bootstrap',
    DateTime? month,
  }) async {
    return _invoke({
      'action': action,
      if (month != null)
        'month': '${month.year}-${month.month.toString().padLeft(2, '0')}',
    });
  }

  Future<Map<String, dynamic>> updateOwnerConfig({
    required String ownerId,
    required int propertyLimit,
    required int tenantLimit,
    required int exploreListingLimit,
    required bool electricityTariffEnabled,
    required bool explorePromotionEnabled,
    required bool advancedExportEnabled,
    required bool meterHardwareEnabled,
  }) async {
    return _invoke({
      'action': 'update_owner_config',
      'ownerId': ownerId,
      'propertyLimit': propertyLimit,
      'tenantLimit': tenantLimit,
      'exploreListingLimit': exploreListingLimit,
      'electricityTariffEnabled': electricityTariffEnabled,
      'explorePromotionEnabled': explorePromotionEnabled,
      'advancedExportEnabled': advancedExportEnabled,
      'meterHardwareEnabled': meterHardwareEnabled,
    });
  }

  Future<void> sendPasswordReset(String userId) async {
    await _invoke({
      'action': 'send_password_reset',
      'userId': userId,
    });
  }

  Future<Map<String, dynamic>> updateAccount({
    required String userId,
    required String name,
    required String email,
    required String status,
  }) =>
      _invoke({
        'action': 'update_account',
        'userId': userId,
        'name': name,
        'email': email,
        'status': status,
      });

  Future<void> deleteAccount(String userId) async {
    await _invoke({
      'action': 'delete_account',
      'userId': userId,
    });
  }

  Future<void> updateWorkspaceRecord({
    required String ownerId,
    required String recordType,
    required String recordId,
    required Map<String, dynamic> fields,
  }) async {
    await _invoke({
      'action': 'update_workspace_record',
      'ownerId': ownerId,
      'recordType': recordType,
      'recordId': recordId,
      'fields': fields,
    });
  }

  Future<Map<String, dynamic>> updateCustomizeRequest({
    required String requestId,
    required String status,
    required String notes,
  }) =>
      _invoke({
        'action': 'update_customize_request',
        'requestId': requestId,
        'status': status,
        'notes': notes,
      });

  Future<Map<String, dynamic>> updateIssueReport({
    required String reportId,
    required String status,
    required String notes,
  }) =>
      _invoke({
        'action': 'update_issue_report',
        'reportId': reportId,
        'status': status,
        'notes': notes,
      });

  Future<String> subscriptionPaymentUrl(String requestId) async {
    final result = await _invoke({
      'action': 'subscription_payment_url',
      'requestId': requestId,
    });
    return '${result['url']}';
  }

  Future<void> reviewSubscription({
    required String requestId,
    required String decision,
    required String notes,
  }) async {
    await _invoke({
      'action': 'review_subscription_request',
      'requestId': requestId,
      'decision': decision,
      'notes': notes,
    });
  }

  Future<void> setMembership({
    required String userId,
    required String tier,
    String billingPeriod = 'monthly',
  }) async {
    await _invoke({
      'action': 'set_membership',
      'userId': userId,
      'tier': tier,
      'billingPeriod': billingPeriod,
    });
  }

  Future<Map<String, dynamic>> grantAdmin({
    required String displayName,
    required String email,
  }) =>
      _invoke({
        'action': 'grant_admin',
        'displayName': displayName,
        'email': email,
      });

  Future<Map<String, dynamic>> setAdminAccess({
    required String userId,
    required bool enabled,
  }) =>
      _invoke({
        'action': 'set_admin_access',
        'userId': userId,
        'enabled': enabled,
      });

  Future<Map<String, dynamic>> _invoke(Map<String, dynamic> body) async {
    final response = await client.functions.invoke(
      'admin-console',
      body: body,
    );
    final data = response.data;
    if (response.status < 200 || response.status >= 300) {
      final message = data is Map ? data['error']?.toString() : null;
      throw AdminPortalException(
        message ?? 'The administrator request failed.',
      );
    }
    if (data is! Map) {
      throw const AdminPortalException(
          'The administrator response is invalid.');
    }
    return Map<String, dynamic>.from(data);
  }

  Future<void> signOut() => client.auth.signOut();
}

List<Map<String, dynamic>> adminMapList(Object? value) {
  if (value is! List) return const [];
  return value
      .whereType<Map>()
      .map((item) => Map<String, dynamic>.from(item))
      .toList();
}

Map<String, dynamic> adminMap(Object? value) =>
    value is Map ? Map<String, dynamic>.from(value) : <String, dynamic>{};

num adminNumber(Object? value) =>
    value is num ? value : num.tryParse('$value') ?? 0;
