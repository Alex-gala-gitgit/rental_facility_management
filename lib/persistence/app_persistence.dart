import 'persistence_contract.dart';
import 'persistence_stub.dart'
    if (dart.library.io) 'persistence_native.dart'
    if (dart.library.html) 'persistence_web.dart';

Future<AppPersistence> createAppPersistence() => createPersistence();
