import 'dart:convert';
import 'dart:typed_data';

import 'package:excel/excel.dart' as xlsx;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rental_facility_management/cloud/supabase_workspace_service.dart';
import 'package:rental_facility_management/cloud/supabase_config.dart';
import 'package:rental_facility_management/cloud/supabase_auth_service.dart';
import 'package:rental_facility_management/main.dart';
import 'package:rental_facility_management/persistence/persistence_contract.dart';
import 'package:rental_facility_management/rentflow/rentflow_app.dart';
import 'package:rental_facility_management/subscription/subscription_models.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class TestPersistence implements AppPersistence {
  String? snapshot;

  @override
  String get storageDescription => 'test storage';

  @override
  Future<void> clear() async => snapshot = null;

  @override
  Future<void> close() async {}

  @override
  Future<String?> readSnapshot() async => snapshot;

  @override
  Future<void> writeSnapshot(String value) async => snapshot = value;
}

class FakeWorkspaceService extends SupabaseWorkspaceService {
  FakeWorkspaceService(this.ownerSnapshot)
      : super(SupabaseClient('https://example.supabase.co', 'test-key'));

  Map<String, dynamic>? ownerSnapshot;

  @override
  Future<Map<String, dynamic>?> readOwnerSnapshot(String ownerId) async =>
      ownerSnapshot;

  @override
  Future<List<TenantCloudSnapshot>> readOwnerTenantSnapshots(
          String ownerId) async =>
      const [];

  @override
  Future<void> writeOwnerSnapshot(
      String ownerId, Map<String, dynamic> payload) async {
    ownerSnapshot = payload;
  }
}

void main() {
  test('temporary profile lookup failures preserve an active cloud session',
      () {
    expect(
      shouldTerminateCloudSessionAfterProfileLookup(
        sessionStillExists: true,
        lookupCompleted: false,
        profileFound: false,
      ),
      isFalse,
    );
    expect(
      shouldTerminateCloudSessionAfterProfileLookup(
        sessionStillExists: true,
        lookupCompleted: true,
        profileFound: true,
      ),
      isFalse,
    );
    expect(
      shouldTerminateCloudSessionAfterProfileLookup(
        sessionStillExists: true,
        lookupCompleted: true,
        profileFound: false,
      ),
      isTrue,
    );
    expect(
      shouldTerminateCloudSessionAfterProfileLookup(
        sessionStillExists: false,
        lookupCompleted: false,
        profileFound: false,
      ),
      isTrue,
    );
  });

  testWidgets(
      'cloud login offers tenant access, language switch, and no Google action',
      (tester) async {
    tester.view.physicalSize = const Size(500, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final store = RentalStore(
      seedDemoData: false,
      cloudAuth: SupabaseAuthService(
        SupabaseClient(
          'https://example.supabase.co',
          'test-key',
          authOptions: const AuthClientOptions(autoRefreshToken: false),
        ),
      ),
    );

    await tester.pumpWidget(RentalFacilityApp(initialStore: store));
    await tester.pump(const Duration(milliseconds: 2200));

    expect(find.text('EN'), findsOneWidget);
    expect(find.text('Tenant'), findsOneWidget);
    expect(find.textContaining('Continue with Google'), findsNothing);

    await tester.tap(find.text('Tenant'));
    await tester.pump();
    expect(find.text('Log in as Tenant'), findsOneWidget);
    expect(find.text('Remember me'), findsOneWidget);
    expect(find.text('Create new account'), findsNothing);

    await tester.tap(find.text('中'));
    await tester.pump();
    expect(find.text('欢迎回来'), findsOneWidget);
    expect(find.text('记住我'), findsOneWidget);
  });

  test('login identifier and language persist independently of workspace data',
      () async {
    final preferences = TestPersistence();
    final first = RentalStore(
      seedDemoData: false,
      loginPreferences: preferences,
    );
    first.updateRememberedOwnerEmail(
      remember: true,
      email: 'tenant@example.com',
    );
    first.updateLanguage(AppLanguage.chinese);
    await Future<void>.delayed(Duration.zero);

    final restored = RentalStore(
      seedDemoData: false,
      loginPreferences: preferences,
    );
    await restored.initializePersistence();

    expect(restored.rememberOwnerEmail, isTrue);
    expect(restored.rememberedOwnerEmail, 'tenant@example.com');
    expect(restored.appLanguage, AppLanguage.chinese);
  });

  test('production and UAT hosts never share Supabase projects or redirects',
      () {
    expect(
      SupabaseConfig.environmentForHost('homeops360.app'),
      AppEnvironment.production,
    );
    expect(
      SupabaseConfig.environmentForHost(
          'facility-billing-management.pages.dev'),
      AppEnvironment.uat,
    );
    expect(SupabaseConfig.isUatHost('homeops360.app'), isFalse);
    expect(
      SupabaseConfig.isUatHost('facility-billing-management.pages.dev'),
      isTrue,
    );
    expect(
      SupabaseConfig.authRedirectUrlForHost('homeops360.app'),
      'https://homeops360.app/',
    );
    expect(
      SupabaseConfig.authRedirectUrlForHost(
          'facility-billing-management.pages.dev'),
      'https://facility-billing-management.pages.dev/',
    );
  });

  test('production billing begins in August and never before launch', () {
    final store = RentalStore(
      now: DateTime(2026, 7, 31),
      seedDemoData: false,
      reportingStartMonth: DateTime(2026, 8),
    );
    store.users.add(AppUser(
      id: 'production-owner',
      name: 'Production Owner',
      email: 'owner@example.com',
      role: UserRole.owner,
    ));
    store.loginAs(UserRole.owner);
    final facility = store.addFacility(
      name: 'Launch Facility',
      addressLine: '1 Launch Road',
      postcode: '50000',
      city: 'Kuala Lumpur',
      state: 'Wilayah Persekutuan Kuala Lumpur',
      installmentAmount: 1000,
      maintenanceFee: 100,
      insuranceFee: 0,
    )!;
    store.addTenantToFacility(
      facility: facility,
      fullName: 'Launch Tenant',
      email: 'tenant@example.com',
      originAddress: '2 Tenant Road',
      originState: 'Selangor',
      originCity: 'Petaling Jaya',
      originPostcode: '47301',
      dateOfBirth: DateTime(1990, 1, 1),
      sex: 'Male',
      unitName: 'A-1',
      monthlyRent: 800,
      leaseStart: DateTime(2026, 7, 1),
      leaseEnd: DateTime(2027, 6, 30),
      electricityPackage: UtilityPackage.excluded,
      waterPackage: UtilityPackage.included,
      internetPackage: UtilityPackage.included,
      carParkIncluded: false,
      carParkDetails: '',
    );

    expect(store.bills, isEmpty);
  });

  test('new tenancy only creates the current eligible month bill', () {
    final store = RentalStore(
      now: DateTime(2026, 7, 23),
      seedDemoData: false,
      reportingStartMonth: DateTime(2026, 7),
    );
    store.users.add(AppUser(
      id: 'owner',
      name: 'Owner',
      email: 'owner@example.com',
      role: UserRole.owner,
    ));
    store.loginAs(UserRole.owner);
    final facility = store.addFacility(
      name: 'Ready Property',
      addressLine: '1 Test Road',
      postcode: '50000',
      city: 'Kuala Lumpur',
      state: 'Wilayah Persekutuan Kuala Lumpur',
      installmentAmount: 0,
      maintenanceFee: 0,
      insuranceFee: 0,
    )!;
    store.addTenantToFacility(
      facility: facility,
      fullName: 'New Tenant',
      email: 'new@example.com',
      originAddress: '2 Test Road',
      originState: 'Selangor',
      originCity: 'Petaling Jaya',
      originPostcode: '47301',
      dateOfBirth: DateTime(1990, 1, 1),
      sex: 'Female',
      unitName: 'A-1',
      monthlyRent: 900,
      leaseStart: DateTime(2026, 7, 1),
      leaseEnd: DateTime(2027, 6, 30),
      electricityPackage: UtilityPackage.included,
      waterPackage: UtilityPackage.included,
      internetPackage: UtilityPackage.included,
      carParkIncluded: false,
      carParkDetails: '',
    );

    expect(store.bills, hasLength(1));
    expect(store.bills.single.month, DateTime(2026, 7));
  });

  test(
      'production restore removes bills and review history from before tenant registration',
      () async {
    final persistence = TestPersistence();
    final source = RentalStore(
      now: DateTime(2026, 7, 24),
      persistence: persistence,
      seedDemoData: false,
      reportingStartMonth: DateTime(2026, 7),
    );
    await source.initializePersistence();
    source.users.add(AppUser(
      id: 'owner',
      name: 'Owner',
      email: 'owner@example.com',
      role: UserRole.owner,
    ));
    source.loginAs(UserRole.owner);
    final facility = source.addFacility(
      name: 'Production Property',
      addressLine: '1 Test Road',
      postcode: '50000',
      city: 'Kuala Lumpur',
      state: 'Wilayah Persekutuan Kuala Lumpur',
      installmentAmount: 0,
      maintenanceFee: 0,
      insuranceFee: 0,
    )!;
    source.addTenantToFacility(
      facility: facility,
      fullName: 'New Tenant',
      email: 'tenant@example.com',
      originAddress: '2 Test Road',
      originState: 'Selangor',
      originCity: 'Petaling Jaya',
      originPostcode: '47301',
      dateOfBirth: DateTime(1990, 1, 1),
      sex: 'Female',
      unitName: 'A-1',
      monthlyRent: 800,
      leaseStart: DateTime(2026, 7, 1),
      leaseEnd: DateTime(2027, 6, 30),
      electricityPackage: UtilityPackage.included,
      waterPackage: UtilityPackage.included,
      internetPackage: UtilityPackage.included,
      carParkIncluded: false,
      carParkDetails: '',
    );
    final tenancy = source.tenancies.single;
    final invalidBill = MonthlyBill(
      id: 'invalid-pre-tenancy-bill',
      facilityId: facility.id,
      tenantId: tenancy.tenantId,
      month: DateTime(2025, 12),
      rentAmount: 800,
      electricityAmount: 0,
      waterAmount: 0,
      internetAmount: 0,
      status: PaymentStatus.approved,
    )
      ..amountPaid = 800
      ..submittedAt = DateTime(2025, 12, 3);
    source.bills.add(invalidBill);
    source.paymentReviewHistory.add(PaymentReviewEvent(
      id: 'invalid-review',
      billId: invalidBill.id,
      status: PaymentStatus.approved,
      timestamp: DateTime(2025, 12, 4),
    ));
    await source.flushPersistence();

    final restored = RentalStore(
      now: DateTime(2026, 7, 24),
      persistence: persistence,
      seedDemoData: false,
      reportingStartMonth: DateTime(2026, 7),
      cloudAuthoritative: true,
    );
    await restored.initializePersistence();

    expect(
      restored.bills.any((bill) => bill.id == invalidBill.id),
      isFalse,
    );
    expect(
      restored.paymentReviewHistory
          .any((event) => event.billId == invalidBill.id),
      isFalse,
    );
    expect(restored.billsForTenant(tenancy.tenantId), hasLength(1));
    expect(
      restored.billsForTenant(tenancy.tenantId).single.month,
      DateTime(2026, 7),
    );
  });

  test('legacy production snapshot can only migrate to its exact owner', () {
    final snapshot = <String, dynamic>{
      'users': [
        {
          'id': 'owner-a',
          'role': 'owner',
          'ownerAccessLevel': 'fullAccess',
          'email': 'owner-a@example.com',
        },
        {
          'id': 'tenant-a',
          'role': 'tenant',
          'email': 'tenant@example.com',
        },
      ],
    };

    expect(
      legacySnapshotBelongsToOwner(snapshot, 'OWNER-A@example.com'),
      isTrue,
    );
    expect(
      legacySnapshotBelongsToOwner(snapshot, 'owner-b@example.com'),
      isFalse,
    );
  });

  test('ambiguous multi-owner legacy snapshot is never auto-migrated', () {
    final snapshot = <String, dynamic>{
      'users': [
        {
          'role': 'owner',
          'ownerAccessLevel': 'fullAccess',
          'email': 'owner-a@example.com',
        },
        {
          'role': 'owner',
          'ownerAccessLevel': 'fullAccess',
          'email': 'owner-b@example.com',
        },
      ],
    };

    expect(
      legacySnapshotBelongsToOwner(snapshot, 'owner-a@example.com'),
      isFalse,
    );
  });

  test('owner cloud notification retains unread category and source details',
      () {
    final notification = OwnerCloudNotification.fromMap({
      'id': 'notification-1',
      'owner_id': 'owner-1',
      'category': 'request',
      'title': 'New tenant request',
      'message': 'Siti submitted a repair request.',
      'source_table': 'tenant_requests',
      'source_id': 'request-1',
      'read_at': null,
      'created_at': '2026-07-19T08:00:00.000Z',
    });

    expect(notification.ownerId, 'owner-1');
    expect(notification.category, 'request');
    expect(notification.sourceId, 'request-1');
    expect(notification.readAt, isNull);
  });

  test('money input normalization removes ambiguous leading zeros', () {
    expect(normalizeMoneyInputText('0300'), '300');
    expect(normalizeMoneyInputText('000'), '0');
    expect(normalizeMoneyInputText('00.50'), '0.50');
    expect(normalizeMoneyInputText('.50'), '0.50');
    expect(normalizeMoneyInputText('0'), '0');
    expect(normalizeMoneyInputText('3700.25'), '3700.25');
    expect(money(0), 'RM 0.00');
    expect(money(1509), 'RM 1,509.00');
  });

  testWidgets('prefilled RM input selects its value for immediate replacement',
      (tester) async {
    final controller = TextEditingController(text: '0.00');
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AppTextField(
            controller: controller,
            label: 'Extra Installment Payment',
          ),
        ),
      ),
    );

    await tester.tap(find.byType(TextField));
    await tester.pump();
    expect(controller.selection.baseOffset, 0);
    expect(controller.selection.extentOffset, 4);

    tester.testTextInput.enterText('567');
    await tester.pump();
    expect(controller.text, '567');
  });

  test('same-month facility cost edit retains extra installment payment', () {
    final store = RentalStore(
      now: DateTime(2026, 7, 22),
      seedDemoData: false,
    );
    store.users.add(AppUser(
      id: 'owner-production',
      name: 'Production Owner',
      email: 'owner@example.com',
      role: UserRole.owner,
    ));
    store.loginAs(UserRole.owner);
    final facility = store.addFacility(
      name: 'New Residence',
      addressLine: '1 Test Road',
      postcode: '50000',
      city: 'Kuala Lumpur',
      state: 'Wilayah Persekutuan Kuala Lumpur',
      installmentAmount: 1243,
      maintenanceFee: 266,
      insuranceFee: 0,
      insuranceFrequency: InsuranceFrequency.yearly,
      insuranceDueMonth: 1,
    )!;

    store.updateFacilityCosts(
      facility,
      installmentAmount: 1243,
      extraInstallmentPayment: 567,
      maintenanceFee: 266,
      insuranceFee: 0,
      insuranceFrequency: InsuranceFrequency.yearly,
      insuranceDueMonth: 1,
    );

    final version = store.costVersionForMonth(facility, DateTime(2026, 7));
    expect(version.extraInstallmentPayment, 567);
    expect(store.monthlyFacilityOutflow(facility), 2076);
  });

  test('tenant phone verification accepts the stored final four digits', () {
    expect(tenantPhoneVerificationMatches('+60165666878', '6878'), isTrue);
    expect(
        tenantPhoneVerificationMatches('+60 16-566 6878', '6 8 7 8'), isTrue);
    expect(tenantPhoneVerificationMatches('+60165666878', '6788'), isFalse);
  });

  test('invoice due date is three days after owner sends it', () {
    final sentAt = DateTime(2026, 7, 30, 20, 15);
    expect(
      invoiceDueDateFromSentAt(sentAt),
      DateTime(2026, 8, 2, 20, 15),
    );
  });

  test('tenant input validation rejects malformed contact and profile data',
      () {
    expect(isValidEmailInput('alex@gmail..co.asd'), isFalse);
    expect(isValidEmailInput('alex@example.com'), isTrue);
    expect(parseDateInput('25872654'), isNull);
    expect(parseDateInput('31/02/2026'), isNull);
    expect(parseDateInput('19/07/2026'), DateTime(2026, 7, 19));
    expect(isValidSexInput('MALE'), isTrue);
    expect(isValidSexInput('unknown'), isFalse);
  });

  test('Malaysia postcode dataset includes complete Ipoh coverage', () {
    final ipohPostcodes = malaysiaPostcodesFor('Perak', 'Ipoh');

    expect(ipohPostcodes.length, greaterThan(100));
    expect(
        ipohPostcodes,
        containsAll(<String>[
          '30000',
          '30100',
          '30200',
          '30300',
          '30450',
          '30590',
          '30750',
          '30990',
          '31350',
          '31400',
          '31500',
        ]));
  });

  test('production workspace starts without demo business records', () {
    final store = RentalStore(seedDemoData: false);

    expect(store.facilities, isEmpty);
    expect(store.tenancies, isEmpty);
    expect(store.bills, isEmpty);
  });

  test('legacy demo tenant identifiers never erase genuine facilities',
      () async {
    final persistence = TestPersistence();
    final source = RentalStore(
      now: DateTime(2026, 7, 23),
      persistence: persistence,
    );
    await source.initializePersistence();
    source.loginAs(UserRole.owner);
    source.addFacility(
      name: 'Genuine Owner Facility',
      addressLine: '1 Real Road',
      postcode: '50000',
      city: 'Kuala Lumpur',
      state: 'Wilayah Persekutuan Kuala Lumpur',
      installmentAmount: 1000,
      maintenanceFee: 100,
      insuranceFee: 0,
    );
    await source.flushPersistence();
    final snapshot = jsonDecode(persistence.snapshot!) as Map<String, dynamic>;
    final workspace = FakeWorkspaceService(snapshot);
    final restored = RentalStore(
      now: DateTime(2026, 7, 23),
      seedDemoData: false,
      cloudWorkspace: workspace,
      cloudAuthoritative: true,
    );

    await restored.restoreCloudWorkspace(const CloudProfile(
      id: 'owner-real',
      email: 'owner@example.com',
      fullName: 'Real Owner',
      role: 'owner',
    ));

    expect(
      restored.facilities.any((item) => item.name == 'Genuine Owner Facility'),
      isTrue,
    );
  });

  test('new cloud owner never inherits the UAT device workspace', () async {
    final workspace = FakeWorkspaceService(null);
    final store = RentalStore(
      now: DateTime(2026, 8, 24),
      seedDemoData: true,
      cloudWorkspace: workspace,
      cloudAuthoritative: false,
    );
    expect(store.facilities, isNotEmpty);

    await store.restoreCloudWorkspace(const CloudProfile(
      id: 'new-cloud-owner',
      email: 'new-owner@example.com',
      fullName: 'New Owner',
      role: 'owner',
    ));

    expect(store.currentUser?.id, 'new-cloud-owner');
    expect(store.facilities, isEmpty);
    expect(store.tenancies, isEmpty);
    expect(store.bills, isEmpty);
    expect(store.tenantRequests, isEmpty);
    expect(workspace.ownerSnapshot?['facilities'], isEmpty);
  });

  testWidgets('tenant request tab always shows the new request button',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final store = RentalStore(now: DateTime(2026, 8, 24));
    store.loginAs(UserRole.tenant);

    await tester.pumpWidget(RentalStoreScope(
      store: store,
      child: const MaterialApp(home: Scaffold(body: TenantRequestsTab())),
    ));
    await tester.pumpAndSettle();

    final addButton = find.byKey(const Key('tenant_new_request_button'));
    expect(addButton, findsOneWidget);
    expect(tester.getRect(addButton).bottom, lessThan(844));
    expect(tester.takeException(), isNull);
  });

  testWidgets('owner can search notifications by keyword', (tester) async {
    await tester.binding.setSurfaceSize(const Size(820, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final store = RentalStore(now: DateTime(2026, 9, 30));
    store.loginAs(UserRole.owner);
    store.notifications
      ..clear()
      ..addAll([
        AppNotification(
          id: 'maintenance-notification',
          message: 'Maintenance request for leaking tap',
          createdAt: DateTime(2026, 9, 30, 9),
        ),
        AppNotification(
          id: 'payment-notification',
          message: 'Payment proof received from tenant',
          createdAt: DateTime(2026, 9, 30, 10),
        ),
      ]);

    await tester.pumpWidget(RentalStoreScope(
      store: store,
      child: const MaterialApp(home: NotificationsScreen()),
    ));
    await tester.pumpAndSettle();

    final search = find.byKey(const Key('owner_notification_search'));
    expect(search, findsOneWidget);
    await tester.enterText(search, 'leaking');
    await tester.pump();

    expect(find.text('Maintenance request for leaking tap'), findsOneWidget);
    expect(find.text('Payment proof received from tenant'), findsNothing);
    expect(find.text('1 result'), findsOneWidget);

    await tester.enterText(search, 'not found');
    await tester.pump();
    expect(
      find.byKey(const Key('owner_notification_no_results')),
      findsOneWidget,
    );
  });

  test('business data and payment metadata survive an app restart', () async {
    final persistence = TestPersistence();
    final now = DateTime(2026, 7, 1);
    final first = RentalStore(now: now, persistence: persistence);
    await first.initializePersistence();
    first.loginAs(UserRole.owner);
    final owner = first.currentUser!;
    await first.updateOwnerAccount(
      name: owner.name,
      email: owner.email,
      phoneNumber: owner.phoneNumber,
      originAddress: owner.originAddress ?? '',
      avatarStyle: owner.avatarStyle,
      paymentReminderAfterDays: owner.paymentReminderAfterDays,
      paymentReminderFrequencyDays: owner.paymentReminderFrequencyDays,
      bankName: 'Maybank',
      bankAccountNumber: '108270060924',
      bankBeneficiary: 'LAU YIK FEI',
      paymentQrName: 'owner-qr.png',
      paymentQrBase64: 'cXItYnl0ZXM=',
    );
    final bill = first.bills.first;
    bill
      ..paymentDate = DateTime(2026, 7, 3)
      ..paymentReference = 'MBB-12345'
      ..portalExpiresAt = DateTime(2026, 7, 4, 12)
      ..utilityEvidenceFileName = 'meter-evidence.jpg'
      ..utilityEvidenceBytes = Uint8List.fromList(<int>[1, 2, 3, 4]);
    first.tenancies.first.electricityBillingMode =
        ElectricityBillingMode.combined;
    first.addAdditionalIncome(
      facility: first.ownerFacilities.first,
      month: DateTime(2026, 7),
      category: 'Parking',
      amount: 180,
      note: 'Persistent audit record',
    );
    await first.flushPersistence();
    final savedSnapshot =
        jsonDecode(persistence.snapshot!) as Map<String, dynamic>;
    expect(savedSnapshot['ownerAccount'], isA<Map<String, dynamic>>());

    final restored = RentalStore(now: now, persistence: persistence);
    await restored.initializePersistence();

    expect(
      restored.additionalIncomes
          .any((item) => item.note == 'Persistent audit record'),
      isTrue,
    );
    final restoredBill =
        restored.bills.firstWhere((item) => item.id == bill.id);
    expect(restoredBill.paymentReference, 'MBB-12345');
    expect(restoredBill.paymentDate, DateTime(2026, 7, 3));
    expect(restoredBill.portalExpiresAt, DateTime(2026, 7, 4, 12));
    expect(restoredBill.utilityEvidenceFileName, 'meter-evidence.jpg');
    expect(restoredBill.utilityEvidenceBytes, <int>[1, 2, 3, 4]);
    expect(
      restored.tenancies.first.electricityBillingMode,
      ElectricityBillingMode.combined,
    );
    final restoredOwner =
        restored.users.firstWhere((user) => user.role == UserRole.owner);
    expect(restoredOwner.bankName, 'Maybank');
    expect(restoredOwner.bankAccountNumber, '108270060924');
    expect(restoredOwner.bankBeneficiary, 'LAU YIK FEI');
    expect(restoredOwner.paymentQrName, 'owner-qr.png');
    expect(restoredOwner.paymentQrBase64, 'cXItYnl0ZXM=');
  });

  test('cloud login retains workspace payment details without an owner row',
      () async {
    final persistence = TestPersistence();
    final source = RentalStore(
      now: DateTime(2026, 7, 30),
      seedDemoData: false,
      persistence: persistence,
    );
    await source.initializePersistence();
    final snapshot = jsonDecode(persistence.snapshot!) as Map<String, dynamic>;
    snapshot
      ..['users'] = <Map<String, dynamic>>[]
      ..['ownerAccount'] = <String, dynamic>{
        'ownerId': 'cloud-owner',
        'bankName': 'Maybank',
        'bankAccountNumber': '108270060924',
        'bankBeneficiary': 'LAU YIK FEI',
        'paymentQrName': 'owner-qr.png',
        'paymentQrBase64': 'cXItYnl0ZXM=',
      };
    final workspace = FakeWorkspaceService(snapshot);
    final restored = RentalStore(
      now: DateTime(2026, 7, 30),
      seedDemoData: false,
      cloudWorkspace: workspace,
      cloudAuthoritative: true,
    );

    await restored.restoreCloudWorkspace(const CloudProfile(
      id: 'cloud-owner',
      email: 'owner@example.com',
      fullName: 'Cloud Owner',
      role: 'owner',
    ));

    expect(restored.currentUser, isNotNull);
    expect(restored.currentUser!.bankName, 'Maybank');
    expect(restored.currentUser!.bankAccountNumber, '108270060924');
    expect(restored.currentUser!.bankBeneficiary, 'LAU YIK FEI');
    expect(restored.currentUser!.paymentQrName, 'owner-qr.png');
    expect(restored.currentUser!.paymentQrBase64, 'cXItYnl0ZXM=');
  });

  test('monthly invoice workflow is created once and owner is notified', () {
    final store = RentalStore(now: DateTime(2026, 7, 1));

    final reminder = store.notifications.where(
      (item) => item.id == 'invoice_preparation_2026_7',
    );
    expect(reminder, hasLength(1));
    expect(reminder.single.message, contains('billing actions pending'));
    expect(reminder.single.category, 'Utility reading');
    expect(
      store.bills.where((bill) =>
          bill.month == DateTime(2026, 7) &&
          bill.status == PaymentStatus.notSubmitted),
      isNotEmpty,
    );
  });

  test('fully included utility package creates invoice without owner reading',
      () {
    final store = RentalStore(now: DateTime(2026, 7, 1));
    store.loginAs(UserRole.owner);
    final tenancy = store.tenancies.firstWhere(
      (item) => item.utilitiesFullyIncluded,
    );
    final bill = store.bills.firstWhere(
      (item) =>
          item.tenantId == tenancy.tenantId && item.month == DateTime(2026, 7),
    );

    expect(bill.utilityEvidenceFileName, isNull);
    expect(bill.status, PaymentStatus.notSubmitted);
    expect(store.pendingUtilityBillsThisMonth, contains(bill));

    store.recordInvoicePortalExpiry(bill, DateTime(2026, 7, 4));
    expect(bill.status, PaymentStatus.pendingTenantPayment);
    expect(store.pendingUtilityBillsThisMonth, isNot(contains(bill)));
  });

  test('tiered electricity calculation is progressive and rounded', () {
    final store = RentalStore(seedDemoData: false);
    store.updateElectricityTariffTiers(const [
      ElectricityTariffTier(fromKwh: 0, toKwh: 100, ratePerKwh: 0.50),
      ElectricityTariffTier(fromKwh: 101, toKwh: 200, ratePerKwh: 0.60),
      ElectricityTariffTier(fromKwh: 201, toKwh: null, ratePerKwh: 0.70),
    ]);

    expect(store.calculateElectricityCharge(50), 25.00);
    expect(store.calculateElectricityCharge(150), 80.00);
    expect(store.calculateElectricityCharge(250), 145.00);
  });

  test('each facility keeps and applies its own electricity tariff', () {
    final store = RentalStore(now: DateTime(2026, 7, 1));
    store.loginAs(UserRole.owner);
    final first = store.ownerFacilities[0];
    final second = store.ownerFacilities[1];
    final secondBefore = List<ElectricityTariffTier>.from(
      second.electricityTariffTiers,
    );

    store.updateFacilityElectricityTariffTiers(first, const [
      ElectricityTariffTier(fromKwh: 0, toKwh: null, ratePerKwh: 1.00),
    ]);

    expect(store.calculateElectricityChargeForFacility(first, 50), 50.00);
    expect(
      store.calculateElectricityChargeForFacility(second, 50),
      isNot(50.00),
    );
    expect(second.electricityTariffTiers.length, secondBefore.length);
    expect(
      second.electricityTariffTiers.first.ratePerKwh,
      secondBefore.first.ratePerKwh,
    );
  });

  test('tariff changes preserve completed bills and apply to the next bill',
      () {
    final store = RentalStore(now: DateTime(2026, 7, 1));
    store.loginAs(UserRole.owner);
    store.ownerAccessConfig = const OwnerAccessConfig(
      electricityTariffEnabled: true,
    );
    final facility = store.ownerFacilities.first;
    final draftBills = store.bills
        .where((bill) =>
            bill.facilityId == facility.id &&
            bill.month == DateTime(2026, 7) &&
            bill.status == PaymentStatus.notSubmitted)
        .toList();
    expect(draftBills.length, greaterThanOrEqualTo(2));

    store.updateFacilityElectricityTariffTiers(facility, const [
      ElectricityTariffTier(fromKwh: 0, toKwh: null, ratePerKwh: 1),
    ]);
    final completedBill = draftBills.first;
    store.updateBillUtilities(
      completedBill,
      electricityUsageKwh: 50,
      waterAmount: 0,
      internetAmount: 0,
      utilityEvidenceFileName: 'completed-meter.jpg',
    );
    completedBill.status = PaymentStatus.approved;

    store.updateFacilityElectricityTariffTiers(facility, const [
      ElectricityTariffTier(fromKwh: 0, toKwh: null, ratePerKwh: 2),
    ]);

    expect(completedBill.electricityAmount, 50);
    expect(completedBill.electricityRatePerKwh, 1);
    expect(completedBill.electricityTariffSummary, contains('RM 1.000'));

    final nextBill = draftBills.last;
    store.updateBillUtilities(
      nextBill,
      electricityUsageKwh: 50,
      waterAmount: 0,
      internetAmount: 0,
      utilityEvidenceFileName: 'next-meter.jpg',
    );
    expect(nextBill.electricityAmount, 100);
    expect(nextBill.electricityRatePerKwh, 2);
    expect(nextBill.electricityTariffSummary, contains('RM 2.000'));
  });

  test('owner meter reading updates exact utility total and payment state', () {
    final store = RentalStore(now: DateTime(2026, 7, 1));
    final bill = store.bills.firstWhere(
      (item) => item.month.year == 2026 && item.month.month == 7,
    );
    bill.status = PaymentStatus.notSubmitted;

    store.updateBillUtilities(
      bill,
      electricityUsageKwh: 14.33,
      waterAmount: 25,
      internetAmount: 0,
      generalElectricAmount: 10,
      parkingRentalAmount: 50,
      utilityEvidenceFileName: 'meter.jpg',
    );

    expect(bill.electricityAmount, 7.39);
    expect(bill.totalUtilityAmount, 42.39);
    expect(bill.totalAmount, bill.rentAmount + 92.39);
    expect(bill.status, PaymentStatus.notSubmitted);
  });

  test('utility history can be filtered by month and sorted', () {
    MonthlyBill historyBill({
      required String id,
      required String tenantId,
      required int month,
      required double usage,
      required int reviewDay,
    }) {
      return MonthlyBill(
        id: id,
        facilityId: 'facility',
        tenantId: tenantId,
        month: DateTime(2026, month),
        rentAmount: 0,
        electricityAmount: 0,
        waterAmount: 0,
        internetAmount: 0,
        electricityUsageKwh: usage,
        reviewedAt: DateTime(2026, month, reviewDay),
      );
    }

    final bills = <MonthlyBill>[
      historyBill(
        id: 'aug-zara',
        tenantId: 'zara',
        month: 8,
        usage: 30,
        reviewDay: 3,
      ),
      historyBill(
        id: 'sep-zara',
        tenantId: 'zara',
        month: 9,
        usage: 25,
        reviewDay: 1,
      ),
      historyBill(
        id: 'sep-amy',
        tenantId: 'amy',
        month: 9,
        usage: 80,
        reviewDay: 2,
      ),
    ];
    const names = <String, String>{'zara': 'Zara', 'amy': 'Amy'};
    String tenantNameFor(String tenantId) => names[tenantId]!;

    expect(
      filterAndSortUtilityHistory(
        bills: bills,
        month: DateTime(2026, 9),
        sort: UtilityHistorySort.newest,
        tenantNameFor: tenantNameFor,
      ).map((bill) => bill.id),
      <String>['sep-amy', 'sep-zara'],
    );
    expect(
      filterAndSortUtilityHistory(
        bills: bills,
        month: null,
        sort: UtilityHistorySort.oldest,
        tenantNameFor: tenantNameFor,
      ).map((bill) => bill.id),
      <String>['aug-zara', 'sep-zara', 'sep-amy'],
    );
    expect(
      filterAndSortUtilityHistory(
        bills: bills,
        month: null,
        sort: UtilityHistorySort.tenantName,
        tenantNameFor: tenantNameFor,
      ).map((bill) => bill.id),
      <String>['sep-amy', 'sep-zara', 'aug-zara'],
    );
    expect(
      filterAndSortUtilityHistory(
        bills: bills,
        month: null,
        sort: UtilityHistorySort.highestUsage,
        tenantNameFor: tenantNameFor,
      ).map((bill) => bill.id),
      <String>['sep-amy', 'aug-zara', 'sep-zara'],
    );
  });

  test('unfinished past-month bill saves detected kWh before generation', () {
    final store = RentalStore(now: DateTime(2026, 7, 18));
    final bill = store.bills.firstWhere(
      (item) =>
          item.month.year == 2026 &&
          item.month.month == 3 &&
          item.status == PaymentStatus.notSubmitted,
    );

    store.updateBillUtilities(
      bill,
      electricityUsageKwh: 14.33,
      waterAmount: 25,
      internetAmount: 0,
      utilityEvidenceFileName: 'march-meter.jpg',
    );

    expect(bill.electricityAmount, 7.39);
    expect(bill.totalUtilityAmount, 32.39);
    expect(bill.totalAmount, 632.39);
    expect(bill.status, PaymentStatus.notSubmitted);

    store.updateBillUtilities(
      bill,
      electricityUsageKwh: 155.04,
      waterAmount: 25,
      internetAmount: 0,
      utilityEvidenceFileName: 'attempted-rewrite.jpg',
    );
    expect(
      bill.electricityAmount,
      7.39,
      reason: 'A generated past bill must remain immutable.',
    );
  });

  test('invoice PDF is valid and reconciles with the invoice total', () async {
    final invoice = RentalInvoice(
      id: 'INV-AUDIT-1',
      tenant: const TenantAccount(
        id: 'tenant-audit',
        name: 'Audit Tenant',
        email: 'audit@example.com',
        phone: '+60123456789',
        property: 'Audit Residence',
        unit: 'A-01',
        rent: 600,
        water: 25,
        internet: 0,
      ),
      period: 'Jul 2026',
      usagePeriod: 'Jun 2026',
      previousReading: 0,
      currentReading: 14.33,
      evidenceName: 'meter.jpg',
      evidenceBytes: base64Decode(
        'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII=',
      ),
      electricityAmountOverride: 7.39,
      generalElectricAmount: 10,
      parkingRentalAmount: 50,
      dueDate: DateTime(2026, 7, 6),
    );

    expect(invoice.total, 692.39);
    final bytes = await invoicePdf(invoice);
    expect(bytes.length, greaterThan(1000));
    expect(utf8.decode(bytes.take(4).toList()), '%PDF');

    final portalLink = tenantInvoiceLink(invoice.id, 'secure-test-token');
    final pdfLink = Uri.parse(
      'https://example.supabase.co/storage/v1/object/public/invoices/${invoice.id}.pdf',
    );
    final message = invoiceWhatsAppMessage(
      invoice,
      portalLink,
      pdfLink: pdfLink,
    );
    expect(portalLink.host, 'homeops360.app');
    expect(portalLink.queryParameters, {'pay': 'secure-test-token'});
    expect(portalLink.toString().length, lessThan(80));
    expect(
      tenantPortalTokenFromUri(portalLink),
      'secure-test-token',
    );
    expect(
      tenantPortalTokenFromUri(Uri.parse(
        'https://facility-billing-management.pages.dev/?invoice=legacy&token=legacy-token',
      )),
      'legacy-token',
    );
    expect(message, contains(portalLink.toString()));
    expect(message, isNot(contains(pdfLink.toString())));
    expect(message, contains('view the invoice PDF'));
    expect(message, contains('RM 692.39'));

    final grantedMessage = invoiceWhatsAppMessage(
      invoice,
      portalLink,
      tenantHasAccount: true,
    );
    expect(grantedMessage, contains('https://homeops360.app'));
    expect(grantedMessage, contains('Log in to HomeOps360'));
    expect(grantedMessage, isNot(contains(portalLink.toString())));

    final invitationLink = Uri.parse(
      'https://homeops360.app/?tenant-profile=secure-invitation-token',
    );
    final pendingMessage = invoiceWhatsAppMessage(
      invoice,
      portalLink,
      invitationLink: invitationLink,
    );
    expect(pendingMessage, contains(portalLink.toString()));
    expect(pendingMessage, contains(invitationLink.toString()));
    expect(pendingMessage, contains('valid for 72 hours'));
    expect(
      tenantPortalBaseUrlForHost('facility-billing-management.pages.dev'),
      'https://facility-billing-management.pages.dev/',
    );
    expect(
      tenantPortalBaseUrlForHost('homeops360.app'),
      'https://homeops360.app/',
    );
  });

  test('invoice PDF cannot omit required meter evidence', () async {
    final invoice = RentalInvoice(
      id: 'INV-MISSING-EVIDENCE',
      tenant: const TenantAccount(
        id: 'tenant-evidence',
        name: 'Evidence Tenant',
        email: 'evidence@example.com',
        phone: '+60123456789',
        property: 'Evidence Residence',
        unit: 'B-01',
        rent: 600,
        water: 0,
        internet: 0,
      ),
      period: 'Jul 2026',
      usagePeriod: 'Jun 2026',
      previousReading: 0,
      currentReading: 10,
      evidenceName: 'meter.jpg',
      dueDate: DateTime(2026, 7, 6),
    );

    await expectLater(invoicePdf(invoice), throwsStateError);
  });

  test('invoice omits evidence page when owner meter reading is not required',
      () async {
    final invoice = RentalInvoice(
      id: 'INV-NO-EVIDENCE-PAGE',
      tenant: const TenantAccount(
        id: 'tenant-no-evidence',
        name: 'Tenant Borne Electricity',
        email: 'tenant@example.com',
        phone: '+60123456789',
        property: 'Package Residence',
        unit: 'C-01',
        rent: 800,
        water: 0,
        internet: 0,
      ),
      period: 'Jul 2026',
      usagePeriod: 'Jun 2026',
      previousReading: 0,
      currentReading: 10,
      evidenceName: 'No owner evidence required',
      evidenceRequired: false,
      dueDate: DateTime(2026, 7, 6),
    );

    final bytes = await invoicePdf(invoice);
    expect(bytes.length, greaterThan(1000));
    expect(utf8.decode(bytes.take(4).toList()), '%PDF');
  });

  testWidgets('PDF payment slip gives the owner open and download actions',
      (tester) async {
    final bill = MonthlyBill(
      id: 'pdf-slip-bill',
      facilityId: 'facility',
      tenantId: 'tenant',
      month: DateTime(2026, 7),
      rentAmount: 800,
      electricityAmount: 0,
      waterAmount: 0,
      internetAmount: 0,
      slipFileName: 'tenant-payment.pdf',
      slipBytes: Uint8List.fromList('%PDF-test'.codeUnits),
    );
    final store = RentalStore(seedDemoData: false);
    await tester.pumpWidget(RentalStoreScope(
      store: store,
      child: MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () => showPaymentSlipAttachmentDialog(context, bill),
            child: const Text('Review attachment'),
          ),
        ),
      ),
    ));

    await tester.tap(find.text('Review attachment'));
    await tester.pumpAndSettle();

    expect(find.text('Open PDF'), findsOneWidget);
    expect(find.text('Download PDF'), findsOneWidget);
  });

  testWidgets('bill performance reviews the exact monthly payment slip',
      (tester) async {
    final store = RentalStore(now: DateTime(2026, 9, 2));
    store.loginAs(UserRole.owner);
    final tenancy = store.tenancies.first;
    final tenant = store.userFor(tenancy.tenantId);
    MonthlyBill paymentBill(String id, int month, String fileName, int marker) {
      return MonthlyBill(
        id: id,
        facilityId: tenancy.facilityId,
        tenantId: tenancy.tenantId,
        month: DateTime(2026, month),
        rentAmount: tenancy.monthlyRent,
        electricityAmount: 0,
        waterAmount: 0,
        internetAmount: 0,
        status: PaymentStatus.approved,
        slipFileName: fileName,
        slipBytes: Uint8List.fromList(<int>[marker, marker + 1]),
        amountPaid: tenancy.monthlyRent,
        submittedAt: DateTime(2026, month, 2),
        reviewedAt: DateTime(2026, month, 3),
      );
    }

    final august = paymentBill('exact-august', 8, 'august-slip.png', 10);
    final september =
        paymentBill('exact-september', 9, 'september-slip.png', 20);
    store.bills.addAll(<MonthlyBill>[august, september]);

    await tester.pumpWidget(
      RentalStoreScope(
        store: store,
        child: MaterialApp(
          home: Scaffold(
            body: ListView(
              children: [
                BillPerformanceCard(bill: august, tenant: tenant),
                BillPerformanceCard(bill: september, tenant: tenant),
              ],
            ),
          ),
        ),
      ),
    );

    await tester.tap(
      find.byKey(const ValueKey('review_payment_slip_exact-september')),
    );
    await tester.pumpAndSettle();

    expect(find.text('september-slip.png'), findsOneWidget);
    expect(find.text('august-slip.png'), findsNothing);
    expect(find.textContaining('Sep 2026'), findsWidgets);
  });

  test('detailed Excel export is a real workbook with financial sheets', () {
    final store = RentalStore(now: DateTime(2026, 7, 18));
    store.loginAs(UserRole.owner);
    final bytes = store.exportDetailedExcelWorkbookXlsx();
    final workbook = xlsx.Excel.decodeBytes(bytes);

    expect(
        workbook.tables.keys,
        containsAll(<String>[
          'Dashboard',
          'Properties & Tenants',
          'Tenant Rent Schedule',
          'Monthly Cashflow',
          'Expense Log',
          'Tenant Requests',
          'Payment Reviews',
        ]));
    expect(workbook.tables['Dashboard']!.maxRows, greaterThan(20));
    expect(workbook.tables['Tenant Rent Schedule']!.maxRows,
        greaterThan(store.bills.length));
    final billHeaders = workbook.tables['Tenant Rent Schedule']!.rows.first
        .map((cell) => cell?.value.toString())
        .toList();
    expect(
        billHeaders,
        containsAll(<String>[
          'Total Due',
          'Amount Paid',
          'Payment Date',
          'Payment Reference',
          'Status',
        ]));

    final dashboard = workbook.tables['Dashboard']!;
    final expectedCollection = store
        .yearlyFinancialSummary(2026)
        .fold<double>(0, (sum, month) => sum + month.collection);
    final expectedExpenses = store
        .yearlyFinancialSummary(2026)
        .fold<double>(0, (sum, month) => sum + month.expenses);
    double dashboardMetric(String label) {
      final row = dashboard.rows.firstWhere(
        (cells) => cells.isNotEmpty && cells.first?.value.toString() == label,
      );
      return double.parse(row[1]!.value.toString());
    }

    expect(
      dashboardMetric('Total Rental Collection'),
      closeTo(expectedCollection, 0.01),
    );
    expect(
      dashboardMetric('Total Expenses'),
      closeTo(expectedExpenses, 0.01),
    );

    final propertySheet = workbook.tables['Properties & Tenants']!;
    final agreementColumn = propertySheet.rows.first.indexWhere(
      (cell) => cell?.value.toString() == 'Agreement File',
    );
    expect(agreementColumn, greaterThanOrEqualTo(0));
    expect(
      propertySheet.rows[1][agreementColumn]?.value,
      isNull,
      reason: 'Missing agreement names must remain blank.',
    );
    expect(
      workbook.tables['Tenant Rent Schedule']!.rows[3][15]?.value,
      isNull,
      reason: 'Unpaid bills must not contain a fake payment date.',
    );
    expect(
      workbook.tables['Payment Reviews']!.rows[1][4]?.value,
      isNull,
      reason: 'Empty review reasons must remain blank.',
    );
  });

  test('tenant exports contain only the signed-in tenant data', () {
    final store = RentalStore(now: DateTime(2026, 7, 18));
    store.loginAs(UserRole.tenant);
    final tenant = store.currentUser!;
    final ownBills =
        store.bills.where((bill) => bill.tenantId == tenant.id).toList();

    final snapshot = store.exportTenantSnapshot();
    expect(snapshot['exportType'], 'tenant_backup');
    expect((snapshot['tenant'] as Map<String, dynamic>)['id'], tenant.id);
    expect(snapshot.containsKey('ownerAccount'), isFalse);
    expect(snapshot.containsKey('localAuthAccounts'), isFalse);
    expect(snapshot.containsKey('additionalIncomes'), isFalse);
    expect(snapshot.containsKey('additionalExpenses'), isFalse);
    expect(
      (snapshot['bills'] as List<dynamic>)
          .cast<Map<String, dynamic>>()
          .every((bill) => bill['tenantId'] == tenant.id),
      isTrue,
    );
    expect(
      (snapshot['facilities'] as List<dynamic>)
          .cast<Map<String, dynamic>>()
          .every((facility) => !facility.containsKey('installmentAmount')),
      isTrue,
    );

    final workbook =
        xlsx.Excel.decodeBytes(store.exportTenantExcelWorkbookXlsx());
    expect(
      workbook.tables.keys,
      containsAll(<String>[
        'My Profile',
        'My Tenancies',
        'Invoices & Payments',
        'My Requests',
        'Payment Reviews',
      ]),
    );
    expect(
      workbook.tables['Invoices & Payments']!.maxRows,
      ownBills.length + 1,
    );
    expect(workbook.tables.keys, isNot(contains('Expense Log')));
  });

  test('payment review transitions retain history and confirmation data', () {
    final store = RentalStore();
    final bill = store.pendingBills.first;
    bill
      ..paymentDate = DateTime(2026, 7, 3)
      ..paymentReference = 'BANK-7788';

    store.approveBill(bill);

    expect(bill.status, PaymentStatus.approved);
    expect(bill.paymentReference, 'BANK-7788');
    expect(
      store.paymentReviewHistory.any(
        (event) =>
            event.billId == bill.id && event.status == PaymentStatus.approved,
      ),
      isTrue,
    );
  });

  test('billing status wording stays short and consistent for owners', () {
    expect(paymentStatusLabel(PaymentStatus.notSubmitted), 'Pending Owner');
    expect(
      paymentStatusLabel(PaymentStatus.pendingTenantPayment),
      'Unpaid',
    );
    expect(paymentStatusLabel(PaymentStatus.pendingApproval), 'Pending Review');
    expect(paymentStatusLabel(PaymentStatus.approved), 'Approved');
    expect(paymentStatusLabel(PaymentStatus.rejected), 'Rejected');
  });

  test('tenant billing months distinguish unpaid, review, and paid', () {
    MonthlyBill bill(
      String id,
      PaymentStatus status, {
      String? slipFileName,
      DateTime? submittedAt,
    }) {
      return MonthlyBill(
        id: id,
        facilityId: 'facility',
        tenantId: 'tenant',
        month: DateTime(2026, 9),
        rentAmount: 100,
        electricityAmount: 0,
        waterAmount: 0,
        internetAmount: 0,
        status: status,
        slipFileName: slipFileName,
        submittedAt: submittedAt,
      );
    }

    expect(
      tenantBillingMonthState([
        bill('unpaid', PaymentStatus.pendingTenantPayment),
      ]),
      TenantBillingMonthState.unpaid,
    );
    expect(
      tenantBillingMonthState([
        bill(
          'review',
          PaymentStatus.pendingApproval,
          slipFileName: 'payment.png',
          submittedAt: DateTime(2026, 9, 2),
        ),
      ]),
      TenantBillingMonthState.awaitingReview,
    );
    expect(
      tenantBillingMonthState([
        bill('paid', PaymentStatus.approved),
      ]),
      TenantBillingMonthState.paid,
    );
  });

  testWidgets('invoice preview badge uses the bill payment status',
      (tester) async {
    final store = RentalStore(now: DateTime(2026, 9, 2));
    store.loginAs(UserRole.owner);
    final bill = store.bills.first;
    bill.status = PaymentStatus.approved;

    await tester.pumpWidget(
      RentalStoreScope(
        store: store,
        child: MaterialApp(
          home: Builder(
            builder: (context) => TextButton(
              onPressed: () => showGeneratedInvoicePreview(context, bill),
              child: const Text('Open invoice'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open invoice'));
    await tester.pumpAndSettle();

    expect(find.text('Approved'), findsOneWidget);
    expect(find.text('Awaiting review'), findsNothing);
    expect(find.text('Approved invoice locked'), findsOneWidget);
  });

  test('unverified tenant status uses the compact pending label', () {
    final tenant = AppUser(
      id: 'tenant_pending',
      name: 'Pending Tenant',
      email: '',
      role: UserRole.tenant,
      profileComplete: false,
    );
    final tenancy = Tenancy(
      id: 'tenancy_pending',
      facilityId: 'facility_pending',
      tenantId: tenant.id,
      unitName: 'A-1',
      monthlyRent: 800,
      electricityPackage: UtilityPackage.included,
      electricityCharge: 0,
      waterPackage: UtilityPackage.included,
      waterCharge: 0,
      internetPackage: UtilityPackage.included,
      internetCharge: 0,
      leaseStart: DateTime(2026, 8),
      leaseEnd: DateTime(2027, 7, 31),
      carParkIncluded: false,
      carParkDetails: '',
    );

    expect(tenantStatusText(tenant, tenancy), 'Pending');
  });

  test('tenant login access recognizes created and granted accounts', () {
    final pendingTenant = AppUser(
      id: 'tenant_access_pending',
      name: 'Pending Tenant',
      email: 'pending@example.com',
      role: UserRole.tenant,
      accountStatus: 'Pending',
      profileComplete: false,
    );
    expect(tenantHasLoginAccess(pendingTenant), isFalse);

    pendingTenant.accountStatus = 'Granted';
    expect(tenantHasLoginAccess(pendingTenant), isTrue);

    final createdTenant = AppUser(
      id: 'tenant_access_created',
      name: 'Created Tenant',
      email: 'created@example.com',
      role: UserRole.tenant,
      accountStatus: 'Pending',
      profileComplete: false,
      accountCreatedAt: DateTime(2026, 9, 9),
    );
    expect(tenantHasLoginAccess(createdTenant), isTrue);
  });

  test('owner dashboard reports completed payment and billing ratios', () {
    final store = RentalStore(now: DateTime(2026, 7, 18));
    store.loginAs(UserRole.owner);
    final currentBills = store.ownerCurrentMonthBills;

    expect(currentBills, isNotEmpty);
    expect(
      store.completedPaymentsThisMonth,
      currentBills
          .where((bill) => bill.status == PaymentStatus.approved)
          .length,
    );
    expect(
      store.completedBillingsThisMonth,
      currentBills
          .where((bill) => bill.status != PaymentStatus.notSubmitted)
          .length,
    );

    final pendingOwnerBill = currentBills.firstWhere(
      (bill) => bill.status == PaymentStatus.notSubmitted,
    );
    final previousCompletedBilling = store.completedBillingsThisMonth;
    store.updateBillUtilities(
      pendingOwnerBill,
      electricityUsageKwh: 10,
      waterAmount: 25,
      internetAmount: 0,
      utilityEvidenceFileName: 'meter.jpg',
    );
    expect(store.completedBillingsThisMonth, previousCompletedBilling);
    store.recordInvoicePortalExpiry(
      pendingOwnerBill,
      DateTime(2026, 7, 21),
    );
    expect(store.completedBillingsThisMonth, previousCompletedBilling + 1);
  });

  test('owner dashboard has no payment denominator when no bill is due', () {
    final store = RentalStore(now: DateTime(2026, 7, 18));
    store.loginAs(UserRole.owner);
    store.bills.clear();

    expect(store.ownerCurrentMonthBills, isEmpty);
    expect(store.completedPaymentsThisMonth, 0);
    expect(store.paymentWorkflowsThisMonth, 0);
  });

  test('owner dashboard counts one workflow per active tenancy', () {
    final store = RentalStore(now: DateTime(2026, 7, 18));
    store.loginAs(UserRole.owner);
    final original = store.ownerCurrentMonthBills.first;
    final originalCount = store.ownerCurrentMonthBills.length;

    store.bills.add(MonthlyBill(
      id: '${original.id}-duplicate',
      facilityId: original.facilityId,
      tenantId: original.tenantId,
      month: original.month,
      rentAmount: original.rentAmount,
      electricityAmount: original.electricityAmount,
      waterAmount: original.waterAmount,
      internetAmount: original.internetAmount,
      status: PaymentStatus.notSubmitted,
    ));

    expect(store.ownerCurrentMonthBills.length, originalCount);
  });

  test('invoice moves through owner billing, tenant payment, and approval',
      () async {
    final store = RentalStore(now: DateTime(2026, 7, 18));
    store.loginAs(UserRole.owner);
    final bill = store.pendingUtilityBillsThisMonth.first;

    expect(bill.status, PaymentStatus.notSubmitted);
    expect(store.pendingUtilityBillsThisMonth, contains(bill));
    expect(store.pendingBills, isNot(contains(bill)));

    store.updateBillUtilities(
      bill,
      electricityUsageKwh: 20,
      waterAmount: 25,
      internetAmount: 0,
      utilityEvidenceFileName: 'july-meter.jpg',
    );
    expect(bill.status, PaymentStatus.notSubmitted);
    expect(store.pendingUtilityBillsThisMonth, contains(bill));

    store.recordInvoicePortalExpiry(bill, DateTime(2026, 7, 21));
    expect(bill.status, PaymentStatus.pendingTenantPayment);
    expect(store.pendingUtilityBillsThisMonth, isNot(contains(bill)));

    store.submitPaymentSlip(
      bill,
      'july-payment.jpg',
      bill.totalAmount,
      slipBytes: Uint8List.fromList(<int>[1, 2, 3]),
    );
    expect(bill.status, PaymentStatus.pendingApproval);
    expect(store.pendingBills, contains(bill));

    await store.approveBill(bill);
    expect(bill.status, PaymentStatus.approved);
    expect(store.pendingBills, isNot(contains(bill)));
    expect(
      store.paymentReviewHistory.any(
        (event) =>
            event.billId == bill.id && event.status == PaymentStatus.approved,
      ),
      isTrue,
    );
  });

  test('rejected payment returns to tenant action and can be resubmitted',
      () async {
    final store = RentalStore(now: DateTime(2026, 7, 18));
    store.loginAs(UserRole.owner);
    final bill = store.pendingBills.first;
    const rejectionReason = 'The transferred amount does not match the bill.';
    final rejectedSlip = Uint8List.fromList(<int>[1, 2, 3]);
    store.submitPaymentSlip(
      bill,
      'rejected-payment.jpg',
      bill.totalAmount,
      slipBytes: rejectedSlip,
    );

    await store.rejectBill(bill, rejectionReason);
    expect(bill.status, PaymentStatus.rejected);
    expect(bill.rejectReason, rejectionReason);
    expect(store.pendingBills, isNot(contains(bill)));
    expect(
      store.paymentReviewHistory.any(
        (event) =>
            event.billId == bill.id &&
            event.status == PaymentStatus.rejected &&
            event.reason == rejectionReason,
      ),
      isTrue,
    );
    final rejectedEvent = store.paymentReviewHistory.last;
    expect(rejectedEvent.slipFileName, 'rejected-payment.jpg');
    expect(rejectedEvent.slipBytes, rejectedSlip);
    expect(bill.slipFileName, isNull);
    expect(bill.slipBytes, isNull);
    expect(bill.amountPaid, 0);

    final correctedSlip = Uint8List.fromList(<int>[4, 5, 6]);
    store.submitPaymentSlip(
      bill,
      'corrected-payment.jpg',
      bill.totalAmount,
      slipBytes: correctedSlip,
    );
    expect(bill.status, PaymentStatus.pendingApproval);
    expect(bill.rejectReason, isNull);
    expect(store.pendingBills, contains(bill));
    expect(bill.slipBytes, correctedSlip);
    expect(rejectedEvent.slipBytes, rejectedSlip);
    expect(
      paymentBillSnapshot(bill, rejectedEvent).slipBytes,
      rejectedSlip,
    );
  });

  test('approved payment is immutable and absent from every pending queue',
      () async {
    final store = RentalStore(now: DateTime(2026, 7, 18));
    store.loginAs(UserRole.owner);
    final bill = store.pendingBills.first;
    final originalTotal = bill.totalAmount;

    await store.approveBill(bill);
    store.updateBillUtilities(
      bill,
      electricityUsageKwh: 999,
      waterAmount: 999,
      internetAmount: 999,
      utilityEvidenceFileName: 'forbidden-change.jpg',
    );

    expect(bill.status, PaymentStatus.approved);
    expect(bill.totalAmount, originalTotal);
    expect(store.pendingBills, isNot(contains(bill)));
    expect(store.pendingUtilityBillsThisMonth, isNot(contains(bill)));
  });

  test('financial amendments never rewrite previous months', () {
    final store = RentalStore(now: DateTime(2026, 7, 18));
    final facility = store.facilities.first;
    final commitment = facility.extraCommitments.first;
    final januaryOutflow =
        store.monthlyFacilityOutflow(facility, month: DateTime(2026, 1));
    final januaryBill = store.bills.firstWhere(
        (bill) => bill.facilityId == facility.id && bill.month.month == 1);
    final januaryRent = januaryBill.rentAmount;
    final tenancy = store.tenancies.firstWhere(
      (item) => item.facilityId == facility.id,
    );
    final historicalRent = tenancy.contractHistory.first.monthlyRent;
    final historicalElectricityPackage =
        tenancy.contractHistory.first.electricityPackage;

    store.updateRecurringCommitment(
      commitment,
      name: commitment.name,
      amount: commitment.amount + 500,
      frequency: CommitmentFrequency.monthly,
      firstDueMonth: 7,
    );
    store.updateTenantContract(
      tenancy,
      unitName: tenancy.unitName,
      monthlyRent: tenancy.monthlyRent + 300,
      leaseStart: tenancy.leaseStart,
      leaseEnd: tenancy.leaseEnd,
      electricityPackage: tenancy.electricityPackage,
      waterPackage: tenancy.waterPackage,
      internetPackage: tenancy.internetPackage,
      carParkIncluded: tenancy.carParkIncluded,
      carParkDetails: tenancy.carParkDetails,
    );

    expect(
      store.monthlyFacilityOutflow(facility, month: DateTime(2026, 1)),
      januaryOutflow,
    );
    expect(januaryBill.rentAmount, januaryRent);
    expect(tenancy.contractHistory.first.monthlyRent, historicalRent);
    expect(
      tenancy.contractHistory.first.electricityPackage,
      historicalElectricityPackage,
    );
    expect(
      store.monthlyFacilityOutflow(facility, month: DateTime(2026, 7)),
      greaterThan(januaryOutflow),
    );
  });

  test('variable commitments can change only in the current month', () {
    final store = RentalStore(now: DateTime(2026, 7, 18));
    store.loginAs(UserRole.owner);
    final facility = store.facilities.first;

    store.addAdditionalExpense(
      facility: facility,
      category: 'TNB',
      amount: 180,
      note: 'July common meter',
      kind: PropertyExpenseKind.variableCommitment,
    );
    final july = store.additionalExpenses.last;
    expect(july.month, DateTime(2026, 7));
    expect(july.kind, PropertyExpenseKind.variableCommitment);
    expect(
      store.updateVariableCommitmentForCurrentMonth(
        july,
        category: 'TNB',
        amount: 215,
        note: 'Corrected July bill',
      ),
      isTrue,
    );
    expect(store.additionalExpenses.last.amount, 215);

    final june = AdditionalExpense(
      id: 'locked_june_tnb',
      facilityId: facility.id,
      month: DateTime(2026, 6),
      category: 'TNB',
      amount: 160,
      note: 'June common meter',
      kind: PropertyExpenseKind.variableCommitment,
    );
    store.additionalExpenses.add(june);
    expect(
      store.updateVariableCommitmentForCurrentMonth(
        june,
        category: 'TNB',
        amount: 999,
        note: 'Forbidden historical rewrite',
      ),
      isFalse,
    );
    expect(
      store.additionalExpenses.firstWhere((item) => item.id == june.id).amount,
      160,
    );
    expect(
      (store.exportSnapshot()['additionalExpenses'] as List<dynamic>)
          .cast<Map<String, dynamic>>()
          .firstWhere((item) => item['id'] == july.id)['kind'],
      PropertyExpenseKind.variableCommitment.name,
    );

    final legacyCurrent = AdditionalExpense(
      id: 'legacy_current_tnb',
      facilityId: facility.id,
      month: DateTime(2026, 7),
      category: 'TNB',
      amount: 179.25,
      note: 'Legacy one-time bill',
    );
    store.additionalExpenses.add(legacyCurrent);
    expect(
      store.updateAdditionalExpenseForCurrentMonth(
        legacyCurrent,
        category: 'TNB',
        amount: 190,
        note: 'Corrected legacy bill',
      ),
      isTrue,
    );
    expect(
      store.additionalExpenses
          .firstWhere((item) => item.id == legacyCurrent.id)
          .amount,
      190,
    );
    expect(store.deleteAdditionalExpenseForCurrentMonth(legacyCurrent), isTrue);
    expect(
      store.additionalExpenses.any((item) => item.id == legacyCurrent.id),
      isFalse,
    );
    expect(store.deleteAdditionalExpenseForCurrentMonth(june), isFalse);

    store.addAdditionalExpense(
      facility: facility,
      category: 'TNB',
      amount: 100,
      note: 'Duplicate-safe account',
      kind: PropertyExpenseKind.variableCommitment,
    );
    store.addAdditionalExpense(
      facility: facility,
      category: 'TNB',
      amount: 125,
      note: 'Duplicate-safe account',
      kind: PropertyExpenseKind.variableCommitment,
    );
    final duplicateSafe = store.additionalExpenses.where(
      (item) =>
          item.facilityId == facility.id &&
          item.category == 'TNB' &&
          item.note == 'Duplicate-safe account',
    );
    expect(duplicateSafe, hasLength(1));
    expect(duplicateSafe.single.amount, 125);
  });

  test('restoring a workspace removes exact current-month expense duplicates',
      () async {
    final source = RentalStore(now: DateTime(2026, 8, 19));
    source.loginAs(UserRole.owner);
    final facility = source.facilities.first;
    final snapshot = source.exportSnapshot();
    final expenses =
        (snapshot['additionalExpenses'] as List<dynamic>).cast<dynamic>();
    final duplicate = <String, dynamic>{
      'id': 'duplicate_tnb_1',
      'facilityId': facility.id,
      'month': DateTime(2026, 8).toIso8601String(),
      'category': 'TNB',
      'amount': 179.25,
      'note': '',
      'kind': PropertyExpenseKind.oneOff.name,
    };
    expenses
      ..add(duplicate)
      ..add(<String, dynamic>{...duplicate, 'id': 'duplicate_tnb_2'});
    final persistence = TestPersistence()..snapshot = jsonEncode(snapshot);
    final restored = RentalStore(
      now: DateTime(2026, 8, 19),
      persistence: persistence,
      seedDemoData: false,
    );

    await restored.initializePersistence();

    expect(
      restored.additionalExpenses.where(
        (item) =>
            item.facilityId == facility.id &&
            item.month.year == 2026 &&
            item.month.month == 8 &&
            item.category == 'TNB' &&
            item.amount == 179.25,
      ),
      hasLength(1),
    );
  });

  test('other property income edits are limited to the current month', () {
    final store = RentalStore(now: DateTime(2026, 7, 18));
    store.loginAs(UserRole.owner);
    final facility = store.facilities.first;
    store.addAdditionalIncome(
      facility: facility,
      month: DateTime(2026, 7),
      category: 'Parking rental',
      amount: 100,
      note: '',
    );
    final july = store.additionalIncomes.last;
    expect(
      store.updateAdditionalIncomeForCurrentMonth(
        july,
        category: 'Parking rental',
        amount: 120,
        note: 'July only',
      ),
      isTrue,
    );
    expect(store.additionalIncomes.last.amount, 120);

    final june = AdditionalIncome(
      id: 'locked_june_income',
      facilityId: facility.id,
      month: DateTime(2026, 6),
      category: 'Parking rental',
      amount: 90,
      note: '',
    );
    store.additionalIncomes.add(june);
    expect(
      store.updateAdditionalIncomeForCurrentMonth(
        june,
        category: 'Parking rental',
        amount: 999,
        note: '',
      ),
      isFalse,
    );
    expect(
      store.additionalIncomes.firstWhere((item) => item.id == june.id).amount,
      90,
    );
  });

  test('inactive tenancy stops future work but preserves its history', () {
    final store = RentalStore(now: DateTime(2026, 7, 18));
    final tenancy = store.tenancies.firstWhere((item) => item.active);
    final historicalBillCount =
        store.bills.where((bill) => bill.tenantId == tenancy.tenantId).length;

    store.deactivateTenancy(tenancy);

    expect(tenancy.active, isFalse);
    expect(store.userFor(tenancy.tenantId).accountStatus, 'Inactive');
    expect(
      store.bills.where((bill) => bill.tenantId == tenancy.tenantId).length,
      historicalBillCount,
    );
  });

  test('scheduled tenancy remains active through the last active date', () {
    final store = RentalStore(now: DateTime(2026, 10, 20));
    final tenancy = store.tenancies.firstWhere((item) => item.active);

    store.scheduleTenancyInactivation(
      tenancy,
      lastActiveDate: DateTime(2026, 10, 29),
      reason: 'Tenancy completed',
      remark: 'Keys to be returned to the owner.',
    );

    expect(store.isTenancyScheduledForInactivation(tenancy), isTrue);
    expect(
      store.isTenancyInactive(tenancy, at: DateTime(2026, 10, 29, 23, 59)),
      isFalse,
    );
    expect(
      store.isTenancyInactive(tenancy, at: DateTime(2026, 10, 30)),
      isTrue,
    );
    expect(tenancy.inactiveReason, 'Tenancy completed');
    expect(tenancy.inactiveRemark, 'Keys to be returned to the owner.');
  });

  test('inactive tenancy can reactivate only during the one-month window', () {
    final store = RentalStore(now: DateTime(2026, 10, 30));
    final tenancy = store.tenancies.firstWhere((item) => item.active);
    tenancy
      ..lastActiveDate = DateTime(2026, 10, 29)
      ..inactivatedAt = DateTime(2026, 10, 30)
      ..active = false;

    expect(store.canReactivateTenancy(tenancy), isTrue);
    expect(
      store.canReactivateTenancy(tenancy, at: DateTime(2026, 11, 29)),
      isTrue,
    );
    expect(
      store.canReactivateTenancy(tenancy, at: DateTime(2026, 11, 30)),
      isFalse,
    );

    expect(store.reactivateTenancy(tenancy), isTrue);
    expect(tenancy.active, isTrue);
    expect(tenancy.lastActiveDate, isNull);
    expect(store.userFor(tenancy.tenantId).accountStatus, 'Active');
  });

  test('scheduled tenancy lifecycle survives workspace persistence', () async {
    final persistence = TestPersistence();
    final first = RentalStore(
      now: DateTime(2026, 10, 20),
      persistence: persistence,
    );
    await first.initializePersistence();
    final tenancy = first.tenancies.firstWhere((item) => item.active);
    first.scheduleTenancyInactivation(
      tenancy,
      lastActiveDate: DateTime(2026, 10, 29),
      reason: 'Tenancy completed',
      remark: 'Handover arranged.',
    );
    await first.flushPersistence();

    final restored = RentalStore(
      now: DateTime(2026, 10, 20),
      persistence: persistence,
    );
    await restored.initializePersistence();
    final restoredTenancy =
        restored.tenancies.firstWhere((item) => item.id == tenancy.id);

    expect(restoredTenancy.lastActiveDate, DateTime(2026, 10, 29));
    expect(restoredTenancy.inactiveReason, 'Tenancy completed');
    expect(restoredTenancy.inactiveRemark, 'Handover arranged.');
    expect(restored.isTenancyScheduledForInactivation(restoredTenancy), isTrue);
  });

  test('facility can be sold only after every tenancy is inactive', () {
    final store = RentalStore(now: DateTime(2026, 7, 18));
    final facility = store.facilities.first;
    final historicalBillCount =
        store.bills.where((bill) => bill.facilityId == facility.id).length;
    final activeTenancies = store.activeTenanciesForFacility(facility);

    expect(activeTenancies, isNotEmpty);
    expect(store.markFacilitySold(facility), isFalse);
    expect(facility.status, isNot(FacilityStatus.sold));
    expect(
      store.activeTenanciesForFacility(facility),
      hasLength(activeTenancies.length),
    );

    for (final tenancy in activeTenancies) {
      store.deactivateTenancy(tenancy);
    }

    expect(store.activeTenanciesForFacility(facility), isEmpty);
    expect(store.markFacilitySold(facility), isTrue);

    expect(facility.status, FacilityStatus.sold);
    expect(store.monthlyFacilityOutflow(facility), 0);
    expect(
      store.tenancies
          .where((tenancy) => tenancy.facilityId == facility.id)
          .every((tenancy) => !tenancy.active),
      isTrue,
    );
    expect(
      store.bills.where((bill) => bill.facilityId == facility.id).length,
      historicalBillCount,
    );
  });

  test('developing facility only records its progression fee', () {
    final store = RentalStore(now: DateTime(2026, 7, 18));
    store.loginAs(UserRole.owner);
    final facility = store.addFacility(
      name: 'Development',
      addressLine: '1 Build Road',
      postcode: '50000',
      city: 'Kuala Lumpur',
      state: 'Wilayah Persekutuan Kuala Lumpur',
      installmentAmount: 0,
      maintenanceFee: 0,
      insuranceFee: 0,
      status: FacilityStatus.developing,
      progressionFee: 321.45,
    )!;

    expect(store.monthlyFacilityOutflow(facility), 321.45);
  });

  test('developing progression commitment updates the dashboard outflow', () {
    final store = RentalStore(now: DateTime(2026, 7, 18));
    store.loginAs(UserRole.owner);
    final facility = store.addFacility(
      name: 'Development',
      addressLine: '1 Build Road',
      postcode: '50000',
      city: 'Kuala Lumpur',
      state: 'Wilayah Persekutuan Kuala Lumpur',
      installmentAmount: 0,
      maintenanceFee: 0,
      insuranceFee: 0,
      status: FacilityStatus.developing,
    )!;

    store.addRecurringCommitment(
      facility: facility,
      name: 'Progression Fee',
      amount: 456.78,
      frequency: CommitmentFrequency.monthly,
      firstDueMonth: 7,
    );

    expect(store.monthlyFacilityOutflow(facility), 456.78);
    expect(
      store.facilityReports
          .firstWhere((report) => report.facility.id == facility.id)
          .outflow,
      456.78,
    );
  });

  test('facility month reports contain only the selected month values', () {
    final store = RentalStore(now: DateTime(2026, 7, 18));
    store.loginAs(UserRole.owner);
    final reports = store.facilityReportsForMonth(2026, 7);
    final summaries = store.yearlyFinancialSummary(2026);

    expect(
      reports.fold<double>(0, (sum, report) => sum + report.inflow),
      closeTo(summaries[6].collection, 0.01),
    );
    expect(
      reports.fold<double>(0, (sum, report) => sum + report.outflow),
      closeTo(summaries[6].expenses, 0.01),
    );
    expect(
      reports.fold<double>(0, (sum, report) => sum + report.netCashflow),
      closeTo(summaries[6].collection - summaries[6].expenses, 0.01),
    );
  });

  test('facility report annualises rent received from property value', () {
    final facility = Facility(
      id: 'yield_property',
      ownerId: 'owner',
      name: 'Yield Property',
      addressLine: 'Hidden from dashboard',
      postcode: '50000',
      city: 'Kuala Lumpur',
      state: 'Wilayah Persekutuan Kuala Lumpur',
      propertyValue: 300000,
      installmentAmount: 0,
      maintenanceFee: 0,
      insuranceFee: 0,
    );

    expect(
      FacilityReport(
        facility: facility,
        inflow: 2000,
        outflow: 800,
        netCashflow: 1200,
        rentReceived: 1200,
      ).annualisedRentalYieldPercentForMonthlyRent(1200),
      closeTo(4.80, 0.001),
    );
    expect(
      FacilityReport(
        facility: facility,
        inflow: 0,
        outflow: 0,
        netCashflow: 0,
      ).annualisedRentalYieldPercentForMonthlyRent(0),
      0,
    );
    facility.propertyValue = 0;
    expect(
      FacilityReport(
        facility: facility,
        inflow: 2000,
        outflow: 800,
        netCashflow: 1200,
        rentReceived: 1200,
      ).annualisedRentalYieldPercentForMonthlyRent(1200),
      isNull,
    );
  });

  test('rental yield excludes utilities, parking, and other income', () {
    final store = RentalStore(now: DateTime(2026, 7, 18));
    store.loginAs(UserRole.owner);
    final facility = store.ownerFacilities.first..propertyValue = 300000;
    store.bills.removeWhere(
      (bill) =>
          bill.facilityId == facility.id &&
          bill.month.year == 2026 &&
          bill.month.month == 7,
    );
    store.bills.add(
      MonthlyBill(
        id: 'gross_yield_bill',
        facilityId: facility.id,
        tenantId: store.tenancies
            .firstWhere((item) => item.facilityId == facility.id)
            .tenantId,
        month: DateTime(2026, 7),
        rentAmount: 1200,
        electricityAmount: 300,
        generalElectricAmount: 50,
        waterAmount: 40,
        internetAmount: 100,
        parkingRentalAmount: 200,
        status: PaymentStatus.approved,
        amountPaid: 1890,
      ),
    );

    final report = store
        .facilityReportsForMonth(2026, 7)
        .firstWhere((item) => item.facility.id == facility.id);

    expect(report.rentReceived, 1200);
    expect(report.inflow, greaterThan(report.rentReceived));
    expect(
      report.annualisedRentalYieldPercentForMonthlyRent(report.rentReceived),
      closeTo(4.80, 0.001),
    );
  });

  test('owner can update a developing property to ready with a new address',
      () {
    final store = RentalStore(now: DateTime(2026, 7, 18));
    store.loginAs(UserRole.owner);
    final facility = store.addFacility(
      name: 'Development',
      addressLine: '1 Old Road',
      postcode: '50000',
      city: 'Kuala Lumpur',
      state: 'Wilayah Persekutuan Kuala Lumpur',
      installmentAmount: 0,
      maintenanceFee: 0,
      insuranceFee: 0,
      status: FacilityStatus.developing,
    )!;

    store.updateFacilityDetails(
      facility,
      name: 'Ready Residence',
      addressLine: '2 New Road',
      postcode: '59200',
      city: 'Lembah Pantai',
      state: 'Wilayah Persekutuan Kuala Lumpur',
      status: FacilityStatus.ready,
      installmentAmount: 1200,
      maintenanceFee: 180,
    );

    expect(facility.status, FacilityStatus.ready);
    expect(facility.name, 'Ready Residence');
    expect(facility.address, contains('2 New Road'));
    expect(store.monthlyFacilityOutflow(facility), 1380);
  });

  test('Kuala Lumpur address directory exposes all major townships', () {
    final cities = malaysiaCitiesForState('Wilayah Persekutuan Kuala Lumpur');

    expect(
      cities,
      containsAll(<String>[
        'Bandar Tun Razak',
        'Batu',
        'Bukit Bintang',
        'Cheras',
        'Kepong',
        'Lembah Pantai',
        'Segambut',
        'Setiawangsa',
        'Seputeh',
        'Titiwangsa',
        'Wangsa Maju',
      ]),
    );
    expect(
      malaysiaPostcodesFor(
        'Wilayah Persekutuan Kuala Lumpur',
        'Lembah Pantai',
      ),
      contains('59200'),
    );
    expect(
      isValidMalaysiaLocation(
        state: 'Wilayah Persekutuan Kuala Lumpur',
        city: 'Lembah Pantai',
        postcode: '59200',
      ),
      isTrue,
    );
  });

  test('report navigation never exposes years before 2026', () {
    expect(earliestReportingYear, 2026);
    expect(canViewPreviousReportingYear(2026), isFalse);
    expect(canViewPreviousReportingYear(2027), isTrue);
  });

  test('business and commitment defaults include the requested options', () {
    expect(defaultBusinessName, 'HomeOps360');
    expect(
      monthlyCommitmentTypeOptions,
      containsAll(<String>[
        'Internet',
        'Security Service',
        'Cleaning Service',
        'Lift Service',
        'Pest Control',
      ]),
    );
    expect(
      monthlyCommitmentTypeOptions,
      isNot(contains(customCommitmentType)),
    );
    expect(
      nonMonthlyCommitmentTypeOptions,
      containsAll(<String>[
        'TNB',
        'Water Bill',
        'DBKL Assessment',
        'Fire Insurance',
        customCommitmentType,
      ]),
    );
    expect(
      variableExpenseTypeOptions,
      containsAll(<String>[
        'Progression Fee',
        'TNB',
        'Water Bill',
        'Accessories',
        'Groceries',
        'Cleaning Service',
        'Repair / Maintenance',
      ]),
    );
    expect(
      propertyExpenseKindForCategory('Progression Fee'),
      PropertyExpenseKind.variableCommitment,
    );
    expect(
      propertyExpenseKindForCategory('TNB'),
      PropertyExpenseKind.variableCommitment,
    );
    expect(
      propertyExpenseKindForCategory('Accessories'),
      PropertyExpenseKind.oneOff,
    );
    expect(
      propertyExpenseKindForCategory('Groceries'),
      PropertyExpenseKind.oneOff,
    );
  });

  test('monthly commitment total excludes scheduled non-monthly costs', () {
    final store = RentalStore(now: DateTime(2026, 8, 18));
    store.loginAs(UserRole.owner);
    final facility = store.addFacility(
      name: 'Commitment Test',
      addressLine: '1 Test Road',
      postcode: '50000',
      city: 'Kuala Lumpur',
      state: 'Wilayah Persekutuan Kuala Lumpur',
      installmentAmount: 100,
      maintenanceFee: 20,
      insuranceFee: 0,
      status: FacilityStatus.ready,
    )!;
    final baseline = store.monthlyFixedCommitmentTotal(facility);

    store.addRecurringCommitment(
      facility: facility,
      name: 'Cleaning Service',
      amount: 75,
      frequency: CommitmentFrequency.monthly,
      firstDueMonth: 8,
    );
    store.addRecurringCommitment(
      facility: facility,
      name: 'DBKL Assessment',
      amount: 300,
      frequency: CommitmentFrequency.quarterly,
      firstDueMonth: 8,
    );

    expect(store.monthlyFixedCommitmentTotal(facility), baseline + 75);
    expect(store.monthlyFacilityOutflow(facility), baseline + 75 + 300);
  });

  test('tenancy extensions create a contract and package timeline', () {
    final store = RentalStore(now: DateTime(2026, 7, 18));
    final tenancy = store.tenancies.first;
    final original = tenancy.contractHistory.first;

    store.updateTenantContract(
      tenancy,
      unitName: tenancy.unitName,
      monthlyRent: tenancy.monthlyRent + 100,
      leaseStart: tenancy.leaseStart,
      leaseEnd: DateTime(2027, 12, 31),
      electricityPackage: UtilityPackage.included,
      waterPackage: tenancy.waterPackage,
      internetPackage: tenancy.internetPackage,
      carParkIncluded: tenancy.carParkIncluded,
      carParkDetails: tenancy.carParkDetails,
      changeType: TenancyChangeType.extendTenancy,
    );

    expect(tenancy.contractHistory, hasLength(2));
    expect(original.leaseEnd, DateTime(2026, 12, 31));
    expect(tenancy.contractHistory.last.leaseStart, DateTime(2027, 1, 1));
    expect(tenancy.contractHistory.last.leaseEnd, DateTime(2027, 12, 31));
    expect(
      tenancy.contractHistory.last.electricityPackage,
      UtilityPackage.included,
    );
  });

  test('package edits split the timeline without overlapping periods', () {
    final store = RentalStore(now: DateTime(2026, 7, 18));
    final tenancy = store.tenancies.first;

    store.updateTenantContract(
      tenancy,
      unitName: tenancy.unitName,
      monthlyRent: tenancy.monthlyRent + 100,
      leaseStart: tenancy.leaseStart,
      leaseEnd: tenancy.leaseEnd,
      electricityPackage: UtilityPackage.included,
      waterPackage: tenancy.waterPackage,
      internetPackage: tenancy.internetPackage,
      carParkIncluded: tenancy.carParkIncluded,
      carParkDetails: tenancy.carParkDetails,
    );

    expect(tenancy.contractHistory, hasLength(2));
    expect(tenancy.contractHistory.first.leaseEnd, DateTime(2026, 6, 30));
    expect(tenancy.contractHistory.last.leaseStart, DateTime(2026, 7, 1));
    expect(tenancy.contractHistory.last.leaseEnd, DateTime(2026, 12, 31));
  });

  test('saving an unchanged package does not add redundant history', () {
    final store = RentalStore(now: DateTime(2026, 7, 18));
    final tenancy = store.tenancies.first;
    final originalCount = tenancy.contractHistory.length;

    store.updateTenantContract(
      tenancy,
      unitName: tenancy.unitName,
      monthlyRent: tenancy.monthlyRent,
      leaseStart: tenancy.leaseStart,
      leaseEnd: tenancy.leaseEnd,
      electricityPackage: tenancy.electricityPackage,
      waterPackage: tenancy.waterPackage,
      internetPackage: tenancy.internetPackage,
      carParkIncluded: tenancy.carParkIncluded,
      carParkDetails: tenancy.carParkDetails,
    );

    expect(tenancy.contractHistory, hasLength(originalCount));
  });

  test('legacy origin addresses do not repeat city, postcode, and state', () {
    expect(
      normalizeOriginStreetAddress(
        address: '22 Jalan Melur, 40100 Shah Alam, Selangor',
        postcode: '40100',
        city: 'Shah Alam',
        state: 'Selangor',
      ),
      '22 Jalan Melur',
    );
    expect(
      normalizeOriginStreetAddress(
        address: '22 Jalan Melur',
        postcode: '40100',
        city: 'Shah Alam',
        state: 'Selangor',
      ),
      '22 Jalan Melur',
    );
  });

  test('tenant-borne electricity never requires an owner meter attachment', () {
    final tenancy = Tenancy(
      id: 'tenancy-tenant-borne',
      facilityId: 'facility-1',
      tenantId: 'tenant-1',
      unitName: 'Room A',
      monthlyRent: 800,
      electricityPackage: UtilityPackage.tenantBorne,
      electricityCharge: 0,
      waterPackage: UtilityPackage.included,
      waterCharge: 0,
      internetPackage: UtilityPackage.included,
      internetCharge: 0,
      leaseStart: DateTime(2026, 1, 1),
      leaseEnd: DateTime(2026, 12, 31),
    );

    expect(tenancy.electricityRequiresOwnerReading, isFalse);
    expect(tenancy.utilitiesFullyIncluded, isTrue);
  });

  test('published invoice carries the configured owner payment details', () {
    final invoice = RentalInvoice(
      id: 'INV-PAYMENT-DETAILS',
      tenant: const TenantAccount(
        id: 'tenant-1',
        name: 'Tenant One',
        email: 'tenant@example.com',
        phone: '60123456789',
        property: 'Property One',
        unit: 'A-1',
        rent: 800,
        water: 0,
        internet: 0,
      ),
      period: 'Jul 2026',
      usagePeriod: 'Jun 2026',
      previousReading: 0,
      currentReading: 0,
      evidenceName: 'No evidence required',
      dueDate: DateTime(2026, 7, 23),
      bankName: 'Maybank',
      bankAccountNumber: '1234567890',
      bankBeneficiary: 'Property Owner',
      paymentQrName: 'duitnow.png',
      paymentQrBase64: 'cXItYnl0ZXM=',
    );

    final record = invoiceCloudRecord(invoice);
    expect(record['bank_name'], 'Maybank');
    expect(record['bank_account_number'], '1234567890');
    expect(record['bank_beneficiary'], 'Property Owner');
    expect(record['payment_qr_name'], 'duitnow.png');
  });

  test('combined electricity is presented as one reconciled invoice line', () {
    final invoice = RentalInvoice(
      id: 'INV-COMBINED',
      tenant: const TenantAccount(
        id: 'tenant',
        name: 'Tenant',
        email: 'tenant@example.com',
        phone: '+60123456789',
        property: 'Property',
        unit: 'A-1',
        rent: 600,
        water: 0,
        internet: 0,
      ),
      period: 'Jul 2026',
      usagePeriod: 'Jun 2026',
      previousReading: 0,
      currentReading: 20,
      evidenceName: 'meter.jpg',
      electricityAmountOverride: 10.32,
      generalElectricAmount: 5,
      electricityLabel: 'Electricity',
      dueDate: DateTime(2026, 7, 6),
    );

    expect(invoice.usesCombinedElectricity, isTrue);
    expect(invoice.displayedElectricity, 15.32);
    expect(invoice.total, 615.32);
    expect(invoiceCloudRecord(invoice)['electricity_label'], 'Electricity');
  });

  test('approved invoices reject utility edits and expiry renewal records', () {
    final store = RentalStore(now: DateTime(2026, 7, 18));
    store.loginAs(UserRole.owner);
    final bill = store.bills.firstWhere(
      (item) => item.status == PaymentStatus.approved,
    );
    final originalUsage = bill.electricityUsageKwh;

    store.updateBillUtilities(
      bill,
      electricityUsageKwh: 999,
      waterAmount: 999,
      internetAmount: 999,
      utilityEvidenceFileName: 'replacement.jpg',
    );
    store.recordInvoicePortalExpiry(bill, DateTime(2026, 7, 21));

    expect(bill.electricityUsageKwh, originalUsage);
    expect(bill.portalExpiresAt, isNull);
    expect(bill.status, PaymentStatus.approved);
  });

  test('shareholder observer can view owner data but cannot mutate it', () {
    final store = RentalStore(now: DateTime(2026, 7, 18));
    final facility = store.facilities.first;
    final originalMaintenance = facility.maintenanceFee;
    final pendingBill = store.bills.firstWhere(
      (bill) => bill.status == PaymentStatus.pendingApproval,
    );

    expect(
      store.signInLocalAccount(
        email: 'observer@example.com',
        password: 'password',
        role: UserRole.owner,
      ),
      isTrue,
    );
    expect(store.isReadOnlyObserver, isTrue);
    expect(store.ownerFacilities, isNotEmpty);

    store.updateFacilityCosts(
      facility,
      installmentAmount: facility.installmentAmount,
      extraInstallmentPayment: facility.extraInstallmentPayment,
      maintenanceFee: 9999,
      insuranceFee: facility.insuranceFee,
      insuranceFrequency: facility.insuranceFrequency,
      insuranceDueMonth: facility.insuranceDueMonth,
    );
    store.approveBill(pendingBill);

    expect(facility.maintenanceFee, originalMaintenance);
    expect(pendingBill.status, PaymentStatus.pendingApproval);
  });

  test('level 1 owner can only add and remove level 2 accounts', () {
    final store = RentalStore(now: DateTime(2026, 7, 18));
    store.loginAs(UserRole.owner);

    expect(
      () => store.createLocalOwnerAccessAccount(
        fullName: 'Second Full Owner',
        email: 'owner2@example.com',
        password: 'password2',
        accessLevel: OwnerAccessLevel.fullAccess,
      ),
      throwsStateError,
    );
    store.createLocalOwnerAccessAccount(
      fullName: 'Second Observer',
      email: 'observer2@example.com',
      password: 'password2',
      accessLevel: OwnerAccessLevel.observer,
    );

    final observer =
        store.users.firstWhere((user) => user.email == 'observer2@example.com');
    expect(observer.ownerAccessLevel, OwnerAccessLevel.observer);

    store.removeLocalObserverAccount(observer);
    expect(store.users.any((user) => user.id == observer.id), isFalse);
    expect(
      store.localAuthAccounts.any((account) => account.userId == observer.id),
      isFalse,
    );
  });

  testWidgets('editable dialogs preserve input after an outside tap',
      (tester) async {
    final store = RentalStore(now: DateTime(2026, 7, 18));
    store.loginAs(UserRole.owner);
    await tester.pumpWidget(
      RentalStoreScope(
        store: store,
        child: MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => showAddFacilityDialog(context),
                child: const Text('Open form'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open form'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextField, 'Facility Name'),
      'Unsaved Facility',
    );
    await tester.tapAt(const Offset(4, 4));
    await tester.pumpAndSettle();

    expect(find.text('Create New Facility'), findsOneWidget);
    expect(find.text('Unsaved Facility'), findsOneWidget);
  });

  testWidgets('tenant editor keeps its frame and actions while content scrolls',
      (tester) async {
    final store = RentalStore(now: DateTime(2026, 7, 18));
    store.loginAs(UserRole.owner);
    final tenancy = store.tenancies.first;
    final tenant = store.userFor(tenancy.tenantId);
    await tester.binding.setSurfaceSize(const Size(390, 760));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      RentalStoreScope(
        store: store,
        child: MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () =>
                    showEditTenantProfileDialog(context, tenant, tenancy),
                child: const Text('Edit tenant'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Edit tenant'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('edit_tenant_profile_dialog')), findsOneWidget);
    expect(find.byKey(const Key('tenant_edit_content_frame')), findsOneWidget);
    expect(find.text('Cancel'), findsOneWidget);
    expect(find.text('Save Changes'), findsOneWidget);

    await tester.drag(
      find.byKey(const Key('tenant_edit_scroll_area')),
      const Offset(0, -500),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('tenant_edit_content_frame')), findsOneWidget);
    expect(find.text('Cancel'), findsOneWidget);
    expect(find.text('Save Changes'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  test('tenant payment portal provides complete English and Chinese copy', () {
    expect(
      tenantPortalText(false, 'Settle your invoice'),
      'Settle your invoice',
    );
    expect(tenantPortalText(true, 'Settle your invoice'), '支付您的账单');
    expect(tenantPortalText(true, 'Download invoice PDF'), '下载发票 PDF');
    expect(tenantPortalText(true, 'Bank account copied.'), '银行账号已复制。');
    expect(tenantPortalPeriod(true, 'Jul 2026'), '2026年7月');
    expect(
      tenantPortalErrorText(
        true,
        StateError('Payment proof PDF must be smaller than 2 MB.'),
      ),
      '付款凭证 PDF 必须小于 2 MB。',
    );
  });

  test('dashboard financial colors follow the requested thresholds', () {
    expect(dashboardSignedMetricColor(-0.01), dashboardMetricRed);
    expect(dashboardSignedMetricColor(null), Colors.white);
    expect(dashboardSignedMetricColor(0), Colors.white);
    expect(dashboardSignedMetricColor(100), dashboardMetricGreen);
    expect(dashboardCoverageRatioColor(80), dashboardMetricGreen);
    expect(dashboardCoverageRatioColor(100), dashboardMetricGreen);
    expect(dashboardCoverageRatioColor(79.9), dashboardMetricYellow);
    expect(dashboardCoverageRatioColor(60), dashboardMetricYellow);
    expect(dashboardCoverageRatioColor(59.9), dashboardMetricRed);
    expect(dashboardCoverageRatioColor(null), Colors.white);
  });

  testWidgets('ROI remains ROI in every language pack', (tester) async {
    for (final language in AppLanguage.values) {
      final store = RentalStore(seedDemoData: false);
      store.updateLanguage(language);
      await tester.pumpWidget(
        RentalStoreScope(
          store: store,
          child: MaterialApp(
            home: Builder(
              builder: (context) => Text(tr(context, 'ROI')),
            ),
          ),
        ),
      );
      expect(find.text('ROI'), findsOneWidget);
    }
  });

  testWidgets('owner dashboard toggles between year and selected month totals',
      (tester) async {
    final store = RentalStore(now: DateTime(2026, 7, 18));
    store.loginAs(UserRole.owner);
    final yearReports = store.facilityReportsForYear(2026);
    final monthReports = store.facilityReportsForMonth(2026, 7);
    final januaryReports = store.facilityReportsForMonth(2026, 1);
    final yearCollection =
        yearReports.fold<double>(0, (sum, report) => sum + report.inflow);
    final yearExpenses =
        yearReports.fold<double>(0, (sum, report) => sum + report.outflow);
    final monthCollection =
        monthReports.fold<double>(0, (sum, report) => sum + report.inflow);
    final monthExpenses =
        monthReports.fold<double>(0, (sum, report) => sum + report.outflow);
    final januaryCollection =
        januaryReports.fold<double>(0, (sum, report) => sum + report.inflow);

    await tester.binding.setSurfaceSize(const Size(390, 844));
    await tester.pumpWidget(
      RentalStoreScope(
        store: store,
        child: const MaterialApp(home: Scaffold(body: OwnerReportTab())),
      ),
    );
    await tester.pumpAndSettle();

    Text collectionText() => tester.widget<Text>(
          find.byKey(const Key('dashboard_collection_total')),
        );
    Text netCashFlowText() => tester.widget<Text>(
          find.byKey(const Key('net_cash_flow_value')),
        );
    Text expenseCoverageText() => tester.widget<Text>(
          find.byKey(const Key('expense_coverage_value')),
        );

    expect(collectionText().data, money(yearCollection));
    expect(find.byKey(const Key('financial_health_card')), findsNothing);
    expect(find.byKey(const Key('properties_summary_card')), findsOneWidget);
    expect(find.byKey(const Key('payments_summary_card')), findsOneWidget);
    expect(find.byKey(const Key('billings_summary_card')), findsOneWidget);
    expect(find.byKey(const Key('net_cash_flow_card')), findsOneWidget);
    expect(find.byKey(const Key('expense_coverage_card')), findsOneWidget);
    expect(find.byKey(const Key('coverage_change_card')), findsOneWidget);
    expect(netCashFlowText().data, money(yearCollection - yearExpenses));
    expect(
      netCashFlowText().style?.color,
      dashboardCoverageRatioColor(
        yearExpenses == 0 ? null : yearCollection / yearExpenses * 100,
      ),
    );
    expect(
      expenseCoverageText().data,
      yearExpenses == 0
          ? '-'
          : '${(yearCollection / yearExpenses * 100).toStringAsFixed(1)}%',
    );
    expect(
      expenseCoverageText().style?.color,
      dashboardCoverageRatioColor(
        yearExpenses == 0 ? null : yearCollection / yearExpenses * 100,
      ),
    );
    expect(find.textContaining('Portfolio overview · 2026'), findsOneWidget);

    await tester.tap(find.byKey(const Key('dashboard_period_toggle')));
    await tester.pumpAndSettle();
    expect(collectionText().data, money(monthCollection));
    expect(netCashFlowText().data, money(monthCollection - monthExpenses));
    expect(
      expenseCoverageText().data,
      monthExpenses == 0
          ? '-'
          : '${(monthCollection / monthExpenses * 100).toStringAsFixed(1)}%',
    );
    expect(
        find.textContaining('Portfolio overview · Jul 2026'), findsOneWidget);

    final chartRect = tester.getRect(
      find.byKey(const Key('financial_chart_touch_area')),
    );
    await tester.tapAt(Offset(chartRect.left + 5, chartRect.center.dy));
    await tester.pumpAndSettle();
    expect(collectionText().data, money(januaryCollection));
    expect(
        find.textContaining('Portfolio overview · Jan 2026'), findsOneWidget);

    await tester.tap(find.byKey(const Key('dashboard_period_toggle')));
    await tester.pumpAndSettle();
    expect(collectionText().data, money(yearCollection));
    expect(tester.takeException(), isNull);
    await tester.binding.setSurfaceSize(null);
  });

  testWidgets('developing property uses the standard facility cost layout',
      (tester) async {
    final store = RentalStore(now: DateTime(2026, 7, 18));
    store.loginAs(UserRole.owner);
    final facility = store.addFacility(
      name: 'Development',
      addressLine: '1 Build Road',
      postcode: '50000',
      city: 'Kuala Lumpur',
      state: 'Wilayah Persekutuan Kuala Lumpur',
      installmentAmount: 0,
      maintenanceFee: 0,
      insuranceFee: 0,
      status: FacilityStatus.developing,
      progressionFee: 321.45,
    )!;

    await tester.pumpWidget(
      RentalStoreScope(
        store: store,
        child: MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(child: CostSummary(facility: facility)),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('facility_cost_total_bar')), findsOneWidget);
    expect(find.byKey(const Key('facility_cost_grid')), findsOneWidget);
    expect(find.text('Progression Fee'), findsOneWidget);
    expect(find.text(money(321.45)), findsWidgets);
    expect(
      find.text(
        'Installment and recurring commitments are not required while developing.',
      ),
      findsNothing,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'ready property does not duplicate a legacy progression commitment card',
      (tester) async {
    final store = RentalStore(now: DateTime(2026, 8, 18));
    store.loginAs(UserRole.owner);
    final facility = store.addFacility(
      name: 'Ready Home',
      addressLine: '1 Ready Road',
      postcode: '50000',
      city: 'Kuala Lumpur',
      state: 'Wilayah Persekutuan Kuala Lumpur',
      installmentAmount: 0,
      maintenanceFee: 0,
      insuranceFee: 0,
      status: FacilityStatus.ready,
    )!;
    store.addRecurringCommitment(
      facility: facility,
      name: 'Progression Fee',
      amount: 1,
      frequency: CommitmentFrequency.monthly,
      firstDueMonth: 8,
    );

    await tester.pumpWidget(
      RentalStoreScope(
        store: store,
        child: MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(child: CostSummary(facility: facility)),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Progression Fee'), findsNothing);
    expect(find.byKey(const Key('facility_cost_grid')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('current owner shell opens every primary module', (tester) async {
    final store = RentalStore(now: DateTime(2026, 7, 18));
    store.loginAs(UserRole.owner);
    await tester.pumpWidget(
      RentalStoreScope(
        store: store,
        child: const MaterialApp(home: OwnerHomeScreen()),
      ),
    );

    expect(find.textContaining('Good '), findsOneWidget);
    expect(find.text('Complete payment'), findsOneWidget);
    expect(find.text('Complete billing'), findsOneWidget);
    expect(find.byKey(const Key('billing_attention_pulse')), findsOneWidget);
    for (final bill in store.ownerCurrentMonthBills) {
      bill.status = PaymentStatus.pendingTenantPayment;
    }
    store.notifyListeners();
    await tester.pump();
    expect(find.byKey(const Key('billing_attention_pulse')), findsNothing);
    for (final label in <String>[
      'Properties',
      'Payments',
      'Home',
      'Requests',
      'Profile',
    ]) {
      expect(find.text(label), findsWidgets);
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets('facility cost edit opens the main cost form directly',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final store = RentalStore(now: DateTime(2026, 8, 24));
    store.loginAs(UserRole.owner);
    final facility = store.facilities.first;
    store.addRecurringCommitment(
      facility: facility,
      name: 'Time Internet',
      amount: 104.95,
      frequency: CommitmentFrequency.monthly,
      firstDueMonth: 1,
    );

    await tester.pumpWidget(
      RentalStoreScope(
        store: store,
        child: MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => showEditCostsDialog(context, facility),
                child: const Text('Edit Costs'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final editCosts = find.text('Edit Costs');
    await tester.tap(editCosts);
    await tester.pumpAndSettle();

    expect(find.text('Edit ${facility.name} Costs'), findsOneWidget);
    expect(find.text('${facility.name} Expenses'), findsNothing);
    expect(find.text('Fire Insurance'), findsNothing);
    expect(find.text('Add Commitment'), findsNothing);
    expect(find.text('Installment'), findsOneWidget);
    expect(find.text('Extra Installment Payment'), findsOneWidget);
    expect(find.text('Maintenance'), findsOneWidget);
    expect(find.text('Monthly commitments'), findsOneWidget);
    expect(find.text('Time Internet (Monthly)'), findsOneWidget);
    final internetField = find.byKey(
      const Key('facility_cost_commitment_commitment_facility_1_3'),
    );
    expect(internetField, findsOneWidget);
    await tester.enterText(
      find.descendant(of: internetField, matching: find.byType(TextField)),
      '125.00',
    );
    await tester.tap(find.text('Review & Apply'));
    await tester.pumpAndSettle();
    expect(find.text('Apply facility cost changes?'), findsOneWidget);
    await tester.tap(find.text('Apply Changes'));
    await tester.pumpAndSettle();
    expect(
      facility.extraCommitments
          .firstWhere((item) => item.name == 'Time Internet')
          .amount,
      125,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('property details do not edit maintenance costs', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final store = RentalStore(now: DateTime(2026, 9, 12));
    store.loginAs(UserRole.owner);
    final facility = store.facilities.first;

    await tester.pumpWidget(
      RentalStoreScope(
        store: store,
        child: MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => showEditFacilityDetailsDialog(
                  context,
                  facility,
                ),
                child: const Text('Edit Property'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Edit Property'));
    await tester.pumpAndSettle();

    expect(find.text('Edit ${facility.name}'), findsOneWidget);
    expect(find.text('Monthly Installment'), findsOneWidget);
    expect(find.text('Maintenance'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('diamond membership uses a yellow profile banner',
      (tester) async {
    final store = RentalStore(now: DateTime(2026, 9, 13));
    store.loginAs(UserRole.owner);
    store.ownerAccessConfig = const OwnerAccessConfig(
      membershipTier: MembershipTier.diamond,
    );

    await tester.pumpWidget(
      RentalStoreScope(
        store: store,
        child: const MaterialApp(
          home: Scaffold(body: OwnerAccountTab()),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final banner = tester.widget<Container>(
      find.byKey(const Key('profile_membership_banner')),
    );
    final decoration = banner.decoration! as BoxDecoration;
    final gradient = decoration.gradient! as LinearGradient;
    expect(
      gradient.colors,
      const [Color(0xFFFFE27A), Color(0xFFF4B942)],
    );
    expect(find.text('Diamond'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('property workspace keeps recurring costs out of one-off entries',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final store = RentalStore(now: DateTime(2026, 9, 5));
    store.loginAs(UserRole.owner);
    final facility = store.ownerFacilities.first;
    store.addAdditionalExpense(
      facility: facility,
      category: 'Internet Bill',
      amount: 10,
      note: 'Current month only',
    );

    await tester.pumpWidget(
      RentalStoreScope(
        store: store,
        child: const MaterialApp(home: Scaffold(body: FacilitiesTab())),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('variable_expense_grid')), findsOneWidget);
    expect(find.byKey(const Key('scheduled_expense_grid')), findsNothing);

    final addEntry = find.byKey(const Key('variable_expense_add_button'));
    await tester.ensureVisible(addEntry);
    await tester.tap(addEntry);
    await tester.pumpAndSettle();

    expect(find.text('Add One-off Expense'), findsOneWidget);
    expect(find.text('Current Month Amount'), findsOneWidget);
    expect(find.text('Payment Pattern'), findsNothing);
    expect(find.text('Frequency'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'facility configuration is a scrollable full page on phone and desktop',
      (tester) async {
    final store = RentalStore(now: DateTime(2026, 7, 18));
    store.loginAs(UserRole.owner);
    final facility = store.facilities.first;
    store.addAdditionalExpense(
      facility: facility,
      category: 'TNB',
      amount: 180,
      note: 'Current common meter bill',
      kind: PropertyExpenseKind.variableCommitment,
    );
    store.addRecurringCommitment(
      facility: facility,
      name: 'DBKL Assessment',
      amount: 300,
      frequency: CommitmentFrequency.quarterly,
      firstDueMonth: 7,
    );
    store.additionalExpenses.add(
      AdditionalExpense(
        id: 'legacy_zero_custom',
        facilityId: facility.id,
        month: store.currentMonth,
        category: 'Legacy Custom Zero',
        amount: 0,
        note: 'Restored legacy value',
      ),
    );
    facility.extraCommitments.add(
      RecurringCommitment(
        id: 'legacy_zero_scheduled',
        name: 'Zero Scheduled Expense',
        amount: 0,
        frequency: CommitmentFrequency.yearly,
        firstDueMonth: 7,
        initialEffectiveMonth: store.currentMonth,
      ),
    );
    for (final size in const [Size(390, 844), Size(1200, 820)]) {
      await tester.binding.setSurfaceSize(size);
      await tester.pumpWidget(
        RentalStoreScope(
          store: store,
          child: MaterialApp(
            home: FacilityConfigurationScreen(
              initialFacilityId: facility.id,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Facility Configuration'), findsOneWidget);
      expect(
          find.byKey(const Key('configuration_settings_list')), findsOneWidget);
      expect(find.text('Variable & One-off Expenses'), findsOneWidget);
      expect(find.text('Scheduled Commitments'), findsOneWidget);
      expect(find.text('Property Value'), findsOneWidget);
      expect(find.text('Legacy Custom Zero'), findsNothing);
      expect(find.text('Zero Scheduled Expense'), findsNothing);
      expect(find.byKey(const Key('variable_expense_header')), findsNothing);
      expect(find.byKey(const Key('scheduled_expense_grid')), findsNothing);
      expect(find.byKey(const Key('variable_expense_grid')), findsNothing);
      expect(find.text('Property Electricity Tariff'), findsOneWidget);
      expect(find.text('Other Property Income'), findsOneWidget);
      expect(find.text('TNB'), findsNothing);
      expect(
        find.text(
          'Add variable or one-off costs such as TNB, water, accessories, groceries, cleaning and repairs.',
        ),
        findsNothing,
      );
      expect(tester.takeException(), isNull);
    }
    await tester.binding.setSurfaceSize(null);
  });

  testWidgets('property-context dialogs omit redundant property selectors',
      (tester) async {
    final store = RentalStore(now: DateTime(2026, 9, 6));
    store.loginAs(UserRole.owner);
    final facility = store.ownerFacilities.first;
    await tester.pumpWidget(
      RentalStoreScope(
        store: store,
        child: MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: Column(
                children: [
                  TextButton(
                    onPressed: () => showBillingConfigurationDialog(
                      context,
                      facility,
                      allowPropertySelection: false,
                    ),
                    child: const Text('Open tariff'),
                  ),
                  TextButton(
                    onPressed: () => showRecurringCommitmentsSettingsDialog(
                      context,
                      initialFacility: facility,
                    ),
                    child: const Text('Open commitments'),
                  ),
                  TextButton(
                    onPressed: () => showAddIncomeDialog(context, facility),
                    child: const Text('Open income'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open tariff'));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const Key('billing_configuration_property_selector')),
      findsNothing,
    );
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Open commitments'));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const Key('recurring_commitments_property_selector')),
      findsNothing,
    );
    await tester.tap(find.text('Close'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Open income'));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const Key('additional_income_property_selector')),
      findsNothing,
    );
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  test('configured property value survives workspace persistence', () async {
    final persistence = TestPersistence();
    final store = RentalStore(
      now: DateTime(2026, 9, 4),
      persistence: persistence,
    );
    await store.initializePersistence();
    store.loginAs(UserRole.owner);
    final facility = store.ownerFacilities.first;

    store.updateFacilityPropertyValue(facility, 300000);
    await store.flushPersistence();

    final restored = RentalStore(
      now: DateTime(2026, 9, 4),
      persistence: persistence,
      seedDemoData: false,
    );
    await restored.initializePersistence();

    expect(restored.facilityFor(facility.id).propertyValue, 300000);
  });

  test('property announcements remain property-scoped and persist', () async {
    final persistence = TestPersistence();
    final store = RentalStore(
      now: DateTime(2026, 8, 30, 10),
      persistence: persistence,
    );
    store.loginAs(UserRole.owner);
    final target = store.facilities.first;
    final other = store.facilities[1];

    store.savePropertyAnnouncement(
      target,
      title: 'Water maintenance',
      message: 'Water supply pauses from 10 AM to 1 PM.',
      startsAt: DateTime(2026, 8, 29),
      endsAt: DateTime(2026, 9, 2, 23, 59),
      enabled: true,
    );

    expect(store.announcementsForFacility(target), hasLength(1));
    expect(store.announcementsForFacility(other), isEmpty);
    await store.flushPersistence();

    final restored = RentalStore(
      now: DateTime(2026, 8, 30, 10),
      persistence: persistence,
      seedDemoData: false,
    );
    await restored.initializePersistence();
    final restoredTarget = restored.facilityFor(target.id);
    expect(restoredTarget.announcements, hasLength(1));
    expect(restoredTarget.announcements.single.title, 'Water maintenance');
  });

  testWidgets('owner profile exposes property announcement settings',
      (tester) async {
    final store = RentalStore(now: DateTime(2026, 8, 30));
    store.loginAs(UserRole.owner);
    await tester.pumpWidget(
      RentalStoreScope(
        store: store,
        child: const MaterialApp(home: Scaffold(body: OwnerAccountTab())),
      ),
    );
    await tester.pump();

    expect(find.text('Property announcements'), findsOneWidget);
    expect(find.text('Different message per property'), findsOneWidget);
  });

  testWidgets('tenant home shows an active assigned-property announcement',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final store = RentalStore(now: DateTime(2026, 8, 30, 10));
    store.loginAs(UserRole.owner);
    final tenant =
        store.users.firstWhere((user) => user.role == UserRole.tenant);
    final tenancy = store.tenancies.firstWhere(
      (item) => item.tenantId == tenant.id,
    );
    final facility = store.facilityFor(tenancy.facilityId);
    store.savePropertyAnnouncement(
      facility,
      title: 'Lift servicing',
      message: 'Lift B is unavailable from 2 PM to 4 PM.',
      startsAt: DateTime(2026, 8, 29),
      endsAt: DateTime(2026, 9, 2, 23, 59),
      enabled: true,
    );
    store.loginAs(UserRole.tenant);

    await tester.pumpWidget(
      RentalStoreScope(
        store: store,
        child: MaterialApp(
          home: Scaffold(
            body: TenantAnnouncementTicker(facility: facility),
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));

    expect(
      find.byKey(const Key('tenant_property_announcement_ticker')),
      findsOneWidget,
    );
    expect(find.textContaining('Lift servicing'), findsOneWidget);
    expect(find.textContaining('Tap for details'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
