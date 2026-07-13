import 'dart:typed_data';

Future<void> downloadTextFile({
  required String fileName,
  required String mimeType,
  required String content,
}) async {
  throw UnsupportedError(
    'Direct file download is only available in the web build. Use Share backup to copy the export content.',
  );
}

Future<void> downloadBytesFile({
  required String fileName,
  required String mimeType,
  required Uint8List bytes,
}) async {
  throw UnsupportedError(
    'Direct file download is only available in the web build. Use Share backup to copy the export content.',
  );
}
