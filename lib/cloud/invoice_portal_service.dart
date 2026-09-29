import 'dart:convert';
import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

class PublishedInvoiceAccess {
  const PublishedInvoiceAccess({
    required this.invoiceId,
    required this.portalToken,
    required this.portalExpiresAt,
    this.pdfUrl,
  });

  final String invoiceId;
  final String portalToken;
  final DateTime portalExpiresAt;
  final Uri? pdfUrl;
}

class InvoicePortalService {
  const InvoicePortalService(this.client);

  final SupabaseClient client;

  Future<PublishedInvoiceAccess> publish(
    Map<String, dynamic> invoice,
  ) async {
    final data = await _invoke({
      'action': 'publish',
      'invoice': invoice,
    });
    await client.from('rentflow_test_invoices').update({
      'bank_name': invoice['bank_name'] ?? '',
      'bank_account_number': invoice['bank_account_number'] ?? '',
      'bank_beneficiary': invoice['bank_beneficiary'] ?? '',
      'payment_qr_name': invoice['payment_qr_name'],
      'payment_qr_base64': invoice['payment_qr_base64'],
    }).eq('id', invoice['id'] as String);
    return PublishedInvoiceAccess(
      invoiceId: data['invoiceId'] as String,
      portalToken: data['portalToken'] as String,
      portalExpiresAt: DateTime.parse(data['portalExpiresAt'] as String),
      pdfUrl: _uri(data['pdfUrl']),
    );
  }

  Future<Map<String, dynamic>> load({
    String? invoiceId,
    required String token,
  }) async {
    final data = await _invoke({
      'action': 'get',
      if (invoiceId != null && invoiceId.trim().isNotEmpty)
        'invoiceId': invoiceId,
      'token': token,
    });
    return Map<String, dynamic>.from(data['invoice'] as Map);
  }

  /// Retrieves an owner-issued invoice for the currently authenticated tenant.
  /// This deliberately does not use or renew the WhatsApp portal token.
  Future<Map<String, dynamic>> loadForSignedInTenant({
    required String invoiceId,
  }) async {
    final data = await _invoke({
      'action': 'get-authenticated-tenant',
      'invoiceId': invoiceId,
    });
    return Map<String, dynamic>.from(data['invoice'] as Map);
  }

  Future<void> submitPayment({
    required String invoiceId,
    required String token,
    required String fileName,
    required Uint8List bytes,
    required double amountPaid,
    required DateTime paymentDate,
    String? paymentReference,
  }) async {
    await _invoke({
      'action': 'submit-payment',
      'invoiceId': invoiceId,
      'token': token,
      'fileName': fileName,
      'mimeType': _mimeType(fileName),
      'base64': base64Encode(bytes),
      'amountPaid': amountPaid,
      'paymentDate': paymentDate.toIso8601String(),
      'paymentReference': paymentReference?.trim(),
    });
  }

  Future<void> reviewPayment({
    required String invoiceId,
    required bool approved,
    String? rejectionReason,
  }) async {
    await _invoke({
      'action': 'review-payment',
      'invoiceId': invoiceId,
      'decision': approved ? 'approved' : 'rejected',
      if (!approved) 'rejectionReason': rejectionReason?.trim(),
    });
  }

  Future<Map<String, dynamic>> _invoke(Map<String, dynamic> body) async {
    late final FunctionResponse response;
    try {
      response = await client.functions.invoke(
        'invoice-portal',
        body: body,
      );
    } on FunctionException catch (error) {
      final details = error.details;
      final message =
          details is Map ? details['error']?.toString() : details?.toString();
      throw AuthException(
        message?.trim().isNotEmpty == true
            ? message!
            : 'The secure invoice service returned ${error.status}.',
      );
    }
    if (response.status < 200 || response.status >= 300) {
      final payload = response.data;
      final message = payload is Map ? payload['error']?.toString() : null;
      throw AuthException(
          message ?? 'The secure invoice service is unavailable.');
    }
    if (response.data is! Map) {
      throw const AuthException(
          'The secure invoice service returned an invalid response.');
    }
    return Map<String, dynamic>.from(response.data as Map);
  }

  static Uri? _uri(dynamic value) {
    final text = value?.toString().trim() ?? '';
    return text.isEmpty ? null : Uri.tryParse(text);
  }

  static String _mimeType(String fileName) {
    final lower = fileName.toLowerCase();
    if (lower.endsWith('.png')) return 'image/png';
    if (lower.endsWith('.pdf')) return 'application/pdf';
    return 'image/jpeg';
  }
}
