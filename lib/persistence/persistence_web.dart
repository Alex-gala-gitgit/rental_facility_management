import 'dart:html' as html;

import 'persistence_contract.dart';

Future<AppPersistence> createPersistence() async => WebPersistence();

class WebPersistence implements AppPersistence {
  static const _stateKey = 'rental_store_snapshot_v1';

  @override
  String get storageDescription => 'browser local storage';

  @override
  Future<String?> readSnapshot() async => html.window.localStorage[_stateKey];

  @override
  Future<void> writeSnapshot(String snapshot) async {
    html.window.localStorage[_stateKey] = snapshot;
  }

  @override
  Future<void> clear() async {
    html.window.localStorage.remove(_stateKey);
  }

  @override
  Future<void> close() async {}
}
