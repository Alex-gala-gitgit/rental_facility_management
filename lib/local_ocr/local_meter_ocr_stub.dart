import 'dart:typed_data';

import '../cloud/meter_reading_service.dart';

class LocalMeterOcr {
  Future<DetectedMeterReading> read({
    required Uint8List bytes,
    required String fileName,
  }) async {
    throw UnsupportedError(
      'Local attachment reading is currently available in the web app.',
    );
  }
}
