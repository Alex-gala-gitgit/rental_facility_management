import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../subscription/subscription_models.dart';

class SubscriptionService {
  SubscriptionService(this.client);

  final SupabaseClient client;

  Future<List<SubscriptionRequestRecord>> listOwnRequests() async {
    final userId = client.auth.currentUser?.id;
    if (userId == null) return const [];
    final rows = await client
        .from('subscription_requests')
        .select(
          'id,billing_period,amount,status,payment_slip_name,submitted_at,admin_notes',
        )
        .eq('user_id', userId)
        .order('created_at', ascending: false);
    return rows
        .map((row) => SubscriptionRequestRecord.fromMap(
              Map<String, dynamic>.from(row),
            ))
        .toList();
  }

  Future<SubscriptionRequestRecord> submitPremiumRequest({
    required SubscriptionBillingPeriod billingPeriod,
    required String fileName,
    required Uint8List bytes,
    required String contentType,
  }) async {
    final userId = client.auth.currentUser?.id;
    if (userId == null) {
      throw const AuthException('Sign in before requesting Premium access.');
    }
    if (bytes.isEmpty) {
      throw const AuthException('Choose a valid payment slip.');
    }
    final extension = _safeExtension(fileName, contentType);
    final path = '$userId/${DateTime.now().microsecondsSinceEpoch}.$extension';
    await client.storage.from('subscription-payment-slips').uploadBinary(
          path,
          bytes,
          fileOptions: FileOptions(contentType: contentType, upsert: false),
        );
    try {
      final row = await client
          .from('subscription_requests')
          .insert({
            'user_id': userId,
            'requested_tier': 'premium',
            'billing_period': subscriptionBillingPeriodValue(billingPeriod),
            'amount': subscriptionPrice(billingPeriod),
            'currency': 'MYR',
            'payment_slip_path': path,
            'payment_slip_name': fileName,
            'status': 'pending_verification',
          })
          .select(
            'id,billing_period,amount,status,payment_slip_name,submitted_at,admin_notes',
          )
          .single();
      return SubscriptionRequestRecord.fromMap(
        Map<String, dynamic>.from(row),
      );
    } catch (_) {
      try {
        await client.storage.from('subscription-payment-slips').remove([path]);
      } catch (_) {
        // The private bucket intentionally does not allow users to delete a
        // submitted receipt. Cleanup is only best-effort if the row insert
        // itself failed.
      }
      rethrow;
    }
  }

  String _safeExtension(String fileName, String contentType) {
    final lower = fileName.toLowerCase();
    if (contentType == 'application/pdf' || lower.endsWith('.pdf')) {
      return 'pdf';
    }
    if (contentType == 'image/png' || lower.endsWith('.png')) return 'png';
    return 'jpg';
  }
}
