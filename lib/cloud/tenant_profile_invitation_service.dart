import 'package:supabase_flutter/supabase_flutter.dart';

class TenantProfileInvitationException implements Exception {
  const TenantProfileInvitationException(this.message);

  final String message;

  @override
  String toString() => message;
}

class TenantProfileInvitation {
  const TenantProfileInvitation({
    required this.id,
    required this.ownerId,
    required this.tenantId,
    required this.tenantEmail,
    required this.status,
    required this.expiresAt,
    this.token,
    this.draft = const {},
    this.rejectionReason,
    this.submittedAt,
  });

  factory TenantProfileInvitation.fromMap(Map<String, dynamic> map) =>
      TenantProfileInvitation(
        id: map['id'] as String,
        ownerId: map['ownerId'] as String? ?? '',
        tenantId: map['tenantId'] as String,
        tenantEmail: map['tenantEmail'] as String,
        status: map['status'] as String? ?? 'invited',
        expiresAt: DateTime.parse(map['expiresAt'] as String),
        token: map['token'] as String?,
        draft: Map<String, dynamic>.from(
          map['draft'] as Map? ?? const <String, dynamic>{},
        ),
        rejectionReason: map['rejectionReason'] as String?,
        submittedAt: map['submittedAt'] == null
            ? null
            : DateTime.tryParse(map['submittedAt'] as String),
      );

  final String id;
  final String ownerId;
  final String tenantId;
  final String tenantEmail;
  final String status;
  final DateTime expiresAt;
  final String? token;
  final Map<String, dynamic> draft;
  final String? rejectionReason;
  final DateTime? submittedAt;
}

class TenantProfileInvitationService {
  const TenantProfileInvitationService(this.client);

  final SupabaseClient client;

  Future<Map<String, dynamic>> _invoke(Map<String, dynamic> body) async {
    late final FunctionResponse response;
    try {
      response = await client.functions.invoke(
        'tenant-profile-invitation',
        body: body,
      );
    } on FunctionException catch (error) {
      final details = error.details;
      final message =
          details is Map ? details['error']?.toString().trim() : null;
      throw TenantProfileInvitationException(
        message?.isNotEmpty == true
            ? message!
            : 'The tenant profile invitation could not be opened.',
      );
    }
    final data = response.data;
    if (response.status < 200 || response.status >= 300) {
      final message = data is Map ? data['error']?.toString() : null;
      throw TenantProfileInvitationException(
        message ?? 'Tenant profile invitation failed.',
      );
    }
    return Map<String, dynamic>.from(data as Map);
  }

  Future<TenantProfileInvitation> create({
    required String tenantId,
    required String tenantEmail,
  }) async =>
      TenantProfileInvitation.fromMap(await _invoke({
        'action': 'create',
        'tenantId': tenantId,
        'tenantEmail': tenantEmail.trim().toLowerCase(),
      }));

  Future<TenantProfileInvitation> load(String token) async =>
      TenantProfileInvitation.fromMap(await _invoke({
        'action': 'load',
        'token': token,
      }));

  Future<TenantProfileInvitation> submit({
    required String token,
    required Map<String, dynamic> draft,
    required String password,
  }) async =>
      TenantProfileInvitation.fromMap(await _invoke({
        'action': 'submit',
        'token': token,
        'draft': draft,
        'password': password,
      }));

  Future<List<TenantProfileInvitation>> listOwner() async {
    final result = await _invoke({'action': 'list'});
    return (result['items'] as List<dynamic>? ?? const [])
        .map((item) => TenantProfileInvitation.fromMap(
              Map<String, dynamic>.from(item as Map),
            ))
        .toList();
  }

  Future<TenantProfileInvitation> review({
    required String invitationId,
    required bool approve,
    String? reason,
  }) async =>
      TenantProfileInvitation.fromMap(await _invoke({
        'action': 'review',
        'invitationId': invitationId,
        'decision': approve ? 'approve' : 'reject',
        if (reason != null) 'reason': reason.trim(),
      }));
}
