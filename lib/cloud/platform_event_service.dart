import 'dart:convert';
import 'dart:math';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../persistence/app_persistence.dart';

class PlatformEventService {
  const PlatformEventService._();

  static Future<void> trackLaunch(
    SupabaseClient client, {
    required bool admin,
    required Uri uri,
  }) async {
    try {
      final persistence =
          await createAppPersistence(namespace: 'platform_analytics');
      var visitorKey = '';
      final saved = await persistence.readSnapshot();
      if (saved != null && saved.isNotEmpty) {
        final decoded = jsonDecode(saved);
        if (decoded is Map) visitorKey = '${decoded['visitorKey'] ?? ''}';
      }
      if (!RegExp(r'^[A-Za-z0-9_-]{16,120}$').hasMatch(visitorKey)) {
        final random = Random.secure();
        visitorKey = List.generate(
          32,
          (_) =>
              'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789_-'[
                  random.nextInt(64)],
        ).join();
        await persistence.writeSnapshot(jsonEncode({'visitorKey': visitorKey}));
      }
      await persistence.close();
      await client.functions.invoke(
        'platform-event',
        body: {
          'eventType': admin ? 'admin_open' : 'page_view',
          'visitorKey': visitorKey,
          'path': uri.path.isEmpty ? '/' : uri.path,
        },
      );
    } catch (_) {
      // Analytics must never delay or block application access.
    }
  }
}
