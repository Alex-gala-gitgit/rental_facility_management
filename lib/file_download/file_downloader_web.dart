import 'dart:async';
import 'dart:convert';
import 'dart:html' as html;
import 'dart:typed_data';

Future<void> downloadTextFile({
  required String fileName,
  required String mimeType,
  required String content,
}) async {
  await downloadBytesFile(
    fileName: fileName,
    mimeType: mimeType,
    bytes: Uint8List.fromList(utf8.encode(content)),
  );
}

Future<void> downloadBytesFile({
  required String fileName,
  required String mimeType,
  required Uint8List bytes,
}) async {
  final blob = html.Blob([bytes], mimeType);
  final url = html.Url.createObjectUrlFromBlob(blob);
  final anchor = html.AnchorElement(href: url)
    ..download = fileName
    ..style.display = 'none';
  html.document.body?.append(anchor);
  anchor.click();
  anchor.remove();
  // Safari may still be reading the blob after the synthetic click returns.
  // Releasing it immediately can cancel the download on iPhone/iPad.
  Timer(const Duration(minutes: 2), () => html.Url.revokeObjectUrl(url));
}
