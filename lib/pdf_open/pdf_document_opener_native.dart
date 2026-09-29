import 'dart:typed_data';

import 'package:printing/printing.dart';

Future<void> openPdfDocument({
  required String fileName,
  required Future<Uint8List> Function() build,
}) async {
  await Printing.layoutPdf(onLayout: (_) => build(), name: fileName);
}

Future<void> openIssuedPdfDocument({
  required String fileName,
  required Future<Uri> Function() resolveUrl,
  required Future<Uint8List> Function() build,
}) async {
  await Printing.layoutPdf(onLayout: (_) => build(), name: fileName);
}
