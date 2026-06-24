import 'package:flutter/material.dart';
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
      addressLine: '10 Jalan Test',
      postcode: '50000',
      city: 'Kuala Lumpur',
      state: 'Wilayah Persekutuan',
      installmentAmount: 2000,
      maintenanceFee: 200,
      insuranceFee: 100,
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
      store.notifications.first.message,
      contains('accepted the invitation and created a tenant account'),
    );
  });

  test('currency uses Malaysian ringgit', () {
    expect(money(1250), 'RM 1,250');
    expect(money(-80), '-RM 80');
  });

  test('rejected payment creates history and can be resubmitted', () {
    final store = RentalStore();
    final bill = store.bills.firstWhere(
      (bill) => bill.status == PaymentStatus.pendingApproval,
    );

    store.rejectBill(bill, 'Image is unclear');
    expect(bill.status, PaymentStatus.rejected);
    expect(store.paymentReviewHistory.last.status, PaymentStatus.rejected);
    expect(store.notifications.first.message, contains('Please resubmit'));

    store.submitPaymentSlip(bill, 'clear_slip.jpg', bill.totalAmount);
    expect(bill.status, PaymentStatus.pendingApproval);
    expect(bill.rejectReason, isNull);
  });

  test('owner can configure reminders and mark notification read', () {
    final store = RentalStore();
    store.loginAs(UserRole.owner);
    store.updateReminderSettings(afterDays: 5, frequencyDays: 3);

    expect(store.currentUser!.paymentReminderAfterDays, 5);
    expect(store.currentUser!.paymentReminderFrequencyDays, 3);
    final notification = store.notifications.first;
    expect(notification.isRead, isFalse);
    store.markNotificationRead(notification);
    expect(notification.isRead, isTrue);
  });

  test('one-off monthly income increases facility collection', () {
    final store = RentalStore(now: DateTime(2026, 6, 18));
    store.loginAs(UserRole.owner);
    final facility = store.ownerFacilities.first;
    final before = store.facilityInflow(facility.id);

    store.addAdditionalIncome(
      facility: facility,
      month: DateTime(2026, 6),
      category: 'Key deposit forfeiture',
      amount: 300,
      note: 'One-time collection',
    );

    expect(store.facilityInflow(facility.id), before + 300);
    expect(store.additionalIncomes.single.month.month, 6);
  });

  test('financial totals and chart stop at the current month', () {
    final store = RentalStore(now: DateTime(2026, 6, 18));
    store.loginAs(UserRole.owner);
    final facility = store.ownerFacilities.first;
    final monthlyExpenses = store.monthlyFacilityOutflow(facility);

    store.addAdditionalIncome(
      facility: facility,
      month: DateTime(2026, 7),
      category: 'Future income',
      amount: 500,
      note: 'Must not be counted before July',
    );

    final summaries = store.yearlyFinancialSummary(2026);
    final scheduledJanuaryExpenses = facility.insuranceFee +
        facility.extraCommitments.fold<double>(
          0,
          (sum, commitment) => sum + commitment.amount,
        );

    expect(summaries, hasLength(12));
    expect(store.totalOutflow, monthlyExpenses * 6 + scheduledJanuaryExpenses);
    expect(
      store.facilityOutflow(facility),
      monthlyExpenses * 6 + scheduledJanuaryExpenses,
    );
    expect(summaries[5].expenses, monthlyExpenses);
    expect(summaries[6].collection, 0);
    expect(summaries[6].expenses, 0);
    expect(summaries.last.collection, 0);
    expect(summaries.last.expenses, 0);
    expect(store.totalInflow, isNot(500));
  });

  test('fire insurance follows yearly or half-yearly payment schedule', () {
    final store = RentalStore(now: DateTime(2026, 12, 18));
    store.loginAs(UserRole.owner);
    final facility = store.ownerFacilities.first;

    expect(store.isInsuranceDue(facility, 1), isTrue);
    expect(store.isInsuranceDue(facility, 6), isFalse);
    expect(
      store.monthlyExpenseBreakdown(2026, 6).any(
            (item) => item.label.contains('Fire insurance'),
          ),
      isFalse,
    );

    facility.insuranceFrequency = InsuranceFrequency.halfYearly;
    expect(store.isInsuranceDue(facility, 7), isTrue);
    expect(
      store.monthlyExpenseBreakdown(2026, 7).any(
            (item) => item.label.contains('Fire insurance'),
          ),
      isTrue,
    );
  });

  test('generic recurring commitments follow flexible schedules', () {
    final store = RentalStore(now: DateTime(2026, 12, 18));
    store.loginAs(UserRole.owner);
    final facility = store.ownerFacilities.first;
    final indahWater = facility.extraCommitments.firstWhere(
      (commitment) => commitment.name == 'Indah Water',
    );

    expect(store.isHalfYearlyDue(indahWater.firstDueMonth, 1), isTrue);
    expect(store.isHalfYearlyDue(indahWater.firstDueMonth, 7), isTrue);
    expect(
      store.monthlyExpenseBreakdown(2026, 7).any(
            (item) => item.label.contains('Indah Water'),
          ),
      isTrue,
    );
    expect(
      store.monthlyExpenseBreakdown(2026, 7).any(
            (item) => item.label.contains('DBKL'),
          ),
      isTrue,
    );

    indahWater.frequency = CommitmentFrequency.quarterly;
    indahWater.firstDueMonth = 2;
    expect(store.isCommitmentDue(indahWater.frequency, 2, 2), isTrue);
    expect(store.isCommitmentDue(indahWater.frequency, 2, 5), isTrue);
    expect(store.isCommitmentDue(indahWater.frequency, 2, 6), isFalse);
    expect(
      store.monthlyExpenseBreakdown(2026, 5).any(
            (item) => item.label.contains('Indah Water (Quarterly)'),
          ),
      isTrue,
    );
  });

  test('extra recurring commitments are included by schedule', () {
    final store = RentalStore(now: DateTime(2026, 6, 18));
    store.loginAs(UserRole.owner);
    final facility = store.ownerFacilities.first;

    store.addRecurringCommitment(
      facility: facility,
      name: 'Lift Service',
      amount: 80,
      frequency: CommitmentFrequency.quarterly,
      firstDueMonth: 3,
    );

    expect(
      store.monthlyExpenseBreakdown(2026, 3).any(
            (item) => item.label.contains('Lift Service') && item.amount == 80,
          ),
      isTrue,
    );
    expect(
      store.monthlyExpenseBreakdown(2026, 4).any(
            (item) => item.label.contains('Lift Service'),
          ),
      isFalse,
    );
    expect(store.facilityExpenseForMonth(facility, 2026, 3),
        store.monthlyFacilityOutflow(facility) + 80);
  });

  testWidgets('utility evidence starts empty and requires upload',
      (tester) async {
    await tester.pumpWidget(const RentalFacilityApp());
    await tester.tap(find.text('Login as Owner'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Utilities').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Daniel Lim Wei Jian'));
    await tester.pumpAndSettle();
    final enterButton = find.text('Enter & Upload').first;
    await tester.ensureVisible(enterButton);
    await tester.pumpAndSettle();
    await tester.tap(enterButton);
    await tester.pumpAndSettle();

    expect(find.text('No file uploaded'), findsOneWidget);
    final saveButton = tester.widget<FilledButton>(
      find.byKey(const Key('save_utility_charges_button')),
    );
    expect(saveButton.onPressed, isNull);

    await tester.tap(find.byKey(const Key('upload_meter_reading_button')));
    await tester.pumpAndSettle();
    expect(find.textContaining('meter_'), findsOneWidget);
  });

  test('included utilities automatically await tenant payment', () {
    final store = RentalStore(now: DateTime(2026, 6, 20));
    final includedTenancy =
        store.tenancies.firstWhere((tenancy) => tenancy.utilitiesFullyIncluded);
    final automaticBill = store.bills.firstWhere(
      (bill) =>
          bill.tenantId == includedTenancy.tenantId &&
          bill.status == PaymentStatus.pendingTenantPayment,
    );

    expect(automaticBill.utilityEvidenceFileName, isNull);
    store.loginAs(UserRole.tenant);
    expect(store.tenantPayableBills, contains(automaticBill));
  });

  test('owner utility entry moves excluded bill to tenant payment', () {
    final store = RentalStore(now: DateTime(2026, 6, 20));
    final bill = store.bills.firstWhere(
      (item) => item.status == PaymentStatus.notSubmitted,
    );

    store.updateBillUtilities(
      bill,
      electricityUsageKwh: 120,
      waterAmount: 25,
      internetAmount: 0,
      utilityEvidenceFileName: 'reading.jpg',
    );

    expect(bill.status, PaymentStatus.pendingTenantPayment);
  });

  testWidgets('utilities use facility-left breakdown-right layout',
      (tester) async {
    tester.view.physicalSize = const Size(1200, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const RentalFacilityApp());
    await tester.tap(find.text('Login as Owner'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Utilities').last);
    await tester.pumpAndSettle();

    expect(find.text('UTILITY FACILITIES'), findsOneWidget);
    expect(find.text('Utility Breakdown'), findsOneWidget);
  });

  testWidgets('utility facility sidebar narrows after using detail page',
      (tester) async {
    tester.view.physicalSize = const Size(1200, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const RentalFacilityApp());
    await tester.tap(find.text('Login as Owner'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Utilities').last);
    await tester.pumpAndSettle();

    final sidebar = find.byKey(const Key('utility_facility_sidebar'));
    expect(tester.getSize(sidebar).width, 290);
    await tester.tap(find.text('Nur Aisyah Binti Rahman'));
    await tester.pumpAndSettle();
    expect(tester.getSize(sidebar).width, 76);
  });

  testWidgets('facility detail shows tenants left and bills right',
      (tester) async {
    tester.view.physicalSize = const Size(1200, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final store = RentalStore(now: DateTime(2026, 6, 20));
    store.loginAs(UserRole.owner);

    await tester.pumpWidget(
      RentalStoreScope(
        store: store,
        child: MaterialApp(
          home: FacilityMasterDetailScreen(
            facility: store.ownerFacilities.first,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final tenantPosition =
        tester.getTopLeft(find.byKey(const Key('all_tenants_filter')));
    final billPosition =
        tester.getTopLeft(find.byKey(const Key('bill_performance_detail')));
    expect(tenantPosition.dx, lessThan(billPosition.dx));
  });

  test('sample rental collection is populated through the current month', () {
    final store = RentalStore(now: DateTime(2026, 6, 18));
    store.loginAs(UserRole.owner);

    final summaries = store.yearlyFinancialSummary(2026);

    expect(
        summaries.take(6).every((summary) => summary.collection > 0), isTrue);
    expect(
        summaries.skip(6).every((summary) => summary.collection == 0), isTrue);
  });

  test('monthly pie breakdowns reconcile with chart totals', () {
    final store = RentalStore(now: DateTime(2026, 6, 18));
    store.loginAs(UserRole.owner);
    final june = store.yearlyFinancialSummary(2026)[5];
    final collectionItems = store.monthlyCollectionBreakdown(2026, 6);
    final expenseItems = store.monthlyExpenseBreakdown(2026, 6);

    expect(
      collectionItems.fold<double>(0, (sum, item) => sum + item.amount),
      june.collection,
    );
    expect(
      expenseItems.fold<double>(0, (sum, item) => sum + item.amount),
      june.expenses,
    );
    expect(collectionItems.any((item) => item.label.contains('Nur Aisyah')),
        isTrue);
    expect(
        expenseItems.any((item) => item.label.contains('Maintenance')), isTrue);
  });

  testWidgets('selecting a chart month shows two pie charts below the graph',
      (tester) async {
    await tester.pumpWidget(const RentalFacilityApp());
    await tester.tap(find.text('Login as Owner'));
    await tester.pumpAndSettle();

    final chart = find.byKey(const Key('financial_chart_touch_area'));
    await tester.ensureVisible(chart);
    await tester.pumpAndSettle();
    final rect = tester.getRect(chart);
    final januaryX = rect.left + 8 + (rect.width - 16) / 24;
    await tester.tapAt(Offset(januaryX, rect.center.dy));
    await tester.pumpAndSettle();

    expect(find.text('Jan 2026 Breakdown'), findsOneWidget);
    expect(find.textContaining('Nur Aisyah Binti Rahman'), findsOneWidget);
    expect(find.byType(Dialog), findsNothing);
    expect(find.textContaining('Facility 1 • Installment'), findsOneWidget);
    await tester.tapAt(Offset(januaryX, rect.center.dy));
    await tester.pumpAndSettle();
    expect(find.text('Jan 2026 Breakdown'), findsNothing);
  });

  test('time greeting follows morning afternoon and evening', () {
    expect(timeGreeting(DateTime(2026, 1, 1, 8)), 'Good morning');
    expect(timeGreeting(DateTime(2026, 1, 1, 14)), 'Good afternoon');
    expect(timeGreeting(DateTime(2026, 1, 1, 20)), 'Good evening');
    expect(firstName('Alex Tan'), 'Alex');
  });

  test('approved payment leaves pending and appears in history', () {
    final store = RentalStore();
    final bill = store.pendingBills.first;

    store.approveBill(bill);

    expect(store.pendingBills, isNot(contains(bill)));
    expect(bill.status, PaymentStatus.approved);
    expect(
      store.paymentReviewHistory.any(
        (event) =>
            event.billId == bill.id && event.status == PaymentStatus.approved,
      ),
      isTrue,
    );
  });

  test('financial chart hover maps cursor to the correct month', () {
    expect(financialChartMonthIndex(8, 728, 12), 0);
    expect(financialChartMonthIndex(368, 728, 12), 6);
    expect(financialChartMonthIndex(720, 728, 12), 11);
  });

  testWidgets('review action immediately updates pending and history tabs',
      (tester) async {
    await tester.pumpWidget(const RentalFacilityApp());
    await tester.tap(find.text('Login as Owner'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Review'));
    await tester.pumpAndSettle();

    expect(find.text('Pending Action (2)'), findsOneWidget);
    expect(find.text('History (9)'), findsOneWidget);

    await tester.tap(find.text('Review Payment'));
    await tester.pumpAndSettle();
    await tester.tap(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.text('Approve'),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Pending Action (1)'), findsOneWidget);
    expect(find.text('History (10)'), findsOneWidget);
  });
}
