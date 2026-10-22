import 'dart:typed_data';
import 'package:printing/printing.dart';

Future<bool> shareSettlementPdf(Uint8List bytes, String filename) =>
    Printing.sharePdf(bytes: bytes, filename: filename);
