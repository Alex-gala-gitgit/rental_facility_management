import 'dart:convert';
import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

class AppIssueReportService {
  AppIssueReportService(this.client);

  final SupabaseClient client;

  Future<void> submit({
    required String reporterName,
    required String reporterEmail,
    required String reporterRole,
    required String category,
    required String title,
    required String description,
    required String severity,
    required String appLanguage,
    String? attachmentName,
    String? attachmentMime,
    Uint8List? attachmentBytes,
  }) async {
    final user = client.auth.currentUser;
    if (user == null) {
      throw const AuthException('Please sign in again before reporting an issue.');
    }
    if (attachmentBytes != null && attachmentBytes.length > 2 * 1024 * 1024) {
      throw ArgumentError('The attachment must not exceed 2 MB.');
    }
    await client.from('app_issue_reports').insert({
      'reporter_id': user.id,
      'reporter_name': reporterName.trim(),
      'reporter_email': reporterEmail.trim().toLowerCase(),
      'reporter_role': reporterRole,
      'category': category,
      'title': title.trim(),
      'description': description.trim(),
      'severity': severity,
      'app_language': appLanguage,
      'source': 'homeops360_web_app',
      'attachment_name': attachmentName,
      'attachment_mime': attachmentMime,
      'attachment_base64':
          attachmentBytes == null ? null : base64Encode(attachmentBytes),
    });
  }

  Future<List<Map<String, dynamic>>> myReports() async {
    final user = client.auth.currentUser;
    if (user == null) return const [];
    final data = await client
        .from('app_issue_reports')
        .select('id,category,title,severity,status,created_at,updated_at,admin_notes')
        .eq('reporter_id', user.id)
        .order('created_at', ascending: false)
        .limit(50);
    return List<Map<String, dynamic>>.from(data);
  }
}
