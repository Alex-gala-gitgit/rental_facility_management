import 'package:flutter/material.dart' show Size;
import 'package:flutter_test/flutter_test.dart';
import 'package:rental_facility_management/main.dart';

void main() {
  testWidgets('shows role login actions', (tester) async {
    await tester.pumpWidget(const RentalFacilityApp());

    expect(find.text('Rental Facility Manager'), findsOneWidget);
    expect(find.text('Login as Owner'), findsOneWidget);
    expect(find.text('Login as Property Agent'), findsOneWidget);
    expect(find.text('Login as Tenant'), findsOneWidget);
  });

  testWidgets('owner report uses rental business labels', (tester) async {
    await tester.pumpWidget(const RentalFacilityApp());
    await tester.tap(find.text('Login as Owner'));
    await tester.pumpAndSettle();

    expect(find.text('Total Rental Collection'), findsOneWidget);
    expect(find.text('Total Expenses'), findsOneWidget);
    expect(find.text('Net Rental Income'), findsOneWidget);
  });

  testWidgets('rental collection card opens grouped details', (tester) async {
    await tester.pumpWidget(const RentalFacilityApp());
    await tester.tap(find.text('Login as Owner'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Total Rental Collection'));
    await tester.pumpAndSettle();

    expect(find.text('Rental Collection Details'), findsOneWidget);
    expect(find.text('Facility 1'), findsOneWidget);
    expect(find.textContaining('approved payment'), findsWidgets);
  });

  testWidgets('expenses card opens facility expense categories',
      (tester) async {
    await tester.pumpWidget(const RentalFacilityApp());
    await tester.tap(find.text('Login as Owner'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Total Expenses'));
    await tester.pumpAndSettle();

    expect(find.text('Expense Details'), findsOneWidget);
    expect(find.text('Installment'), findsWidgets);
    expect(find.text('Maintenance'), findsWidgets);
  });

  testWidgets('facilities use compact selector on phone layout',
      (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const RentalFacilityApp());
    await tester.tap(find.text('Login as Owner'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Facilities').last);
    await tester.pumpAndSettle();

    expect(find.text('Add'), findsOneWidget);
    expect(find.text('MY FACILITIES'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  test('electricity usage is converted at RM 0.516 per kWh', () {
    final store = RentalStore();
    final bill = store.bills.first;

    store.updateBillUtilities(
      bill,
      electricityUsageKwh: 100,
      waterAmount: 25,
      internetAmount: 50,
      utilityEvidenceFileName: 'meter.jpg',
    );

    expect(bill.electricityAmount, closeTo(51.60, 0.001));
    expect(bill.totalUtilityAmount, closeTo(126.60, 0.001));
    expect(bill.utilityEvidenceFileName, 'meter.jpg');
  });

  test('new tenant is tied to a facility with car park terms', () {
    final store = RentalStore();
    store.loginAs(UserRole.owner);
    final facility = store.ownerFacilities.first;

    store.addTenantToFacility(
      facility: facility,
      fullName: 'Test Tenant',
      email: 'tenant@test.com',
      originAddress: 'Test address',
      dateOfBirth: DateTime(1990, 1, 1),
      sex: 'Female',
      unitName: 'Room C',
      monthlyRent: 900,
      leaseStart: DateTime(2026, 1, 1),
      leaseEnd: DateTime(2026, 12, 31),
      electricityPackage: UtilityPackage.excluded,
      waterPackage: UtilityPackage.included,
      internetPackage: UtilityPackage.included,
      carParkIncluded: true,
      carParkDetails: 'Covered bay C-08',
    );

    final tenancy = store.tenancies.last;
    expect(tenancy.facilityId, facility.id);
    expect(tenancy.carParkIncluded, isTrue);
    expect(tenancy.carParkDetails, 'Covered bay C-08');
  });

  test('new facility is returned and belongs to the current owner', () {
    final store = RentalStore();
    store.loginAs(UserRole.owner);

    final facility = store.addFacility(
      name: 'Facility 2',
      address: 'Kuala Lumpur',
      installmentAmount: 2000,
      maintenanceFee: 200,
      insuranceFee: 100,
      otherFee: 50,
    );

    expect(facility, isNotNull);
    expect(facility!.name, 'Facility 2');
    expect(store.ownerFacilities, contains(facility));
  });

  test('tenant invitation records the sent date', () {
    final store = RentalStore();
    store.loginAs(UserRole.owner);
    final facility = store.ownerFacilities.first;

    store.addTenantToFacility(
      facility: facility,
      fullName: 'Invited Tenant',
      email: 'invite@test.com',
      originAddress: '',
      dateOfBirth: DateTime(1990),
      sex: '',
      unitName: 'Room D',
      monthlyRent: 700,
      leaseStart: DateTime(2026),
      leaseEnd: DateTime(2026, 12, 31),
      electricityPackage: UtilityPackage.excluded,
      waterPackage: UtilityPackage.excluded,
      internetPackage: UtilityPackage.included,
      carParkIncluded: false,
      carParkDetails: '',
    );
    final tenant = store.users.last;

    expect(tenant.profileComplete, isFalse);
    expect(tenant.invitationSent, isFalse);
    store.sendTenantInvitation(tenant);
    expect(tenant.invitationSent, isTrue);
    expect(tenant.invitationSentAt, isNotNull);

    store.acceptTenantInvitation(tenant);
    expect(tenant.accountCreated, isTrue);
    expect(tenant.profileComplete, isTrue);
    expect(tenant.accountCreatedAt, isNotNull);
    expect(
      store.notifications.first,
      contains('accepted the invitation and created a tenant account'),
    );
  });
}
