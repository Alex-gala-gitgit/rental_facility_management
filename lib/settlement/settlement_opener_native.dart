import 'dart:typed_data';
import 'package:printing/printing.dart';

Future<void> openSettlementPdf(Uint8List bytes) =>
    Printing.layoutPdf(onLayout: (_) async => bytes).then((_) {});
