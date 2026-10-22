import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:rental_facility_management/main.dart';
import 'package:rental_facility_management/persistence/persistence_contract.dart';

class MemoryPersistence implements AppPersistence {
  String? snapshot;
  @override
  Future<String?> readSnapshot() async => snapshot;
  @override
  Future<void> writeSnapshot(String value) async {
    snapshot = value;
  }

  @override
  Future<void> clear() async {
    snapshot = null;
  }

  @override
  Future<void> close() async {}
  @override
  String get storageDescription => 'test memory';
}

void main() {
  test('owner reload applies tenant edits without reverting newer reviews', () {
    final request = TenantRequest(
        id: 'move',
        tenantId: 'tenant',
        facilityId: 'property',
        title: 'Move-out',
        message: 'Old date',
        createdAt: DateTime(2026, 10, 3),
        requestType: 'Move-out',
        requestedMoveOutDate: DateTime(2026, 10, 23),
        bankName: 'Old Bank',
        bankAccountNumber: '001',
        status: 'Accepted',
        reviewedAt: DateTime.utc(2026, 10, 3, 12));
    final incoming = <String, dynamic>{
      'id': 'move',
      'message': 'Move-out date: 30/10/2026',
      'requestedMoveOutDate': '2026-10-30T00:00:00.000',
      'bankName': 'New Bank',
      'bankAccountNumber': '002',
      'tenantEditedAt': '2026-10-03T11:00:00.000Z',
      'status': 'Open'
    };
    mergeTenantRequestRecord(request, incoming);
    expect(request.requestedMoveOutDate, DateTime(2026, 10, 30));
    expect(request.message, 'Move-out date: 30/10/2026');
    expect(request.bankName, 'New Bank');
    expect(request.bankAccountNumber, '002');
    expect(request.status, 'Accepted');
    mergeTenantRequestRecord(request, {
      ...incoming,
      'requestedMoveOutDate': '2026-10-23',
      'tenantEditedAt': '2026-10-03T10:00:00Z'
    });
    expect(request.requestedMoveOutDate, DateTime(2026, 10, 30));
    mergeTenantRequestRecord(request, {
      ...incoming,
      'status': 'Withdrawn',
      'tenantEditedAt': '2026-10-03T13:00:00Z'
    });
    expect(request.status, 'Withdrawn');
    mergeTenantRequestRecord(request, incoming);
    expect(request.status, 'Withdrawn');
  });
  test('only an active move-out request blocks the same tenant', () {
    final store = RentalStore(seedDemoData: false);
    final request = TenantRequest(
        id: 'active',
        tenantId: 'tenant',
        facilityId: 'property',
        title: 'Move-out',
        message: '',
        createdAt: DateTime(2026, 10, 3),
        requestType: 'Move-out');
    store.tenantRequests.add(request);
    expect(store.hasActiveMoveOutRequestFor('tenant'), isTrue);
    expect(store.hasActiveMoveOutRequestFor('another-tenant'), isFalse);
    for (final status in ['Withdrawn', 'Rejected', 'Accepted', 'Closed']) {
      request.status = status;
      expect(store.hasActiveMoveOutRequestFor('tenant'), isFalse);
    }
    store.dispose();
  });
  test('only the four requested categories remain', () {
    expect(tenantRequestTypes, [
      'Repair & Maintenance',
      'Move-out',
      'Access Card / Key',
      'General Enquiry'
    ]);
  });
  test('move-out date and bank details survive persistence', () async {
    final storage = MemoryPersistence();
    final source = RentalStore(seedDemoData: false);
    source.tenantRequests.add(TenantRequest(
        id: 'move-out-test',
        tenantId: 'tenant',
        facilityId: 'property',
        title: 'Move-out',
        message: 'Move-out requested',
        createdAt: DateTime(2026, 10, 3),
        requestType: 'Move-out',
        requestedMoveOutDate: DateTime(2026, 10, 31),
        tenantEditedAt: DateTime.utc(2026, 10, 3, 12),
        rejectionReason: 'Please choose another date.',
        bankName: 'Example Bank',
        bankAccountNumber: '001234567890'));
    storage.snapshot = jsonEncode(source.exportSnapshot());
    final restored = RentalStore(seedDemoData: false, persistence: storage);
    await restored.initializePersistence();
    final request = restored.tenantRequests.single;
    expect(request.requestedMoveOutDate, DateTime(2026, 10, 31));
    expect(request.bankName, 'Example Bank');
    expect(request.rejectionReason, 'Please choose another date.');
    expect(request.bankAccountNumber, '001234567890');
    expect(request.status, 'Open');
    expect(request.tenantEditedAt, DateTime.utc(2026, 10, 3, 12));
    source.dispose();
    restored.dispose();
  });
}
