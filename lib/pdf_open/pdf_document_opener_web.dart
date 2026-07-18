import 'dart:convert';
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
    // Do not navigate the new tab to a blob URL. On iOS Safari the blob can
    // belong to the opener's WebKit process and become unavailable in the new
    // tab, which surfaces as WebKitBlobResource error 1. Generated invoices
    // are small enough to hand off as an in-memory PDF data URL instead.
    final dataUrl = 'data:application/pdf;base64,${base64Encode(bytes)}';
    previewWindow.location.href = dataUrl;
  } catch (_) {
    previewWindow.close();
    rethrow;
  }
}
