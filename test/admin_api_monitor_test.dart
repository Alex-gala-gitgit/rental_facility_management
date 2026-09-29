import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rental_facility_management/admin/admin_app.dart';

void main() {
  testWidgets('Supabase usage monitor shows live quotas and scope warning',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: AdminSupabaseUsagePage(usage: {
            'projectRef': 'poftsyskfuyeznbzxpow',
            'databaseBytes': 262144000,
            'databaseLimitBytes': 524288000,
            'storageBytes': 805306368,
            'storageLimitBytes': 1073741824,
            'storageObjects': 42,
            'monthlyActiveUsers': 25,
            'monthlyActiveUsersLimit': 50000,
            'measuredAt': '2026-08-29T10:00:00Z',
          }),
        ),
      ),
    ));

    expect(find.text('Supabase usage'), findsOneWidget);
    expect(find.text('250.0 MB'), findsOneWidget);
    expect(find.text('75.0%'), findsOneWidget);
    expect(find.textContaining('42 uploaded objects'), findsOneWidget);
    expect(find.textContaining('current project only'), findsOneWidget);
  });

  testWidgets('API monitor summarizes request health and recent calls',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: AdminApiMonitorPage(monitor: {
            'windowHours': 24,
            'totalRequests': 25,
            'successfulRequests': 23,
            'failedRequests': 2,
            'errorRate': 8.0,
            'averageLatencyMs': 184,
            'p95LatencyMs': 620,
            'slowRequests': 1,
            'sampleSize': 25,
            'truncated': false,
            'lastRequestAt': '2026-08-23T10:00:00Z',
            'endpoints': [
              {
                'functionName': 'invoice-portal',
                'requests': 20,
                'failures': 2,
                'errorRate': 10.0,
                'averageLatencyMs': 200,
                'lastRequestAt': '2026-08-23T10:00:00Z',
              }
            ],
            'recentRequests': [
              {
                'function_name': 'invoice-portal',
                'method': 'POST',
                'status_code': 201,
                'duration_ms': 215,
                'error_code': null,
                'created_at': '2026-08-23T10:00:00Z',
              }
            ],
          }),
        ),
      ),
    ));

    expect(find.text('API monitor'), findsOneWidget);
    expect(find.text('25'), findsOneWidget);
    expect(find.text('8.0% error rate'), findsOneWidget);
    expect(find.text('184 ms'), findsOneWidget);
    expect(find.text('invoice-portal · POST'), findsOneWidget);
    expect(find.text('POST · 215 ms · completed'), findsOneWidget);
  });

  testWidgets('API monitor has a clear empty state', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: AdminApiMonitorPage(monitor: {'windowHours': 24}),
        ),
      ),
    ));

    expect(find.text('No API calls recorded yet.'), findsNWidgets(2));
    expect(find.text('0.0% error rate'), findsOneWidget);
  });

  testWidgets('only non-Diamond accounts expose founder delete action',
      (tester) async {
    tester.view.physicalSize = const Size(1440, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final accounts = [
      {
        'id': 'founder',
        'name': 'Founder',
        'email': 'founder@example.com',
        'role': 'owner',
        'membership': 'diamond',
        'subscriptionStatus': 'active',
        'status': 'active',
      },
      {
        'id': 'tenant',
        'name': 'Tenant',
        'email': 'tenant@example.com',
        'role': 'tenant',
        'membership': null,
        'subscriptionStatus': null,
        'status': 'active',
      },
    ];
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: AdminAccountsPage(
            accounts: accounts,
            canManage: true,
            onResetPassword: (_) async {},
            onEditAccount: (account) async => account,
            onSetMembership: (_, __, ___) async {},
            onDeleteAccount: (_) async {},
          ),
        ),
      ),
    ));

    expect(find.text('Delete'), findsOneWidget);
  });
}
