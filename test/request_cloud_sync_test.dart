import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:rental_facility_management/cloud/supabase_workspace_service.dart';
import 'package:rental_facility_management/cloud/supabase_auth_service.dart';
import 'package:rental_facility_management/main.dart' as app;

Map<String, dynamic> request(String id,
        {String status = 'Open', String? reviewed}) =>
    {
      'id': id,
      'title': 'Move-out',
      'requestedMoveOutDate': '2026-10-31',
      'bankName': 'Example',
      'bankAccountNumber': '001234',
      'status': status,
      'reviewedAt': reviewed
    };

void main() {
  test('open owner workspace refreshes cached request from tenant cloud row',
      () async {
    var reads = 0;
    final client = SupabaseClient('https://example.supabase.co', 'test-key',
        httpClient: MockClient((req) async {
      expect(req.method, 'GET');
      expect(req.url.queryParameters['owner_id'], 'eq.owner');
      reads++;
      return http.Response(
          jsonEncode([
            {
              'owner_id': 'owner',
              'tenant_email': 'tenant@example.com',
              'payload': {
                'tenantRequests': [
                  {
                    ...request('move'),
                    'requestedMoveOutDate': '2026-10-30T00:00:00.000',
                    'message': 'Move-out date: 30/10/2026',
                    'bankName': 'Updated Bank',
                    'bankAccountNumber': '0099',
                    'tenantEditedAt': '2026-10-03T03:50:07.155Z'
                  }
                ]
              }
            }
          ]),
          200,
          request: req,
          headers: {'content-type': 'application/json'});
    }));
    final store = app.RentalStore(
        seedDemoData: false, cloudWorkspace: SupabaseWorkspaceService(client));
    store.cloudProfile = const CloudProfile(
        id: 'owner',
        email: 'owner@example.com',
        fullName: 'Owner',
        role: 'owner');
    final cached = app.TenantRequest(
        id: 'move',
        tenantId: 'tenant',
        facilityId: 'property',
        title: 'Move-out',
        message: 'Move-out date: 23/10/2026',
        createdAt: DateTime(2026, 10, 3),
        requestType: 'Move-out',
        requestedMoveOutDate: DateTime(2026, 10, 23));
    store.tenantRequests.add(cached);
    await store.refreshOwnerRequests(rethrowOnError: true);
    expect(cached.requestedMoveOutDate, DateTime(2026, 10, 30));
    expect(cached.message, 'Move-out date: 30/10/2026');
    expect(cached.bankName, 'Updated Bank');
    expect(cached.bankAccountNumber, '0099');
    expect(reads, 1);
    store.receiveOwnerRequestUpdate('owner', {'tenantRequests': [{...request('move'),
      'requestedMoveOutDate': '2026-11-01T00:00:00.000', 'message': 'Move-out date: 01/11/2026',
      'bankName': 'Realtime Bank', 'bankAccountNumber': '0088', 'tenantEditedAt': '2026-10-03T04:00:00Z'}]});
    expect(cached.requestedMoveOutDate, DateTime(2026, 11, 1));
    expect(cached.bankName, 'Realtime Bank');
    expect(reads, 1); // Push event applies directly, without polling.
    store.receiveOwnerRequestUpdate('different-owner', {'tenantRequests': [{...request('move'),
      'message': 'Wrong workspace', 'tenantEditedAt': '2026-10-03T05:00:00Z'}]});
    expect(cached.message, 'Move-out date: 01/11/2026');
    store.dispose();
    await client.dispose();
  });
  test('newer rejection saves its reason and stale snapshot keeps it', () {
    final rejected = {
      ...request('move'),
      'status': 'Rejected',
      'reviewedAt': '2026-10-03T12:00:00Z',
      'rejectionReason': 'Please choose another date.'
    };
    final saved = preserveTenantRequests({
      'tenantRequests': [request('move')]
    }, {
      'tenantRequests': [rejected]
    });
    final stale = preserveTenantRequests(saved, {
      'tenantRequests': [request('move')]
    });
    final row = (stale['tenantRequests'] as List).single;
    expect(row['status'], 'Rejected');
    expect(row['rejectionReason'], 'Please choose another date.');
  });
  test('date edits and withdrawals survive stale owner snapshots', () {
    final original = request('move');
    final edited = {
      ...original,
      'requestedMoveOutDate': '2026-11-01',
      'message': 'New date',
      'bankName': 'New Bank',
      'bankAccountNumber': '009876',
      'tenantEditedAt': '2026-10-03T11:00:00Z'
    };
    final saved = preserveTenantRequests({
      'tenantRequests': [original]
    }, {
      'tenantRequests': [edited]
    });
    final stale = preserveTenantRequests(saved, {
      'tenantRequests': [original]
    });
    expect((stale['tenantRequests'] as List).single['requestedMoveOutDate'],
        '2026-11-01');
    expect((stale['tenantRequests'] as List).single['bankName'], 'New Bank');
    expect((stale['tenantRequests'] as List).single['bankAccountNumber'],
        '009876');
    final withdrawn = {
      ...edited,
      'status': 'Withdrawn',
      'tenantEditedAt': '2026-10-03T12:00:00Z'
    };
    final finalSaved = preserveTenantRequests(stale, {
      'tenantRequests': [withdrawn]
    });
    expect(
        (preserveTenantRequests(finalSaved, {
          'tenantRequests': [original]
        })['tenantRequests'] as List)
            .single['status'],
        'Withdrawn');
  });
  test('stale owner snapshot retains submitted request and newer review', () {
    final saved = {
      'tenantRequests': [
        request('submitted', status: 'Closed', reviewed: '2026-10-03T10:00:00Z')
      ]
    };
    final merged = preserveTenantRequests(saved, {
      'tenantRequests': [request('submitted'), request('new')]
    });
    final rows = merged['tenantRequests'] as List;
    expect(rows.length, 2);
    expect(rows.first['status'], 'Closed');
    expect(rows.first['requestedMoveOutDate'], '2026-10-31');
    expect(rows.first['bankAccountNumber'], '001234');
    expect(
        (preserveTenantRequests(saved, {'tenantRequests': []})['tenantRequests']
                as List)
            .length,
        1);
  });
  test('tenant save updates assigned row and retries concurrent change',
      () async {
    var patches = 0, reads = 0;
    final client = SupabaseClient('https://example.supabase.co', 'test-key',
        httpClient: MockClient((req) async {
      if (req.method == 'GET') {
        reads++;
        return http.Response(
            jsonEncode({
              'payload': {
                'tenantRequests': [request('remote')]
              },
              'updated_at': '2026-10-03T10:00:00Z'
            }),
            200,
            request: req,
            headers: {'content-type': 'application/json'});
      }
      expect(req.method, 'PATCH'); // INSERT/upsert is forbidden to tenants.
      expect(req.url.queryParameters.containsKey('updated_at'), isTrue);
      final rows = jsonDecode(req.body)['payload']['tenantRequests'] as List;
      expect(rows.map((e) => e['id']).toSet(), {'remote', 'local'});
      patches++;
      return http.Response(
          patches == 1 ? '[]' : '[{"tenant_email":"tenant@example.com"}]', 200,
          request: req, headers: {'content-type': 'application/json'});
    }));
    await SupabaseWorkspaceService(client).writeTenantSnapshot(
        ownerId: 'owner',
        tenantEmail: 'tenant@example.com',
        payload: {
          'tenantRequests': [request('local')]
        });
    expect(patches, 2);
    expect(reads, 2);
    await client.dispose();
  });
  test('cloud write errors propagate rather than reporting success', () async {
    final client = SupabaseClient('https://example.supabase.co', 'test-key',
        httpClient: MockClient((req) async => http.Response(
            '{"message":"permission denied","code":"42501"}', 403,
            request: req, headers: {'content-type': 'application/json'})));
    await expectLater(
        SupabaseWorkspaceService(client).writeTenantSnapshot(
            ownerId: 'owner', tenantEmail: 'tenant@example.com', payload: {}),
        throwsA(isA<PostgrestException>()));
    await client.dispose();
  });
}
