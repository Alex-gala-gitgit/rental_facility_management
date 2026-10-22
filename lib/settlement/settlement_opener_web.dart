import 'dart:html' as html;
import 'dart:typed_data';

/// Called with prepared bytes directly from a button press. Same-tab navigation
/// keeps the blob in Safari's creating process and avoids blocked data URLs.
Future<void> openSettlementPdf(Uint8List bytes) async {
  if (bytes.isEmpty) throw StateError('Empty PDF');
  final url =
      html.Url.createObjectUrlFromBlob(html.Blob([bytes], 'application/pdf'));
  html.window.location.assign(url);
  Future<void>.delayed(
      const Duration(minutes: 5), () => html.Url.revokeObjectUrl(url));
}
