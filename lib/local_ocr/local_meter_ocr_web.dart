import 'dart:convert';
import 'dart:html' as html;
import 'dart:js_util' as js_util;
import 'dart:typed_data';

import '../cloud/meter_reading_service.dart';

class LocalMeterOcr {
  Future<DetectedMeterReading> read({
    required Uint8List bytes,
    required String fileName,
  }) async {
    final extension = fileName.split('.').last.toLowerCase();
    final mime = extension == 'png' ? 'image/png' : 'image/jpeg';
    final dataUrl = 'data:$mime;base64,${base64Encode(bytes)}';
    final promise = js_util.callMethod<Object>(
      html.window,
      'readMeterText',
      [dataUrl],
    );
    final text = await js_util.promiseToFuture<String>(promise);
    return _extractReading(text);
  }

  DetectedMeterReading _extractReading(String source) {
    final text = source.replaceAll('\n', ' ');
    double? value(RegExp expression) {
      final match = expression.firstMatch(text);
      return match == null
          ? null
          : double.tryParse(
              match.group(1)!.replaceAll(',', '.').replaceAll(' ', ''),
            );
    }

    final previous = value(RegExp(
      r'(?:previous|prev|last)\s*(?:reading)?\s*[:\-]?\s*([0-9]+(?:\.[0-9]+)?)',
      caseSensitive: false,
    ));
    final current = value(RegExp(
      r'(?:current|present|new)\s*(?:reading)?\s*[:\-]?\s*([0-9]+(?:\.[0-9]+)?)',
      caseSensitive: false,
    ));
    final printedUsage = value(RegExp(
      r'(?:usage|consumption|used)\s*[:\-]?\s*([0-9]+(?:\.[0-9]+)?)\s*kwh',
      caseSensitive: false,
    ));
    final displayedKwh = value(RegExp(
      r'([0-9]+(?:[.,]\s*[0-9]+)?)\s*k\s*[wvv]\s*[hn]',
      caseSensitive: false,
    ));
    final prominentDecimal = value(RegExp(
      r'\b([0-9]{1,6}[.,]\s*[0-9]{1,3})\b',
      caseSensitive: false,
    ));
    final focusedSection =
        source.split(RegExp(r'FULL CONTEXT', caseSensitive: false)).first;
    final compactFocusedMatch = RegExp(
      r'(?:FOCUSED READING\s*)\D*([0-9]{3,4})(?![0-9])',
      caseSensitive: false,
    ).firstMatch(focusedSection.replaceAll('\n', ' '));
    // High-contrast OCR can remove a small decimal point. Meter-app usage
    // screenshots commonly render 14.33 as 1433, so restore two decimals
    // only inside the deliberately cropped focused-reading region.
    final compactFocusedUsage = compactFocusedMatch == null
        ? null
        : double.tryParse(compactFocusedMatch.group(1)!)! / 100;
    final usage = printedUsage ??
        (previous != null && current != null && current >= previous
            ? current - previous
            : displayedKwh ?? prominentDecimal ?? compactFocusedUsage);
    if (usage == null) {
      final excerpt = text.replaceAll(RegExp(r'\s+'), ' ').trim();
      final preview =
          excerpt.length > 140 ? excerpt.substring(0, 140) : excerpt;
      throw Exception(
        'The photo was read, but usage could not be identified. Recognized text: ${preview.isEmpty ? '(none)' : preview}',
      );
    }
    return DetectedMeterReading(
      usageKwh: usage,
      previousReading: previous,
      currentReading: current,
      confidence: printedUsage != null
          ? 0.9
          : previous != null && current != null
              ? 0.8
              : compactFocusedUsage != null
                  ? 0.65
                  : 0.75,
    );
  }
}
