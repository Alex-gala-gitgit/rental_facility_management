import 'dart:convert';
import 'dart:io';

void main() {
  final failures = <String>[];

  final pubspec = File('pubspec.yaml').readAsStringSync();
  final versionMatch =
      RegExp(r'^version:\s*([^+\s]+)\+(\d+)\s*$', multiLine: true)
          .firstMatch(pubspec);
  final release =
      jsonDecode(File('web/updates/version.json').readAsStringSync())
          as Map<String, dynamic>;
  if (versionMatch == null) {
    failures.add('pubspec.yaml must contain version: <name>+<code>.');
  } else {
    if (release['versionName'] != versionMatch.group(1)) {
      failures.add('version.json versionName does not match pubspec.yaml.');
    }
    if (release['versionCode'] != int.parse(versionMatch.group(2)!)) {
      failures.add('version.json versionCode does not match pubspec.yaml.');
    }
  }

  for (final root in ['lib', 'web', 'test']) {
    final directory = Directory(root);
    if (!directory.existsSync()) continue;
    for (final file in directory.listSync(recursive: true).whereType<File>()) {
      const textExtensions = {
        '.dart',
        '.html',
        '.js',
        '.json',
        '.mjs',
        '.ts',
        '.yaml',
        '.yml',
      };
      if (!textExtensions.any(file.path.toLowerCase().endsWith)) continue;
      final contents = file.readAsStringSync();
      if (contents.contains('SUPABASE_SERVICE_ROLE_KEY') ||
          contents.contains('SUPABASE_SECRET_KEY')) {
        failures
            .add('Server-only Supabase credential referenced by ${file.path}.');
      }
    }
  }

  final sql = Directory('supabase/migrations')
      .listSync()
      .whereType<File>()
      .where((file) => file.path.endsWith('.sql'))
      .map((file) => file.readAsStringSync().toLowerCase())
      .join('\n');
  final createdTables =
      RegExp(r'create\s+table(?:\s+if\s+not\s+exists)?\s+public\.([a-z0-9_]+)')
          .allMatches(sql)
          .map((match) => match.group(1)!)
          .toSet();
  for (final table in createdTables) {
    final rls = RegExp(
        'alter\\s+table\\s+(?:if\\s+exists\\s+)?public\\.$table\\s+enable\\s+row\\s+level\\s+security');
    if (!rls.hasMatch(sql))
      failures.add('RLS is not enabled for public.$table.');
  }

  final config = File('supabase/config.toml').readAsStringSync();
  final unverifiedFunctions = RegExp(
    r'\[functions\.([^\]]+)\]\s*verify_jwt\s*=\s*false',
  ).allMatches(config).map((match) => match.group(1)!).toSet();
  const publicFunctionAuthSignals = <String, List<String>>{
    'invoice-portal': ['portal_token', 'token'],
    'invite-tenant': ['authorization', 'getuser'],
    'meter-reading-ocr': ['authorization', 'getuser'],
    'tenant-profile-invitation': ['token', 'invitation'],
    'platform-event': ['authorization', 'anonymous'],
    'tenant-lifecycle': ['x-lifecycle-secret', 'tenant_lifecycle_cron_secret'],
  };
  for (final functionName in unverifiedFunctions) {
    final sourceFile = File('supabase/functions/$functionName/index.ts');
    if (!sourceFile.existsSync()) {
      failures.add('verify_jwt=false function $functionName has no index.ts.');
      continue;
    }
    final source = sourceFile.readAsStringSync().toLowerCase();
    final signals = publicFunctionAuthSignals[functionName];
    if (signals == null || !signals.any(source.contains)) {
      failures.add(
          'verify_jwt=false function $functionName lacks an approved auth control.');
    }
  }

  if (failures.isNotEmpty) {
    stderr.writeln('Release readiness failed:');
    for (final failure in failures) stderr.writeln(' - $failure');
    exitCode = 1;
    return;
  }
  stdout.writeln(
    'Release readiness passed: versions aligned, client secrets absent, RLS present, and public functions checked.',
  );
}
