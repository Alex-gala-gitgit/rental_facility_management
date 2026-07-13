import 'dart:convert';
import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

class DetectedMeterReading {
  const DetectedMeterReading({
    required this.usageKwh,
    this.previousReading,
    this.currentReading,
    this.confidence,
  });

  final double usageKwh;
  final double? previousReading;
  final double? currentReading;
  final double? confidence;
}

class MeterReadingService {
  const MeterReadingService(this.client);

  final SupabaseClient client;

  Future<DetectedMeterReading> read({
    required Uint8List bytes,
    required String fileName,
  }) async {
    final extension = fileName.split('.').last.toLowerCase();
    final mimeType = switch (extension) {
      'png' => 'image/png',
      'pdf' => 'application/pdf',
      _ => 'image/jpeg',
    };
    final response = await client.functions.invoke(
      'meter-reading-ocr',
      body: {
        'fileName': fileName,
        'mimeType': mimeType,
        'base64': base64Encode(bytes),
      },
    );
    if (response.status < 200 || response.status >= 300) {
      final data = response.data;
      final message = data is Map ? data['error']?.toString() : null;
      throw Exception(message ?? 'Unable to read the meter attachment.');
    }
    final data = Map<String, dynamic>.from(response.data as Map);
    double? number(String key) => (data[key] as num?)?.toDouble();
    final usage = number('usageKwh');
    if (usage == null || usage < 0) {
      throw Exception('No reliable electricity usage was found.');
    }
    return DetectedMeterReading(
      usageKwh: usage,
      previousReading: number('previousReading'),
      currentReading: number('currentReading'),
      confidence: number('confidence'),
    );
  }
}
