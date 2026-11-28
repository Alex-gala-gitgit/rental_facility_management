import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:rental_facility_management/settlement/settlement_cloud_persistence.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  test('final settlement uploads its PDF and writes the matching record',
      () async {
    String encode(Object value) =>
        base64Url.encode(utf8.encode(jsonEncode(value))).replaceAll('=', '');
    final expiry = DateTime.now().millisecondsSinceEpoch ~/ 1000 + 3600;
    final token =
        '${encode({'alg': 'HS256'})}.${encode({'exp': expiry})}.test';
    String? uploadedPath;
    final client = SupabaseClient(
      'https://example.supabase.co',
      'test-key',
      httpClient: MockClient((request) async {
        http.Response response(Object body, [int status = 200]) =>
            http.Response(jsonEncode(body), status, request: request,
                headers: {'content-type': 'application/json'});
        if (request.url.path == '/auth/v1/token') {
          return response({
            'access_token': token,
            'expires_in': 3600,
            'refresh_token': 'test-refresh-token',
            'token_type': 'bearer',
            'user': {'id': 'owner', 'app_metadata': {}, 'user_metadata': {}},
          });
        }
        const uploadPrefix = '/storage/v1/object/move-out-settlements/';
        if (request.url.path.startsWith(uploadPrefix)) {
          expect(request.method, 'POST');
          uploadedPath = request.url.path.substring(uploadPrefix.length);
          expect(uploadedPath, matches(r'^owner/[^/]+/[0-9]+_[0-9]+\.pdf$'));
          return response({'Key': 'move-out-settlements/$uploadedPath'});
        }
        expect(request.url.path, '/rest/v1/move_out_settlements');
        expect(request.method, 'PATCH');
        expect(request.url.queryParameters['revision'], 'eq.2');
        expect(uploadedPath, isNotNull);
        final row = jsonDecode(request.body) as Map<String, dynamic>;
        expect(row['pdf_path'], uploadedPath);
        expect(row['revision'], 3);
        expect(row['payload'], {'isFinalInvoice': true});
        return response([{'record_key': 'settlement-key'}]);
      }),
    );
    addTearDown(client.dispose);
    await client.auth.signInWithPassword(
        email: 'owner@example.com', password: 'test-password');
    await SupabaseSettlementRemote(client, 'settlement-key').save(
        '{"isFinalInvoice":true}', Uint8List.fromList([37, 80, 68, 70]), 2);
    expect(uploadedPath, isNotNull);
  });
}
