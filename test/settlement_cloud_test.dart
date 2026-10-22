import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:rental_facility_management/settlement/settlement_cloud_persistence.dart';
import 'settlement_test.dart' show DraftMemory, example;

class RemoteMemory implements SettlementRemote {
  Map<String, dynamic>? row;
  Uint8List? bytes;
  bool fail = false;
  int saves = 0;
  @override
  Future<Map<String, dynamic>?> read() async {
    if (fail) throw StateError('Offline');
    return row;
  }

  @override
  Future<void> save(
      String snapshot, Uint8List pdf, int? expectedRevision) async {
    if (fail || expectedRevision != row?['revision'])
      throw StateError('Conflict/offline');
    row = {
      'payload': jsonDecode(snapshot),
      'revision': (expectedRevision ?? 0) + 1,
      'pdf_path': 'private/test.pdf'
    };
    bytes = pdf;
    saves++;
  }

  @override
  Future<Uint8List> pdf(String path) async => bytes!;
}

void main() {
  final pdf = Uint8List.fromList([37, 80, 68, 70]);
  SettlementCloudPersistence adapter(RemoteMemory remote, DraftMemory local) =>
      SettlementCloudPersistence(remote, local, buildPdf: (_) async => pdf);
  test('legacy settlement migrates once without deleting local record',
      () async {
    final local = DraftMemory()..saved = jsonEncode(example().toJson());
    final remote = RemoteMemory();
    final cloud = adapter(remote, local);
    expect(await cloud.readSnapshot(), local.saved);
    expect(remote.saves, 1);
    expect(await cloud.readPdf(), pdf);
    await cloud.readSnapshot();
    expect(remote.saves, 1);
    expect(local.saved, isNotNull);
  });
  test('a second device retrieves settlement and the exact stored PDF',
      () async {
    final remote = RemoteMemory();
    final first = adapter(remote, DraftMemory());
    await first.readSnapshot();
    await first.writeSnapshot(jsonEncode(example().toJson()));
    final second = adapter(remote, DraftMemory());
    expect(jsonDecode((await second.readSnapshot())!)['tenantName'],
        'Mei Kei (Miki)');
    expect(await second.readPdf(), pdf);
  });
  test('cloud record wins over old local migration data', () async {
    final remote = RemoteMemory();
    final first = adapter(remote, DraftMemory());
    await first.readSnapshot();
    await first.writeSnapshot(jsonEncode(example(deposit: 50000).toJson()));
    final staleLocal = DraftMemory()..saved = jsonEncode(example().toJson());
    expect(
        jsonDecode(
            (await adapter(remote, staleLocal).readSnapshot())!)['deposit'],
        50000);
    expect(remote.saves, 1);
  });
  test('offline migration is not reported as a cloud save', () async {
    final local = DraftMemory()..saved = jsonEncode(example().toJson());
    final remote = RemoteMemory()..fail = true;
    await expectLater(adapter(remote, local).readSnapshot(), throwsStateError);
    expect(remote.saves, 0);
    expect(local.saved, isNotNull);
  });
  test('two device stale update is rejected', () async {
    final remote = RemoteMemory();
    final first = adapter(remote, DraftMemory());
    await first.readSnapshot();
    await first.writeSnapshot(jsonEncode(example().toJson()));
    final second = adapter(remote, DraftMemory());
    await second.readSnapshot();
    await first.writeSnapshot(jsonEncode(example(deposit: 90000).toJson()));
    await expectLater(
        second.writeSnapshot(jsonEncode(example().toJson())), throwsStateError);
    expect(remote.row!['payload']['deposit'], 90000);
  });
}
