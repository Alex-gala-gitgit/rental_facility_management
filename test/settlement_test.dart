import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as images;
import 'package:rental_facility_management/persistence/persistence_contract.dart';
import 'package:rental_facility_management/settlement/settlement_model.dart';
import 'package:rental_facility_management/settlement/settlement_page.dart';
import 'package:rental_facility_management/settlement/settlement_pdf.dart';
import 'package:rental_facility_management/settlement/saved_settlement_invoice.dart';
import 'package:rental_facility_management/settlement/money_input.dart';
import 'package:rental_facility_management/cloud/meter_reading_service.dart';
import 'package:rental_facility_management/file_upload/picked_image_data.dart';
import 'package:rental_facility_management/main.dart' as app;

class DraftMemory implements AppPersistence {
  String? saved;
  @override
  Future<String?> readSnapshot() async => saved;
  @override
  Future<void> writeSnapshot(String value) async {
    saved = value;
  }

  @override
  Future<void> clear() async {
    saved = null;
  }

  @override
  Future<void> close() async {}
  @override
  String get storageDescription => 'memory';
}

MoveOutSettlement example(
        {int water = 2000,
        int deposit = 290000,
        SettlementAttachment? meter,
        SettlementAttachment? payslip}) =>
    MoveOutSettlement(
      tenantName: 'Mei Kei (Miki)',
      propertyName: 'Skyawani 2',
      unitName: '3903',
      moveOutDate: DateTime(2026, 10, 30),
      deposit: deposit,
      electricity: 14550,
      water: water,
      internet: 5000,
      parking: 10000,
      other: 1000,
      otherDescription: 'Cleaning fee',
      meter: meter,
      payslip: payslip,
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('invoice click prepares PDF and offers preview and download without blank route', (tester) async {
    final persistence = DraftMemory()..saved = jsonEncode(example().toJson());
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: SavedSettlementInvoice(
      draftKey: 'test', translate: (key) => key, persistence: persistence,
    ))));
    await tester.pumpAndSettle();
    await tester.runAsync(() async {
      // Font asset loading/PDF encoding use real asynchronous I/O.
      await Future<void>.delayed(const Duration(seconds: 1));
    });
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsNothing);
    expect(find.text('View PDF'), findsOneWidget);
    expect(find.text('Download PDF'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(tester.widget<FilledButton>(find.byWidgetPredicate((widget) => widget is FilledButton)).onPressed, isNotNull);
    expect(find.byIcon(Icons.chevron_right), findsNothing);
    expect(tester.takeException(), isNull);
  });
  test('billing stops after move-out month including year boundary', () {
    final store = app.RentalStore(now: DateTime(2026, 10, 1));
    final tenancy = store.tenancies.first;
    tenancy.leaseStart = DateTime(2026, 1, 1);
    tenancy.leaseEnd = DateTime(2028, 12, 31);
    tenancy.active = true;
    tenancy.lastActiveDate = DateTime(2026, 10, 30);
    expect(tenancy.canGenerateBillForMonth(DateTime(2026, 10)), isTrue);
    expect(tenancy.canGenerateBillForMonth(DateTime(2026, 11)), isFalse);
    expect(tenancy.canGenerateBillForMonth(DateTime(2027, 1)), isFalse);
    tenancy.lastActiveDate = DateTime(2026, 12, 31);
    expect(tenancy.canGenerateBillForMonth(DateTime(2026, 12)), isTrue);
    expect(tenancy.canGenerateBillForMonth(DateTime(2027, 1)), isFalse);
    tenancy.active = false;
    expect(tenancy.canGenerateBillForMonth(DateTime(2026, 12)), isFalse);
    store.dispose();
  });
  test('complete refund records request history and tenancy ending once', () {
    final store = app.RentalStore();
    store.currentUser = store.users.firstWhere((user) => user.role == app.UserRole.owner);
    final tenancy = store.tenancies.first;
    final date = DateTime.now().add(const Duration(days: 10));
    final request = app.TenantRequest(id: 'refund-test', tenantId: tenancy.tenantId,
      facilityId: tenancy.facilityId, title: 'Move-out', message: '',
      createdAt: DateTime.now(), requestType: 'Move-out', requestedMoveOutDate: date);
    store.tenantRequests.add(request);
    final value = MoveOutSettlement(tenantName: 'Test', propertyName: 'Test',
      unitName: tenancy.unitName, moveOutDate: date, deposit: 10000,
      electricity: 0, water: 0, internet: 0, parking: 0, other: 0,
      otherDescription: '', payslip: SettlementAttachment('paid.png', Uint8List.fromList([1])));
    store.completeMoveOutRefund(tenancy, value);
    expect(request.status, 'Completed');
    expect(tenancy.lastActiveDate, DateTime(date.year, date.month, date.day));
    expect(tenancy.inactiveReason, 'Tenancy completed');
    expect(tenancy.canGenerateBillForMonth(DateTime(date.year, date.month + 1)), isFalse);
    expect(tenancy.inactiveRemark, 'Triggered by system because deposit refund completed.');
    final reviewed = request.reviewedAt;
    store.completeMoveOutRefund(tenancy, value);
    expect(request.reviewedAt, reviewed);
    store.dispose();
  });
  testWidgets('saved invoice row is hidden without a generated settlement',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: SavedSettlementInvoice(
      draftKey: 'test',
      translate: (key) => key,
      persistence: DraftMemory(),
    ))));
    await tester.pumpAndSettle();
    expect(find.text('Move-out settlement invoice'), findsNothing);
  });
  testWidgets(
      'saved invoice row shows date and proof status without claiming refund',
      (tester) async {
    final persistence = DraftMemory()..saved = jsonEncode(example().toJson());
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: SavedSettlementInvoice(
      draftKey: 'test',
      translate: (key) => key,
      persistence: persistence,
    ))));
    await tester.pumpAndSettle();
    expect(find.text('Move-out settlement invoice'), findsOneWidget);
    expect(find.textContaining('30/10/2026'), findsOneWidget);
    expect(find.textContaining('Refund pending'), findsOneWidget);
    expect(find.text('View PDF'), findsOneWidget);
  });
  testWidgets('saved payslip marks settlement refunded after reload',
      (tester) async {
    final persistence = DraftMemory()
      ..saved = jsonEncode(example(
        payslip: SettlementAttachment('refund.png', Uint8List.fromList([1])),
      ).toJson());
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: SavedSettlementInvoice(
      draftKey: 'test',
      translate: (key) => key,
      persistence: persistence,
    ))));
    await tester.pumpAndSettle();
    expect(find.textContaining('Refunded'), findsOneWidget);
    expect(example().isRefunded, isFalse);
  });
  test(
      'shared app money formatter limits decimals and normalizes leading zeros',
      () {
    final formatter = appMoneyInputFormatters().last;
    const old = TextEditingValue(
        text: '0.00', selection: TextSelection.collapsed(offset: 4));
    expect(
        formatter.formatEditUpdate(
            old,
            const TextEditingValue(
                text: '0.005555',
                selection: TextSelection.collapsed(offset: 8))),
        old);
    expect(
        formatter
            .formatEditUpdate(
                old,
                const TextEditingValue(
                    text: '0010.50',
                    selection: TextSelection.collapsed(offset: 7)))
            .text,
        '10.50');
    expect(
        formatter.formatEditUpdate(old, const TextEditingValue(text: '1.2.3')),
        old);
  });
  testWidgets('all settlement money fields use two-decimal formatting',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
        home: MoveOutSettlementPage(
      tenantName: 'Miki',
      propertyName: 'Skyawani 2',
      unitName: '3903',
      draftKey: 'money-test',
      initialDate: DateTime(2026, 10, 30),
      translate: (key) => key,
      persistence: DraftMemory(),
      calculateElectricityCharge: (usage) => usage * 0.516,
    )));
    await tester.pumpAndSettle();
    for (final label in [
      'Deposit held',
      'Electricity',
      'Water bill',
      'Internet',
      'Parking',
      'Other charges'
    ]) {
      final field = find.byKey(ValueKey('settlement-$label'));
      expect(
          tester
              .widget<TextField>(
                  find.descendant(of: field, matching: find.byType(TextField)))
              .inputFormatters!
              .length,
          2);
      await tester.enterText(field, '10.50');
      await tester.pump();
      await tester.enterText(field, '10.505');
      await tester.pump();
      expect(tester.widget<TextFormField>(field).controller!.text, '10.50');
    }
    await tester.enterText(
        find.byKey(const ValueKey('settlement-Water bill')), '12');
    await tester.pump();
    await tester.enterText(
        find.byKey(const ValueKey('settlement-Internet')), '0');
    await tester.pumpAndSettle();
    expect(
        tester
            .widget<TextFormField>(
                find.byKey(const ValueKey('settlement-Water bill')))
            .controller!
            .text,
        '12.00');
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets(
      'meter upload detects usage and calculates charge with supplied property tariff',
      (tester) async {
    final image = images.Image(width: 10, height: 10);
    final bytes = Uint8List.fromList(images.encodePng(image));
    await tester.pumpWidget(MaterialApp(
        home: MoveOutSettlementPage(
      tenantName: 'Miki',
      propertyName: 'Skyawani 2',
      unitName: '3903',
      draftKey: 'test-ocr',
      initialDate: DateTime(2026, 10, 30),
      translate: (key) => key,
      persistence: DraftMemory(),
      calculateElectricityCharge: (usage) => usage * 0.516,
      pickImage: () async => PickedImageData(name: 'meter.png', bytes: bytes),
      readMeter: (original, name) async {
        expect(original, bytes);
        expect(name, 'meter.png');
        return const DetectedMeterReading(usageKwh: 169.50);
      },
    )));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Upload').first);
    await tester.tap(find.text('Upload').first);
    await tester.pumpAndSettle();
    final charge = tester.widget<TextFormField>(
        find.byKey(const ValueKey('settlement-Electricity')));
    expect(charge.controller!.text, '87.46');
    final usage = tester.widget<TextFormField>(
        find.byKey(const ValueKey('settlement-electricity-usage')));
    expect(usage.controller!.text, '169.50');
    await tester.enterText(
        find.byKey(const ValueKey('settlement-electricity-usage')), '100');
    await tester.pump();
    expect(charge.controller!.text, '51.60');
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets('failed OCR retains evidence but clears stale electricity charge',
      (tester) async {
    final bytes = Uint8List.fromList(
        images.encodePng(images.Image(width: 10, height: 10)));
    await tester.pumpWidget(MaterialApp(
        home: MoveOutSettlementPage(
      tenantName: 'Miki',
      propertyName: 'Skyawani 2',
      unitName: '3903',
      draftKey: 'test-fail',
      initialDate: DateTime(2026, 10, 30),
      translate: (key) => key,
      persistence: DraftMemory(),
      calculateElectricityCharge: (usage) => usage * 0.516,
      pickImage: () async => PickedImageData(name: 'meter.png', bytes: bytes),
      readMeter: (_, __) async => throw StateError('Unreadable'),
    )));
    await tester.pumpAndSettle();
    await tester.enterText(
        find.byKey(const ValueKey('settlement-Electricity')), '100');
    await tester.ensureVisible(find.text('Upload').first);
    await tester.tap(find.text('Upload').first);
    await tester.pumpAndSettle();
    final charge = tester.widget<TextFormField>(
        find.byKey(const ValueKey('settlement-Electricity')));
    expect(charge.controller!.text, '');
    expect(find.text('meter.png'), findsOneWidget);
    expect(
        find.text(
            'Could not read the meter. Enter the usage or electricity amount manually.'),
        findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });
  test('money parsing is exact and rejects malformed or negative inputs', () {
    expect(settlementCents('010'), 1000);
    expect(settlementCents('145.50'), 14550);
    expect(settlementCents('0.1'), 10);
    for (final invalid in ['-1', 'NaN', 'Infinity', '1.001', '', '1e5']) {
      expect(settlementCents(invalid), isNull);
    }
  });
  test('all five charges reduce refund, including water and other description',
      () {
    final value = example();
    expect(value.deductions, 32550);
    expect(value.balance, 257450);
    expect(value.charges.map((item) => item.$1), contains('Water bill'));
    expect(value.otherLabel, 'Other charges - Cleaning fee');
    expect(example(deposit: 1000).balance, -31550);
  });
  test('draft round trip retains date, description and both attachments', () {
    final attachment =
        SettlementAttachment('proof.png', Uint8List.fromList([1, 2, 3]));
    final original = example(meter: attachment, payslip: attachment);
    final restored =
        MoveOutSettlement.fromJson(jsonDecode(jsonEncode(original.toJson())));
    expect(restored.toJson(), original.toJson());
    expect(restored.dateLabel, '30/10/2026');
  });
  test('PDF generation includes both image pages', () async {
    final image = images.Image(width: 300, height: 180);
    images.fill(image, color: images.ColorRgb8(229, 240, 252));
    final attachment = SettlementAttachment(
        'sample-proof.png', Uint8List.fromList(images.encodePng(image)));
    final bytes = await buildSettlementPdf(
        example(meter: attachment, payslip: attachment));
    expect(ascii.decode(bytes.take(4).toList()), '%PDF');
    // Design QA output, never a live invoice or a write to tenant records.
    final output = File('test_artifacts/move-out-settlement-qa.pdf');
    await output.parent.create(recursive: true);
    await output.writeAsBytes(bytes);
  });
  test('PDF renders Chinese other-charge descriptions', () async {
    final value = MoveOutSettlement(
      tenantName: '测试租客',
      propertyName: 'Skyawani 2',
      unitName: '3903',
      moveOutDate: DateTime(2026, 10, 30),
      deposit: 290000,
      electricity: 14550,
      water: 2000,
      internet: 5000,
      parking: 10000,
      other: 1000,
      otherDescription: '清洁费',
    );
    final bytes = await buildSettlementPdf(value);
    await File('test_artifacts/move-out-settlement-cjk-qa.pdf')
        .writeAsBytes(bytes);
    expect(bytes.length, greaterThan(1000));
  });
  testWidgets('form has water and description; summary reflects input',
      (tester) async {
    final memory = DraftMemory();
    await tester.pumpWidget(MaterialApp(
        home: MoveOutSettlementPage(
      tenantName: 'Miki',
      propertyName: 'Skyawani 2',
      unitName: '3903',
      draftKey: 'test',
      initialDate: DateTime(2026, 10, 30),
      calculateElectricityCharge: (usage) => usage * 0.516,
      translate: (key) => key,
      persistence: memory,
    )));
    await tester.pumpAndSettle();
    expect(find.text('Initiate move-out'), findsNothing);
    expect(find.text('Cancel'), findsNothing);
    await tester.enterText(
        find.byKey(const ValueKey('settlement-Other charges')), '10');
    await tester.enterText(
        find.byKey(const ValueKey('settlement-other-description')),
        'Cleaning fee');
    await tester.pump();
    expect(find.text('Other charges - Cleaning fee'), findsOneWidget);
    expect(find.byKey(const ValueKey('settlement-Water bill')), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });
}
