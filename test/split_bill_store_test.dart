import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rental_facility_management/persistence/persistence_contract.dart';
import 'package:rental_facility_management/split_bill/split_bill_app.dart';
import 'package:rental_facility_management/split_bill/split_bill_store.dart';

class _MemoryPersistence implements AppPersistence {
  String? value;

  @override
  Future<void> clear() async => value = null;

  @override
  Future<void> close() async {}

  @override
  Future<String?> readSnapshot() async => value;

  @override
  String get storageDescription => 'memory';

  @override
  Future<void> writeSnapshot(String snapshot) async => value = snapshot;
}

void main() {
  test('multiple payers and bills produce correct net balances', () async {
    final store = SplitBillStore(persistence: _MemoryPersistence());
    await store.initialize();
    final event = await store.createEvent(
      name: 'Dinner',
      ownerName: 'You',
      date: DateTime(2026, 8, 17),
    );
    await store.addParticipant(event, 'Mei');
    await store.addParticipant(event, 'Alex');
    final you = event.participants[0];
    final mei = event.participants[1];
    final alex = event.participants[2];

    await store.addBill(
      event: event,
      description: 'Dinner',
      amount: 90,
      payerId: you.id,
      participantIds: [you.id, mei.id, alex.id],
    );
    await store.addBill(
      event: event,
      description: 'Taxi',
      amount: 30,
      payerId: mei.id,
      participantIds: [you.id, mei.id],
    );

    expect(event.balances[you.id], 45);
    expect(event.balances[mei.id], -15);
    expect(event.balances[alex.id], -30);
    expect(event.settlements, hasLength(2));
    expect(event.settlements.fold<double>(0, (sum, item) => sum + item.amount),
        45);
  });

  test('event can close only after every calculated payment is marked',
      () async {
    final store = SplitBillStore(persistence: _MemoryPersistence());
    await store.initialize();
    final event = await store.createEvent(
      name: 'Trip',
      ownerName: 'A',
      date: DateTime(2026, 8, 17),
    );
    await store.addParticipant(event, 'B');
    await store.addBill(
      event: event,
      description: 'Hotel',
      amount: 100,
      payerId: event.participants.first.id,
      participantIds: event.participants.map((item) => item.id).toList(),
    );

    expect(event.canClose, isFalse);
    expect(await store.closeEvent(event), isFalse);
    await store.markSettlementPaid(event, event.settlements.single);
    expect(event.canClose, isTrue);
    expect(await store.closeEvent(event), isTrue);
    expect(event.isClosed, isTrue);
  });

  test('one item can have multiple payers and four equal participants',
      () async {
    final store = SplitBillStore(persistence: _MemoryPersistence());
    await store.initialize();
    final event = await store.createEvent(
      name: 'Dinner',
      ownerName: 'AA',
      date: DateTime(2026, 9, 13),
    );
    await store.addParticipant(event, 'BB');
    await store.addParticipant(event, 'CC');
    await store.addParticipant(event, 'DD');
    final aa = event.participants[0];
    final bb = event.participants[1];
    final cc = event.participants[2];
    final dd = event.participants[3];

    final bill = await store.addBill(
      event: event,
      description: 'Item A',
      amount: 100,
      payerId: aa.id,
      payerContributions: {aa.id: 80, bb.id: 20},
      participantIds: [aa.id, bb.id, cc.id, dd.id],
    );

    expect(bill, isNotNull);
    expect(event.balances[aa.id], 55);
    expect(event.balances[bb.id], -5);
    expect(event.balances[cc.id], -25);
    expect(event.balances[dd.id], -25);
    expect(event.settlements.fold<double>(0, (sum, item) => sum + item.amount),
        55);
    expect(
        store
            .shareBillUri(Uri.parse('https://homeops360.app/'), event, bill!)
            .path,
        '/splitz/');
  });

  test('different breakfast values use exact shares', () async {
    final store = SplitBillStore(persistence: _MemoryPersistence());
    await store.initialize();
    final event = await store.createEvent(
      name: 'Breakfast',
      ownerName: 'Alex',
      date: DateTime(2026, 9, 14),
    );
    await store.addParticipant(event, 'Benson');
    final alex = event.participants[0];
    final benson = event.participants[1];

    await store.addBill(
      event: event,
      description: 'Set breakfast',
      amount: 55,
      payerId: alex.id,
      payerContributions: {alex.id: 55},
      participantIds: [alex.id, benson.id],
      participantShares: {alex.id: 30, benson.id: 25},
    );

    expect(event.balances[alex.id], 25);
    expect(event.balances[benson.id], -25);
    expect(event.settlements.single.fromId, benson.id);
    expect(event.settlements.single.toId, alex.id);
    expect(event.settlements.single.amount, 25);
  });

  test('a bill entered for another payer waits for confirmation', () async {
    final store = SplitBillStore(persistence: _MemoryPersistence());
    await store.initialize();
    final event = await store.createEvent(
      name: 'Lunch',
      ownerName: 'You',
      date: DateTime(2026, 8, 17),
    );
    await store.addParticipant(event, 'Mei');
    final bill = await store.addBill(
      event: event,
      description: 'Lunch',
      amount: 40,
      payerId: event.participants.last.id,
      participantIds: event.participants.map((item) => item.id).toList(),
    );

    expect(bill, isNotNull);
    expect(bill!.payerConfirmed, isFalse);
    await store.setLocalParticipant(event, event.participants.last.id);
    await store.confirmBill(event, bill.id);
    expect(event.bills.single.payerConfirmed, isTrue);
  });

  testWidgets('first event can be created on a mobile screen', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(SplitBillApp(
      persistence: _MemoryPersistence(),
      launchUri: Uri.parse('https://example.com/splitz/'),
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Create event').first);
    await tester.pumpAndSettle();
    await tester.enterText(
        find.widgetWithText(TextField, 'Event name'), 'Dinner');
    await tester.enterText(
        find.widgetWithText(TextField, 'Your name on this device'), 'You');
    await tester.tap(find.widgetWithText(FilledButton, 'Create'));
    await tester.pumpAndSettle();

    expect(find.text('Dinner'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
