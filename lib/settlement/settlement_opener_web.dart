import 'dart:html' as html;
import 'dart:typed_data';

/// Called with prepared bytes directly from a button press. Keep the app in its
/// original tab so closing Safari's PDF preview returns to the settlement page.
Future<void> openSettlementPdf(Uint8List bytes) async {
  if (bytes.isEmpty) throw StateError('Empty PDF');
  final url =
      html.Url.createObjectUrlFromBlob(html.Blob([bytes], 'application/pdf'));
  html.window.open(url, '_blank');
  Future<void>.delayed(
      const Duration(minutes: 5), () => html.Url.revokeObjectUrl(url));
}
