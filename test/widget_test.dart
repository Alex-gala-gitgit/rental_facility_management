import 'dart:convert';

import 'package:excel/excel.dart' as xlsx;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rental_facility_management/main.dart';
import 'package:rental_facility_management/persistence/persistence_contract.dart';
import 'package:rental_facility_management/rentflow/rentflow_app.dart';

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

void main() {
  test('production workspace starts without demo business records', () {
    final store = RentalStore(seedDemoData: false);

    expect(store.facilities, isEmpty);
    expect(store.tenancies, isEmpty);
    expect(store.bills, isEmpty);
  });

  test('business data and payment metadata survive an app restart', () async {
    final persistence = TestPersistence();
    final now = DateTime(2026, 7, 1);
    final first = RentalStore(now: now, persistence: persistence);
    await first.initializePersistence();
    first.loginAs(UserRole.owner);
    final bill = first.bills.first;
    bill
      ..paymentDate = DateTime(2026, 7, 3)
      ..paymentReference = 'MBB-12345';
    first.addAdditionalIncome(
      facility: first.ownerFacilities.first,
      month: DateTime(2026, 7),
      category: 'Parking',
      amount: 180,
      note: 'Persistent audit record',
    );
    await first.flushPersistence();

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
  });

  test('monthly invoice workflow is created once and owner is notified', () {
    final store = RentalStore(now: DateTime(2026, 7, 1));

    final reminder = store.notifications.where(
      (item) => item.id == 'invoice_preparation_2026_7',
    );
    expect(reminder, hasLength(1));
    expect(reminder.single.message, contains('utility readings pending'));
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
    final tenancy = store.tenancies.firstWhere(
      (item) => item.utilitiesFullyIncluded,
    );
    final bill = store.bills.firstWhere(
      (item) =>
          item.tenantId == tenancy.tenantId && item.month == DateTime(2026, 7),
    );

    expect(bill.utilityEvidenceFileName, isNull);
    expect(
      bill.status == PaymentStatus.pendingTenantPayment ||
          bill.status == PaymentStatus.approved,
      isTrue,
    );
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

  test('owner meter reading updates exact utility total and payment state', () {
    final store = RentalStore(now: DateTime(2026, 7, 1));
    final bill = store.bills.firstWhere(
      (item) => item.status == PaymentStatus.notSubmitted,
    );

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
    expect(bill.status, PaymentStatus.pendingTenantPayment);
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
      electricityAmountOverride: 7.39,
      generalElectricAmount: 10,
      parkingRentalAmount: 50,
      dueDate: DateTime(2026, 7, 6),
    );

    expect(invoice.total, 692.39);
    final bytes = await invoicePdf(invoice);
    expect(bytes.length, greaterThan(1000));
    expect(utf8.decode(bytes.take(4).toList()), '%PDF');

    final portalLink = tenantInvoiceLink(invoice.id);
    final pdfLink = Uri.parse(
      'https://example.supabase.co/storage/v1/object/public/invoices/${invoice.id}.pdf',
    );
    final message = invoiceWhatsAppMessage(
      invoice,
      portalLink,
      pdfLink: pdfLink,
    );
    expect(portalLink.host, 'facility-billing-management.pages.dev');
    expect(message, contains(portalLink.toString()));
    expect(message, contains(pdfLink.toString()));
    expect(message, contains('RM 692.39'));
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

    expect(
      workbook.tables['Properties & Tenants']!.rows[1][18]?.value,
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
}
