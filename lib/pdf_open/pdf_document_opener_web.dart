import 'dart:async';
import 'dart:html' as html;
import 'dart:typed_data';

Future<void> openPdfDocument({
  required String fileName,
  required Future<Uint8List> Function() build,
}) async {
  // Reserve the tab synchronously while this call still belongs to the user's
  // button press. Browsers otherwise block window.open after PDF generation.
  final previewWindow = html.window.open('', '_blank');
  try {
    final bytes = await build();
    if (bytes.isEmpty) throw StateError('The generated PDF is empty.');
    final blob = html.Blob(<Object>[bytes], 'application/pdf');
    final url = html.Url.createObjectUrlFromBlob(blob);

    previewWindow.location.href = url;
    Timer(const Duration(minutes: 2), () => html.Url.revokeObjectUrl(url));
  } catch (_) {
    previewWindow.close();
    rethrow;
  }
}
