import 'persistence_contract.dart';

Future<AppPersistence> createPersistence() async => MemoryPersistence();

class MemoryPersistence implements AppPersistence {
  String? _snapshot;

  @override
  String get storageDescription => 'temporary memory';

  @override
  Future<void> clear() async => _snapshot = null;

  @override
  Future<void> close() async {}

  @override
  Future<String?> readSnapshot() async => _snapshot;

  @override
  Future<void> writeSnapshot(String snapshot) async => _snapshot = snapshot;
}
