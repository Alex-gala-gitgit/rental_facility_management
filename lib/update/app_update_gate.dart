import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';

const _updateManifestUrl =
    'https://facility-billing-management.pages.dev/updates/version.json';

class AppUpdateInfo {
  const AppUpdateInfo({
    required this.versionName,
    required this.versionCode,
    required this.apkUrl,
    required this.releaseNotes,
    required this.mandatory,
    required this.installedVersionName,
    required this.installedVersionCode,
  });

  final String versionName;
  final int versionCode;
  final Uri apkUrl;
  final String releaseNotes;
  final bool mandatory;
  final String installedVersionName;
  final int installedVersionCode;
}

class AppUpdateService {
  const AppUpdateService();

  static const _versionChannel =
      MethodChannel('rental_facility_manager/app_version');

  Future<AppUpdateInfo?> checkForUpdate() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
      return null;
    }

    final installedVersion = await _installedVersion();
    final installedBuild = installedVersion.versionCode;
    final response = await http.get(
      Uri.parse(_updateManifestUrl).replace(
        queryParameters: <String, String>{
          'installedBuild': installedBuild.toString(),
          'checkedAt': DateTime.now().millisecondsSinceEpoch.toString(),
        },
      ),
      headers: const <String, String>{'Cache-Control': 'no-cache'},
    ).timeout(const Duration(seconds: 8));

    if (response.statusCode != 200) {
      return null;
    }

    final payload = jsonDecode(response.body);
    if (payload is! Map<String, dynamic>) {
      return null;
    }

    final versionCode = _asInt(payload['versionCode']);
    final versionName = payload['versionName']?.toString().trim() ?? '';
    final apkUrl = Uri.tryParse(payload['apkUrl']?.toString().trim() ?? '');
    if (versionCode == null ||
        versionCode <= installedBuild ||
        versionName.isEmpty ||
        apkUrl == null ||
        apkUrl.scheme != 'https') {
      return null;
    }

    return AppUpdateInfo(
      versionName: versionName,
      versionCode: versionCode,
      apkUrl: apkUrl,
      releaseNotes: payload['releaseNotes']?.toString().trim() ?? '',
      mandatory: payload['mandatory'] == true,
      installedVersionName: installedVersion.versionName,
      installedVersionCode: installedBuild,
    );
  }

  Future<_InstalledVersion> _installedVersion() async {
    final payload = await _versionChannel
        .invokeMapMethod<String, dynamic>('getAppVersion');
    final versionName = payload?['versionName']?.toString().trim() ?? '';
    final versionCode = _asInt(payload?['versionCode']) ?? 0;
    return _InstalledVersion(
      versionName: versionName.isEmpty ? 'Unknown' : versionName,
      versionCode: versionCode,
    );
  }

  int? _asInt(Object? value) {
    if (value is int) return value;
    return int.tryParse(value?.toString() ?? '');
  }
}

class _InstalledVersion {
  const _InstalledVersion({
    required this.versionName,
    required this.versionCode,
  });

  final String versionName;
  final int versionCode;
}

class AppUpdateGate extends StatefulWidget {
  const AppUpdateGate({required this.child, super.key});

  final Widget child;

  @override
  State<AppUpdateGate> createState() => _AppUpdateGateState();
}

class _AppUpdateGateState extends State<AppUpdateGate> {
  bool _hasChecked = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkForUpdate());
  }

  Future<void> _checkForUpdate() async {
    if (_hasChecked) return;
    _hasChecked = true;

    try {
      final update = await const AppUpdateService().checkForUpdate();
      if (!mounted || update == null) return;
      await _showUpdateDialog(update);
    } catch (error, stackTrace) {
      debugPrint('Update check skipped: $error');
      debugPrintStack(stackTrace: stackTrace);
    }
  }

  Future<void> _showUpdateDialog(AppUpdateInfo update) async {
    await showDialog<void>(
      context: context,
      barrierDismissible: !update.mandatory,
      builder: (dialogContext) => WillPopScope(
        onWillPop: () async => !update.mandatory,
        child: AlertDialog(
          icon: const Icon(Icons.system_update_alt_rounded, size: 34),
          title: const Text('New version available'),
          content: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Version ${update.versionName} is ready. '
                  'You currently have ${update.installedVersionName}.',
                ),
                if (update.releaseNotes.isNotEmpty) ...[
                  const SizedBox(height: 14),
                  const Text(
                    'What\'s new',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 4),
                  Text(update.releaseNotes),
                ],
                const SizedBox(height: 14),
                const Text(
                  'Android will ask you to confirm the update after the APK '
                  'downloads. Your existing app data will remain available.',
                  style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                ),
              ],
            ),
          ),
          actions: [
            if (!update.mandatory)
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: const Text('Later'),
              ),
            FilledButton.icon(
              onPressed: () async {
                final messenger = ScaffoldMessenger.maybeOf(context);
                final opened = await launchUrl(
                  update.apkUrl,
                  mode: LaunchMode.externalApplication,
                );
                if (!opened && mounted) {
                  messenger?.showSnackBar(
                    const SnackBar(
                      content: Text(
                        'The update download could not be opened. Please try again.',
                      ),
                    ),
                  );
                  return;
                }
                if (!update.mandatory && dialogContext.mounted) {
                  Navigator.of(dialogContext).pop();
                }
              },
              icon: const Icon(Icons.download_rounded),
              label: const Text('Update now'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
