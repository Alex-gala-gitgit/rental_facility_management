abstract class AppPersistence {
  Future<String?> readSnapshot();

  Future<void> writeSnapshot(String snapshot);

  Future<void> clear();

  Future<void> close();

  String get storageDescription;
}
