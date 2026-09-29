import 'dart:html' as html;

import 'persistence_contract.dart';

Future<AppPersistence> createPersistence(String namespace) async =>
    WebPersistence(namespace);

class WebPersistence implements AppPersistence {
  WebPersistence(String namespace)
      : _stateKey = 'rental_store_snapshot_${namespace}_v1',
        _allowUatLegacyImport = namespace.startsWith('uat') {
    if (!_allowUatLegacyImport) {
      html.window.localStorage.remove(_legacyStateKey);
    }
  }

  static const _legacyStateKey = 'rental_store_snapshot_v2';
  final String _stateKey;
  final bool _allowUatLegacyImport;

  @override
  String get storageDescription => 'browser local storage';

  @override
  Future<String?> readSnapshot() async {
    final current = html.window.localStorage[_stateKey];
    if (current != null || !_allowUatLegacyImport) return current;
    final legacy = html.window.localStorage[_legacyStateKey];
    if (legacy != null) html.window.localStorage[_stateKey] = legacy;
    return legacy;
  }

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
